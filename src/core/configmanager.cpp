#include "configmanager.h"
#include <QCoreApplication>
#include <QDBusConnection>
#include <QDBusMessage>
#include <QDBusObjectPath>
#include <QDBusReply>
#include <QDateTime>
#include <QDebug>
#include <QFile>
#include <QFileDialog>
#include <QJsonArray>
#include <QJsonDocument>
#include <QJsonObject>
#include <QUuid>

// Define special workspace constants
const QString ConfigManager::FAVORITES_WORKSPACE = QStringLiteral("__favorites__");
const QString ConfigManager::ALL_SERVICES_WORKSPACE = QStringLiteral("__all_services__");

namespace
{
// Build the commandline the desktop session should run on login. Inside Flatpak
// the in-sandbox application path is unreachable from the host session, so the
// portal needs `flatpak run` instead.
QStringList autostartCommandLine()
{
    if (qEnvironmentVariableIsSet("FLATPAK_ID")) {
        return {QStringLiteral("flatpak"), QStringLiteral("run"), QStringLiteral("io.github.denysmb.unify")};
    }
    return {QCoreApplication::applicationFilePath()};
}

// Ask org.freedesktop.portal.Background to (un)register us for autostart. The
// portal works inside Flatpak (where ~/.config/autostart isn't writable from
// the sandbox) and on native installs alike, so this is the single code path.
bool requestBackgroundPortal(bool autostart)
{
    QDBusMessage msg = QDBusMessage::createMethodCall(QStringLiteral("org.freedesktop.portal.Desktop"),
                                                      QStringLiteral("/org/freedesktop/portal/desktop"),
                                                      QStringLiteral("org.freedesktop.portal.Background"),
                                                      QStringLiteral("RequestBackground"));

    QVariantMap options;
    options.insert(QStringLiteral("autostart"), autostart);
    options.insert(QStringLiteral("reason"), QStringLiteral("Launch Unify on system start"));
    options.insert(QStringLiteral("commandline"), autostartCommandLine());

    msg << QString() // parent_window: empty — no parent dialog handle
        << options;

    QDBusReply<QDBusObjectPath> reply = QDBusConnection::sessionBus().call(msg);
    if (!reply.isValid()) {
        qWarning() << "Background portal RequestBackground failed:" << reply.error().message();
        return false;
    }
    return true;
}
} // namespace

ConfigManager::ConfigManager(QObject *parent)
    : QObject(parent)
    , m_settings(QStringLiteral("io.github.denysmb"), QStringLiteral("unify"))
    , m_currentWorkspace(QStringLiteral("Personal"))
{
    loadSettings();
}

QVariantList ConfigManager::services() const
{
    return m_services;
}

void ConfigManager::setServices(const QVariantList &services)
{
    if (m_services != services) {
        m_services = services;
        updateWorkspacesList();
        Q_EMIT servicesChanged();
        saveSettings();
    }
}

QStringList ConfigManager::workspaces() const
{
    return m_workspaces;
}

QString ConfigManager::currentWorkspace() const
{
    return m_currentWorkspace;
}

void ConfigManager::setCurrentWorkspace(const QString &workspace)
{
    if (m_currentWorkspace != workspace) {
        m_currentWorkspace = workspace;
        Q_EMIT currentWorkspaceChanged();
        saveSettings();
    }
}

QVariantMap ConfigManager::workspaceIcons() const
{
    QVariantMap map;
    for (auto it = m_workspaceIcons.constBegin(); it != m_workspaceIcons.constEnd(); ++it) {
        map.insert(it.key(), it.value());
    }
    return map;
}

QString ConfigManager::workspaceIcon(const QString &workspace) const
{
    return m_workspaceIcons.value(workspace);
}

void ConfigManager::setWorkspaceIcon(const QString &workspace, const QString &iconName)
{
    if (workspace.isEmpty()) {
        return;
    }

    // Protect special workspaces from icon changes
    if (isSpecialWorkspace(workspace)) {
        qDebug() << "Cannot change icon for special workspace:" << workspace;
        return;
    }
    const QString value = iconName; // allow empty to clear
    const auto it = m_workspaceIcons.find(workspace);
    if (it == m_workspaceIcons.end() || it.value() != value) {
        if (value.isEmpty()) {
            m_workspaceIcons.remove(workspace);
        } else {
            m_workspaceIcons.insert(workspace, value);
        }
        Q_EMIT workspaceIconsChanged();
        saveSettings();
    }
}

QVariantMap ConfigManager::workspaceIsolatedStorage() const
{
    QVariantMap map;
    for (auto it = m_workspaceIsolatedStorage.constBegin(); it != m_workspaceIsolatedStorage.constEnd(); ++it) {
        map.insert(it.key(), it.value());
    }
    return map;
}

bool ConfigManager::isWorkspaceIsolated(const QString &workspace) const
{
    return m_workspaceIsolatedStorage.value(workspace, false);
}

void ConfigManager::setWorkspaceIsolatedStorage(const QString &workspace, bool isolated)
{
    if (workspace.isEmpty()) {
        return;
    }

    // Protect special workspaces from isolated storage changes
    if (isSpecialWorkspace(workspace)) {
        qDebug() << "Cannot change isolated storage for special workspace:" << workspace;
        return;
    }

    const auto it = m_workspaceIsolatedStorage.find(workspace);
    if (it == m_workspaceIsolatedStorage.end() || it.value() != isolated) {
        if (!isolated) {
            m_workspaceIsolatedStorage.remove(workspace);
        } else {
            m_workspaceIsolatedStorage.insert(workspace, isolated);
        }
        Q_EMIT workspaceIsolatedStorageChanged();
        saveSettings();
    }
}

QVariantMap ConfigManager::disabledServices() const
{
    return m_disabledServices;
}

void ConfigManager::setDisabledServices(const QVariantMap &disabledServices)
{
    if (m_disabledServices != disabledServices) {
        m_disabledServices = disabledServices;
        Q_EMIT disabledServicesChanged();
        saveSettings();
    }
}

void ConfigManager::setServiceDisabled(const QString &serviceId, bool disabled)
{
    if (serviceId.isEmpty()) {
        return;
    }

    bool changed = false;
    if (disabled) {
        // Add to disabled services if not already present
        if (!m_disabledServices.contains(serviceId) || m_disabledServices.value(serviceId).toBool() != true) {
            m_disabledServices.insert(serviceId, true);
            changed = true;
        }
    } else {
        // Remove from disabled services if present
        if (m_disabledServices.contains(serviceId)) {
            m_disabledServices.remove(serviceId);
            changed = true;
        }
    }

    if (changed) {
        Q_EMIT disabledServicesChanged();
        saveSettings();
        qDebug() << "Service" << serviceId << (disabled ? "disabled" : "enabled");
    }
}

bool ConfigManager::isServiceDisabled(const QString &serviceId) const
{
    return m_disabledServices.contains(serviceId) && m_disabledServices.value(serviceId).toBool();
}

QVariantMap ConfigManager::disabledWorkspaces() const
{
    return m_disabledWorkspaces;
}

void ConfigManager::setDisabledWorkspaces(const QVariantMap &disabledWorkspaces)
{
    if (m_disabledWorkspaces != disabledWorkspaces) {
        m_disabledWorkspaces = disabledWorkspaces;
        Q_EMIT disabledWorkspacesChanged();
        saveSettings();
    }
}

void ConfigManager::setWorkspaceDisabled(const QString &workspace, bool disabled)
{
    if (workspace.isEmpty()) {
        return;
    }
    if (isSpecialWorkspace(workspace)) {
        return;
    }

    bool changed = false;
    if (disabled) {
        if (!m_disabledWorkspaces.contains(workspace) || m_disabledWorkspaces.value(workspace).toBool() != true) {
            m_disabledWorkspaces.insert(workspace, true);
            changed = true;
        }
    } else {
        if (m_disabledWorkspaces.contains(workspace)) {
            m_disabledWorkspaces.remove(workspace);
            changed = true;
        }
    }

    if (changed) {
        Q_EMIT disabledWorkspacesChanged();
        saveSettings();
        qDebug() << "Workspace" << workspace << (disabled ? "disabled" : "enabled");
    }
}

bool ConfigManager::isWorkspaceDisabled(const QString &workspace) const
{
    return m_disabledWorkspaces.contains(workspace) && m_disabledWorkspaces.value(workspace).toBool();
}

void ConfigManager::moveWorkspace(int fromIndex, int toIndex)
{
    if (fromIndex < 0 || fromIndex >= m_workspaces.size() || toIndex < 0 || toIndex >= m_workspaces.size() || fromIndex == toIndex) {
        qDebug() << "Invalid move workspace indices:" << fromIndex << "to" << toIndex;
        return;
    }

    m_workspaces.move(fromIndex, toIndex);

    Q_EMIT workspacesChanged();
    saveSettings();

    qDebug() << "Moved workspace from index" << fromIndex << "to" << toIndex;
}

QVariantMap ConfigManager::mutedServices() const
{
    return m_mutedServices;
}

void ConfigManager::setMutedServices(const QVariantMap &mutedServices)
{
    if (m_mutedServices != mutedServices) {
        m_mutedServices = mutedServices;
        Q_EMIT mutedServicesChanged();
        saveSettings();
    }
}

void ConfigManager::setServiceMuted(const QString &serviceId, bool muted)
{
    if (serviceId.isEmpty()) {
        return;
    }

    bool changed = false;
    if (muted) {
        if (!m_mutedServices.contains(serviceId) || m_mutedServices.value(serviceId).toBool() != true) {
            m_mutedServices.insert(serviceId, true);
            changed = true;
        }
    } else {
        if (m_mutedServices.contains(serviceId)) {
            m_mutedServices.remove(serviceId);
            changed = true;
        }
    }

    if (changed) {
        Q_EMIT mutedServicesChanged();
        saveSettings();
        qDebug() << "Service" << serviceId << (muted ? "muted" : "unmuted");
    }
}

bool ConfigManager::isServiceMuted(const QString &serviceId) const
{
    return m_mutedServices.contains(serviceId) && m_mutedServices.value(serviceId).toBool();
}

QVariantMap ConfigManager::serviceTabs() const
{
    return m_serviceTabs;
}

QVariantList ConfigManager::getTabsForService(const QString &serviceId) const
{
    if (m_serviceTabs.contains(serviceId)) {
        return m_serviceTabs.value(serviceId).toList();
    }
    return QVariantList();
}

void ConfigManager::setTabsForService(const QString &serviceId, const QVariantList &tabs)
{
    if (serviceId.isEmpty()) {
        return;
    }

    if (tabs.isEmpty()) {
        if (m_serviceTabs.contains(serviceId)) {
            m_serviceTabs.remove(serviceId);
            Q_EMIT serviceTabsChanged();
            saveSettings();
        }
    } else {
        m_serviceTabs.insert(serviceId, tabs);
        Q_EMIT serviceTabsChanged();
        saveSettings();
        qDebug() << "Saved" << tabs.size() << "tabs for service:" << serviceId;
    }
}

void ConfigManager::clearTabsForService(const QString &serviceId)
{
    if (m_serviceTabs.contains(serviceId)) {
        m_serviceTabs.remove(serviceId);
        Q_EMIT serviceTabsChanged();
        saveSettings();
        qDebug() << "Cleared tabs for service:" << serviceId;
    }
}

bool ConfigManager::globalMute() const
{
    return m_globalMute;
}

void ConfigManager::setGlobalMute(bool enabled)
{
    if (m_globalMute != enabled) {
        m_globalMute = enabled;
        Q_EMIT globalMuteChanged();
        saveSettings();
        qDebug() << "Global mute" << (enabled ? "enabled" : "disabled");
    }
}

bool ConfigManager::horizontalSidebar() const
{
    return m_horizontalSidebar;
}

void ConfigManager::setHorizontalSidebar(bool enabled)
{
    if (m_horizontalSidebar != enabled) {
        m_horizontalSidebar = enabled;
        Q_EMIT horizontalSidebarChanged();
        saveSettings();
    }
}

bool ConfigManager::alwaysShowWorkspacesBar() const
{
    return m_alwaysShowWorkspacesBar;
}

void ConfigManager::setAlwaysShowWorkspacesBar(bool enabled)
{
    if (m_alwaysShowWorkspacesBar != enabled) {
        m_alwaysShowWorkspacesBar = enabled;
        Q_EMIT alwaysShowWorkspacesBarChanged();
        saveSettings();
    }
}

bool ConfigManager::confirmDownloads() const
{
    return m_confirmDownloads;
}

void ConfigManager::setConfirmDownloads(bool enabled)
{
    if (m_confirmDownloads != enabled) {
        m_confirmDownloads = enabled;
        Q_EMIT confirmDownloadsChanged();
        saveSettings();
    }
}

bool ConfigManager::systemTrayEnabled() const
{
    return m_systemTrayEnabled;
}

void ConfigManager::setSystemTrayEnabled(bool enabled)
{
    if (m_systemTrayEnabled != enabled) {
        m_systemTrayEnabled = enabled;
        Q_EMIT systemTrayEnabledChanged();
        saveSettings();
    }
}

bool ConfigManager::showZoomInHeader() const
{
    return m_showZoomInHeader;
}

void ConfigManager::setShowZoomInHeader(bool enabled)
{
    if (m_showZoomInHeader != enabled) {
        m_showZoomInHeader = enabled;
        Q_EMIT showZoomInHeaderChanged();
        saveSettings();
    }
}

bool ConfigManager::autostartEnabled() const
{
    return m_autostartEnabled;
}

void ConfigManager::setAutostartEnabled(bool enabled)
{
    if (m_autostartEnabled == enabled) {
        return;
    }

    if (!requestBackgroundPortal(enabled)) {
        return;
    }

    m_autostartEnabled = enabled;
    Q_EMIT autostartEnabledChanged();
    saveSettings();
}

bool ConfigManager::hideHeader() const
{
    return m_hideHeader;
}

void ConfigManager::setHideHeader(bool enabled)
{
    if (m_hideHeader != enabled) {
        m_hideHeader = enabled;
        Q_EMIT hideHeaderChanged();
        saveSettings();
    }
}

QString ConfigManager::sidebarSizePreset() const
{
    return m_sidebarSizePreset;
}

void ConfigManager::setSidebarSizePreset(const QString &preset)
{
    if (m_sidebarSizePreset != preset) {
        m_sidebarSizePreset = preset;
        Q_EMIT sidebarSizePresetChanged();
        saveSettings();
    }
}

QString ConfigManager::voiceChatService() const
{
    return m_voiceChatService;
}

void ConfigManager::setVoiceChatService(const QString &service)
{
    if (m_voiceChatService != service) {
        m_voiceChatService = service;
        Q_EMIT voiceChatServiceChanged();
        saveSettings();
    }
}

bool ConfigManager::experimentalFeaturesEnabled() const
{
    return m_experimentalFeaturesEnabled;
}

void ConfigManager::setExperimentalFeaturesEnabled(bool enabled)
{
    if (m_experimentalFeaturesEnabled != enabled) {
        m_experimentalFeaturesEnabled = enabled;
        Q_EMIT experimentalFeaturesEnabledChanged();
        saveSettings();
    }
}

QStringList ConfigManager::tlsProxyHosts() const
{
    return m_tlsProxyHosts;
}

void ConfigManager::setTlsProxyHosts(const QStringList &hosts)
{
    if (m_tlsProxyHosts != hosts) {
        m_tlsProxyHosts = hosts;
        Q_EMIT tlsProxyHostsChanged();
        saveSettings();
    }
}

void ConfigManager::addService(const QVariantMap &service)
{
    QVariantMap newService = service;

    // Generate UUID if not provided
    if (!newService.contains(QStringLiteral("id")) || newService[QStringLiteral("id")].toString().isEmpty()) {
        newService[QStringLiteral("id")] = QUuid::createUuid().toString(QUuid::WithoutBraces);
    }

    // Set default workspace if not provided
    if (!newService.contains(QStringLiteral("workspace")) || newService[QStringLiteral("workspace")].toString().isEmpty()) {
        newService[QStringLiteral("workspace")] = m_currentWorkspace.isEmpty() ? QStringLiteral("Personal") : m_currentWorkspace;
    }

    // Find the correct position to insert - after the last service of the same workspace
    const QString targetWorkspace = newService[QStringLiteral("workspace")].toString();
    int insertPosition = -1;

    for (int i = 0; i < m_services.size(); ++i) {
        QVariantMap existingService = m_services[i].toMap();
        if (existingService[QStringLiteral("workspace")].toString() == targetWorkspace) {
            insertPosition = i + 1;
        }
    }

    if (insertPosition >= 0 && insertPosition <= m_services.size()) {
        m_services.insert(insertPosition, newService);
    } else {
        m_services.append(newService);
    }

    updateWorkspacesList();
    Q_EMIT servicesChanged();
    saveSettings();

    qDebug() << "Added service:" << newService[QStringLiteral("title")].toString() << "to workspace:" << newService[QStringLiteral("workspace")].toString();
}

void ConfigManager::updateService(const QString &serviceId, const QVariantMap &service)
{
    for (int i = 0; i < m_services.size(); ++i) {
        QVariantMap existingService = m_services[i].toMap();
        if (existingService[QStringLiteral("id")].toString() == serviceId) {
            QVariantMap updatedService = service;
            updatedService[QStringLiteral("id")] = serviceId; // Preserve the ID

            // Preserve the favorite status if it exists in the original service
            if (existingService.contains(QStringLiteral("favorite"))) {
                updatedService[QStringLiteral("favorite")] = existingService[QStringLiteral("favorite")];
            }

            // Preserve the isolatedProfile flag - it cannot be changed after creation
            if (existingService.contains(QStringLiteral("isolatedProfile"))) {
                updatedService[QStringLiteral("isolatedProfile")] = existingService[QStringLiteral("isolatedProfile")];
            }

            m_services[i] = updatedService;
            updateWorkspacesList();
            Q_EMIT servicesChanged();
            saveSettings();

            qDebug() << "Updated service:" << serviceId;
            return;
        }
    }
    qDebug() << "Service not found for update:" << serviceId;
}

void ConfigManager::removeService(const QString &serviceId)
{
    for (int i = 0; i < m_services.size(); ++i) {
        QVariantMap service = m_services[i].toMap();
        if (service[QStringLiteral("id")].toString() == serviceId) {
            m_services.removeAt(i);
            updateWorkspacesList();
            Q_EMIT servicesChanged();
            saveSettings();

            qDebug() << "Removed service:" << serviceId;
            return;
        }
    }
    qDebug() << "Service not found for removal:" << serviceId;
}

void ConfigManager::moveService(int fromIndex, int toIndex)
{
    if (fromIndex < 0 || fromIndex >= m_services.size() || toIndex < 0 || toIndex >= m_services.size() || fromIndex == toIndex) {
        qDebug() << "Invalid move indices:" << fromIndex << "to" << toIndex;
        return;
    }

    QVariant service = m_services.takeAt(fromIndex);
    m_services.insert(toIndex, service);

    Q_EMIT servicesChanged();
    saveSettings();

    qDebug() << "Moved service from index" << fromIndex << "to" << toIndex;
}

void ConfigManager::addWorkspace(const QString &workspaceName, bool isolatedStorage)
{
    if (!workspaceName.isEmpty() && !m_workspaces.contains(workspaceName)) {
        m_workspaces.append(workspaceName);

        // Set isolated storage if requested
        if (isolatedStorage) {
            m_workspaceIsolatedStorage.insert(workspaceName, true);
            Q_EMIT workspaceIsolatedStorageChanged();
        }

        Q_EMIT workspacesChanged();
        saveSettings();

        qDebug() << "Added workspace:" << workspaceName << (isolatedStorage ? "(isolated)" : "(shared)");
    }
}

void ConfigManager::removeWorkspace(const QString &workspaceName)
{
    // Protect special workspaces from deletion
    if (isSpecialWorkspace(workspaceName)) {
        qDebug() << "Cannot remove special workspace:" << workspaceName;
        return;
    }

    if (m_workspaces.contains(workspaceName)) {
        // Remove all services in this workspace
        for (int i = m_services.size() - 1; i >= 0; --i) {
            QVariantMap service = m_services[i].toMap();
            if (service[QStringLiteral("workspace")].toString() == workspaceName) {
                m_services.removeAt(i);
            }
        }

        m_workspaces.removeAll(workspaceName);

        // Remove icon mapping if present
        if (m_workspaceIcons.contains(workspaceName)) {
            m_workspaceIcons.remove(workspaceName);
            Q_EMIT workspaceIconsChanged();
        }

        // Remove isolated storage mapping if present
        if (m_workspaceIsolatedStorage.contains(workspaceName)) {
            m_workspaceIsolatedStorage.remove(workspaceName);
            Q_EMIT workspaceIsolatedStorageChanged();
        }

        // Remove disabled workspace flag if present
        if (m_disabledWorkspaces.contains(workspaceName)) {
            m_disabledWorkspaces.remove(workspaceName);
            Q_EMIT disabledWorkspacesChanged();
        }

        // If current workspace was removed, switch to first available or create Personal
        if (m_currentWorkspace == workspaceName) {
            if (!m_workspaces.isEmpty()) {
                setCurrentWorkspace(m_workspaces.first());
            } else {
                addWorkspace(QStringLiteral("Personal"));
                setCurrentWorkspace(QStringLiteral("Personal"));
            }
        }

        Q_EMIT servicesChanged();
        Q_EMIT workspacesChanged();
        saveSettings();

        qDebug() << "Removed workspace:" << workspaceName;
    }
}

void ConfigManager::renameWorkspace(const QString &oldName, const QString &newName)
{
    // Protect special workspaces from renaming
    if (isSpecialWorkspace(oldName) || isSpecialWorkspace(newName)) {
        qDebug() << "Cannot rename special workspace:" << oldName << "to" << newName;
        return;
    }

    if (oldName != newName && m_workspaces.contains(oldName) && !m_workspaces.contains(newName)) {
        // Update workspace name in all services
        for (int i = 0; i < m_services.size(); ++i) {
            QVariantMap service = m_services[i].toMap();
            if (service[QStringLiteral("workspace")].toString() == oldName) {
                service[QStringLiteral("workspace")] = newName;
                m_services[i] = service;
            }
        }

        // Update workspace list
        int index = m_workspaces.indexOf(oldName);
        if (index >= 0) {
            m_workspaces[index] = newName;
        }

        // Update current workspace if it was the renamed one
        if (m_currentWorkspace == oldName) {
            m_currentWorkspace = newName;
            Q_EMIT currentWorkspaceChanged();
        }

        // Move icon mapping along with the rename
        if (m_workspaceIcons.contains(oldName)) {
            const QString icon = m_workspaceIcons.value(oldName);
            m_workspaceIcons.remove(oldName);
            m_workspaceIcons.insert(newName, icon);
            Q_EMIT workspaceIconsChanged();
        }

        // Move isolated storage mapping along with the rename
        if (m_workspaceIsolatedStorage.contains(oldName)) {
            const bool isolated = m_workspaceIsolatedStorage.value(oldName);
            m_workspaceIsolatedStorage.remove(oldName);
            m_workspaceIsolatedStorage.insert(newName, isolated);
            Q_EMIT workspaceIsolatedStorageChanged();
        }

        // Move disabled workspace flag along with the rename
        if (m_disabledWorkspaces.contains(oldName)) {
            const bool disabled = m_disabledWorkspaces.value(oldName).toBool();
            m_disabledWorkspaces.remove(oldName);
            m_disabledWorkspaces.insert(newName, disabled);
        }

        Q_EMIT servicesChanged();
        Q_EMIT workspacesChanged();
        saveSettings();

        qDebug() << "Renamed workspace from:" << oldName << "to:" << newName;
    }
}

void ConfigManager::saveSettings()
{
    m_settings.beginGroup(QStringLiteral("Services"));
    m_settings.setValue(QStringLiteral("list"), m_services);
    m_settings.endGroup();

    m_settings.beginGroup(QStringLiteral("Workspaces"));
    m_settings.setValue(QStringLiteral("current"), m_currentWorkspace);
    // Persist workspace list
    m_settings.setValue(QStringLiteral("list"), m_workspaces);
    // Persist workspace icon map
    {
        QVariantMap iconMap;
        for (auto it = m_workspaceIcons.constBegin(); it != m_workspaceIcons.constEnd(); ++it) {
            iconMap.insert(it.key(), it.value());
        }
        m_settings.setValue(QStringLiteral("icons"), iconMap);
    }
    // Persist workspace isolated storage map
    {
        QVariantMap isolatedMap;
        for (auto it = m_workspaceIsolatedStorage.constBegin(); it != m_workspaceIsolatedStorage.constEnd(); ++it) {
            isolatedMap.insert(it.key(), it.value());
        }
        m_settings.setValue(QStringLiteral("isolatedStorage"), isolatedMap);
    }
    // Persist disabled workspaces map
    m_settings.setValue(QStringLiteral("disabled"), m_disabledWorkspaces);
    m_settings.endGroup();

    // Persist last used service per workspace
    m_settings.beginGroup(QStringLiteral("LastSession"));
    QVariantMap map;
    for (auto it = m_lastServiceByWorkspace.constBegin(); it != m_lastServiceByWorkspace.constEnd(); ++it) {
        map.insert(it.key(), it.value());
    }
    m_settings.setValue(QStringLiteral("lastServiceByWorkspace"), map);
    m_settings.endGroup();

    // Persist disabled services
    m_settings.beginGroup(QStringLiteral("DisabledServices"));
    m_settings.setValue(QStringLiteral("list"), m_disabledServices);
    m_settings.endGroup();

    // Persist muted services
    m_settings.beginGroup(QStringLiteral("MutedServices"));
    m_settings.setValue(QStringLiteral("list"), m_mutedServices);
    m_settings.endGroup();

    // Persist service tabs
    m_settings.beginGroup(QStringLiteral("ServiceTabs"));
    m_settings.setValue(QStringLiteral("tabs"), m_serviceTabs);
    m_settings.endGroup();

    // Persist display settings
    m_settings.beginGroup(QStringLiteral("Display"));
    m_settings.setValue(QStringLiteral("horizontalSidebar"), m_horizontalSidebar);
    m_settings.setValue(QStringLiteral("alwaysShowWorkspacesBar"), m_alwaysShowWorkspacesBar);
    m_settings.setValue(QStringLiteral("systemTrayEnabled"), m_systemTrayEnabled);
    m_settings.setValue(QStringLiteral("showZoomInHeader"), m_showZoomInHeader);
    m_settings.setValue(QStringLiteral("globalMute"), m_globalMute);
    m_settings.setValue(QStringLiteral("autostartEnabled"), m_autostartEnabled);
    m_settings.setValue(QStringLiteral("hideHeader"), m_hideHeader);
    m_settings.setValue(QStringLiteral("sidebarSizePreset"), m_sidebarSizePreset);
    m_settings.setValue(QStringLiteral("voiceChatService"), m_voiceChatService);
    m_settings.setValue(QStringLiteral("experimentalFeaturesEnabled"), m_experimentalFeaturesEnabled);
    m_settings.setValue(QStringLiteral("tlsProxyHosts"), m_tlsProxyHosts);
    m_settings.endGroup();

    m_settings.sync();
    qDebug() << "Settings saved. Services count:" << m_services.size() << "Current workspace:" << m_currentWorkspace
             << "Disabled services count:" << m_disabledServices.size();
}

void ConfigManager::loadSettings()
{
    m_settings.beginGroup(QStringLiteral("Services"));
    m_services = m_settings.value(QStringLiteral("list"), QVariantList()).toList();
    m_settings.endGroup();

    m_settings.beginGroup(QStringLiteral("Workspaces"));
    // Load workspace list explicitly
    m_workspaces = m_settings.value(QStringLiteral("list"), QStringList()).toStringList();
    m_currentWorkspace = m_settings.value(QStringLiteral("current"), QStringLiteral("Personal")).toString();
    // Load workspace icon map
    {
        const QVariantMap iconMap = m_settings.value(QStringLiteral("icons"), QVariantMap()).toMap();
        m_workspaceIcons.clear();
        for (auto it = iconMap.constBegin(); it != iconMap.constEnd(); ++it) {
            m_workspaceIcons.insert(it.key(), it.value().toString());
        }
    }
    // Load workspace isolated storage map
    {
        const QVariantMap isolatedMap = m_settings.value(QStringLiteral("isolatedStorage"), QVariantMap()).toMap();
        m_workspaceIsolatedStorage.clear();
        for (auto it = isolatedMap.constBegin(); it != isolatedMap.constEnd(); ++it) {
            m_workspaceIsolatedStorage.insert(it.key(), it.value().toBool());
        }
    }
    // Load disabled workspaces
    m_disabledWorkspaces = m_settings.value(QStringLiteral("disabled"), QVariantMap()).toMap();
    m_settings.endGroup();

    // Load last used service mapping
    m_settings.beginGroup(QStringLiteral("LastSession"));
    const QVariantMap map = m_settings.value(QStringLiteral("lastServiceByWorkspace"), QVariantMap()).toMap();
    m_lastServiceByWorkspace.clear();
    for (auto it = map.constBegin(); it != map.constEnd(); ++it) {
        m_lastServiceByWorkspace.insert(it.key(), it.value().toString());
    }
    m_settings.endGroup();

    // Load disabled services
    m_settings.beginGroup(QStringLiteral("DisabledServices"));
    m_disabledServices = m_settings.value(QStringLiteral("list"), QVariantMap()).toMap();
    m_settings.endGroup();

    // Load muted services
    m_settings.beginGroup(QStringLiteral("MutedServices"));
    m_mutedServices = m_settings.value(QStringLiteral("list"), QVariantMap()).toMap();
    m_settings.endGroup();

    // Load service tabs
    m_settings.beginGroup(QStringLiteral("ServiceTabs"));
    m_serviceTabs = m_settings.value(QStringLiteral("tabs"), QVariantMap()).toMap();
    m_settings.endGroup();

    // Load display settings
    m_settings.beginGroup(QStringLiteral("Display"));
    m_horizontalSidebar = m_settings.value(QStringLiteral("horizontalSidebar"), false).toBool();
    m_alwaysShowWorkspacesBar = m_settings.value(QStringLiteral("alwaysShowWorkspacesBar"), false).toBool();
    m_confirmDownloads = m_settings.value(QStringLiteral("confirmDownloads"), true).toBool();
    m_systemTrayEnabled = m_settings.value(QStringLiteral("systemTrayEnabled"), true).toBool();
    m_showZoomInHeader = m_settings.value(QStringLiteral("showZoomInHeader"), true).toBool();
    m_globalMute = m_settings.value(QStringLiteral("globalMute"), false).toBool();
    m_autostartEnabled = m_settings.value(QStringLiteral("autostartEnabled"), false).toBool();
    m_hideHeader = m_settings.value(QStringLiteral("hideHeader"), false).toBool();
    m_sidebarSizePreset = m_settings.value(QStringLiteral("sidebarSizePreset"), QStringLiteral("normal")).toString();
    m_voiceChatService = m_settings.value(QStringLiteral("voiceChatService"), QStringLiteral("perplexity")).toString();
    m_experimentalFeaturesEnabled = m_settings.value(QStringLiteral("experimentalFeaturesEnabled"), false).toBool();
    m_tlsProxyHosts =
        m_settings.value(QStringLiteral("tlsProxyHosts"), QStringList{QStringLiteral("api.standardnotes.com"), QStringLiteral("api.hcaptcha.com")})
            .toStringList();
    m_settings.endGroup();

    // Only update workspaces list if it's empty (first run)
    if (m_workspaces.isEmpty()) {
        updateWorkspacesList();
        // If still empty after updating, create Personal workspace as default
        if (m_workspaces.isEmpty()) {
            m_workspaces.append(QStringLiteral("Personal"));
            m_currentWorkspace = QStringLiteral("Personal");
            Q_EMIT workspacesChanged();
            Q_EMIT currentWorkspaceChanged();
        }
    }

    qDebug() << "Settings loaded. Services count:" << m_services.size() << "Workspaces:" << m_workspaces << "Current workspace:" << m_currentWorkspace
             << "Disabled services count:" << m_disabledServices.size();
}

void ConfigManager::setLastUsedService(const QString &workspace, const QString &serviceId)
{
    if (workspace.isEmpty() || serviceId.isEmpty()) {
        return;
    }
    const auto it = m_lastServiceByWorkspace.find(workspace);
    if (it == m_lastServiceByWorkspace.end() || it.value() != serviceId) {
        m_lastServiceByWorkspace.insert(workspace, serviceId);
        saveSettings();
        qDebug() << "Last used service set:" << workspace << serviceId;
    }
}

QString ConfigManager::lastUsedService(const QString &workspace) const
{
    return m_lastServiceByWorkspace.value(workspace);
}

void ConfigManager::updateWorkspacesList()
{
    QStringList newWorkspaces;

    // Extract workspaces from services
    for (const QVariant &serviceVariant : m_services) {
        QVariantMap service = serviceVariant.toMap();
        QString workspace = service[QStringLiteral("workspace")].toString();
        if (!workspace.isEmpty() && !newWorkspaces.contains(workspace) && !isSpecialWorkspace(workspace)) {
            newWorkspaces.append(workspace);
        }
    }

    // Ensure current workspace is in the list (but not special workspaces)
    if (!m_currentWorkspace.isEmpty() && !newWorkspaces.contains(m_currentWorkspace) && !isSpecialWorkspace(m_currentWorkspace)) {
        newWorkspaces.append(m_currentWorkspace);
    }

    if (newWorkspaces != m_workspaces) {
        m_workspaces = newWorkspaces;
        Q_EMIT workspacesChanged();
    }
}

bool ConfigManager::isSpecialWorkspace(const QString &workspaceName) const
{
    return workspaceName == FAVORITES_WORKSPACE || workspaceName == ALL_SERVICES_WORKSPACE;
}

void ConfigManager::setServiceFavorite(const QString &serviceId, bool favorite)
{
    for (int i = 0; i < m_services.size(); ++i) {
        QVariantMap service = m_services[i].toMap();
        if (service[QStringLiteral("id")].toString() == serviceId) {
            service[QStringLiteral("favorite")] = favorite;
            m_services[i] = service;
            Q_EMIT servicesChanged();
            saveSettings();
            qDebug() << "Service" << serviceId << (favorite ? "added to" : "removed from") << "favorites";
            return;
        }
    }
    qDebug() << "Service not found for favorite toggle:" << serviceId;
}

bool ConfigManager::isServiceFavorite(const QString &serviceId) const
{
    for (const QVariant &varService : m_services) {
        QVariantMap service = varService.toMap();
        if (service[QStringLiteral("id")].toString() == serviceId) {
            return service.value(QStringLiteral("favorite"), false).toBool();
        }
    }
    return false;
}

void ConfigManager::setServiceZoomFactor(const QString &serviceId, qreal zoomFactor)
{
    for (int i = 0; i < m_services.size(); ++i) {
        QVariantMap service = m_services[i].toMap();
        if (service[QStringLiteral("id")].toString() == serviceId) {
            service[QStringLiteral("zoomFactor")] = zoomFactor;
            m_services[i] = service;
            Q_EMIT servicesChanged();
            saveSettings();
            qDebug() << "Service" << serviceId << "zoom factor set to" << zoomFactor;
            return;
        }
    }
    qDebug() << "Service not found for zoom factor update:" << serviceId;
}

qreal ConfigManager::serviceZoomFactor(const QString &serviceId) const
{
    for (const QVariant &varService : m_services) {
        QVariantMap service = varService.toMap();
        if (service[QStringLiteral("id")].toString() == serviceId) {
            return service.value(QStringLiteral("zoomFactor"), 1.0).toReal();
        }
    }
    return 1.0;
}

bool ConfigManager::exportToJson(const QString &filePath) const
{
    QJsonObject root;
    root[QStringLiteral("version")] = 1;
    root[QStringLiteral("exportDate")] = QDateTime::currentDateTimeUtc().toString(Qt::ISODate);

    QJsonObject data;

    data[QStringLiteral("services")] = QJsonValue::fromVariant(m_services);

    QJsonObject workspacesObj;
    workspacesObj[QStringLiteral("current")] = m_currentWorkspace;
    workspacesObj[QStringLiteral("list")] = QJsonArray::fromStringList(m_workspaces);

    QJsonObject iconsObj;
    for (auto it = m_workspaceIcons.constBegin(); it != m_workspaceIcons.constEnd(); ++it) {
        iconsObj.insert(it.key(), it.value());
    }
    workspacesObj[QStringLiteral("icons")] = iconsObj;

    QJsonObject isolatedObj;
    for (auto it = m_workspaceIsolatedStorage.constBegin(); it != m_workspaceIsolatedStorage.constEnd(); ++it) {
        isolatedObj.insert(it.key(), it.value());
    }
    workspacesObj[QStringLiteral("isolatedStorage")] = isolatedObj;

    workspacesObj[QStringLiteral("disabled")] = QJsonValue::fromVariant(m_disabledWorkspaces);
    data[QStringLiteral("workspaces")] = workspacesObj;

    data[QStringLiteral("disabledServices")] = QJsonValue::fromVariant(m_disabledServices);
    data[QStringLiteral("mutedServices")] = QJsonValue::fromVariant(m_mutedServices);
    data[QStringLiteral("serviceTabs")] = QJsonValue::fromVariant(m_serviceTabs);

    QJsonObject displayObj;
    displayObj[QStringLiteral("horizontalSidebar")] = m_horizontalSidebar;
    displayObj[QStringLiteral("alwaysShowWorkspacesBar")] = m_alwaysShowWorkspacesBar;
    displayObj[QStringLiteral("systemTrayEnabled")] = m_systemTrayEnabled;
    displayObj[QStringLiteral("showZoomInHeader")] = m_showZoomInHeader;
    displayObj[QStringLiteral("globalMute")] = m_globalMute;
    displayObj[QStringLiteral("autostartEnabled")] = m_autostartEnabled;
    displayObj[QStringLiteral("hideHeader")] = m_hideHeader;
    displayObj[QStringLiteral("sidebarSizePreset")] = m_sidebarSizePreset;
    displayObj[QStringLiteral("voiceChatService")] = m_voiceChatService;
    displayObj[QStringLiteral("experimentalFeaturesEnabled")] = m_experimentalFeaturesEnabled;
    data[QStringLiteral("display")] = displayObj;

    root[QStringLiteral("data")] = data;

    QJsonDocument doc(root);
    QFile file(filePath);
    if (!file.open(QIODevice::WriteOnly)) {
        qWarning() << "Failed to open file for export:" << filePath;
        return false;
    }

    file.write(doc.toJson(QJsonDocument::Indented));
    file.close();
    qDebug() << "Configuration exported to:" << filePath;
    return true;
}

bool ConfigManager::importFromJson(const QString &filePath)
{
    QFile file(filePath);
    if (!file.open(QIODevice::ReadOnly)) {
        qWarning() << "Failed to open file for import:" << filePath;
        return false;
    }

    QByteArray content = file.readAll();
    file.close();

    QJsonParseError parseError;
    QJsonDocument doc = QJsonDocument::fromJson(content, &parseError);
    if (parseError.error != QJsonParseError::NoError) {
        qWarning() << "JSON parse error:" << parseError.errorString();
        return false;
    }

    QJsonObject root = doc.object();
    if (!root.contains(QStringLiteral("data")) || !root[QStringLiteral("data")].isObject()) {
        qWarning() << "Invalid import file: missing 'data' object";
        return false;
    }

    QJsonObject data = root[QStringLiteral("data")].toObject();

    if (data.contains(QStringLiteral("services")) && data[QStringLiteral("services")].isArray()) {
        m_services = data[QStringLiteral("services")].toArray().toVariantList();
    }

    if (data.contains(QStringLiteral("workspaces")) && data[QStringLiteral("workspaces")].isObject()) {
        QJsonObject ws = data[QStringLiteral("workspaces")].toObject();
        if (ws.contains(QStringLiteral("list")) && ws[QStringLiteral("list")].isArray()) {
            m_workspaces.clear();
            for (const QJsonValue &val : ws[QStringLiteral("list")].toArray()) {
                m_workspaces.append(val.toString());
            }
        }
        if (ws.contains(QStringLiteral("current")) && ws[QStringLiteral("current")].isString()) {
            m_currentWorkspace = ws[QStringLiteral("current")].toString();
        }
        if (ws.contains(QStringLiteral("icons")) && ws[QStringLiteral("icons")].isObject()) {
            m_workspaceIcons.clear();
            QJsonObject icons = ws[QStringLiteral("icons")].toObject();
            for (auto it = icons.constBegin(); it != icons.constEnd(); ++it) {
                m_workspaceIcons.insert(it.key(), it.value().toString());
            }
        }
        if (ws.contains(QStringLiteral("isolatedStorage")) && ws[QStringLiteral("isolatedStorage")].isObject()) {
            m_workspaceIsolatedStorage.clear();
            QJsonObject iso = ws[QStringLiteral("isolatedStorage")].toObject();
            for (auto it = iso.constBegin(); it != iso.constEnd(); ++it) {
                m_workspaceIsolatedStorage.insert(it.key(), it.value().toBool());
            }
        }
        if (ws.contains(QStringLiteral("disabled")) && ws[QStringLiteral("disabled")].isObject()) {
            m_disabledWorkspaces.clear();
            m_disabledWorkspaces = ws[QStringLiteral("disabled")].toObject().toVariantMap();
        }
    }

    if (data.contains(QStringLiteral("disabledServices")) && data[QStringLiteral("disabledServices")].isObject()) {
        m_disabledServices = data[QStringLiteral("disabledServices")].toObject().toVariantMap();
    }

    if (data.contains(QStringLiteral("mutedServices")) && data[QStringLiteral("mutedServices")].isObject()) {
        m_mutedServices = data[QStringLiteral("mutedServices")].toObject().toVariantMap();
    }

    if (data.contains(QStringLiteral("serviceTabs")) && data[QStringLiteral("serviceTabs")].isObject()) {
        m_serviceTabs = data[QStringLiteral("serviceTabs")].toObject().toVariantMap();
    }

    if (data.contains(QStringLiteral("display")) && data[QStringLiteral("display")].isObject()) {
        QJsonObject d = data[QStringLiteral("display")].toObject();
        m_horizontalSidebar = d.value(QStringLiteral("horizontalSidebar")).toBool(false);
        m_alwaysShowWorkspacesBar = d.value(QStringLiteral("alwaysShowWorkspacesBar")).toBool(false);
        m_systemTrayEnabled = d.value(QStringLiteral("systemTrayEnabled")).toBool(true);
        m_showZoomInHeader = d.value(QStringLiteral("showZoomInHeader")).toBool(true);
        m_globalMute = d.value(QStringLiteral("globalMute")).toBool(false);
        m_autostartEnabled = d.value(QStringLiteral("autostartEnabled")).toBool(false);
        m_hideHeader = d.value(QStringLiteral("hideHeader")).toBool(false);
        m_sidebarSizePreset = d.value(QStringLiteral("sidebarSizePreset")).toString(QStringLiteral("normal"));
        m_voiceChatService = d.value(QStringLiteral("voiceChatService")).toString(QStringLiteral("perplexity"));
        m_experimentalFeaturesEnabled = d.value(QStringLiteral("experimentalFeaturesEnabled")).toBool(false);
    }

    // Ensure there's at least one workspace
    if (m_workspaces.isEmpty()) {
        m_workspaces.append(QStringLiteral("Personal"));
        m_currentWorkspace = QStringLiteral("Personal");
    }

    // Clear last-used service cache since IDs may have changed
    m_lastServiceByWorkspace.clear();

    updateWorkspacesList();
    saveSettings();

    Q_EMIT servicesChanged();
    Q_EMIT workspacesChanged();
    Q_EMIT currentWorkspaceChanged();
    Q_EMIT workspaceIconsChanged();
    Q_EMIT workspaceIsolatedStorageChanged();
    Q_EMIT disabledWorkspacesChanged();
    Q_EMIT disabledServicesChanged();
    Q_EMIT mutedServicesChanged();
    Q_EMIT serviceTabsChanged();
    Q_EMIT globalMuteChanged();
    Q_EMIT horizontalSidebarChanged();
    Q_EMIT alwaysShowWorkspacesBarChanged();
    Q_EMIT systemTrayEnabledChanged();
    Q_EMIT showZoomInHeaderChanged();
    Q_EMIT autostartEnabledChanged();
    Q_EMIT hideHeaderChanged();
    Q_EMIT sidebarSizePresetChanged();
    Q_EMIT voiceChatServiceChanged();
    Q_EMIT experimentalFeaturesEnabledChanged();

    qDebug() << "Configuration imported from:" << filePath;
    return true;
}

void ConfigManager::exportConfigViaDialog()
{
    const QString defaultName = QDateTime::currentDateTime().toString(QStringLiteral("yyyy-MM-dd")) + QStringLiteral(" Unify backup.json");
    const QString filePath = QFileDialog::getSaveFileName(nullptr, tr("Export Configuration"), defaultName, tr("JSON Files (*.json)"));
    if (filePath.isEmpty()) {
        return;
    }
    if (!exportToJson(filePath)) {
        qWarning() << "Failed to export configuration to:" << filePath;
    }
}

void ConfigManager::importConfigViaDialog()
{
    const QString filePath = QFileDialog::getOpenFileName(nullptr, tr("Import Configuration"), QString(), tr("JSON Files (*.json)"));
    if (filePath.isEmpty()) {
        return;
    }
    if (!importFromJson(filePath)) {
        qWarning() << "Failed to import configuration from:" << filePath;
    }
}
