#include "configmanager.h"
#include "faviconcache.h"
#include "keyeventfilter.h"
#include "trayiconmanager.h"
#include <KIconTheme>
#include <KLocalizedContext>
#include <KLocalizedString>
#include <KNotification>
#include <QApplication>
#include <QDebug>
#include <QImage>
#include <QPixmap>
#include <QQmlApplicationEngine>
#include <QQuickStyle>
#include <QUrl>
#include <QWebEngineNotification>
#include <QWebEngineProfile>
#include <QtQml>
#include <QtWebEngineQuick>

class NotificationPresenter : public QObject
{
    Q_OBJECT
public:
    explicit NotificationPresenter(QObject *parent = nullptr)
        : QObject(parent)
    {
    }

    // Present notification from QML with QWebEngineNotification object (includes icon)
    Q_INVOKABLE void presentFromQmlWithNotification(QWebEngineNotification *webNotification, const QString &serviceId)
    {
        if (!webNotification) {
            qDebug() << "❌ presentFromQmlWithNotification called with null notification";
            return;
        }

        QString title = webNotification->title().isEmpty() ? QStringLiteral("Web Notification") : webNotification->title();
        QString message = webNotification->message();
        QImage icon = webNotification->icon();

        qDebug() << "📢 QML-present notification (with icon):";
        qDebug() << "   Title:" << title;
        qDebug() << "   Message:" << message;
        qDebug() << "   Origin:" << webNotification->origin().host();
        qDebug() << "   Service ID:" << serviceId;
        qDebug() << "   Has icon:" << !icon.isNull() << (icon.isNull() ? QStringLiteral("") : QStringLiteral("(%1x%2)").arg(icon.width()).arg(icon.height()));

        auto *notification = new KNotification(QStringLiteral("notification"), KNotification::CloseOnTimeout, this);
        notification->setComponentName(QStringLiteral("unify"));
        notification->setTitle(title);
        notification->setText(message);

        // Use the icon from the web notification if available, otherwise use default icon
        if (!icon.isNull()) {
            notification->setPixmap(QPixmap::fromImage(icon));
        } else {
            notification->setIconName(QStringLiteral("dialog-information"));
        }

        // Add a default action that will be triggered when the notification is clicked
        KNotificationAction *defaultAction = notification->addDefaultAction(QStringLiteral("Open"));

        // Connect the action's activated signal to emit our notificationClicked signal
        connect(defaultAction, &KNotificationAction::activated, this, [this, serviceId]() {
            qDebug() << "📢 Notification clicked for service:" << serviceId;
            if (!serviceId.isEmpty()) {
                Q_EMIT notificationClicked(serviceId);
            }
        });

        notification->sendEvent();

        // Close the web notification
        webNotification->close();
    }

    // Fallback method without icon (for compatibility)
    Q_INVOKABLE void presentFromQml(const QString &titleIn, const QString &messageIn, const QUrl &originUrl, const QString &serviceId)
    {
        QString title = titleIn.isEmpty() ? QStringLiteral("Web Notification") : titleIn;
        QString message = messageIn;

        qDebug() << "📢 QML-present notification (fallback):";
        qDebug() << "   Title:" << title;
        qDebug() << "   Message:" << message;
        qDebug() << "   Origin:" << originUrl.host();
        qDebug() << "   Service ID:" << serviceId;

        auto *notification = new KNotification(QStringLiteral("notification"), KNotification::CloseOnTimeout, this);
        notification->setComponentName(QStringLiteral("unify"));
        notification->setTitle(title);
        notification->setText(message);
        notification->setIconName(QStringLiteral("dialog-information"));

        // Add a default action that will be triggered when the notification is clicked
        KNotificationAction *defaultAction = notification->addDefaultAction(QStringLiteral("Open"));

        // Connect the action's activated signal to emit our notificationClicked signal
        connect(defaultAction, &KNotificationAction::activated, this, [this, serviceId]() {
            qDebug() << "📢 Notification clicked for service:" << serviceId;
            if (!serviceId.isEmpty()) {
                Q_EMIT notificationClicked(serviceId);
            }
        });

        notification->sendEvent();
    }

    void present(std::unique_ptr<QWebEngineNotification> notification, const QString &serviceId = QString())
    {
        if (!notification) {
            qDebug() << "❌ Notification presenter called with null notification";
            return;
        }

        QString title = notification->title().isEmpty() ? QStringLiteral("Web Notification") : notification->title();
        QString message = notification->message();

        qDebug() << "📢 Notification presenter called:";
        qDebug() << "   Title:" << title;
        qDebug() << "   Message:" << message;
        qDebug() << "   Origin:" << notification->origin().host();
        qDebug() << "   Service ID:" << serviceId;

        auto *knotification = new KNotification(QStringLiteral("notification"), KNotification::CloseOnTimeout, this);
        knotification->setComponentName(QStringLiteral("unify"));
        knotification->setTitle(title);
        knotification->setText(message);
        knotification->setIconName(QStringLiteral("dialog-information"));

        // Add a default action that will be triggered when the notification is clicked
        KNotificationAction *defaultAction = knotification->addDefaultAction(QStringLiteral("Open"));

        // Connect the action's activated signal to emit our notificationClicked signal
        connect(defaultAction, &KNotificationAction::activated, this, [this, serviceId]() {
            qDebug() << "📢 Notification clicked for service:" << serviceId;
            if (!serviceId.isEmpty()) {
                Q_EMIT notificationClicked(serviceId);
            }
        });

        knotification->sendEvent();

        notification->close();
    }

Q_SIGNALS:
    void notificationClicked(const QString &serviceId);
};

int main(int argc, char *argv[])
{
    // Set Chromium command line arguments for better OAuth/Google compatibility
    // These flags help avoid detection as an automated/embedded browser
    // Chromium flags with GPU acceleration disabled to prevent freezing on some systems
    qputenv("QTWEBENGINE_CHROMIUM_FLAGS",
            "--disable-blink-features=AutomationControlled "
            "--disable-gpu "
            "--disable-gpu-compositing "
            "--disable-features=VizDisplayCompositor "
            "--disable-web-security=false "
            "--enable-features=NetworkService,NetworkServiceInProcess "
            "--disable-background-networking=false "
            "--disable-client-side-phishing-detection "
            "--disable-default-apps "
            "--disable-extensions "
            "--disable-hang-monitor "
            "--disable-popup-blocking "
            "--disable-prompt-on-repost "
            "--disable-sync "
            "--metrics-recording-only "
            "--no-first-run "
            "--safebrowsing-disable-auto-update");

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

    // Create tray icon manager instance
    TrayIconManager *trayIconManager = new TrayIconManager(&app);

    // Create favicon cache instance
    FaviconCache *faviconCache = new FaviconCache(&app);

    // Create key event filter for double Ctrl detection
    KeyEventFilter *keyEventFilter = new KeyEventFilter(&app);
    app.installEventFilter(keyEventFilter);

    // Create notification presenter instance
    NotificationPresenter *notificationPresenter = new NotificationPresenter(&app);

    // Set up a global notification presenter function that can be used by all profiles
    // Note: This is used by the default profile, but QML profiles use presentFromQml instead
    auto globalNotificationPresenter = [notificationPresenter](std::unique_ptr<QWebEngineNotification> notification) {
        notificationPresenter->present(std::move(notification));
    };

    // Configure the default profile BEFORE any QML is loaded
    // Note: The default profile is already disk-based (not off-the-record)
    // In Qt 6, profile type is determined by constructor, not setter methods
    auto *defaultProf = QWebEngineProfile::defaultProfile();

    // Configure persistence settings
    defaultProf->setHttpCacheType(QWebEngineProfile::DiskHttpCache);
    defaultProf->setPersistentCookiesPolicy(QWebEngineProfile::ForcePersistentCookies);

    // Set user agent for compatibility - Firefox simulation
    defaultProf->setHttpUserAgent(QStringLiteral("Mozilla/5.0 (X11; Linux x86_64; rv:145.0) Gecko/20100101 Firefox/145.0"));

    // Set up notification presenter
    defaultProf->setNotificationPresenter(globalNotificationPresenter);

    qDebug() << "Default WebEngineProfile configured:";
    qDebug() << "  Storage name:" << defaultProf->storageName();
    qDebug() << "  Off-the-record:" << defaultProf->isOffTheRecord();
    qDebug() << "  Persistent storage path:" << defaultProf->persistentStoragePath();
    qDebug() << "  Cache path:" << defaultProf->cachePath();

    QQmlApplicationEngine engine;

    // Register the notification presenter, config manager, tray icon manager, favicon cache and key event filter with QML context
    engine.rootContext()->setContextProperty(QStringLiteral("notificationPresenter"), notificationPresenter);
    engine.rootContext()->setContextProperty(QStringLiteral("configManager"), configManager);
    engine.rootContext()->setContextProperty(QStringLiteral("trayIconManager"), trayIconManager);
    engine.rootContext()->setContextProperty(QStringLiteral("faviconCache"), faviconCache);
    engine.rootContext()->setContextProperty(QStringLiteral("keyEventFilter"), keyEventFilter);

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
