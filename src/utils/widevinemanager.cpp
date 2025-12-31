#include "widevinemanager.h"

#include <KLocalizedString>
#include <KZip>
#include <QCoreApplication>
#include <QDebug>
#include <QDir>
#include <QFile>
#include <QFileInfo>
#include <QJsonDocument>
#include <QJsonObject>
#include <QNetworkRequest>
#include <QProcess>
#include <QSaveFile>
#include <QStandardPaths>

WidevineManager::WidevineManager(QObject *parent)
    : QObject(parent)
    , m_networkManager(new QNetworkAccessManager(this))
{
    checkInstallation();
}

bool WidevineManager::isInstalled() const
{
    return m_isInstalled;
}

bool WidevineManager::isInstalling() const
{
    return m_isInstalling;
}

QString WidevineManager::installedVersion() const
{
    return m_installedVersion;
}

QString WidevineManager::statusMessage() const
{
    return m_statusMessage;
}

int WidevineManager::downloadProgress() const
{
    return m_downloadProgress;
}

bool WidevineManager::isRunningInFlatpak() const
{
    return QFile::exists(QStringLiteral("/.flatpak-info")) || !qEnvironmentVariableIsEmpty("FLATPAK_ID");
}

QString WidevineManager::getPluginsPath() const
{
    // Widevine is installed at ~/.var/app/io.github.denysmb.unify/plugins
    const QString homePath = QDir::homePath();
    return homePath + QStringLiteral("/.var/app/io.github.denysmb.unify/plugins");
}

QString WidevineManager::getWidevinePath() const
{
    return getPluginsPath() + QStringLiteral("/WidevineCdm");
}

QString WidevineManager::findInstalledVersion() const
{
    const QString widevinePath = getWidevinePath();
    QDir widevineDir(widevinePath);

    if (!widevineDir.exists()) {
        return QString();
    }

    // Look for version directories (e.g., 4.10.2830.0)
    const QStringList entries = widevineDir.entryList(QDir::Dirs | QDir::NoDotAndDotDot);
    for (const QString &entry : entries) {
        // Check if this looks like a version number (contains dots and numbers)
        if (entry.contains(QLatin1Char('.')) && !entry.isEmpty() && entry.at(0).isDigit()) {
            // Verify the library exists in this version
            const QString libPath =
                widevinePath + QLatin1Char('/') + entry + QStringLiteral("/_platform_specific/linux_x64/libwidevinecdm.so");
            if (QFile::exists(libPath)) {
                return entry;
            }
        }
    }

    return QString();
}

void WidevineManager::checkInstallation()
{
    const QString version = findInstalledVersion();
    const bool wasInstalled = m_isInstalled;
    const QString oldVersion = m_installedVersion;

    m_installedVersion = version;
    m_isInstalled = !version.isEmpty();

    if (wasInstalled != m_isInstalled) {
        Q_EMIT isInstalledChanged();
    }
    if (oldVersion != m_installedVersion) {
        Q_EMIT installedVersionChanged();
    }
}

void WidevineManager::setStatusMessage(const QString &message)
{
    if (m_statusMessage != message) {
        m_statusMessage = message;
        Q_EMIT statusMessageChanged();
    }
}

void WidevineManager::setDownloadProgress(int progress)
{
    if (m_downloadProgress != progress) {
        m_downloadProgress = progress;
        Q_EMIT downloadProgressChanged();
    }
}

void WidevineManager::install()
{
    if (m_isInstalling) {
        qWarning() << "Installation already in progress";
        return;
    }

    m_isInstalling = true;
    Q_EMIT isInstallingChanged();
    Q_EMIT installationStarted();

    setStatusMessage(i18n("Fetching Widevine metadata..."));
    setDownloadProgress(0);

    // Create temporary directory for downloads
    m_tempDir = new QTemporaryDir();
    if (!m_tempDir->isValid()) {
        finishInstallation(false, i18n("Failed to create temporary directory"));
        return;
    }

    // Step 1: Download metadata JSON from Firefox repository
    QNetworkRequest request(QUrl(QString::fromLatin1(FIREFOX_WIDEVINE_JSON)));
    request.setHeader(QNetworkRequest::UserAgentHeader, QStringLiteral("Mozilla/5.0"));

    m_currentReply = m_networkManager->get(request);
    connect(m_currentReply, &QNetworkReply::finished, this, &WidevineManager::onMetadataReceived);
    connect(m_currentReply, &QNetworkReply::errorOccurred, this, &WidevineManager::onNetworkError);
}

void WidevineManager::onMetadataReceived()
{
    if (!m_currentReply) {
        return;
    }

    if (m_currentReply->error() != QNetworkReply::NoError) {
        m_currentReply->deleteLater();
        m_currentReply = nullptr;
        return; // Error handled by onNetworkError
    }

    const QByteArray data = m_currentReply->readAll();
    m_currentReply->deleteLater();
    m_currentReply = nullptr;

    // Parse JSON
    QJsonParseError parseError;
    const QJsonDocument doc = QJsonDocument::fromJson(data, &parseError);

    if (parseError.error != QJsonParseError::NoError) {
        finishInstallation(false, i18n("Failed to parse Widevine metadata: %1", parseError.errorString()));
        return;
    }

    const QJsonObject root = doc.object();

    // Extract version from "name" field (e.g., "Widevine-4.10.2830.0")
    const QString name = root[QStringLiteral("name")].toString();
    if (name.contains(QLatin1Char('-'))) {
        m_widevineVersion = name.section(QLatin1Char('-'), 1);
    }

    // Get Linux x64 platform info
    const QJsonObject vendors = root[QStringLiteral("vendors")].toObject();
    const QJsonObject gmpWidevine = vendors[QStringLiteral("gmp-widevinecdm")].toObject();
    const QJsonObject platforms = gmpWidevine[QStringLiteral("platforms")].toObject();
    const QJsonObject linuxPlatform = platforms[QStringLiteral("Linux_x86_64-gcc3")].toObject();

    m_widevineUrl = linuxPlatform[QStringLiteral("fileUrl")].toString();
    m_widevineHash = linuxPlatform[QStringLiteral("hashValue")].toString();

    if (m_widevineUrl.isEmpty() || m_widevineVersion.isEmpty()) {
        finishInstallation(false, i18n("Failed to extract Widevine download information"));
        return;
    }

    qDebug() << "Widevine version:" << m_widevineVersion;
    qDebug() << "Widevine URL:" << m_widevineUrl;

    // Check if already installed
    const QString installDir = getWidevinePath() + QLatin1Char('/') + m_widevineVersion;
    const QString libPath = installDir + QStringLiteral("/_platform_specific/linux_x64/libwidevinecdm.so");

    if (QFile::exists(libPath)) {
        finishInstallation(true, i18n("Widevine %1 is already installed.", m_widevineVersion));
        return;
    }

    // Step 2: Download the .crx3 file
    setStatusMessage(i18n("Downloading Widevine CDM %1...", m_widevineVersion));

    QNetworkRequest downloadRequest{QUrl(m_widevineUrl)};
    downloadRequest.setHeader(QNetworkRequest::UserAgentHeader, QStringLiteral("Mozilla/5.0"));

    m_currentReply = m_networkManager->get(downloadRequest);
    connect(m_currentReply, &QNetworkReply::downloadProgress, this, &WidevineManager::onDownloadProgress);
    connect(m_currentReply, &QNetworkReply::finished, this, &WidevineManager::onDownloadFinished);
    connect(m_currentReply, &QNetworkReply::errorOccurred, this, &WidevineManager::onNetworkError);
}

void WidevineManager::onDownloadProgress(qint64 bytesReceived, qint64 bytesTotal)
{
    if (bytesTotal > 0) {
        setDownloadProgress(static_cast<int>((bytesReceived * 100) / bytesTotal));
    }
}

void WidevineManager::onDownloadFinished()
{
    if (!m_currentReply || !m_tempDir) {
        return;
    }

    if (m_currentReply->error() != QNetworkReply::NoError) {
        m_currentReply->deleteLater();
        m_currentReply = nullptr;
        return; // Error handled by onNetworkError
    }

    setStatusMessage(i18n("Extracting Widevine CDM..."));
    setDownloadProgress(100);

    // Save downloaded file
    const QString crxPath = m_tempDir->path() + QStringLiteral("/widevine.crx3");
    QSaveFile crxFile(crxPath);

    if (!crxFile.open(QIODevice::WriteOnly)) {
        m_currentReply->deleteLater();
        m_currentReply = nullptr;
        finishInstallation(false, i18n("Failed to save downloaded file"));
        return;
    }

    crxFile.write(m_currentReply->readAll());

    if (!crxFile.commit()) {
        m_currentReply->deleteLater();
        m_currentReply = nullptr;
        finishInstallation(false, i18n("Failed to save downloaded file"));
        return;
    }

    m_currentReply->deleteLater();
    m_currentReply = nullptr;

    // Step 3: Extract the .crx3 file
    const QString extractDir = m_tempDir->path() + QStringLiteral("/extracted");
    QDir().mkpath(extractDir);

    if (!extractCrx3(crxPath, extractDir)) {
        finishInstallation(false, i18n("Failed to extract Widevine CDM archive"));
        return;
    }

    // Step 4: Install files to destination
    setStatusMessage(i18n("Installing Widevine files..."));

    const QString installDir = getWidevinePath() + QLatin1Char('/') + m_widevineVersion;

    if (!copyWidevineFiles(extractDir, installDir)) {
        finishInstallation(false, i18n("Failed to install Widevine files"));
        return;
    }

    // Step 5: Configure Flatpak environment (if running in Flatpak)
    const QString libPath = installDir + QStringLiteral("/_platform_specific/linux_x64/libwidevinecdm.so");
    configureEnvironment(libPath);

    finishInstallation(true, i18n("Widevine %1 installed successfully! Please restart Unify to enable DRM content playback.", m_widevineVersion));
}

void WidevineManager::onNetworkError(QNetworkReply::NetworkError error)
{
    Q_UNUSED(error)

    QString errorMsg;
    if (m_currentReply) {
        errorMsg = m_currentReply->errorString();
        m_currentReply->deleteLater();
        m_currentReply = nullptr;
    }

    finishInstallation(false, i18n("Network error: %1", errorMsg));
}

bool WidevineManager::extractCrx3(const QString &crxPath, const QString &destDir)
{
    // CRX3 files are ZIP archives with a header
    // We need to find where the ZIP data starts

    QFile crxFile(crxPath);
    if (!crxFile.open(QIODevice::ReadOnly)) {
        qWarning() << "Failed to open CRX3 file";
        return false;
    }

    QByteArray data = crxFile.readAll();
    crxFile.close();

    // Find the ZIP signature (PK\x03\x04)
    const QByteArray zipSignature = QByteArray::fromHex("504B0304");
    int zipStart = data.indexOf(zipSignature);

    if (zipStart < 0) {
        qWarning() << "Could not find ZIP signature in CRX3 file";
        return false;
    }

    qDebug() << "ZIP data starts at offset:" << zipStart;

    // Write the ZIP portion to a temporary file
    const QString zipPath = m_tempDir->path() + QStringLiteral("/widevine.zip");
    QFile zipFile(zipPath);

    if (!zipFile.open(QIODevice::WriteOnly)) {
        qWarning() << "Failed to create temporary ZIP file";
        return false;
    }

    zipFile.write(data.mid(zipStart));
    zipFile.close();

    // Extract using KZip
    KZip zip(zipPath);
    if (!zip.open(QIODevice::ReadOnly)) {
        qWarning() << "Failed to open ZIP archive";
        return false;
    }

    const KArchiveDirectory *root = zip.directory();
    if (!root) {
        qWarning() << "Failed to get archive root directory";
        zip.close();
        return false;
    }

    // Extract all files
    root->copyTo(destDir);
    zip.close();

    // Verify extraction
    const QString libPath = destDir + QStringLiteral("/_platform_specific/linux_x64/libwidevinecdm.so");
    if (!QFile::exists(libPath)) {
        qWarning() << "libwidevinecdm.so not found after extraction";
        qDebug() << "Expected at:" << libPath;

        // List extracted contents for debugging
        QDir dir(destDir);
        qDebug() << "Extracted contents:" << dir.entryList(QDir::AllEntries | QDir::NoDotAndDotDot);
        return false;
    }

    return true;
}

bool WidevineManager::copyWidevineFiles(const QString &extractDir, const QString &installDir)
{
    const QString libDir = installDir + QStringLiteral("/_platform_specific/linux_x64");

    // Create installation directories
    if (!QDir().mkpath(libDir)) {
        qWarning() << "Failed to create installation directory:" << libDir;
        return false;
    }

    // Copy libwidevinecdm.so
    const QString srcLib = extractDir + QStringLiteral("/_platform_specific/linux_x64/libwidevinecdm.so");
    const QString destLib = libDir + QStringLiteral("/libwidevinecdm.so");

    if (!QFile::copy(srcLib, destLib)) {
        qWarning() << "Failed to copy libwidevinecdm.so";
        return false;
    }

    // Set permissions (644)
    QFile libFile(destLib);
    libFile.setPermissions(QFile::ReadOwner | QFile::WriteOwner | QFile::ReadGroup | QFile::ReadOther);

    // Copy manifest.json if exists
    const QString srcManifest = extractDir + QStringLiteral("/manifest.json");
    if (QFile::exists(srcManifest)) {
        const QString destManifest = installDir + QStringLiteral("/manifest.json");
        QFile::copy(srcManifest, destManifest);
        QFile(destManifest).setPermissions(QFile::ReadOwner | QFile::WriteOwner | QFile::ReadGroup | QFile::ReadOther);
    }

    // Copy LICENSE if exists
    const QString srcLicense = extractDir + QStringLiteral("/LICENSE");
    const QString srcLicenseTxt = extractDir + QStringLiteral("/LICENSE.txt");
    const QString destLicense = installDir + QStringLiteral("/LICENSE.txt");

    if (QFile::exists(srcLicense)) {
        QFile::copy(srcLicense, destLicense);
    } else if (QFile::exists(srcLicenseTxt)) {
        QFile::copy(srcLicenseTxt, destLicense);
    }

    if (QFile::exists(destLicense)) {
        QFile(destLicense).setPermissions(QFile::ReadOwner | QFile::WriteOwner | QFile::ReadGroup | QFile::ReadOther);
    }

    return true;
}

void WidevineManager::configureEnvironment(const QString &libPath)
{
    if (!isRunningInFlatpak()) {
        qDebug() << "Not running in Flatpak, skipping environment configuration";
        return;
    }

    setStatusMessage(i18n("Configuring Flatpak environment..."));

    // Build Chromium flags
    QStringList flags;
    flags << QStringLiteral("--autoplay-policy=no-user-gesture-required");
    flags << QStringLiteral("--enable-features=HardwareMediaDecoding,PlatformEncryptedDolbyVision,PlatformHEVCEncoderSupport");
    flags << QStringLiteral("--enable-widevine-cdm");
    flags << QStringLiteral("--widevine-path=") + libPath;
    flags << QStringLiteral("--no-sandbox");

    const QString chromiumFlags = flags.join(QLatin1Char(' '));

    // Use flatpak-spawn to call flatpak on the host
    QProcess process;
    process.setProgram(QStringLiteral("flatpak-spawn"));
    process.setArguments({QStringLiteral("--host"),
                          QStringLiteral("flatpak"),
                          QStringLiteral("override"),
                          QStringLiteral("--user"),
                          QStringLiteral("--env=QTWEBENGINE_CHROMIUM_FLAGS=") + chromiumFlags,
                          QString::fromLatin1(APP_ID)});

    process.start();
    process.waitForFinished(30000);

    if (process.exitCode() != 0) {
        qWarning() << "Failed to configure Flatpak environment:" << process.readAllStandardError();
    } else {
        qDebug() << "Flatpak environment configured successfully";
    }
}

void WidevineManager::finishInstallation(bool success, const QString &message)
{
    m_isInstalling = false;
    Q_EMIT isInstallingChanged();

    if (m_tempDir) {
        delete m_tempDir;
        m_tempDir = nullptr;
    }

    if (m_currentReply) {
        m_currentReply->deleteLater();
        m_currentReply = nullptr;
    }

    setStatusMessage(QString());
    setDownloadProgress(0);

    checkInstallation();

    Q_EMIT installationFinished(success, message);
}

void WidevineManager::uninstall()
{
    if (m_isInstalling) {
        qWarning() << "Operation already in progress";
        return;
    }

    const QString widevinePath = getWidevinePath();

    // Remove Widevine files
    if (QDir(widevinePath).exists()) {
        if (!QDir(widevinePath).removeRecursively()) {
            Q_EMIT uninstallationFinished(false, i18n("Failed to remove Widevine files"));
            return;
        }
    }

    // Reset Flatpak environment override (if in Flatpak)
    if (isRunningInFlatpak()) {
        QProcess process;
        process.setProgram(QStringLiteral("flatpak-spawn"));
        process.setArguments({QStringLiteral("--host"),
                              QStringLiteral("flatpak"),
                              QStringLiteral("override"),
                              QStringLiteral("--user"),
                              QStringLiteral("--unset-env=QTWEBENGINE_CHROMIUM_FLAGS"),
                              QString::fromLatin1(APP_ID)});

        process.start();
        process.waitForFinished(30000);
    }

    checkInstallation();

    Q_EMIT uninstallationFinished(true, i18n("Widevine uninstalled successfully. Please restart Unify for changes to take effect."));
}
