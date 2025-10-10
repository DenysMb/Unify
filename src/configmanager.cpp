#include "configmanager.h"
#include <QDebug>
#include <QUuid>

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
    
    m_services.append(newService);
    updateWorkspacesList();
    Q_EMIT servicesChanged();
    saveSettings();
    
    qDebug() << "Added service:" << newService[QStringLiteral("title")].toString() 
             << "to workspace:" << newService[QStringLiteral("workspace")].toString();
}

void ConfigManager::updateService(const QString &serviceId, const QVariantMap &service)
{
    for (int i = 0; i < m_services.size(); ++i) {
        QVariantMap existingService = m_services[i].toMap();
        if (existingService[QStringLiteral("id")].toString() == serviceId) {
            QVariantMap updatedService = service;
            updatedService[QStringLiteral("id")] = serviceId; // Preserve the ID
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

void ConfigManager::addWorkspace(const QString &workspaceName)
{
    if (!workspaceName.isEmpty() && !m_workspaces.contains(workspaceName)) {
        m_workspaces.append(workspaceName);
        Q_EMIT workspacesChanged();
        saveSettings();
        
        qDebug() << "Added workspace:" << workspaceName;
    }
}

void ConfigManager::removeWorkspace(const QString &workspaceName)
{
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
    // Persist workspace icon map
    {
        QVariantMap iconMap;
        for (auto it = m_workspaceIcons.constBegin(); it != m_workspaceIcons.constEnd(); ++it) {
            iconMap.insert(it.key(), it.value());
        }
        m_settings.setValue(QStringLiteral("icons"), iconMap);
    }
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
    m_currentWorkspace = m_settings.value(QStringLiteral("current"), QStringLiteral("Personal")).toString();
    // Load workspace icon map
    {
        const QVariantMap iconMap = m_settings.value(QStringLiteral("icons"), QVariantMap()).toMap();
        m_workspaceIcons.clear();
        for (auto it = iconMap.constBegin(); it != iconMap.constEnd(); ++it) {
            m_workspaceIcons.insert(it.key(), it.value().toString());
        }
    }
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

    updateWorkspacesList();

    // Ensure we have at least one workspace
    if (m_workspaces.isEmpty()) {
        m_workspaces.append(QStringLiteral("Personal"));
        m_currentWorkspace = QStringLiteral("Personal");
        Q_EMIT workspacesChanged();
        Q_EMIT currentWorkspaceChanged();
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
        if (!workspace.isEmpty() && !newWorkspaces.contains(workspace)) {
            newWorkspaces.append(workspace);
        }
    }
    
    // Ensure current workspace is in the list
    if (!m_currentWorkspace.isEmpty() && !newWorkspaces.contains(m_currentWorkspace)) {
        newWorkspaces.append(m_currentWorkspace);
    }
    
    // Always have at least "Personal" workspace
    if (newWorkspaces.isEmpty() || !newWorkspaces.contains(QStringLiteral("Personal"))) {
        newWorkspaces.append(QStringLiteral("Personal"));
    }
    
    if (newWorkspaces != m_workspaces) {
        m_workspaces = newWorkspaces;
        Q_EMIT workspacesChanged();
    }
}
