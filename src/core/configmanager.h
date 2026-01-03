#ifndef CONFIGMANAGER_H
#define CONFIGMANAGER_H

#include <QObject>
#include <QSettings>
#include <QString>
#include <QStringList>
#include <QVariantList>
#include <QVariantMap>

class ConfigManager : public QObject
{
    Q_OBJECT
    Q_PROPERTY(QVariantList services READ services WRITE setServices NOTIFY servicesChanged)
    Q_PROPERTY(QStringList workspaces READ workspaces NOTIFY workspacesChanged)
    Q_PROPERTY(QString currentWorkspace READ currentWorkspace WRITE setCurrentWorkspace NOTIFY currentWorkspaceChanged)
    Q_PROPERTY(QVariantMap workspaceIcons READ workspaceIcons NOTIFY workspaceIconsChanged)
    Q_PROPERTY(QVariantMap disabledServices READ disabledServices WRITE setDisabledServices NOTIFY disabledServicesChanged)
    Q_PROPERTY(bool horizontalSidebar READ horizontalSidebar WRITE setHorizontalSidebar NOTIFY horizontalSidebarChanged)
    Q_PROPERTY(bool alwaysShowWorkspacesBar READ alwaysShowWorkspacesBar WRITE setAlwaysShowWorkspacesBar NOTIFY alwaysShowWorkspacesBarChanged)
    Q_PROPERTY(bool confirmDownloads READ confirmDownloads WRITE setConfirmDownloads NOTIFY confirmDownloadsChanged)

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
    Q_INVOKABLE void moveService(int fromIndex, int toIndex);

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

    // Horizontal sidebar mode
    bool horizontalSidebar() const;
    void setHorizontalSidebar(bool enabled);

    // Always show workspaces bar at bottom
    bool alwaysShowWorkspacesBar() const;
    void setAlwaysShowWorkspacesBar(bool enabled);

    // Download confirmation setting
    bool confirmDownloads() const;
    void setConfirmDownloads(bool enabled);

    Q_INVOKABLE void saveSettings();
    Q_INVOKABLE void loadSettings();

    // Last-used service persistence (per workspace)
    Q_INVOKABLE void setLastUsedService(const QString &workspace, const QString &serviceId);
    Q_INVOKABLE QString lastUsedService(const QString &workspace) const;

    // Favorites management
    Q_INVOKABLE void setServiceFavorite(const QString &serviceId, bool favorite);
    Q_INVOKABLE bool isServiceFavorite(const QString &serviceId) const;

    // Special workspaces
    Q_INVOKABLE bool isSpecialWorkspace(const QString &workspaceName) const;

    // Constants for special workspaces
    static const QString FAVORITES_WORKSPACE;
    static const QString ALL_SERVICES_WORKSPACE;

Q_SIGNALS:
    void servicesChanged();
    void workspacesChanged();
    void currentWorkspaceChanged();
    void workspaceIconsChanged();
    void disabledServicesChanged();
    void horizontalSidebarChanged();
    void alwaysShowWorkspacesBarChanged();
    void confirmDownloadsChanged();

private:
    void updateWorkspacesList();

    QSettings m_settings;
    QVariantList m_services;
    QStringList m_workspaces;
    QString m_currentWorkspace;
    QHash<QString, QString> m_lastServiceByWorkspace; // workspace -> serviceId
    QHash<QString, QString> m_workspaceIcons; // workspace -> icon name
    QVariantMap m_disabledServices; // serviceId -> bool (true if disabled)
    bool m_horizontalSidebar = false;
    bool m_alwaysShowWorkspacesBar = false;
    bool m_confirmDownloads = true;
};

#endif // CONFIGMANAGER_H
