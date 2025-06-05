// Includes relevant modules used by the QML
import QtQuick
import QtQuick.Layouts
import QtQuick.Controls as Controls
import QtWebEngine
import org.kde.kirigami as Kirigami

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
    property var workspaces: ["Personal", "Work", "Cloud"]
    
    // Services configuration array
    property var services: [
        { 
            id: 'kde-001',
            title: 'KDE', 
            url: 'https://kde.org',
            image: 'https://kde.org/stuff/clipart/logo/kde-logo-blue-transparent-source.svg',
            workspace: 'Personal'
        },
        { 
            id: 'gnome-001',
            title: 'GNOME', 
            url: 'https://gnome.org',
            image: 'https://upload.wikimedia.org/wikipedia/commons/6/68/Gnomelogo.svg',
            workspace: 'Personal'
        },
        { 
            id: 'opensuse-001',
            title: 'openSUSE', 
            url: 'https://opensuse.org',
            image: 'https://upload.wikimedia.org/wikipedia/commons/d/d1/OpenSUSE_Button.svg',
            workspace: 'Personal'
        },
        { 
            id: 'fedora-001',
            title: 'Fedora', 
            url: 'https://fedoraproject.org',
            image: 'https://upload.wikimedia.org/wikipedia/commons/3/3f/Fedora_logo.svg',
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
                text: i18n(root.workspaces[2]) // "Cloud"
                icon.name: "folder"
                onTriggered: {
                    root.switchToWorkspace(root.workspaces[2])
                    console.log(root.workspaces[2] + " workspace clicked")
                }
            },
            Kirigami.Action {
                separator: true
            },
            Kirigami.Action {
                text: i18n("Add Workspace")
                icon.name: "folder-new"
                onTriggered: {
                    console.log("Add Workspace button clicked")
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
                text: i18n("Add Service")
                icon.name: "list-add"
                onTriggered: {
                    // Reset dialog to add mode
                    addServiceDialog.isEditMode = false
                    addServiceDialog.open()
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
                            
                            // Basic profile for web browsing with unique storage per service
                            profile: WebEngineProfile {
                                storageName: "UnifyProfile_" + modelData.id
                                persistentCookiesPolicy: WebEngineProfile.AllowPersistentCookies
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
}
