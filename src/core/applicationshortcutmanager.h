#ifndef APPLICATIONSHORTCUTMANAGER_H
#define APPLICATIONSHORTCUTMANAGER_H

#include <QObject>
#include <QVariantList>
#include <QVariantMap>

class ApplicationShortcutManager : public QObject
{
    Q_OBJECT
    Q_PROPERTY(QVariantList installedApplications READ installedApplications NOTIFY installedApplicationsChanged)

public:
    explicit ApplicationShortcutManager(QObject *parent = nullptr);

    QVariantList installedApplications() const;

    Q_INVOKABLE bool launchApplication(const QString &desktopFileName);
    Q_INVOKABLE QVariantMap getApplicationInfo(const QString &desktopFileName) const;
    Q_INVOKABLE QVariantList searchApplications(const QString &query) const;
    Q_INVOKABLE void refreshApplications();

Q_SIGNALS:
    void installedApplicationsChanged();
    void applicationLaunched(const QString &desktopFileName);
    void launchError(const QString &errorMessage);

private:
    void loadApplications();
    void loadApplicationsFromKService();
    void loadApplicationsFromDesktopFiles();
    void loadApplicationsViaFlatpakSpawn(QSet<QString> &processedIds);
    void scanDesktopFilesInDirectory(const QString &dirPath, QSet<QString> &processedIds);
    QVariantMap parseDesktopFile(const QString &filePath) const;
    QVariantMap parseDesktopFileViaFlatpakSpawn(const QString &filePath) const;
    QVariantMap parseDesktopFileContent(const QString &content, const QString &filePath) const;
    bool isRunningInFlatpak() const;
    QString cacheIconFromHost(const QString &iconName) const;

    QVariantList m_applications;
};

#endif // APPLICATIONSHORTCUTMANAGER_H
