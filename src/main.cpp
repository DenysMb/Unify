#include "core/configmanager.h"
#include "core/notificationpresenter.h"
#include "ui/trayiconmanager.h"
#include "utils/faviconcache.h"
#include "utils/fileutils.h"
#include "utils/keyeventfilter.h"
#include "utils/printhandler.h"
#include "utils/widevinemanager.h"
#include <KIconTheme>
#include <KLocalizedContext>
#include <KLocalizedString>
#include <QApplication>
#include <QDebug>
#include <QDir>
#include <QQmlApplicationEngine>
#include <QQuickStyle>
#include <QUrl>
#include <QWebEngineNotification>
#include <QWebEngineProfile>
#include <QtQml>
#include <QtWebEngineQuick>

// Helper function to find installed Widevine library path
static QString findWidevinePath()
{
    const QString homePath = QDir::homePath();
    const QString widevinePath = homePath + QStringLiteral("/.var/app/io.github.denysmb.unify/plugins/WidevineCdm");
    QDir widevineDir(widevinePath);

    if (!widevineDir.exists()) {
        return QString();
    }

    // Look for version directories (e.g., 4.10.2830.0)
    const QStringList entries = widevineDir.entryList(QDir::Dirs | QDir::NoDotAndDotDot);
    for (const QString &entry : entries) {
        // Check if this looks like a version number
        if (entry.contains(QLatin1Char('.')) && !entry.isEmpty() && entry.at(0).isDigit()) {
            const QString libPath =
                widevinePath + QLatin1Char('/') + entry + QStringLiteral("/_platform_specific/linux_x64/libwidevinecdm.so");
            if (QFile::exists(libPath)) {
                return libPath;
            }
        }
    }

    return QString();
}

int main(int argc, char *argv[])
{
    // Check if Widevine is installed
    const QString widevinePath = findWidevinePath();
    const bool isInFlatpak = QFile::exists(QStringLiteral("/.flatpak-info")) || !qEnvironmentVariableIsEmpty("FLATPAK_ID");

    // Set Chromium command line arguments for better OAuth/Google compatibility
    // These flags help avoid detection as an automated/embedded browser
    // Chromium flags with GPU acceleration disabled to prevent freezing on some systems
    // WebRTCPipeWireCapturer enables screen/window sharing via PipeWire on Wayland
    QByteArray chromiumFlags;

    if (qEnvironmentVariableIsEmpty("QTWEBENGINE_CHROMIUM_FLAGS")) {
        // No flags set, use our defaults
        chromiumFlags =
            "--disable-blink-features=AutomationControlled "
            "--disable-gpu "
            "--disable-gpu-compositing "
            "--disable-features=VizDisplayCompositor "
            "--disable-web-security=false "
            "--enable-features=NetworkService,NetworkServiceInProcess,WebRTCPipeWireCapturer,HardwareMediaDecoding,PlatformEncryptedDolbyVision,PlatformHEVCEncoderSupport "
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
            "--safebrowsing-disable-auto-update "
            "--enable-widevine-cdm "
            "--autoplay-policy=no-user-gesture-required";
    } else {
        // Flags already set (e.g., by Flatpak manifest), use them as base
        chromiumFlags = qgetenv("QTWEBENGINE_CHROMIUM_FLAGS");
    }

    // Add Widevine path if installed and not already present in flags
    if (!widevinePath.isEmpty() && !chromiumFlags.contains("--widevine-path=")) {
        qDebug() << "Found Widevine at:" << widevinePath;
        chromiumFlags += " --widevine-path=" + widevinePath.toUtf8();

        // Add --no-sandbox flag required for Widevine in Flatpak (if not already present)
        if (isInFlatpak && !chromiumFlags.contains("--no-sandbox")) {
            chromiumFlags += " --no-sandbox";
        }
    }

    qputenv("QTWEBENGINE_CHROMIUM_FLAGS", chromiumFlags);
    qDebug() << "QTWEBENGINE_CHROMIUM_FLAGS:" << chromiumFlags;

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

    // Create file utils instance
    FileUtils *fileUtils = new FileUtils(&app);

    // Create print handler instance
    PrintHandler *printHandler = new PrintHandler(&app);

    // Create widevine manager instance
    WidevineManager *widevineManager = new WidevineManager(&app);

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

    // Register the notification presenter, config manager, tray icon manager, favicon cache, key event filter, application shortcut manager and file utils with QML context
    engine.rootContext()->setContextProperty(QStringLiteral("notificationPresenter"), notificationPresenter);
    engine.rootContext()->setContextProperty(QStringLiteral("configManager"), configManager);
    engine.rootContext()->setContextProperty(QStringLiteral("trayIconManager"), trayIconManager);
    engine.rootContext()->setContextProperty(QStringLiteral("faviconCache"), faviconCache);
    engine.rootContext()->setContextProperty(QStringLiteral("keyEventFilter"), keyEventFilter);
    engine.rootContext()->setContextProperty(QStringLiteral("fileUtils"), fileUtils);
    engine.rootContext()->setContextProperty(QStringLiteral("printHandler"), printHandler);
    engine.rootContext()->setContextProperty(QStringLiteral("widevineManager"), widevineManager);

    engine.rootContext()->setContextObject(new KLocalizedContext(&engine));
    engine.loadFromModule("io.github.denysmb.unify", "Main");

    if (engine.rootObjects().isEmpty()) {
        return -1;
    }

    // Get the main window and set it in tray icon manager
    QObject *rootObject = engine.rootObjects().first();
    QWindow *mainWindow = nullptr;
    if (rootObject) {
        mainWindow = qobject_cast<QWindow *>(rootObject);
        if (mainWindow) {
            trayIconManager->setMainWindow(mainWindow);
        }
    }

    // Show the tray icon
    trayIconManager->show();

    return app.exec();
}
