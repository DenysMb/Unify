#include "widevinemanager.h"

#include <KLocalizedString>
#include <QCoreApplication>
#include <QDebug>
#include <QDir>
#include <QFile>
#include <QFileInfo>

WidevineManager::WidevineManager(QObject *parent)
    : QObject(parent)
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
            const QString libPath = widevinePath + QLatin1Char('/') + entry
                + QStringLiteral("/_platform_specific/linux_x64/libwidevinecdm.so");
            if (QFile::exists(libPath)) {
                return entry;
            }
        }
    }

    return QString();
}

QString WidevineManager::getInstallScriptPath() const
{
    // In Flatpak, the script is installed at /app/bin/install-widevine.sh
    const QString flatpakPath = QStringLiteral("/app/bin/install-widevine.sh");
    if (QFile::exists(flatpakPath)) {
        return flatpakPath;
    }

    // For development/native builds, look relative to the executable
    const QString appDir = QCoreApplication::applicationDirPath();

    // Check common development paths
    QStringList searchPaths;
    searchPaths << appDir + QStringLiteral("/../install-widevine.sh");           // build/bin/../
    searchPaths << appDir + QStringLiteral("/../../install-widevine.sh");         // build/bin/../../
    searchPaths << appDir + QStringLiteral("/install-widevine.sh");               // same dir

    for (const QString &path : searchPaths) {
        QFileInfo fileInfo(path);
        if (fileInfo.exists() && fileInfo.isFile()) {
            return fileInfo.absoluteFilePath();
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

void WidevineManager::install()
{
    if (m_isInstalling) {
        qWarning() << "Installation already in progress";
        return;
    }

    const QString scriptPath = getInstallScriptPath();
    if (scriptPath.isEmpty()) {
        qWarning() << "install-widevine.sh script not found";
        Q_EMIT installationFinished(false, i18n("Installation script not found. Please reinstall the application."));
        return;
    }

    qDebug() << "Found install script at:" << scriptPath;

    m_isInstalling = true;
    m_isUninstalling = false;
    Q_EMIT isInstallingChanged();
    Q_EMIT installationStarted();

    m_process = new QProcess(this);
    connect(m_process, &QProcess::finished, this, &WidevineManager::onProcessFinished);
    connect(m_process, &QProcess::errorOccurred, this, &WidevineManager::onProcessError);

    qDebug() << "Starting Widevine installation...";
    m_process->start(scriptPath, QStringList() << QStringLiteral("install"));
}

void WidevineManager::uninstall()
{
    if (m_isInstalling) {
        qWarning() << "Operation already in progress";
        return;
    }

    const QString scriptPath = getInstallScriptPath();
    if (scriptPath.isEmpty()) {
        qWarning() << "install-widevine.sh script not found";
        Q_EMIT uninstallationFinished(false, i18n("Installation script not found. Please reinstall the application."));
        return;
    }

    m_isInstalling = true;
    m_isUninstalling = true;
    Q_EMIT isInstallingChanged();

    m_process = new QProcess(this);
    connect(m_process, &QProcess::finished, this, &WidevineManager::onProcessFinished);
    connect(m_process, &QProcess::errorOccurred, this, &WidevineManager::onProcessError);

    qDebug() << "Starting Widevine uninstallation...";
    m_process->start(scriptPath, QStringList() << QStringLiteral("uninstall"));
}

void WidevineManager::onProcessFinished(int exitCode, QProcess::ExitStatus exitStatus)
{
    const bool wasUninstalling = m_isUninstalling;
    m_isInstalling = false;
    m_isUninstalling = false;
    Q_EMIT isInstallingChanged();

    QString output;
    if (m_process) {
        output = QString::fromUtf8(m_process->readAllStandardOutput());
        output += QString::fromUtf8(m_process->readAllStandardError());
        m_process->deleteLater();
        m_process = nullptr;
    }

    qDebug() << "Process finished with exit code:" << exitCode;
    qDebug() << "Process output:" << output;

    checkInstallation();

    const bool success = (exitStatus == QProcess::NormalExit && exitCode == 0);

    if (wasUninstalling) {
        if (success) {
            Q_EMIT uninstallationFinished(true, i18n("Widevine has been uninstalled. Please restart Unify for changes to take effect."));
        } else {
            Q_EMIT uninstallationFinished(false, i18n("Widevine uninstallation failed. Exit code: %1", exitCode));
        }
    } else {
        if (success) {
            Q_EMIT installationFinished(true, i18n("Widevine has been installed successfully! Please restart Unify to enable DRM content playback."));
        } else {
            QString errorMsg = i18n("Widevine installation failed. Exit code: %1", exitCode);
            if (!output.isEmpty()) {
                // Extract error message from output if possible
                if (output.contains(QStringLiteral("[ERROR]"))) {
                    const int errorIdx = output.indexOf(QStringLiteral("[ERROR]"));
                    const int endIdx = output.indexOf(QLatin1Char('\n'), errorIdx);
                    if (endIdx > errorIdx) {
                        errorMsg = output.mid(errorIdx + 8, endIdx - errorIdx - 8).trimmed();
                    }
                }
            }
            Q_EMIT installationFinished(false, errorMsg);
        }
    }
}

void WidevineManager::onProcessError(QProcess::ProcessError error)
{
    const bool wasUninstalling = m_isUninstalling;
    m_isInstalling = false;
    m_isUninstalling = false;
    Q_EMIT isInstallingChanged();

    if (m_process) {
        m_process->deleteLater();
        m_process = nullptr;
    }

    QString errorMsg;
    switch (error) {
    case QProcess::FailedToStart:
        errorMsg = i18n("Failed to start the installation script. Please check that bash is available.");
        break;
    case QProcess::Crashed:
        errorMsg = i18n("Installation process crashed unexpectedly.");
        break;
    case QProcess::Timedout:
        errorMsg = i18n("Installation timed out.");
        break;
    default:
        errorMsg = i18n("An unknown error occurred during installation.");
        break;
    }

    if (wasUninstalling) {
        Q_EMIT uninstallationFinished(false, errorMsg);
    } else {
        Q_EMIT installationFinished(false, errorMsg);
    }
}
