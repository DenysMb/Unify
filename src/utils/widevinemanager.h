#pragma once

#include <QNetworkAccessManager>
#include <QNetworkReply>
#include <QObject>
#include <QString>
#include <QTemporaryDir>

class WidevineManager : public QObject
{
    Q_OBJECT
    Q_PROPERTY(bool isInstalled READ isInstalled NOTIFY isInstalledChanged)
    Q_PROPERTY(bool isInstalling READ isInstalling NOTIFY isInstallingChanged)
    Q_PROPERTY(QString installedVersion READ installedVersion NOTIFY installedVersionChanged)
    Q_PROPERTY(QString statusMessage READ statusMessage NOTIFY statusMessageChanged)
    Q_PROPERTY(int downloadProgress READ downloadProgress NOTIFY downloadProgressChanged)

public:
    explicit WidevineManager(QObject *parent = nullptr);

    bool isInstalled() const;
    bool isInstalling() const;
    QString installedVersion() const;
    QString statusMessage() const;
    int downloadProgress() const;

    Q_INVOKABLE void checkInstallation();
    Q_INVOKABLE void install();
    Q_INVOKABLE void uninstall();

Q_SIGNALS:
    void isInstalledChanged();
    void isInstallingChanged();
    void installedVersionChanged();
    void statusMessageChanged();
    void downloadProgressChanged();
    void installationStarted();
    void installationFinished(bool success, const QString &message);
    void uninstallationFinished(bool success, const QString &message);

private Q_SLOTS:
    void onMetadataReceived();
    void onDownloadProgress(qint64 bytesReceived, qint64 bytesTotal);
    void onDownloadFinished();
    void onNetworkError(QNetworkReply::NetworkError error);

private:
    QString getPluginsPath() const;
    QString getWidevinePath() const;
    QString findInstalledVersion() const;
    bool extractCrx3(const QString &crxPath, const QString &destDir);
    bool copyWidevineFiles(const QString &extractDir, const QString &installDir);
    void setStatusMessage(const QString &message);
    void setDownloadProgress(int progress);
    void finishInstallation(bool success, const QString &message);
    void configureEnvironment(const QString &libPath);
    bool isRunningInFlatpak() const;

    QNetworkAccessManager *m_networkManager = nullptr;
    QNetworkReply *m_currentReply = nullptr;
    QTemporaryDir *m_tempDir = nullptr;

    bool m_isInstalled = false;
    bool m_isInstalling = false;
    QString m_installedVersion;
    QString m_statusMessage;
    int m_downloadProgress = 0;

    // Widevine metadata from Firefox repository
    QString m_widevineUrl;
    QString m_widevineVersion;
    QString m_widevineHash;

    static constexpr const char *FIREFOX_WIDEVINE_JSON =
        "https://raw.githubusercontent.com/mozilla/gecko-dev/master/toolkit/content/gmp-sources/widevinecdm.json";
    static constexpr const char *APP_ID = "io.github.denysmb.unify";
};
