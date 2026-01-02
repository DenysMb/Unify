// Includes relevant modules used by the QML
import QtQuick
import QtQuick.Window
import QtQuick.Layouts
import QtCore
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

    // Track last two services for quick switching with double Ctrl
    property string previousServiceId: ""
    property string previousServiceWorkspace: ""

    // Flag to track if the app is fully initialized
    property bool appInitialized: false

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

    // Object to track services currently playing audio
    property var serviceAudibleStates: ({})

    // Object to track media metadata for services playing audio
    property var serviceMediaMetadata: ({})

    // Computed property for the currently playing service info (first audible service)
    // Kept for backward compatibility
    readonly property var nowPlayingInfo: {
        var audibleIds = Object.keys(serviceAudibleStates);
        if (audibleIds.length === 0) {
            return null;
        }
        var serviceId = audibleIds[0];
        var service = findServiceById(serviceId);
        if (!service) {
            return null;
        }
        var metadata = serviceMediaMetadata[serviceId] || {};
        return {
            serviceId: serviceId,
            serviceName: service.title,
            mediaTitle: metadata.title || "",
            mediaArtist: metadata.artist || "",
            mediaAlbum: metadata.album || ""
        };
    }

    // Computed property for all playing services with metadata
    readonly property var allPlayingServices: {
        var audibleIds = Object.keys(serviceAudibleStates);
        var playingList = [];

        for (var i = 0; i < audibleIds.length; i++) {
            var serviceId = audibleIds[i];
            var service = findServiceById(serviceId);
            if (!service) {
                continue;
            }
            var metadata = serviceMediaMetadata[serviceId] || {};
            playingList.push({
                serviceId: serviceId,
                serviceName: service.title,
                mediaTitle: metadata.title || "",
                mediaArtist: metadata.artist || "",
                mediaAlbum: metadata.album || ""
            });
        }

        return playingList;
    }

    // Watcher for notification counts to update tray icon
    onServiceNotificationCountsChanged: {
        if (trayIconManager) {
            // Check if there are any notifications across all services
            var hasNotifications = false;
            for (var serviceId in serviceNotificationCounts) {
                if (serviceNotificationCounts[serviceId] > 0) {
                    hasNotifications = true;
                    break;
                }
            }
            trayIconManager.hasNotifications = hasNotifications;
        }
    }

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

    // Function to find serviceId by URL origin
    function findServiceIdByOrigin(originUrl) {
        if (!services || !originUrl)
            return "";
        var originStr = originUrl.toString().toLowerCase();
        // Extract host from origin URL
        var originHost = "";
        try {
            originHost = originUrl.host ? originUrl.host.toLowerCase() : "";
            if (!originHost) {
                // Try to extract from string
                var match = originStr.match(/^https?:\/\/([^\/]+)/);
                if (match)
                    originHost = match[1].toLowerCase();
            }
        } catch (e) {
            console.warn("Error extracting host from origin:", e);
        }

        if (!originHost)
            return "";

        // Search through all services to find matching URL
        for (var i = 0; i < services.length; i++) {
            var service = services[i];
            if (service && service.url) {
                var serviceUrl = service.url.toString().toLowerCase();
                try {
                    var serviceMatch = serviceUrl.match(/^https?:\/\/([^\/]+)/);
                    if (serviceMatch) {
                        var serviceHost = serviceMatch[1].toLowerCase();
                        // Check if hosts match (including subdomains)
                        if (serviceHost === originHost || originHost.endsWith("." + serviceHost) || serviceHost.endsWith("." + originHost)) {
                            return service.id;
                        }
                    }
                } catch (e) {
                    continue;
                }
            }
        }
        return "";
    }

    // Function to find service index by ID
    function findServiceIndexById(id) {
        return Services.indexById(services, id);
    }

    // Function to toggle favorite status of a service
    function handleToggleFavorite(id) {
        if (!configManager)
            return;
        var isFavorite = configManager.isServiceFavorite(id);
        configManager.setServiceFavorite(id, !isFavorite);
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
            // Call setCurrentByServiceId with empty string to show empty state
            webViewStack.setCurrentByServiceId("");
        }
    }

    // Function to switch to a specific service by ID
    function switchToService(serviceId, skipHistory) {
        var service = findServiceById(serviceId);

        // Check if service belongs to current workspace
        // For special workspaces (__favorites__, __all_services__), allow switching to any service in filteredServices
        var isInCurrentWorkspace = false;
        if (configManager && configManager.isSpecialWorkspace(currentWorkspace)) {
            // For special workspaces, check if service is in filteredServices
            for (var i = 0; i < filteredServices.length; i++) {
                if (filteredServices[i].id === serviceId) {
                    isInCurrentWorkspace = true;
                    break;
                }
            }
        } else {
            // For regular workspaces, check workspace property
            isInCurrentWorkspace = service && service.workspace === currentWorkspace;
        }

        if (isInCurrentWorkspace) {
            // Track previous service for quick switching (only if not skipping history)
            if (!skipHistory && currentServiceId !== "" && currentServiceId !== serviceId) {
                previousServiceId = currentServiceId;
                previousServiceWorkspace = currentWorkspace;
            }

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

    // Function to switch to previous service (for double Ctrl)
    function switchToPreviousService() {
        if (previousServiceId === "" || previousServiceId === currentServiceId) {
            return false;
        }

        var prevService = findServiceById(previousServiceId);
        if (!prevService) {
            return false;
        }

        // Store current service as the new "previous" before switching
        var tempCurrentId = currentServiceId;
        var tempCurrentWorkspace = currentWorkspace;

        // Switch to the previous service's workspace if needed
        if (previousServiceWorkspace !== "" && previousServiceWorkspace !== currentWorkspace) {
            currentWorkspace = previousServiceWorkspace;
            if (configManager && configManager.currentWorkspace !== previousServiceWorkspace) {
                configManager.currentWorkspace = previousServiceWorkspace;
            }
        }

        // Switch to service without updating history (skipHistory = true)
        var success = switchToService(previousServiceId, true);

        if (success) {
            // Now set the previous service to what was current
            previousServiceId = tempCurrentId;
            previousServiceWorkspace = tempCurrentWorkspace;
        }

        return success;
    }

    // Workspaces configuration array
    // Workspaces are now managed by configManager
    property var workspaces: configManager ? configManager.workspaces : ["Personal"]

    // Firefox User-Agent string to simulate Firefox browser for compatibility with web services
    // Using latest stable Firefox version to avoid detection issues
    property string chromeUserAgent: "Mozilla/5.0 (X11; Linux x86_64; rv:145.0) Gecko/20100101 Firefox/145.0"

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
    // IMPORTANT: storageName must be set BEFORE the profile is used
    WebEngineProfile {
        id: persistentProfile

        // Set storageName first - this is critical for persistence
        storageName: "unify-storage"

        // Explicitly set to NOT be off-the-record (enables persistence)
        offTheRecord: false

        // Set user agent
        httpUserAgent: root.chromeUserAgent

        // Cache and cookie settings
        httpCacheType: WebEngineProfile.DiskHttpCache
        persistentCookiesPolicy: WebEngineProfile.ForcePersistentCookies

        onPresentNotification: function (notification) {
            if (notificationPresenter) {
                // Find the serviceId based on the notification origin
                var serviceId = root.findServiceIdByOrigin(notification.origin);
                console.log("📢 Notification from origin:", notification.origin.toString(), "-> serviceId:", serviceId);
                // Use the new method that passes the full notification object (includes icon)
                notificationPresenter.presentFromQmlWithNotification(notification, serviceId);
            }
        }

        onDownloadRequested: function (download) {
            var downloadDirUrl = StandardPaths.writableLocation(StandardPaths.DownloadLocation);
            var downloadDir = downloadDirUrl.toString().replace("file://", "");

            // Get unique filename to avoid overwriting existing files
            var fileName = fileUtils.getUniqueFileName(downloadDir, download.suggestedFileName);

            download.downloadDirectory = downloadDir;
            download.downloadFileName = fileName;

            // Monitor download completion
            download.isFinishedChanged.connect(function () {
                if (download.isFinished) {
                    var fullPath = downloadDir + "/" + fileName;
                    root.showPassiveNotification(i18n("Download completed: %1", fileName), "long");
                }
            });

            download.accept();
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

                // Update current service name if we edited the active service
                if (serviceId === root.currentServiceId) {
                    root.currentServiceName = serviceData.title;
                }

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
                    workspace: serviceData.workspace,
                    useFavicon: serviceData.useFavicon || false,
                    isolatedProfile: serviceData.isolatedProfile || false
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
                        webViewStack.setCurrentByServiceId("");
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

    // Handle tray icon manager signals
    Connections {
        target: trayIconManager
        function onShowWindowRequested() {
            root.show();
            root.raise();
            root.requestActivate();
            trayIconManager.windowVisible = true;
        }
        function onHideWindowRequested() {
            root.hide();
            trayIconManager.windowVisible = false;
        }
        function onQuitRequested() {
            Qt.quit();
        }
    }

    // Handle notification click events
    Connections {
        target: notificationPresenter
        function onNotificationClicked(serviceId) {
            console.log("📢 Notification clicked, switching to service:", serviceId);
            if (!serviceId)
                return;

            // Find the service to get its workspace
            var service = root.findServiceById(serviceId);
            if (!service) {
                console.warn("Service not found for notification click:", serviceId);
                return;
            }

            // Show and raise the window first
            root.show();
            root.raise();
            root.requestActivate();
            if (trayIconManager)
                trayIconManager.windowVisible = true;

            // Check if we're in a special workspace (Favorites or All Services)
            var isInSpecialWorkspace = configManager && configManager.isSpecialWorkspace(root.currentWorkspace);

            // Check if the service is available in the current workspace
            var isServiceInCurrentWorkspace = false;
            if (isInSpecialWorkspace) {
                // For special workspaces, check if service is in filteredServices
                for (var i = 0; i < root.filteredServices.length; i++) {
                    if (root.filteredServices[i].id === serviceId) {
                        isServiceInCurrentWorkspace = true;
                        break;
                    }
                }
            }

            // If we're in a special workspace and the service is available, stay in current workspace
            // Otherwise, switch to the service's original workspace
            if (isInSpecialWorkspace && isServiceInCurrentWorkspace) {
                // Stay in the current special workspace (Favorites or All Services)
                console.log("📢 Staying in current workspace:", root.currentWorkspace);
            } else if (service.workspace && service.workspace !== root.currentWorkspace) {
                // Switch to the service's workspace
                root.switchToWorkspace(service.workspace);
            }

            // Switch to the service
            root.switchToService(serviceId);
        }
    }

    // Update tray icon manager when window visibility changes
    onVisibilityChanged: function () {
        if (trayIconManager) {
            trayIconManager.windowVisible = (root.visibility !== Window.Hidden && root.visibility !== Window.Minimized);
        }
    }

    // Helper property to track horizontal sidebar setting
    property bool isHorizontalSidebar: configManager ? configManager.horizontalSidebar : false

    // Reference to the current WebViewStack (updated when layout changes)
    property var webViewStack: null

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
                visible: root.nowPlayingInfo !== null
                displayHint: Kirigami.DisplayHint.KeepVisible
                displayComponent: NowPlayingIndicator {
                    serviceName: root.nowPlayingInfo ? root.nowPlayingInfo.serviceName : ""
                    serviceId: root.nowPlayingInfo ? root.nowPlayingInfo.serviceId : ""
                    mediaTitle: root.nowPlayingInfo ? root.nowPlayingInfo.mediaTitle : ""
                    mediaArtist: root.nowPlayingInfo ? root.nowPlayingInfo.mediaArtist : ""
                    isPlaying: root.nowPlayingInfo !== null
                    playingServices: root.allPlayingServices
                    onSwitchToService: function (id) {
                        root.switchToService(id);
                    }
                }
            },
            Kirigami.Action {
                text: i18n("Refresh Service")
                icon.name: "view-refresh"
                enabled: root.currentServiceId !== ""
                onTriggered: {
                    if (root.currentServiceId !== "" && root.webViewStack) {
                        root.webViewStack.refreshByServiceId(root.currentServiceId);
                    }
                }
            },
            Kirigami.Action {
                text: i18n("Add Service")
                icon.name: "list-add"
                onTriggered: {
                    // Reset dialog to add mode
                    addServiceDialog.isEditMode = false;
                    addServiceDialog.clearFields();
                    addServiceDialog.open();
                }
            }
        ]

        // Dynamic layout loader based on horizontal sidebar setting
        Loader {
            anchors.fill: parent
            sourceComponent: root.isHorizontalSidebar ? horizontalLayoutComponent : verticalLayoutComponent
        }

        // Vertical layout component (sidebar on left - default)
        Component {
            id: verticalLayoutComponent
            ColumnLayout {
                spacing: 0

                RowLayout {
                    Layout.fillWidth: true
                    Layout.fillHeight: true
                    spacing: 0

                    ServicesSidebar {
                        id: sidebarVertical
                        horizontal: false
                        services: root.filteredServices
                        disabledServices: root.disabledServices
                        detachedServices: root.detachedServices
                        notificationCounts: root.serviceNotificationCounts
                        audibleServices: root.serviceAudibleStates
                        currentServiceId: root.currentServiceId
                        currentWorkspace: root.currentWorkspace
                        sidebarWidth: root.sidebarWidth
                        buttonSize: root.buttonSize
                        iconSize: root.iconSize
                        onServiceSelected: function (id) {
                            root.switchToService(id);
                            var svc = root.findServiceById(id);
                            if (svc)
                                console.log(svc.title + " clicked - loading " + svc.url);
                        }
                        onEditServiceRequested: function (id) {
                            var svc = root.findServiceById(id);
                            if (svc) {
                                root.editingServiceId = id;
                                addServiceDialog.isEditMode = true;
                                addServiceDialog.populateFields(svc);
                                addServiceDialog.open();
                            }
                        }
                        onMoveServiceUp: function (id) {
                            root.moveServiceUp(id);
                        }
                        onMoveServiceDown: function (id) {
                            root.moveServiceDown(id);
                        }
                        onRefreshService: function (id) {
                            webViewStackVertical.refreshByServiceId(id);
                            var svc = root.findServiceById(id);
                            if (svc)
                                console.log("Refreshing service: " + svc.title);
                        }
                        onDisableService: function (id) {
                            root.setServiceEnabled(id, root.isServiceDisabled(id));
                        }
                        onDetachService: function (id) {
                            if (root.isServiceDetached(id)) {
                                root.reattachService(id);
                            } else {
                                root.detachService(id);
                            }
                        }
                        onToggleFavoriteRequested: function (id) {
                            root.handleToggleFavorite(id);
                        }
                    }

                    Rectangle {
                        Layout.fillWidth: true
                        Layout.fillHeight: true
                        color: Kirigami.Theme.backgroundColor
                        WebViewStack {
                            id: webViewStackVertical
                            anchors.fill: parent
                            services: root.appInitialized ? root.services : []
                            filteredCount: root.filteredServices.length
                            currentWorkspace: root.currentWorkspace
                            disabledServices: root.disabledServices
                            webProfile: persistentProfile
                            onTitleUpdated: root.updateBadgeFromTitle
                            onAudibleServicesChanged: {
                                root.serviceAudibleStates = audibleServices;
                            }
                            onServiceMediaMetadataUpdated: function (serviceId, metadata) {
                                var meta = Object.assign({}, root.serviceMediaMetadata);
                                if (metadata) {
                                    meta[serviceId] = metadata;
                                } else {
                                    delete meta[serviceId];
                                }
                                root.serviceMediaMetadata = meta;
                            }
                            onUpdateServiceUrlRequested: function (serviceId, newUrl) {
                                var service = root.findServiceById(serviceId);
                                if (service && configManager) {
                                    var updatedService = {
                                        id: service.id,
                                        title: service.title,
                                        url: newUrl,
                                        image: service.image,
                                        workspace: service.workspace,
                                        useFavicon: service.useFavicon,
                                        favorite: service.favorite
                                    };
                                    configManager.updateService(serviceId, updatedService);
                                }
                            }
                            Component.onCompleted: {
                                root.webViewStack = webViewStackVertical;
                            }
                        }
                    }
                }

                WorkspacesBar {
                    showBar: configManager && configManager.alwaysShowWorkspacesBar
                    workspaces: root.workspaces
                    currentWorkspace: root.currentWorkspace
                    onSwitchToWorkspace: function (name) {
                        root.switchToWorkspace(name);
                    }
                }
            }
        }

        // Horizontal layout component (sidebar on top)
        Component {
            id: horizontalLayoutComponent
            ColumnLayout {
                spacing: 0

                ServicesSidebar {
                    id: sidebarHorizontal
                    horizontal: true
                    services: root.filteredServices
                    disabledServices: root.disabledServices
                    detachedServices: root.detachedServices
                    notificationCounts: root.serviceNotificationCounts
                    audibleServices: root.serviceAudibleStates
                    currentServiceId: root.currentServiceId
                    currentWorkspace: root.currentWorkspace
                    sidebarWidth: root.sidebarWidth
                    buttonSize: root.buttonSize
                    iconSize: root.iconSize
                    onServiceSelected: function (id) {
                        root.switchToService(id);
                        var svc = root.findServiceById(id);
                        if (svc)
                            console.log(svc.title + " clicked - loading " + svc.url);
                    }
                    onEditServiceRequested: function (id) {
                        var svc = root.findServiceById(id);
                        if (svc) {
                            root.editingServiceId = id;
                            addServiceDialog.isEditMode = true;
                            addServiceDialog.populateFields(svc);
                            addServiceDialog.open();
                        }
                    }
                    onMoveServiceUp: function (id) {
                        root.moveServiceUp(id);
                    }
                    onMoveServiceDown: function (id) {
                        root.moveServiceDown(id);
                    }
                    onRefreshService: function (id) {
                        webViewStackHorizontal.refreshByServiceId(id);
                        var svc = root.findServiceById(id);
                        if (svc)
                            console.log("Refreshing service: " + svc.title);
                    }
                    onDisableService: function (id) {
                        root.setServiceEnabled(id, root.isServiceDisabled(id));
                    }
                    onDetachService: function (id) {
                        if (root.isServiceDetached(id)) {
                            root.reattachService(id);
                        } else {
                            root.detachService(id);
                        }
                    }
                    onToggleFavoriteRequested: function (id) {
                        root.handleToggleFavorite(id);
                    }
                }

                Rectangle {
                    Layout.fillWidth: true
                    Layout.fillHeight: true
                    color: Kirigami.Theme.backgroundColor
                    WebViewStack {
                        id: webViewStackHorizontal
                        anchors.fill: parent
                        services: root.appInitialized ? root.services : []
                        filteredCount: root.filteredServices.length
                        currentWorkspace: root.currentWorkspace
                        disabledServices: root.disabledServices
                        webProfile: persistentProfile
                        onTitleUpdated: root.updateBadgeFromTitle
                        onAudibleServicesChanged: {
                            root.serviceAudibleStates = audibleServices;
                        }
                        onServiceMediaMetadataUpdated: function (serviceId, metadata) {
                            var meta = Object.assign({}, root.serviceMediaMetadata);
                            if (metadata) {
                                meta[serviceId] = metadata;
                            } else {
                                delete meta[serviceId];
                            }
                            root.serviceMediaMetadata = meta;
                        }
                        onUpdateServiceUrlRequested: function (serviceId, newUrl) {
                            var service = root.findServiceById(serviceId);
                            if (service && configManager) {
                                var updatedService = {
                                    id: service.id,
                                    title: service.title,
                                    url: newUrl,
                                    image: service.image,
                                    workspace: service.workspace,
                                    useFavicon: service.useFavicon,
                                    favorite: service.favorite
                                };
                                configManager.updateService(serviceId, updatedService);
                            }
                        }
                        Component.onCompleted: {
                            root.webViewStack = webViewStackHorizontal;
                        }
                    }
                }

                WorkspacesBar {
                    showBar: configManager && configManager.alwaysShowWorkspacesBar
                    workspaces: root.workspaces
                    currentWorkspace: root.currentWorkspace
                    onSwitchToWorkspace: function (name) {
                        root.switchToWorkspace(name);
                    }
                }
            }
        }
    }

    // Initialize with the first workspace on startup - delayed to ensure profile is ready
    Component.onCompleted: {
        // Initialize disabled services from configManager
        if (configManager && configManager.disabledServices) {
            root.disabledServices = configManager.disabledServices;
        }

        // Delay initialization to ensure WebEngineProfile is fully set up
        initTimer.start();
    }

    // Timer to delay service loading until profile is ready
    Timer {
        id: initTimer
        interval: 100  // Small delay to ensure profile initialization
        repeat: false
        onTriggered: {
            console.log("Initializing app after profile setup...");
            root.appInitialized = true;

            // Use persisted current workspace
            var ws = root.currentWorkspace;
            if (!ws || ws === "")
                ws = workspaces[0];
            root.switchToWorkspace(ws);
        }
    }

    // Quick switch to previous service using double Ctrl or Ctrl+` (backtick/grave)
    // Similar to Alt+Tab behavior for switching between last two services
    Connections {
        target: keyEventFilter
        function onDoubleCtrlPressed() {
            root.switchToPreviousService();
        }
    }

    // Alternative: Ctrl+` shortcut for quick switching
    Shortcut {
        sequences: ["Ctrl+`"]
        context: Qt.ApplicationShortcut
        onActivated: {
            root.switchToPreviousService();
        }
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

    // Print current page with Ctrl+P
    Shortcut {
        sequences: ["Ctrl+P"]
        context: Qt.ApplicationShortcut
        onActivated: {
            if (root.currentServiceId !== "" && root.webViewStack) {
                var webView = root.webViewStack.getCurrentWebView();
                if (webView && webView.printPage) {
                    webView.printPage();
                }
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

    // Ctrl+B => Favorites workspace
    Shortcut {
        sequences: ["Ctrl+B"]
        context: Qt.ApplicationShortcut
        onActivated: switchToWorkspace("__favorites__")
    }

    // Function to detach a service (open in separate window)
    // Uses reparenting to preserve WebView state (video playback, calls, etc.)
    function detachService(serviceId) {
        var service = findServiceById(serviceId);
        if (!service) {
            console.log("Service not found:", serviceId);
            return false;
        }

        // Check if already detached
        if (isServiceDetached(serviceId)) {
            console.log("Service already detached:", service.title);
            return false;
        }

        // Get the ServiceWebView container (not just WebEngineView)
        var serviceWebView = webViewStack.getServiceWebViewByServiceId(serviceId);
        if (!serviceWebView) {
            console.log("ServiceWebView not found for service:", serviceId);
            return false;
        }

        // Detach the WebView from the stack (prepares for reparenting)
        var detachedView = webViewStack.detachWebView(serviceId);
        if (!detachedView) {
            console.log("Failed to detach WebView from stack:", service.title);
            return false;
        }

        // Create detached window component
        var detachedComponent = Qt.createComponent("DetachedServiceWindow.qml");
        if (detachedComponent.status !== Component.Ready) {
            console.log("Failed to load detached window component:", detachedComponent.errorString());
            // Reattach the view back if window creation fails
            webViewStack.reattachWebView(serviceId, detachedView);
            return false;
        }

        // Create the detached window with the existing WebView
        var detachedWindow = detachedComponent.createObject(root, {
            "serviceId": serviceId,
            "serviceTitle": service.title
        });

        if (!detachedWindow) {
            console.log("Failed to create detached window for:", service.title);
            // Reattach the view back if window creation fails
            webViewStack.reattachWebView(serviceId, detachedView);
            return false;
        }

        // Reparent the existing ServiceWebView to the detached window
        // This preserves all WebView state (video, audio, WebRTC calls, etc.)
        detachedView.parent = detachedWindow.webViewContainer;
        detachedView.anchors.fill = detachedWindow.webViewContainer;
        detachedView.visible = true;

        // Set the existingWebView property for the window to reference
        detachedWindow.existingWebView = detachedView;

        // Connect to window closed signal
        detachedWindow.windowClosed.connect(function (closedServiceId) {
            reattachService(closedServiceId);
        });

        // Store the detached window and view references
        var newDetachedServices = Object.assign({}, detachedServices);
        newDetachedServices[serviceId] = {
            window: detachedWindow,
            webView: detachedView
        };
        detachedServices = newDetachedServices;

        // Show the detached window
        detachedWindow.show();
        detachedWindow.raise();

        console.log("Service detached (with state preserved):", service.title);
        return true;
    }

    // Function to reattach a service (close detached window and re-enable in main)
    // Reparents the WebView back to the main window stack, preserving state
    function reattachService(serviceId) {
        if (!isServiceDetached(serviceId)) {
            return false;
        }

        var service = findServiceById(serviceId);
        if (!service) {
            return false;
        }

        // Get the detached window and webview
        var detached = detachedServices[serviceId];
        if (!detached) {
            return false;
        }

        var detachedWindow = detached.window;
        var serviceWebView = detached.webView;

        if (serviceWebView) {
            // Reparent the ServiceWebView back to the stack
            // This preserves all WebView state
            webViewStack.reattachWebView(serviceId, serviceWebView);
        }

        // Close and cleanup detached window (but not the WebView!)
        if (detachedWindow) {
            // Clear the reference to prevent destroying the reparented WebView
            detachedWindow.existingWebView = null;
            detachedWindow.close();
            detachedWindow.destroy();
        }

        // Remove from detached services
        var newDetachedServices = Object.assign({}, detachedServices);
        delete newDetachedServices[serviceId];
        detachedServices = newDetachedServices;

        console.log("Service reattached (with state preserved):", service.title);
        return true;
    }

    // Function to check if a service is detached
    function isServiceDetached(serviceId) {
        return detachedServices.hasOwnProperty(serviceId) && detachedServices[serviceId] !== null;
    }

    // Function to get detached window for a service
    function getDetachedWindow(serviceId) {
        if (isServiceDetached(serviceId)) {
            return detachedServices[serviceId].window;
        }
        return null;
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

    // Function to move a service up in the list
    function moveServiceUp(serviceId) {
        // Prevent moving services in special workspaces
        if (configManager && configManager.isSpecialWorkspace(currentWorkspace)) {
            console.log("Cannot move services in special workspace:", currentWorkspace);
            return false;
        }

        if (!configManager || !configManager.moveService) {
            console.log("ConfigManager moveService not available");
            return false;
        }

        var currentIndex = findServiceIndexById(serviceId);
        if (currentIndex <= 0) {
            // Already at the top or not found
            return false;
        }

        // Find the previous service in the same workspace
        var service = findServiceById(serviceId);
        if (!service) {
            return false;
        }

        var targetIndex = -1;
        for (var i = currentIndex - 1; i >= 0; i--) {
            if (services[i].workspace === service.workspace) {
                targetIndex = i;
                break;
            }
        }

        if (targetIndex === -1) {
            // No previous service in the same workspace
            return false;
        }

        configManager.moveService(currentIndex, targetIndex);
        console.log("Moved service up:", service.title);
        return true;
    }

    // Function to move a service down in the list
    function moveServiceDown(serviceId) {
        // Prevent moving services in special workspaces
        if (configManager && configManager.isSpecialWorkspace(currentWorkspace)) {
            console.log("Cannot move services in special workspace:", currentWorkspace);
            return false;
        }

        if (!configManager || !configManager.moveService) {
            console.log("ConfigManager moveService not available");
            return false;
        }

        var currentIndex = findServiceIndexById(serviceId);
        if (currentIndex === -1 || currentIndex >= services.length - 1) {
            // Not found or already at the bottom
            return false;
        }

        // Find the next service in the same workspace
        var service = findServiceById(serviceId);
        if (!service) {
            return false;
        }

        var targetIndex = -1;
        for (var i = currentIndex + 1; i < services.length; i++) {
            if (services[i].workspace === service.workspace) {
                targetIndex = i;
                break;
            }
        }

        if (targetIndex === -1) {
            // No next service in the same workspace
            return false;
        }

        configManager.moveService(currentIndex, targetIndex);
        console.log("Moved service down:", service.title);
        return true;
    }
}
