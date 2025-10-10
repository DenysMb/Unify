#ifndef CONFIGMANAGER_H
#define CONFIGMANAGER_H

#include <QObject>
#include <QSettings>
#include <QVariantList>
#include <QVariantMap>
#include <QStringList>
#include <QString>

class ConfigManager : public QObject
{
    Q_OBJECT
    Q_PROPERTY(QVariantList services READ services WRITE setServices NOTIFY servicesChanged)
    Q_PROPERTY(QStringList workspaces READ workspaces NOTIFY workspacesChanged)
    Q_PROPERTY(QString currentWorkspace READ currentWorkspace WRITE setCurrentWorkspace NOTIFY currentWorkspaceChanged)
    Q_PROPERTY(QVariantMap workspaceIcons READ workspaceIcons NOTIFY workspaceIconsChanged)
    Q_PROPERTY(QVariantMap disabledServices READ disabledServices WRITE setDisabledServices NOTIFY disabledServicesChanged)

public:
    explicit ConfigManager(QObject *parent = nullptr);

    QVariantList services() const;
    void setServices(const QVariantList &services);

    QStringList workspaces() const;
    
    QString currentWorkspace() const;
    void setCurrentWorkspace(const QString &workspace);

    Q_INVOKABLE void addService(const QVariantMap &service);
    Q_INVOKABLE void updateService(const QString &serviceId, const QVariantMap &service);
    Q_INVOKABLE void removeService(const QString &serviceId);
    
    Q_INVOKABLE void addWorkspace(const QString &workspaceName);
    Q_INVOKABLE void removeWorkspace(const QString &workspaceName);
    Q_INVOKABLE void renameWorkspace(const QString &oldName, const QString &newName);

    // Per-workspace icon mapping
    QVariantMap workspaceIcons() const;
    Q_INVOKABLE QString workspaceIcon(const QString &workspace) const;
    Q_INVOKABLE void setWorkspaceIcon(const QString &workspace, const QString &iconName);

    // Disabled services management
    QVariantMap disabledServices() const;
    void setDisabledServices(const QVariantMap &disabledServices);
    Q_INVOKABLE void setServiceDisabled(const QString &serviceId, bool disabled);
    Q_INVOKABLE bool isServiceDisabled(const QString &serviceId) const;

    Q_INVOKABLE void saveSettings();
    Q_INVOKABLE void loadSettings();

    // Last-used service persistence (per workspace)
    Q_INVOKABLE void setLastUsedService(const QString &workspace, const QString &serviceId);
    Q_INVOKABLE QString lastUsedService(const QString &workspace) const;

Q_SIGNALS:
    void servicesChanged();
    void workspacesChanged();
    void currentWorkspaceChanged();
    void workspaceIconsChanged();
    void disabledServicesChanged();

private:
    void updateWorkspacesList();

    QSettings m_settings;
    QVariantList m_services;
    QStringList m_workspaces;
    QString m_currentWorkspace;
    QHash<QString, QString> m_lastServiceByWorkspace; // workspace -> serviceId
    QHash<QString, QString> m_workspaceIcons; // workspace -> icon name
    QVariantMap m_disabledServices; // serviceId -> bool (true if disabled)
};

#endif // CONFIGMANAGER_H
