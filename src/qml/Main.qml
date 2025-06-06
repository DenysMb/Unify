// Includes relevant modules used by the QML
import QtQuick
import QtQuick.Layouts
import QtQuick.Controls as Controls
import QtWebEngine
import org.kde.kirigami as Kirigami
import org.kde.notification

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
    
    // Current active workspace
    property string currentWorkspace: "Personal"
    
    // Current selected service ID (empty string means no service selected)
    property string currentServiceId: ""
    
    // Object to track disabled service IDs (using object instead of Set for QML compatibility)
    property var disabledServices: ({})
    
    // Function to generate random UUID
    function generateUUID() {
        return 'xxxxxxxx-xxxx-4xxx-yxxx-xxxxxxxxxxxx'.replace(/[xy]/g, function(c) {
            var r = Math.random() * 16 | 0;
            var v = c == 'x' ? r : (r & 0x3 | 0x8);
            return v.toString(16);
        });
    }
    
    // Function to find service by ID
    function findServiceById(id) {
        for (var i = 0; i < services.length; i++) {
            if (services[i].id === id) {
                return services[i];
            }
        }
        return null;
    }
    
    // Function to find service index by ID
    function findServiceIndexById(id) {
        for (var i = 0; i < services.length; i++) {
            if (services[i].id === id) {
                return i;
            }
        }
        return -1;
    }
    
    // Function to switch workspace and select first service
    function switchToWorkspace(workspaceName) {
        currentWorkspace = workspaceName;
        
        // Find first service in the new workspace
        var firstService = null;
        var firstServiceIndex = -1;
        for (var i = 0; i < services.length; i++) {
            if (services[i].workspace === workspaceName) {
                firstService = services[i];
                firstServiceIndex = i;
                break;
            }
        }
        
        // If we found a service, select it and switch to its WebView
        if (firstService) {
            currentServiceName = firstService.title;
            currentServiceId = firstService.id;
            webViewStack.currentIndex = firstServiceIndex;
        } else {
            // No services in this workspace
            currentServiceName = i18n("Unify - Web app aggregator");
            currentServiceId = "";
            // Keep current WebView visible or show first one
        }
    }
    
    // Function to switch to a specific service by ID
    function switchToService(serviceId) {
        var serviceIndex = findServiceIndexById(serviceId);
        if (serviceIndex >= 0) {
            var service = services[serviceIndex];
            currentServiceName = service.title;
            currentServiceId = service.id;
            webViewStack.currentIndex = serviceIndex;
            return true;
        }
        return false;
    }
    
    // Workspaces configuration array
    property var workspaces: ["Personal", "Work"]
    
    // Services configuration array
    property var services: [
        { 
            id: 'kde-001',
            title: 'Notification Test', 
            url: 'https://www.bennish.net/web-notifications.html',
            image: 'https://www.svgrepo.com/show/24723/chat.svg',
            workspace: 'Personal'
        },
        { 
            id: 'gnome-001',
            title: 'Webcam Test', 
            url: 'https://pt.webcamtests.com/',
            image: 'https://www.svgrepo.com/show/122752/webcam.svg',
            workspace: 'Personal'
        },
        { 
            id: 'opensuse-001',
            title: 'Microphone Test', 
            url: 'https://mictests.com/',
            image: 'https://www.svgrepo.com/show/144970/microphone.svg',
            workspace: 'Personal'
        },
        { 
            id: 'fedora-001',
            title: 'Screen Share Test', 
            url: 'https://onlinescreenshare.com/',
            image: 'https://www.svgrepo.com/show/149608/television.svg',
            workspace: 'Work'
        },
        { 
            id: 'discord-001',
            title: 'Discord', 
            url: 'https://discord.com/channels/@me',
            image: 'https://www.svgrepo.com/show/149608/television.svg',
            workspace: 'Work'
        }
    ]
    
    // Filtered services based on current workspace
    property var filteredServices: services.filter(function(service) {
        return service.workspace === currentWorkspace;
    })

    // Reusable border color that matches Kirigami's internal separators
    property color borderColor: {
        var textColor = Kirigami.Theme.textColor;
        return Qt.rgba(textColor.r, textColor.g, textColor.b, 0.2);
    }

    // Window title
    // i18nc() makes a string translatable
    // and provides additional context for the translators
    title: i18nc("@title:window", "Unify")

    // Global drawer (hamburger menu)
    globalDrawer: Kirigami.GlobalDrawer {
        actions: [
            Kirigami.Action {
                text: i18n(root.workspaces[0]) // "Personal"
                icon.name: "folder"
                onTriggered: {
                    root.switchToWorkspace(root.workspaces[0])
                    console.log(root.workspaces[0] + " workspace clicked")
                }
            },
            Kirigami.Action {
                text: i18n(root.workspaces[1]) // "Work"
                icon.name: "folder"
                onTriggered: {
                    root.switchToWorkspace(root.workspaces[1])
                    console.log(root.workspaces[1] + " workspace clicked")
                }
            },
            Kirigami.Action {
                separator: true
            },
            Kirigami.Action {
                text: i18n("Edit Workspace")
                icon.name: "document-edit"
                enabled: root.currentWorkspace !== ""
                onTriggered: {
                    // Set dialog to edit mode and populate with current workspace
                    addWorkspaceDialog.isEditMode = true
                    addWorkspaceDialog.editingIndex = root.workspaces.indexOf(root.currentWorkspace)
                    addWorkspaceDialog.populateFields(root.currentWorkspace)
                    addWorkspaceDialog.open()
                }
            },
            Kirigami.Action {
                text: i18n("Add Workspace")
                icon.name: "folder-new"
                onTriggered: {
                    // Reset dialog to add mode
                    addWorkspaceDialog.isEditMode = false
                    addWorkspaceDialog.clearFields()
                    addWorkspaceDialog.open()
                }
            }
        ]
    }

    // Add Service Dialog
    Kirigami.Dialog {
        id: addServiceDialog
        
        property bool isEditMode: false
        
        title: isEditMode ? i18n("Edit Service") : i18n("Add Service")
        
        standardButtons: Kirigami.Dialog.Ok | Kirigami.Dialog.Cancel
        padding: Kirigami.Units.largeSpacing
        preferredWidth: Kirigami.Units.gridUnit * 20
        
        function populateFields(service) {
            serviceNameField.text = service.title
            iconUrlField.text = service.image
            serviceUrlField.text = service.url
            workspaceComboBox.currentIndex = root.workspaces.indexOf(service.workspace)
        }
        
        function clearFields() {
            serviceNameField.text = ""
            iconUrlField.text = ""
            serviceUrlField.text = ""
            workspaceComboBox.currentIndex = 0
        }
        
        onAccepted: {
            var serviceData = {
                title: serviceNameField.text,
                url: serviceUrlField.text,
                image: iconUrlField.text,
                workspace: root.workspaces[workspaceComboBox.currentIndex]
            }
            
            if (isEditMode) {
                // Update existing service
                var serviceIndex = root.findServiceIndexById(root.currentServiceId)
                if (serviceIndex >= 0) {
                    serviceData.id = root.currentServiceId  // Keep the same ID
                    var updatedServices = root.services.slice()
                    updatedServices[serviceIndex] = serviceData
                    root.services = updatedServices
                }
            } else {
                // Add new service with generated UUID
                serviceData.id = root.generateUUID()
                var updatedServices = root.services.slice()
                updatedServices.push(serviceData)
                root.services = updatedServices
            }
            
            // Clear the form
            clearFields()
        }
        
        Kirigami.FormLayout {
            Controls.TextField {
                id: serviceNameField
                Kirigami.FormData.label: i18n("Service Name:")
                placeholderText: i18n("Enter service name")
            }
            
            Controls.TextField {
                id: iconUrlField
                Kirigami.FormData.label: i18n("Icon URL:")
                placeholderText: i18n("Enter icon URL")
            }
            
            Controls.TextField {
                id: serviceUrlField
                Kirigami.FormData.label: i18n("Service URL:")
                placeholderText: i18n("Enter service URL")
            }
            
            Controls.ComboBox {
                id: workspaceComboBox
                Kirigami.FormData.label: i18n("Workspace:")
                model: root.workspaces
            }
        }
    }

    // Add Workspace Dialog
    Kirigami.Dialog {
        id: addWorkspaceDialog
        
        property bool isEditMode: false
        property int editingIndex: -1
        
        title: isEditMode ? i18n("Edit Workspace") : i18n("Add Workspace")
        
        standardButtons: Kirigami.Dialog.Ok | Kirigami.Dialog.Cancel
        padding: Kirigami.Units.largeSpacing
        preferredWidth: Kirigami.Units.gridUnit * 20
        
        function populateFields(workspaceName) {
            workspaceNameField.text = workspaceName
        }
        
        function clearFields() {
            workspaceNameField.text = ""
        }
        
        onAccepted: {
            var workspaceName = workspaceNameField.text.trim()
            
            if (workspaceName === "") {
                console.log("Workspace name cannot be empty")
                return
            }
            
            if (isEditMode) {
                // Update existing workspace
                if (editingIndex >= 0 && editingIndex < root.workspaces.length) {
                    var updatedWorkspaces = root.workspaces.slice()
                    var oldWorkspaceName = updatedWorkspaces[editingIndex]
                    updatedWorkspaces[editingIndex] = workspaceName
                    root.workspaces = updatedWorkspaces
                    
                    // Update all services that use the old workspace name
                    var updatedServices = root.services.slice()
                    for (var i = 0; i < updatedServices.length; i++) {
                        if (updatedServices[i].workspace === oldWorkspaceName) {
                            updatedServices[i].workspace = workspaceName
                        }
                    }
                    root.services = updatedServices
                    
                    // Update current workspace if it was the one being edited
                    if (root.currentWorkspace === oldWorkspaceName) {
                        root.currentWorkspace = workspaceName
                    }
                }
            } else {
                // Add new workspace
                if (root.workspaces.indexOf(workspaceName) === -1) {
                    var updatedWorkspaces = root.workspaces.slice()
                    updatedWorkspaces.push(workspaceName)
                    root.workspaces = updatedWorkspaces
                } else {
                    console.log("Workspace with name '" + workspaceName + "' already exists")
                }
            }
            
            // Clear the form
            clearFields()
        }
        
        Kirigami.FormLayout {
            Controls.TextField {
                id: workspaceNameField
                Kirigami.FormData.label: i18n("Workspace Name:")
                placeholderText: i18n("Enter workspace name")
            }
        }
    }

    // Web Notification System
    Notification {
        id: webNotification
        componentName: "unify"
        eventId: "web-notification"
        defaultAction: i18n("Open")
        iconName: "dialog-information"
    }
    
    // Function to show web notifications as system notifications
    function showWebNotification(title, message, serviceName, origin) {
        webNotification.title = title || i18n("Web Notification")
        webNotification.text = message || i18n("Notification from ") + serviceName
        webNotification.sendEvent()
        console.log("📢 Web notification displayed: " + title + " from " + serviceName + " (" + origin + ")")
    }

    // Permission Request Dialog
    Kirigami.Dialog {
        id: permissionDialog
        
        property var pendingPermission: null
        property string serviceName: ""
        
        title: i18n("Permission Request")
        standardButtons: Kirigami.Dialog.Ok | Kirigami.Dialog.Cancel
        padding: Kirigami.Units.largeSpacing
        preferredWidth: Kirigami.Units.gridUnit * 25
        
        onAccepted: {
            if (pendingPermission) {
                pendingPermission.grant()
                console.log("Permission granted for " + serviceName)
            }
        }
        
        onRejected: {
            if (pendingPermission) {
                pendingPermission.deny()
                console.log("Permission denied for " + serviceName)
            }
        }
        
        function showPermissionRequest(permission, serviceTitle) {
            pendingPermission = permission
            serviceName = serviceTitle
            permissionText.text = questionForPermissionType(permission, serviceTitle)
            open()
        }
        
        function questionForPermissionType(permission, serviceTitle) {
            var question = i18n("Allow %1 to ", serviceTitle)
            
            switch (permission.permissionType) {
            case WebEnginePermission.PermissionType.Geolocation:
                question += i18n("access your location information?")
                break
            case WebEnginePermission.PermissionType.MediaAudioCapture:
                question += i18n("access your microphone?")
                break
            case WebEnginePermission.PermissionType.MediaVideoCapture:
                question += i18n("access your webcam?")
                break
            case WebEnginePermission.PermissionType.MediaAudioVideoCapture:
                question += i18n("access your microphone and webcam?")
                break
            case WebEnginePermission.PermissionType.Notifications:
                question += i18n("show notifications on your desktop?")
                break
            case WebEnginePermission.PermissionType.DesktopAudioVideoCapture:
                question += i18n("capture audio and video of your desktop?")
                break
            default:
                question += i18n("access unknown or unsupported permission type [%1]?", permission.permissionType)
                break
            }
            
            return question
        }
        
        Controls.Label {
            id: permissionText
            Layout.fillWidth: true
            wrapMode: Text.WordWrap
            horizontalAlignment: Text.AlignLeft
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
                    addServiceDialog.isEditMode = false
                    addServiceDialog.open()
                }
            },
            Kirigami.Action {
                text: i18n("Edit Service")
                icon.name: "document-edit"
                enabled: root.currentServiceId !== ""
                onTriggered: {
                    // Set dialog to edit mode and populate with current service data
                    addServiceDialog.isEditMode = true
                    var currentService = root.findServiceById(root.currentServiceId)
                    if (currentService) {
                        addServiceDialog.populateFields(currentService)
                    }
                    addServiceDialog.open()
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
                        root.setServiceEnabled(root.currentServiceId, !checked)
                    }
                }
            }
        ]

        RowLayout {
            anchors.fill: parent
            spacing: 0

            // Left sidebar
            Rectangle {
                Layout.preferredWidth: root.sidebarWidth
                Layout.fillHeight: true
                color: Kirigami.Theme.backgroundColor

                Kirigami.ScrollablePage {
                    anchors.fill: parent
                    padding: Kirigami.Units.smallSpacing

                    ColumnLayout {
                        width: parent.width
                        spacing: Kirigami.Units.smallSpacing

                        Repeater {
                            model: root.filteredServices
                            
                            Controls.Button {
                                text: i18n(modelData.title)
                                display: Controls.AbstractButton.IconOnly
                                Layout.preferredWidth: root.buttonSize
                                Layout.preferredHeight: root.buttonSize
                                Layout.alignment: Qt.AlignHCenter
                                
                                contentItem: Item {
                                    Image {
                                        anchors.centerIn: parent
                                        width: root.iconSize
                                        height: root.iconSize
                                        source: modelData.image
                                        fillMode: Image.PreserveAspectFit
                                        smooth: true
                                        opacity: root.isServiceDisabled(modelData.id) ? 0.3 : 1.0
                                    }
                                }
                                
                                onClicked: {
                                    root.switchToService(modelData.id)
                                    console.log(modelData.title + " clicked - loading " + modelData.url)
                                }
                            }
                        }

                        // Spacer to push content to top
                        Item {
                            Layout.fillHeight: true
                        }
                    }
                }

                // Right border only
                Rectangle {
                    anchors.right: parent.right
                    anchors.top: parent.top
                    anchors.bottom: parent.bottom
                    width: 1
                    color: root.borderColor
                }
            }

            // Main content area
            Rectangle {
                Layout.fillWidth: true
                Layout.fillHeight: true
                color: Kirigami.Theme.backgroundColor

                // Main content area - Multiple WebViews in StackLayout
                StackLayout {
                    id: webViewStack
                    anchors.fill: parent
                    currentIndex: 0  // Start with first service
                    
                    // Create a WebEngineView for each service
                    Repeater {
                        model: root.services
                        
                        WebEngineView {
                            // Load the service URL immediately when created
                            url: modelData.url
                            
                            // Use default profile with notification presenter support
                            // Note: All services will share the same profile, but each has unique storage via different URLs
                            
                            // Enable settings required for screen sharing and media capture
                            settings.screenCaptureEnabled: true
                            settings.webRTCPublicInterfacesOnly: false
                            settings.javascriptCanAccessClipboard: true
                            settings.allowWindowActivationFromJavaScript: true
                            
                            // Handle permission requests
                            onPermissionRequested: function(permission) {
                                // Auto-grant required permissions for the app to work properly
                                var requiredPermissions = [
                                    WebEnginePermission.PermissionType.Geolocation,
                                    WebEnginePermission.PermissionType.MediaAudioCapture,
                                    WebEnginePermission.PermissionType.MediaVideoCapture,
                                    WebEnginePermission.PermissionType.MediaAudioVideoCapture,
                                    WebEnginePermission.PermissionType.Notifications,
                                    WebEnginePermission.PermissionType.DesktopVideoCapture,
                                    WebEnginePermission.PermissionType.DesktopAudioVideoCapture,
                                    WebEnginePermission.PermissionType.MouseLock,
                                    WebEnginePermission.PermissionType.ClipboardReadWrite
                                ]
                                
                                if (requiredPermissions.indexOf(permission.permissionType) >= 0) {
                                    // Automatically grant required permissions
                                    permission.grant()
                                    console.log("✅ Permission granted:", permission.permissionType, "for", modelData.title)
                                } else {
                                    // For other permissions, deny by default but log them
                                    permission.deny()
                                    console.log("❌ Permission denied:", permission.permissionType, "for", modelData.title)
                                }
                            }
                            
                            // Handle link hovering for better UX
                            onLinkHovered: function(hoveredUrl) {
                                if (hoveredUrl.toString() !== "") {
                                    // Could show status in the future
                                }
                            }
                            
                            // Log when page loads for debugging
                            onLoadingChanged: function(loadRequest) {
                                if (loadRequest.status === WebEngineView.LoadSucceededStatus) {
                                    console.log("Service loaded: " + modelData.title + " - " + modelData.url)
                                }
                            }
                        }
                    }
                }
            }
        }
    }

    // Initialize with the first workspace on startup
    Component.onCompleted: {
        switchToWorkspace(workspaces[0]); // Start with "Personal"
    }

    // Function to disable/enable a service
    function setServiceEnabled(serviceId, enabled) {
        var serviceIndex = findServiceIndexById(serviceId);
        if (serviceIndex >= 0) {
            var webView = webViewStack.children[serviceIndex];
            if (enabled) {
                // Re-enable service
                delete disabledServices[serviceId];
                var service = findServiceById(serviceId);
                if (service) {
                    webView.url = service.url;
                }
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
    
    // Function to check if a service is disabled
    function isServiceDisabled(serviceId) {
        return disabledServices.hasOwnProperty(serviceId);
    }
}
