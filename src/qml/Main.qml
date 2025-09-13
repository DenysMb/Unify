// Includes relevant modules used by the QML
import QtQuick
import QtQuick.Window
import QtQuick.Layouts
import QtWebEngine
// Controls are used in components; WebEngine used here for profile
import org.kde.kirigami as Kirigami
// Note: QML files are flattened into module root by CMake.
// Use types directly and import JS by its root alias.
import "Services.js" as Services

// Provides basic features needed for all kirigami applications
Kirigami.ApplicationWindow {
    // Unique identifier to reference this object
    id: root

    width: 1200
    height: 800

    property int buttonSize: 64
    property int iconSize: 64 - Kirigami.Units.smallSpacing * 4
    property int sidebarWidth: buttonSize + Kirigami.Units.smallSpacing * 2

    // Current selected service name for the header
    property string currentServiceName: i18n("Unify - Web app aggregator")

    // Current active workspace - bound to configManager
    property string currentWorkspace: configManager ? configManager.currentWorkspace : "Personal"

    // Current selected service ID (empty string means no service selected)
    property string currentServiceId: ""

    // Update configManager when currentWorkspace changes
    onCurrentWorkspaceChanged: {
        if (configManager && configManager.currentWorkspace !== currentWorkspace) {
            configManager.currentWorkspace = currentWorkspace;
        }
    }

    // Object to track disabled service IDs (using object instead of Set for QML compatibility)
    property var disabledServices: ({})

    // Function to generate random UUID
    function generateUUID() {
        return Services.generateUUID();
    }

    // Function to find service by ID
    function findServiceById(id) {
        return Services.findById(services, id);
    }

    // Function to find service index by ID
    function findServiceIndexById(id) {
        return Services.indexById(services, id);
    }

    // Function to switch workspace and select first service
    function switchToWorkspace(workspaceName) {
        currentWorkspace = workspaceName;

        if (!configManager || !configManager.services) {
            currentServiceName = i18n("Unify - Web app aggregator");
            currentServiceId = "";
            return;
        }

        // Find first service in the new workspace
        var services = configManager.services;
        var firstService = null;
        var firstServiceIndex = -1;
        for (var i = 0; i < services.length; i++) {
            if (services[i].workspace === workspaceName) {
                firstService = services[i];
                firstServiceIndex = i;
                break;
            }
        }

        // Try last used service for this workspace
        var lastId = configManager && configManager.lastUsedService ? configManager.lastUsedService(workspaceName) : "";
        var usedService = null;
        var usedFilteredIndex = -1;
        if (lastId && lastId !== "") {
            for (var j = 0; j < filteredServices.length; j++) {
                if (filteredServices[j].id === lastId) {
                    usedService = filteredServices[j];
                    usedFilteredIndex = j;
                    break;
                }
            }
        }

        if (usedService) {
            currentServiceName = usedService.title;
            currentServiceId = usedService.id;
            webViewStack.currentIndex = usedFilteredIndex + 1; // +1 because empty state is index 0
        } else if (firstService) {
            currentServiceName = firstService.title;
            currentServiceId = firstService.id;
            // Find index in filtered services (which is what the repeater uses)
            var filteredIndex = -1;
            for (var k = 0; k < filteredServices.length; k++) {
                if (filteredServices[k].id === firstService.id) {
                    filteredIndex = k;
                    break;
                }
            }
            webViewStack.currentIndex = filteredIndex >= 0 ? filteredIndex + 1 : 0;
        } else {
            // No services in this workspace
            currentServiceName = i18n("Unify - Web app aggregator");
            currentServiceId = "";
            webViewStack.currentIndex = 0; // Show empty state
        }
    }

    // Function to switch to a specific service by ID
    function switchToService(serviceId) {
        var service = findServiceById(serviceId);
        if (service && service.workspace === currentWorkspace) {
            currentServiceName = service.title;
            currentServiceId = service.id;

            // Find index in filtered services
            webViewStack.setCurrentByServiceId(serviceId);
            if (configManager && configManager.setLastUsedService) {
                configManager.setLastUsedService(currentWorkspace, serviceId);
            }
            return true;
        }
        return false;
    }

    // Workspaces configuration array
    // Workspaces are now managed by configManager
    property var workspaces: configManager ? configManager.workspaces : ["Personal"]

    // Firefox user agent string to ensure compatibility with Google OAuth and modern web apps
    property string firefoxUserAgent: "Mozilla/5.0 (X11; Linux x86_64; rv:131.0) Gecko/20100101 Firefox/131.0"

    // Services configuration array
    // Services are now managed by configManager
    property var services: configManager ? configManager.services : []

    // Filtered services based on current workspace
    property var filteredServices: Services.filterByWorkspace(services, currentWorkspace)

    // Reusable border color that matches Kirigami's internal separators
    property color borderColor: {
        var textColor = Kirigami.Theme.textColor;
        return Qt.rgba(textColor.r, textColor.g, textColor.b, 0.2);
    }

    // Shared persistent WebEngine profile for all web views (ensures cookies/storage persist)
    // Use the same configuration as main.cpp to avoid inconsistencies
    WebEngineProfile {
        id: persistentProfile
        storageName: "unify-default"
        offTheRecord: false
        httpUserAgent: root.firefoxUserAgent
        httpCacheType: WebEngineProfile.DiskHttpCache
        persistentCookiesPolicy: WebEngineProfile.ForcePersistentCookies
        // Use default cache/persistent paths derived from storageName and app dirs
    }

    // Window title
    // i18nc() makes a string translatable
    // and provides additional context for the translators
    title: i18nc("@title:window", "Unify")

    // Global drawer (hamburger menu)
    globalDrawer: WorkspaceDrawer {
        id: drawer
        workspaces: root.workspaces
        currentWorkspace: root.currentWorkspace
        onSwitchToWorkspace: function (name) {
            root.switchToWorkspace(name);
        }
        onAddWorkspaceRequested: {
            addWorkspaceDialog.isEditMode = false;
            addWorkspaceDialog.clearFields();
            addWorkspaceDialog.open();
        }
        onEditWorkspaceRequested: function (index) {
            if (index >= 0 && index < root.workspaces.length) {
                addWorkspaceDialog.isEditMode = true;
                addWorkspaceDialog.editingIndex = index;
                addWorkspaceDialog.initialName = root.workspaces[index]
                // Pre-fill current icon if available
                if (configManager && configManager.workspaceIcons) {
                    var iconMap = configManager.workspaceIcons
                    addWorkspaceDialog.initialIcon = iconMap[addWorkspaceDialog.initialName] || "folder"
                } else {
                    addWorkspaceDialog.initialIcon = "folder"
                }
                addWorkspaceDialog.populateFields(addWorkspaceDialog.initialName);
                addWorkspaceDialog.open();
            }
        }
    }

    // Add/Edit Service Dialog
    ServiceDialog {
        id: addServiceDialog
        property bool isEditMode: false
        workspaces: root.workspaces
        onAcceptedData: function (serviceData) {
            if (isEditMode) {
                if (configManager)
                    configManager.updateService(root.currentServiceId, serviceData);
            } else {
                if (configManager)
                    configManager.addService(serviceData);
            }
        }
    }

    // Add/Edit Workspace Dialog
    WorkspaceDialog {
        id: addWorkspaceDialog
        property bool isEditMode: false
        property int editingIndex: -1
        onAcceptedWorkspace: function (workspaceName, iconName) {
            if (isEditMode) {
                if (editingIndex >= 0 && editingIndex < root.workspaces.length && configManager) {
                    var oldWorkspaceName = root.workspaces[editingIndex];
                    configManager.renameWorkspace(oldWorkspaceName, workspaceName);
                    // Always set/update icon regardless of rename
                    if (configManager.setWorkspaceIcon)
                        configManager.setWorkspaceIcon(workspaceName, iconName || "folder");
                }
            } else {
                if (configManager) {
                    configManager.addWorkspace(workspaceName);
                    if (configManager.setWorkspaceIcon)
                        configManager.setWorkspaceIcon(workspaceName, iconName || "folder");
                }
            }
        }
    }

    // Permission Request Dialog (componente)
    PermissionDialog {
        id: permissionDialog
    }

    // Set the first page that will be loaded when the app opens
    // This can also be set to an id of a Kirigami.Page
    pageStack.initialPage: Kirigami.Page {
        // Remove default padding to make sidebar go to window edge
        padding: 0

        // Dynamic title based on selected service
        title: root.currentServiceName

        // Add actions to the page header
        actions: [
            Kirigami.Action {
                text: i18n("Add Service")
                icon.name: "list-add"
                onTriggered: {
                    // Reset dialog to add mode
                    addServiceDialog.isEditMode = false;
                    addServiceDialog.open();
                }
            },
            Kirigami.Action {
                text: i18n("Edit Service")
                icon.name: "document-edit"
                enabled: root.currentServiceId !== ""
                onTriggered: {
                    // Set dialog to edit mode and populate with current service data
                    addServiceDialog.isEditMode = true;
                    var currentService = root.findServiceById(root.currentServiceId);
                    if (currentService) {
                        addServiceDialog.populateFields(currentService);
                    }
                    addServiceDialog.open();
                }
            },
            Kirigami.Action {
                text: i18n("Refresh Service")
                icon.name: "view-refresh"
                enabled: root.currentServiceId !== "" && !root.isServiceDisabled(root.currentServiceId)
                onTriggered: {
                    webViewStack.refreshCurrent();
                    console.log("Refreshing service: " + root.currentServiceName);
                }
            },
            Kirigami.Action {
                text: root.isServiceDisabled(root.currentServiceId) ? i18n("Enable Service") : i18n("Disable Service")
                icon.name: root.isServiceDisabled(root.currentServiceId) ? "media-playback-start" : "media-playback-pause"
                enabled: root.currentServiceId !== ""
                checkable: true
                checked: root.isServiceDisabled(root.currentServiceId)
                onCheckedChanged: {
                    if (root.currentServiceId !== "") {
                        root.setServiceEnabled(root.currentServiceId, !checked);
                    }
                }
            }
        ]

        RowLayout {
            anchors.fill: parent
            spacing: 0

            // Left sidebar
            ServicesSidebar {
                services: root.filteredServices
                disabledServices: root.disabledServices
                sidebarWidth: root.sidebarWidth
                buttonSize: root.buttonSize
                iconSize: root.iconSize
                onServiceSelected: function (id) {
                    root.switchToService(id);
                    var svc = root.findServiceById(id);
                    if (svc)
                        console.log(svc.title + " clicked - loading " + svc.url);
                }
            }

            // Main content area
            Rectangle {
                Layout.fillWidth: true
                Layout.fillHeight: true
                color: Kirigami.Theme.backgroundColor
                WebViewStack {
                    id: webViewStack
                    anchors.fill: parent
                    services: root.filteredServices
                    disabledServices: root.disabledServices
                    webProfile: persistentProfile
                }
            }
        }
    }

    // Initialize with the first workspace on startup
    Component.onCompleted: {
        // Use persisted current workspace
        var ws = root.currentWorkspace;
        if (!ws || ws === "") ws = workspaces[0];
        switchToWorkspace(ws);
    }

    // Toggle fullscreen on F11 (StandardKey.FullScreen)
    Shortcut {
        id: fullscreenShortcut
        sequences: [ StandardKey.FullScreen, "F11" ]
        context: Qt.WindowShortcut
        onActivated: {
            if (root.visibility === Window.FullScreen) {
                root.showNormal()
            } else {
                root.showFullScreen()
            }
        }
    }

    // Function to disable/enable a service
    function setServiceEnabled(serviceId, enabled) {
        var service = findServiceById(serviceId);
        if (service && service.workspace === currentWorkspace) {
            var webView = webViewStack.getWebViewByServiceId(serviceId);
            if (webView) {
                if (enabled) {
                    // Re-enable service
                    delete disabledServices[serviceId];
                    webView.url = service.url;
                } else {
                    // Disable service
                    disabledServices[serviceId] = true;
                    webView.stop();
                    webView.url = "about:blank";
                }
                // Emit property change signal so QML knows to update bindings
                disabledServicesChanged();
            }
        }
    }

    // Function to check if a service is disabled
    function isServiceDisabled(serviceId) {
        return disabledServices.hasOwnProperty(serviceId);
    }
}
