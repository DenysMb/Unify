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
    m_settings.endGroup();
    
    m_settings.sync();
    qDebug() << "Settings saved. Services count:" << m_services.size() 
             << "Current workspace:" << m_currentWorkspace;
}

void ConfigManager::loadSettings()
{
    m_settings.beginGroup(QStringLiteral("Services"));
    m_services = m_settings.value(QStringLiteral("list"), QVariantList()).toList();
    m_settings.endGroup();
    
    m_settings.beginGroup(QStringLiteral("Workspaces"));
    m_currentWorkspace = m_settings.value(QStringLiteral("current"), QStringLiteral("Personal")).toString();
    m_settings.endGroup();
    
    updateWorkspacesList();
    
    // Ensure we have at least one workspace
    if (m_workspaces.isEmpty()) {
        m_workspaces.append(QStringLiteral("Personal"));
        m_currentWorkspace = QStringLiteral("Personal");
        Q_EMIT workspacesChanged();
        Q_EMIT currentWorkspaceChanged();
    }
    
    qDebug() << "Settings loaded. Services count:" << m_services.size() 
             << "Workspaces:" << m_workspaces 
             << "Current workspace:" << m_currentWorkspace;
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