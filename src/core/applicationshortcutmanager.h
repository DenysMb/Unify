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

    QVariantList m_applications;
};

#endif // APPLICATIONSHORTCUTMANAGER_H
