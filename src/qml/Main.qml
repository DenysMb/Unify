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
    // Now loaded from and saved to configManager
    property var disabledServices: configManager ? configManager.disabledServices : ({})

    // Object to track detached service IDs and their window instances
    property var detachedServices: ({})

    // Temporary property to track which service is being edited (to avoid changing currentServiceId)
    property string editingServiceId: ""

    // Object to track notification counts per service ID
    property var serviceNotificationCounts: ({})

    // Function to update badge from service title
    function updateBadgeFromTitle(serviceId, title) {
        // Regex to extract notification count from title: (n) or [n] at the beginning
        var match = title.match(/^\s*[\(\[]\s*(\d+)\s*[\)\]]/);

        if (match && match[1]) {
            var count = parseInt(match[1], 10);

            // Show badge if count > 0, regardless of whether service is active
            if (count > 0) {
                var newCounts = Object.assign({}, serviceNotificationCounts);
                newCounts[serviceId] = count;
                serviceNotificationCounts = newCounts;
            } else {
                // Remove badge if count is 0
                var newCounts = Object.assign({}, serviceNotificationCounts);
                delete newCounts[serviceId];
                serviceNotificationCounts = newCounts;
            }
        } else {
            // No match found, remove badge if exists
            var newCounts = Object.assign({}, serviceNotificationCounts);
            delete newCounts[serviceId];
            serviceNotificationCounts = newCounts;
        }
    }

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
            webViewStack.setCurrentByServiceId(usedService.id);
        } else if (firstService) {
            currentServiceName = firstService.title;
            currentServiceId = firstService.id;
            // Select by service ID in the global web view stack
            webViewStack.setCurrentByServiceId(firstService.id);
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

    // Modern Chrome User-Agent string for compatibility with web services (WhatsApp Web, Proton, etc.)
    property string chromeUserAgent: "Mozilla/5.0 (X11; Linux x86_64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36"

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
    // Keep notifications working by forwarding to C++ presenter.
    WebEngineProfile {
        id: persistentProfile
        storageName: "unify-default"
        offTheRecord: false
        httpUserAgent: root.chromeUserAgent
        httpCacheType: WebEngineProfile.DiskHttpCache
        persistentCookiesPolicy: WebEngineProfile.ForcePersistentCookies
        // Allow 3rd-party cookies to improve SSO persistence across restarts
        // (property available in recent Qt versions)
        // thirdPartyCookiePolicy: WebEngineProfile.AlwaysAllowThirdPartyCookies
        onPresentNotification: function (notification) {
            if (notificationPresenter && notificationPresenter.presentFromQml) {
                notificationPresenter.presentFromQml(notification.title, notification.message, notification.origin);
            }
            if (notification && notification.close)
                notification.close();
        }
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
                addWorkspaceDialog.initialName = root.workspaces[index];
                // Pre-fill current icon if available
                if (configManager && configManager.workspaceIcons) {
                    var iconMap = configManager.workspaceIcons;
                    addWorkspaceDialog.initialIcon = iconMap[addWorkspaceDialog.initialName] || "folder";
                } else {
                    addWorkspaceDialog.initialIcon = "folder";
                }
                addWorkspaceDialog.populateFields(addWorkspaceDialog.initialName);
                addWorkspaceDialog.open();
            }
        }
    }

    // Add/Edit Service Dialog
    ServiceDialog {
        id: addServiceDialog
        workspaces: root.workspaces
        currentWorkspace: root.currentWorkspace
        onRejected: {
            // Clear temporary editing ID when dialog is cancelled
            root.editingServiceId = "";
        }
        onAcceptedData: function (serviceData) {
            if (isEditMode) {
                // Use editingServiceId if set (right-click edit), otherwise use currentServiceId (menu edit)
                var serviceId = root.editingServiceId || root.currentServiceId;
                // If workspace changed during edit, switch to the new workspace and keep service selected
                var prev = root.findServiceById(serviceId);
                var prevWs = prev ? prev.workspace : "";
                if (configManager)
                    configManager.updateService(serviceId, serviceData);
                if (serviceData.workspace && serviceData.workspace !== prevWs) {
                    root.switchToWorkspace(serviceData.workspace);
                    Qt.callLater(function () {
                        root.switchToService(serviceId);
                    });
                }
                // No need to manually reselect - onServicesChanged handler will take care of it
                // Clear temporary editing ID
                root.editingServiceId = "";
            } else {
                // Create a stable ID up front so we can select the new service after adding
                var newId = root.generateUUID();
                var newService = {
                    id: newId,
                    title: serviceData.title,
                    url: serviceData.url,
                    image: serviceData.image,
                    workspace: serviceData.workspace
                };
                if (configManager)
                    configManager.addService(newService);
                // If created in another workspace, switch to it
                if (newService.workspace && newService.workspace !== root.currentWorkspace) {
                    root.switchToWorkspace(newService.workspace);
                }
                // After the model updates and views are created, select the newly added service
                Qt.callLater(function () {
                    root.switchToService(newId);
                });
            }
        }
        onDeleteRequested: {
            if (isEditMode && configManager) {
                // Use editingServiceId if set (right-click edit), otherwise use currentServiceId (menu edit)
                var deletedId = root.editingServiceId || root.currentServiceId;
                if (deletedId === "")
                    return;

                var ws = root.currentWorkspace;
                configManager.removeService(deletedId);
                addServiceDialog.close();
                // Clear temporary editing ID
                root.editingServiceId = "";
                // After services update, choose next service: last used in workspace if available and exists; otherwise first
                Qt.callLater(function () {
                    var nextId = "";
                    var last = configManager && configManager.lastUsedService ? configManager.lastUsedService(ws) : "";
                    // Helper to check membership
                    function findIdx(list, id) {
                        for (var i = 0; i < list.length; ++i) {
                            if (list[i].id === id)
                                return i;
                        }
                        return -1;
                    }
                    var list = root.filteredServices; // reflects current workspace
                    if (last && last !== "" && findIdx(list, last) !== -1) {
                        nextId = last;
                    } else if (list && list.length > 0) {
                        nextId = list[0].id;
                    }
                    if (nextId && nextId !== "") {
                        root.switchToService(nextId);
                        if (configManager && configManager.setLastUsedService)
                            configManager.setLastUsedService(ws, nextId);
                    } else {
                        // No services left in workspace; show empty state
                        root.currentServiceName = i18n("Unify - Web app aggregator");
                        root.currentServiceId = "";
                        webViewStack.currentIndex = 0;
                    }
                });
            }
        }
    }

    // Add/Edit Workspace Dialog
    WorkspaceDialog {
        id: addWorkspaceDialog
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
                    // Switch to the newly created workspace
                    root.switchToWorkspace(workspaceName);
                }
            }
        }
        onDeleteRequested: {
            if (isEditMode && editingIndex >= 0 && editingIndex < root.workspaces.length && configManager) {
                var wsName = root.workspaces[editingIndex];
                configManager.removeWorkspace(wsName);
                addWorkspaceDialog.close();
            }
        }
    }

    // Permission Request Dialog (componente)
    PermissionDialog {
        id: permissionDialog
    }

    // Keep currently selected service visible after services list changes (add/update/remove)
    Connections {
        target: configManager
        function onServicesChanged() {
            // Only reselect if we have an active service and it still exists
            if (root.currentServiceId && root.currentServiceId !== "") {
                var stillExists = root.findServiceById(root.currentServiceId);
                if (stillExists) {
                    Qt.callLater(function () {
                        webViewStack.setCurrentByServiceId(root.currentServiceId);
                    });
                }
            }
        }
        function onDisabledServicesChanged() {
            // Update local disabledServices when configManager changes
            root.disabledServices = configManager.disabledServices;
        }
        function onCurrentWorkspaceChanged() {
            // Sync QML currentWorkspace when ConfigManager changes it (e.g., after workspace deletion)
            if (configManager.currentWorkspace !== root.currentWorkspace) {
                root.switchToWorkspace(configManager.currentWorkspace);
            }
        }
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
                    addServiceDialog.clearFields();
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
                enabled: root.currentServiceId !== "" && !root.isServiceDisabled(root.currentServiceId) && !root.isServiceDetached(root.currentServiceId)
                onTriggered: {
                    webViewStack.refreshCurrent();
                    console.log("Refreshing service: " + root.currentServiceName);
                }
            },
            Kirigami.Action {
                text: root.isServiceDetached(root.currentServiceId) ? i18n("Reattach Service") : i18n("Detach Service")
                icon.name: root.isServiceDetached(root.currentServiceId) ? "view-restore" : "view-split-left-right"
                enabled: root.currentServiceId !== "" && !root.isServiceDisabled(root.currentServiceId)
                onTriggered: {
                    if (root.currentServiceId !== "") {
                        if (root.isServiceDetached(root.currentServiceId)) {
                            root.reattachService(root.currentServiceId);
                        } else {
                            root.detachService(root.currentServiceId);
                        }
                    }
                }
            },
            Kirigami.Action {
                text: root.isServiceDisabled(root.currentServiceId) ? i18n("Enable Service") : i18n("Disable Service")
                icon.name: root.isServiceDisabled(root.currentServiceId) ? "media-playback-start" : "media-playback-pause"
                enabled: root.currentServiceId !== "" && !root.isServiceDetached(root.currentServiceId)
                onTriggered: {
                    if (root.currentServiceId !== "") {
                        root.setServiceEnabled(root.currentServiceId, root.isServiceDisabled(root.currentServiceId));
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
                detachedServices: root.detachedServices
                notificationCounts: root.serviceNotificationCounts
                currentServiceId: root.currentServiceId
                sidebarWidth: root.sidebarWidth
                buttonSize: root.buttonSize
                iconSize: root.iconSize
                onServiceSelected: function (id) {
                    root.switchToService(id);
                    var svc = root.findServiceById(id);
                    if (svc)
                        console.log(svc.title + " clicked - loading " + svc.url);
                }
                onServiceRightClicked: function (id) {
                    var svc = root.findServiceById(id);
                    if (svc) {
                        // Store which service is being edited without changing the active service
                        root.editingServiceId = id;
                        // Open edit dialog for this service
                        addServiceDialog.isEditMode = true;
                        addServiceDialog.populateFields(svc);
                        addServiceDialog.open();
                    }
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
                    // Keep all services instantiated to preserve background activity across workspaces
                    services: root.services
                    // Drive empty state off the filtered (current workspace) count
                    filteredCount: root.filteredServices.length
                    disabledServices: root.disabledServices
                    webProfile: persistentProfile
                    onTitleUpdated: root.updateBadgeFromTitle
                }
            }
        }
    }

    // Initialize with the first workspace on startup
    Component.onCompleted: {
        // Initialize disabled services from configManager
        if (configManager && configManager.disabledServices) {
            root.disabledServices = configManager.disabledServices;
        }

        // Use persisted current workspace
        var ws = root.currentWorkspace;
        if (!ws || ws === "")
            ws = workspaces[0];
        switchToWorkspace(ws);
    }

    // Toggle fullscreen on F11 (StandardKey.FullScreen)
    Shortcut {
        id: fullscreenShortcut
        sequences: [StandardKey.FullScreen, "F11"]
        context: Qt.WindowShortcut
        onActivated: {
            if (root.visibility === Window.FullScreen) {
                root.showNormal();
            } else {
                root.showFullScreen();
            }
        }
    }

    // --- Numeric shortcuts: Ctrl+1..9 for services (within current workspace) ---
    // Helper to switch to Nth service (1-based) in filteredServices
    function switchToServiceByPosition(pos) {
        if (!filteredServices || filteredServices.length === 0)
            return;
        var idx = Math.max(0, Math.min(filteredServices.length - 1, pos - 1));
        var svc = filteredServices[idx];
        if (svc && svc.id) {
            switchToService(svc.id);
        }
    }
    // Helper to switch to Nth workspace (1-based)
    function switchToWorkspaceByPosition(pos) {
        if (!workspaces || workspaces.length === 0)
            return;
        var idx = Math.max(0, Math.min(workspaces.length - 1, pos - 1));
        var ws = workspaces[idx];
        if (ws) {
            switchToWorkspace(ws);
        }
    }
    // Cycle helpers
    function cycleService(next) {
        if (!filteredServices || filteredServices.length === 0)
            return;
        var count = filteredServices.length;
        var cur = 0;
        for (var i = 0; i < count; ++i) {
            if (filteredServices[i].id === currentServiceId) {
                cur = i;
                break;
            }
        }
        var target = (cur + (next ? 1 : -1) + count) % count;
        switchToService(filteredServices[target].id);
    }
    function cycleWorkspace(next) {
        if (!workspaces || workspaces.length === 0)
            return;
        var count = workspaces.length;
        var cur = Math.max(0, workspaces.indexOf(currentWorkspace));
        var target = (cur + (next ? 1 : -1) + count) % count;
        switchToWorkspace(workspaces[target]);
    }

    // Ctrl+Tab: next service
    Shortcut {
        sequences: ["Ctrl+Tab"]
        context: Qt.ApplicationShortcut
        onActivated: cycleService(true)
    }
    // Ctrl+Shift+Tab: next workspace
    Shortcut {
        sequences: ["Ctrl+Shift+Tab"]
        context: Qt.ApplicationShortcut
        onActivated: cycleWorkspace(true)
    }

    // Ctrl+1..Ctrl+9 => Nth service
    Shortcut {
        sequences: ["Ctrl+1"]
        context: Qt.ApplicationShortcut
        onActivated: switchToServiceByPosition(1)
    }
    Shortcut {
        sequences: ["Ctrl+2"]
        context: Qt.ApplicationShortcut
        onActivated: switchToServiceByPosition(2)
    }
    Shortcut {
        sequences: ["Ctrl+3"]
        context: Qt.ApplicationShortcut
        onActivated: switchToServiceByPosition(3)
    }
    Shortcut {
        sequences: ["Ctrl+4"]
        context: Qt.ApplicationShortcut
        onActivated: switchToServiceByPosition(4)
    }
    Shortcut {
        sequences: ["Ctrl+5"]
        context: Qt.ApplicationShortcut
        onActivated: switchToServiceByPosition(5)
    }
    Shortcut {
        sequences: ["Ctrl+6"]
        context: Qt.ApplicationShortcut
        onActivated: switchToServiceByPosition(6)
    }
    Shortcut {
        sequences: ["Ctrl+7"]
        context: Qt.ApplicationShortcut
        onActivated: switchToServiceByPosition(7)
    }
    Shortcut {
        sequences: ["Ctrl+8"]
        context: Qt.ApplicationShortcut
        onActivated: switchToServiceByPosition(8)
    }
    Shortcut {
        sequences: ["Ctrl+9"]
        context: Qt.ApplicationShortcut
        onActivated: switchToServiceByPosition(9)
    }

    // Ctrl+Shift+1..Ctrl+Shift+9 => Nth workspace
    Shortcut {
        sequences: ["Ctrl+Shift+1"]
        context: Qt.ApplicationShortcut
        onActivated: switchToWorkspaceByPosition(1)
    }
    Shortcut {
        sequences: ["Ctrl+Shift+2"]
        context: Qt.ApplicationShortcut
        onActivated: switchToWorkspaceByPosition(2)
    }
    Shortcut {
        sequences: ["Ctrl+Shift+3"]
        context: Qt.ApplicationShortcut
        onActivated: switchToWorkspaceByPosition(3)
    }
    Shortcut {
        sequences: ["Ctrl+Shift+4"]
        context: Qt.ApplicationShortcut
        onActivated: switchToWorkspaceByPosition(4)
    }
    Shortcut {
        sequences: ["Ctrl+Shift+5"]
        context: Qt.ApplicationShortcut
        onActivated: switchToWorkspaceByPosition(5)
    }
    Shortcut {
        sequences: ["Ctrl+Shift+6"]
        context: Qt.ApplicationShortcut
        onActivated: switchToWorkspaceByPosition(6)
    }
    Shortcut {
        sequences: ["Ctrl+Shift+7"]
        context: Qt.ApplicationShortcut
        onActivated: switchToWorkspaceByPosition(7)
    }
    Shortcut {
        sequences: ["Ctrl+Shift+8"]
        context: Qt.ApplicationShortcut
        onActivated: switchToWorkspaceByPosition(8)
    }
    Shortcut {
        sequences: ["Ctrl+Shift+9"]
        context: Qt.ApplicationShortcut
        onActivated: switchToWorkspaceByPosition(9)
    }

    // Function to detach a service (open in separate window)
    function detachService(serviceId) {
        var service = findServiceById(serviceId);
        if (!service || service.workspace !== currentWorkspace) {
            return false;
        }

        // Check if already detached
        if (isServiceDetached(serviceId)) {
            console.log("Service already detached:", service.title);
            return false;
        }

        // Get the current WebView to preserve state
        var webView = webViewStack.getWebViewByServiceId(serviceId);
        if (!webView) {
            console.log("WebView not found for service:", serviceId);
            return false;
        }

        // Create detached window component
        var detachedComponent = Qt.createComponent("DetachedServiceWindow.qml");
        if (detachedComponent.status !== Component.Ready) {
            console.log("Failed to load detached window component:", detachedComponent.errorString());
            return false;
        }

        // Create the detached window
        var detachedWindow = detachedComponent.createObject(root, {
            "serviceId": serviceId,
            "serviceTitle": service.title,
            "serviceUrl": webView.url // Use current URL to preserve state
            ,
            "webProfile": persistentProfile
        });

        if (!detachedWindow) {
            console.log("Failed to create detached window for:", service.title);
            return false;
        }

        // Connect to window closed signal
        detachedWindow.windowClosed.connect(function (closedServiceId) {
            reattachService(closedServiceId);
        });

        // Store the detached window reference
        detachedServices[serviceId] = detachedWindow;

        // Disable the service in the main window (similar to disabled services)
        disabledServices[serviceId] = true;
        webView.stop();
        webView.url = "about:blank";

        // Show the detached window
        detachedWindow.show();
        detachedWindow.raise();

        // Emit signals to update UI
        disabledServicesChanged();

        console.log("Service detached:", service.title);
        return true;
    }

    // Function to reattach a service (close detached window and re-enable in main)
    function reattachService(serviceId) {
        if (!isServiceDetached(serviceId)) {
            return false;
        }

        var service = findServiceById(serviceId);
        if (!service) {
            return false;
        }

        // Get the detached window
        var detachedWindow = detachedServices[serviceId];
        if (detachedWindow && detachedWindow.webView) {
            // Get the current URL from the detached window to preserve state
            var currentUrl = detachedWindow.webView.url;

            // Re-enable service in main window
            delete disabledServices[serviceId];
            var mainWebView = webViewStack.getWebViewByServiceId(serviceId);
            if (mainWebView && currentUrl && currentUrl.toString() !== "about:blank") {
                mainWebView.url = currentUrl;
            } else if (mainWebView) {
                mainWebView.url = service.url;
            }

            // Close and cleanup detached window
            detachedWindow.close();
            detachedWindow.destroy();
        }

        // Remove from detached services
        delete detachedServices[serviceId];

        // Emit signals to update UI
        disabledServicesChanged();

        console.log("Service reattached:", service.title);
        return true;
    }

    // Function to check if a service is detached
    function isServiceDetached(serviceId) {
        return detachedServices.hasOwnProperty(serviceId);
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
                // Update configManager to persist the state
                if (configManager && configManager.setServiceDisabled) {
                    configManager.setServiceDisabled(serviceId, !enabled);
                }
            }
        }
    }

    // Function to check if a service is disabled
    function isServiceDisabled(serviceId) {
        return disabledServices.hasOwnProperty(serviceId);
    }
}
