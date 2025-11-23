#include "configmanager.h"
#include "oauthmanager.h"
#include "trayiconmanager.h"
#include <KIconTheme>
#include <KLocalizedContext>
#include <KLocalizedString>
#include <KNotification>
#include <QApplication>
#include <QDBusInterface>
#include <QDBusReply>
#include <QDebug>
#include <QDir>
#include <QProcess>
#include <QQmlApplicationEngine>
#include <QQuickStyle>
#include <QStandardPaths>
#include <QSystemTrayIcon>
#include <QTimer>
#include <QUrl>
#include <QWebEngineNotification>
#include <QWebEngineProfile>
#include <QtQml>
#include <QtWebEngineQuick>

class NotificationPresenter : public QObject
{
    Q_OBJECT
public:
    explicit NotificationPresenter(QObject *parent = nullptr, TrayIconManager *trayManager = nullptr)
        : QObject(parent)
        , m_trayManager(trayManager)
    {
    }
    Q_INVOKABLE void presentFromQml(const QString &titleIn, const QString &messageIn, const QUrl &originUrl)
    {
        QString title = titleIn.isEmpty() ? QStringLiteral("Web Notification") : titleIn;
        QString message = messageIn;
        QString origin = originUrl.host();

        qDebug() << "📢 QML-present notification:";
        qDebug() << "   Title:" << title;
        qDebug() << "   Message:" << message;
        qDebug() << "   Origin:" << origin;
        qDebug() << "   URL:" << originUrl.toString();

        KNotification *knotification = new KNotification(QStringLiteral("notification"));
        knotification->setTitle(title);
        knotification->setText(message);
        knotification->setIconName(QStringLiteral("dialog-information"));
        knotification->setComponentName(QStringLiteral("unify"));
        knotification->setFlags(KNotification::Persistent);
        knotification->sendEvent();
        qDebug() << "📢 KNotification sent (QML)";

        QDBusInterface interface(QStringLiteral("org.freedesktop.Notifications"),
                                 QStringLiteral("/org/freedesktop/Notifications"),
                                 QStringLiteral("org.freedesktop.Notifications"));
        if (interface.isValid()) {
            QDBusReply<uint> reply = interface.call(QStringLiteral("Notify"),
                                                    QStringLiteral("Unify"),
                                                    uint(0),
                                                    QStringLiteral("dialog-information"),
                                                    title,
                                                    message,
                                                    QStringList(),
                                                    QVariantMap(),
                                                    int(5000));
            if (reply.isValid()) {
                qDebug() << "📢 DBus notification sent with ID (QML):" << reply.value();
            } else {
                qDebug() << "❌ DBus notification failed (QML):" << reply.error().message();
            }
        }

        // Use the existing tray icon manager to show notification
        if (m_trayManager) {
            m_trayManager->showNotification(title, message);
        }

        QTimer::singleShot(5000, knotification, &KNotification::deleteLater);
    }

    void present(std::unique_ptr<QWebEngineNotification> notification)
    {
        if (!notification) {
            qDebug() << "❌ Notification presenter called with null notification";
            return;
        }

        QString title = notification->title().isEmpty() ? QStringLiteral("Web Notification") : notification->title();
        QString message = notification->message();
        QString origin = notification->origin().host();

        qDebug() << "📢 Notification presenter called:";
        qDebug() << "   Title:" << title;
        qDebug() << "   Message:" << message;
        qDebug() << "   Origin:" << origin;
        qDebug() << "   URL:" << notification->origin().toString();

        // Try KNotification first
        KNotification *knotification = new KNotification(QStringLiteral("notification"));
        knotification->setTitle(title);
        knotification->setText(message);
        knotification->setIconName(QStringLiteral("dialog-information"));
        knotification->setComponentName(QStringLiteral("unify"));
        knotification->setFlags(KNotification::Persistent);
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

        // Use the existing tray icon manager to show notification
        if (m_trayManager) {
            m_trayManager->showNotification(title, message);
        }

        // Keep the notification object alive for a reasonable time
        QTimer::singleShot(5000, knotification, &KNotification::deleteLater);

        // Close the WebEngine notification since we're handling it ourselves
        notification->close();
    }

private:
    TrayIconManager *m_trayManager;
};

int main(int argc, char *argv[])
{
    // Set Chromium command line arguments for better OAuth compatibility
    qputenv("QTWEBENGINE_CHROMIUM_FLAGS",
            "--disable-features=VizDisplayCompositor --disable-blink-features=AutomationControlled --exclude-switches=enable-automation");

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

    // Create config manager instance
    ConfigManager *configManager = new ConfigManager(&app);

    // Create OAuth manager instance
    OAuthManager *oauthManager = new OAuthManager(&app);

    // Create tray icon manager instance
    TrayIconManager *trayIconManager = new TrayIconManager(&app);

    // Create notification presenter instance with tray manager reference
    NotificationPresenter *notificationPresenter = new NotificationPresenter(&app, trayIconManager);

    // Set up a global notification presenter function that can be used by all profiles
    auto globalNotificationPresenter = [notificationPresenter](std::unique_ptr<QWebEngineNotification> notification) {
        notificationPresenter->present(std::move(notification));
    };

    // Set up notification presenter for default profile and configure persistence
    auto *defaultProf = QWebEngineProfile::defaultProfile();
    defaultProf->setNotificationPresenter(globalNotificationPresenter);
    // Ensure data is persisted on disk (cookies, cache, storage)
    const QString dataDir = QStandardPaths::writableLocation(QStandardPaths::AppDataLocation) + QStringLiteral("/webengine/default");
    QDir().mkpath(dataDir + QStringLiteral("/cache"));
    QDir().mkpath(dataDir + QStringLiteral("/storage"));
    defaultProf->setCachePath(dataDir + QStringLiteral("/cache"));
    defaultProf->setPersistentStoragePath(dataDir + QStringLiteral("/storage"));
    defaultProf->setPersistentCookiesPolicy(QWebEngineProfile::ForcePersistentCookies);

    QQmlApplicationEngine engine;

    // Register the notification presenter, config manager, OAuth manager and tray icon manager with QML context
    engine.rootContext()->setContextProperty(QStringLiteral("notificationPresenter"), notificationPresenter);
    engine.rootContext()->setContextProperty(QStringLiteral("configManager"), configManager);
    engine.rootContext()->setContextProperty(QStringLiteral("oauthManager"), oauthManager);
    engine.rootContext()->setContextProperty(QStringLiteral("trayIconManager"), trayIconManager);

    engine.rootContext()->setContextObject(new KLocalizedContext(&engine));
    engine.loadFromModule("io.github.denysmb.unify", "Main");

    if (engine.rootObjects().isEmpty()) {
        return -1;
    }

    // Get the main window and set it in tray icon manager
    QObject *rootObject = engine.rootObjects().first();
    if (rootObject) {
        QWindow *mainWindow = qobject_cast<QWindow *>(rootObject);
        if (mainWindow) {
            trayIconManager->setMainWindow(mainWindow);
        }
    }

    // Show the tray icon
    trayIconManager->show();

    return app.exec();
}

#include "main.moc"
