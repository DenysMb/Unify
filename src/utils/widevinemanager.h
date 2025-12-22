#pragma once

#include <QObject>
#include <QProcess>
#include <QString>

class WidevineManager : public QObject
{
    Q_OBJECT
    Q_PROPERTY(bool isInstalled READ isInstalled NOTIFY isInstalledChanged)
    Q_PROPERTY(bool isInstalling READ isInstalling NOTIFY isInstallingChanged)
    Q_PROPERTY(QString installedVersion READ installedVersion NOTIFY installedVersionChanged)

public:
    explicit WidevineManager(QObject *parent = nullptr);

    bool isInstalled() const;
    bool isInstalling() const;
    QString installedVersion() const;

    Q_INVOKABLE void checkInstallation();
    Q_INVOKABLE void install();
    Q_INVOKABLE void uninstall();

Q_SIGNALS:
    void isInstalledChanged();
    void isInstallingChanged();
    void installedVersionChanged();
    void installationStarted();
    void installationFinished(bool success, const QString &message);
    void uninstallationFinished(bool success, const QString &message);

private Q_SLOTS:
    void onProcessFinished(int exitCode, QProcess::ExitStatus exitStatus);
    void onProcessError(QProcess::ProcessError error);

private:
    QString getPluginsPath() const;
    QString getWidevinePath() const;
    QString findInstalledVersion() const;
    QString getInstallScriptPath() const;

    bool m_isInstalled = false;
    bool m_isInstalling = false;
    QString m_installedVersion;
    QProcess *m_process = nullptr;
    bool m_isUninstalling = false;
};
