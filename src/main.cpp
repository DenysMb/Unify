#include <QApplication>
#include <QQmlApplicationEngine>
#include <QtQml>
#include <QUrl>
#include <QQuickStyle>
#include <KLocalizedContext>
#include <KLocalizedString>
#include <KIconTheme>
#include <QtWebEngineQuick>
#include <QWebEngineProfile>
#include <QWebEngineNotification>
#include <KNotification>
#include <QTimer>
#include <QDebug>
#include <QSystemTrayIcon>
#include <QProcess>
#include <QDBusInterface>
#include <QDBusReply>

class NotificationPresenter : public QObject
{
    Q_OBJECT
public:
    explicit NotificationPresenter(QObject *parent = nullptr) : QObject(parent) {}
    
    void present(std::unique_ptr<QWebEngineNotification> notification)
    {
        if (!notification) return;
        
        QString title = notification->title().isEmpty() ? QStringLiteral("Web Notification") : notification->title();
        QString message = notification->message();
        QString origin = notification->origin().host();
        
        qDebug() << "📢 Attempting to display notification:" << title << "from" << origin;
        
        // Try KNotification first
        KNotification *knotification = new KNotification(QStringLiteral("notification"));
        knotification->setTitle(title);
        knotification->setText(message);
        knotification->setIconName(QStringLiteral("dialog-information"));
        knotification->setComponentName(QStringLiteral("unify"));
        knotification->setFlags(KNotification::CloseOnTimeout);
        knotification->sendEvent();
        qDebug() << "📢 KNotification sent";
        
        // Try DBus notification
        QDBusInterface interface(QStringLiteral("org.freedesktop.Notifications"), 
                                QStringLiteral("/org/freedesktop/Notifications"), 
                                QStringLiteral("org.freedesktop.Notifications"));
        if (interface.isValid()) {
            QDBusReply<uint> reply = interface.call(QStringLiteral("Notify"), 
                                                   QStringLiteral("Unify"), // app name
                                                   uint(0), // replaces id
                                                   QStringLiteral("dialog-information"), // icon
                                                   title, // summary
                                                   message, // body
                                                   QStringList(), // actions
                                                   QVariantMap(), // hints
                                                   int(5000)); // timeout
            if (reply.isValid()) {
                qDebug() << "📢 DBus notification sent with ID:" << reply.value();
            } else {
                qDebug() << "❌ DBus notification failed:" << reply.error().message();
            }
        } else {
            qDebug() << "❌ DBus notification interface not available";
        }
        
        // Try system tray notification as fallback
        if (QSystemTrayIcon::isSystemTrayAvailable()) {
            // Create a temporary system tray icon for the notification
            auto trayIcon = new QSystemTrayIcon(this);
            trayIcon->show(); // Must show the tray icon first
            trayIcon->showMessage(title, message, QSystemTrayIcon::Information, 5000);
            qDebug() << "📢 System tray notification sent";
            // Clean up the tray icon after the message
            QTimer::singleShot(6000, trayIcon, &QSystemTrayIcon::deleteLater);
        } else {
            qDebug() << "❌ System tray not available";
        }
        
        // Final fallback: use notify-send command
        QProcess *process = new QProcess(this);
        process->start(QStringLiteral("notify-send"), QStringList() << title << message);
        process->waitForFinished(1000);
        if (process->exitCode() == 0) {
            qDebug() << "📢 notify-send command succeeded";
        } else {
            qDebug() << "❌ notify-send failed:" << process->errorString();
        }
        process->deleteLater();
        
        // Keep the notification object alive for a reasonable time
        QTimer::singleShot(5000, knotification, &KNotification::deleteLater);
        
        // Close the WebEngine notification since we're handling it ourselves
        notification->close();
    }
};

int main(int argc, char *argv[])
{
    // Initialize WebEngine before QApplication
    QtWebEngineQuick::initialize();
    
    KIconTheme::initTheme();
    QApplication app(argc, argv);
    KLocalizedString::setApplicationDomain("unify");
    QApplication::setOrganizationName(QStringLiteral("io.github.denysmb"));
    QApplication::setOrganizationDomain(QStringLiteral("io.github.denysmb"));
    QApplication::setApplicationName(QStringLiteral("Unify"));
    QApplication::setDesktopFileName(QStringLiteral("io.github.denysmb.unify"));

    QApplication::setStyle(QStringLiteral("breeze"));
    if (qEnvironmentVariableIsEmpty("QT_QUICK_CONTROLS_STYLE")) {
        QQuickStyle::setStyle(QStringLiteral("org.kde.desktop"));
    }

    // Create notification presenter instance
    NotificationPresenter *notificationPresenter = new NotificationPresenter(&app);
    
    // Set up a global notification presenter function that can be used by all profiles
    auto globalNotificationPresenter = [notificationPresenter](std::unique_ptr<QWebEngineNotification> notification) {
        notificationPresenter->present(std::move(notification));
    };
    
    QQmlApplicationEngine engine;

    // Register the notification presenter with QML context so it can be accessed
    engine.rootContext()->setContextProperty(QStringLiteral("notificationPresenter"), notificationPresenter);
    
    engine.rootContext()->setContextObject(new KLocalizedContext(&engine));
    engine.loadFromModule("io.github.denysmb.unify", "Main");

    if (engine.rootObjects().isEmpty()) {
        return -1;
    }

    // Set up notification presenter for default profile
    QWebEngineProfile::defaultProfile()->setNotificationPresenter(globalNotificationPresenter);
    qDebug() << "✅ Notification presenter set up for default profile";

    return app.exec();
}

#include "main.moc"
