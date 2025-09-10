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
#include <QStandardPaths>
#include "configmanager.h"
#include "oauthmanager.h"

class NotificationPresenter : public QObject
{
    Q_OBJECT
public:
    explicit NotificationPresenter(QObject *parent = nullptr) : QObject(parent) {}
    
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
        
        // Keep the notification object alive for a reasonable time
        QTimer::singleShot(5000, knotification, &KNotification::deleteLater);
        
        // Close the WebEngine notification since we're handling it ourselves
        notification->close();
    }
};

int main(int argc, char *argv[])
{
    // Set Chromium command line arguments for better OAuth compatibility
    qputenv("QTWEBENGINE_CHROMIUM_FLAGS", "--disable-features=VizDisplayCompositor --disable-blink-features=AutomationControlled --exclude-switches=enable-automation");
    
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
    
    // Create config manager instance
    ConfigManager *configManager = new ConfigManager(&app);
    
    // Create OAuth manager instance
    OAuthManager *oauthManager = new OAuthManager(&app);
    
    // Set up a global notification presenter function that can be used by all profiles
    auto globalNotificationPresenter = [notificationPresenter](std::unique_ptr<QWebEngineNotification> notification) {
        notificationPresenter->present(std::move(notification));
    };
    
    QQmlApplicationEngine engine;

    // Register the notification presenter, config manager and OAuth manager with QML context
    engine.rootContext()->setContextProperty(QStringLiteral("notificationPresenter"), notificationPresenter);
    engine.rootContext()->setContextProperty(QStringLiteral("configManager"), configManager);
    engine.rootContext()->setContextProperty(QStringLiteral("oauthManager"), oauthManager);
    
    engine.rootContext()->setContextObject(new KLocalizedContext(&engine));
    engine.loadFromModule("io.github.denysmb.unify", "Main");

    if (engine.rootObjects().isEmpty()) {
        return -1;
    }

    // Set up notification presenter for default profile
    QWebEngineProfile::defaultProfile()->setNotificationPresenter(globalNotificationPresenter);
    
    // Set Firefox user agent for compatibility with Google OAuth (Google blocks WebEngine detection)
    QString firefoxUserAgent = QStringLiteral("Mozilla/5.0 (X11; Ubuntu; Linux x86_64; rv:131.0) Gecko/20100101 Firefox/131.0");
    QWebEngineProfile::defaultProfile()->setHttpUserAgent(firefoxUserAgent);
    
    // Configure additional security settings for OAuth compatibility
    QWebEngineProfile::defaultProfile()->setPersistentCookiesPolicy(QWebEngineProfile::AllowPersistentCookies);
    QWebEngineProfile::defaultProfile()->setHttpCacheType(QWebEngineProfile::DiskHttpCache);
    
    // Enable features that Google OAuth expects
    auto profile = QWebEngineProfile::defaultProfile();
    profile->settings()->setAttribute(QWebEngineSettings::JavascriptEnabled, true);
    profile->settings()->setAttribute(QWebEngineSettings::LocalStorageEnabled, true);
    profile->settings()->setAttribute(QWebEngineSettings::PluginsEnabled, false); // Disable plugins for security
    profile->settings()->setAttribute(QWebEngineSettings::DnsPrefetchEnabled, true);
    profile->settings()->setAttribute(QWebEngineSettings::AllowRunningInsecureContent, false);
    
    // Set proper paths for OAuth providers storage
    profile->setCachePath(QStandardPaths::writableLocation(QStandardPaths::CacheLocation) + QStringLiteral("/webengine"));
    profile->setPersistentStoragePath(QStandardPaths::writableLocation(QStandardPaths::AppDataLocation) + QStringLiteral("/webengine"));
    
    qDebug() << "✅ Notification presenter set up for default profile";
    qDebug() << "✅ Firefox user agent set for default profile (Google OAuth compatibility)";

    return app.exec();
}

#include "main.moc"
