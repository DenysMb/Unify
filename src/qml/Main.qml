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
    
    // Workspaces configuration array
    property var workspaces: ["Personal", "Work", "Cloud"]
    
    // Services configuration array
    property var services: [
        { 
            title: 'KDE', 
            url: 'https://kde.org',
            image: 'https://kde.org/stuff/clipart/logo/kde-logo-blue-transparent-source.svg'
        },
        { 
            title: 'GNOME', 
            url: 'https://gnome.org',
            image: 'https://upload.wikimedia.org/wikipedia/commons/6/68/Gnomelogo.svg'
        },
        { 
            title: 'openSUSE', 
            url: 'https://opensuse.org',
            image: 'https://upload.wikimedia.org/wikipedia/commons/d/d1/OpenSUSE_Button.svg'
        },
        { 
            title: 'Fedora', 
            url: 'https://fedoraproject.org',
            image: 'https://upload.wikimedia.org/wikipedia/commons/3/3f/Fedora_logo.svg'
        }
    ]

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
                    console.log(root.workspaces[0] + " workspace clicked")
                }
            },
            Kirigami.Action {
                text: i18n(root.workspaces[1]) // "Work"
                icon.name: "folder"
                onTriggered: {
                    console.log(root.workspaces[1] + " workspace clicked")
                }
            },
            Kirigami.Action {
                text: i18n(root.workspaces[2]) // "Cloud"
                icon.name: "folder"
                onTriggered: {
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
        title: i18n("Add Service")
        
        standardButtons: Kirigami.Dialog.Ok | Kirigami.Dialog.Cancel
        padding: Kirigami.Units.largeSpacing
        preferredWidth: Kirigami.Units.gridUnit * 20
        
        onAccepted: {
            // Add the new service to the services array
            var newService = {
                title: serviceNameField.text,
                url: serviceUrlField.text,
                image: iconUrlField.text
            }
            
            // Create a new array with the added service
            var updatedServices = root.services.slice()
            updatedServices.push(newService)
            root.services = updatedServices
            
            // Clear the form
            serviceNameField.text = ""
            serviceUrlField.text = ""
            iconUrlField.text = ""
            workspaceComboBox.currentIndex = 0
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
                text: i18n("Add Service")
                icon.name: "list-add"
                onTriggered: {
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
                            model: root.services
                            
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
                                    root.currentServiceName = modelData.title
                                    webView.url = modelData.url
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

                // Main content area - WebView
                WebEngineView {
                    id: webView
                    anchors.fill: parent
                    
                    // Default URL
                    url: "https://kde.org"
                    
                    // Basic profile for web browsing
                    profile: WebEngineProfile {
                        id: webProfile
                        storageName: "UnifyProfile"
                    }
                    
                    // Handle link hovering for better UX
                    onLinkHovered: function(hoveredUrl) {
                        if (hoveredUrl.toString() !== "") {
                            // Could show status in the future
                        }
                    }
                }
            }
        }
    }
}
