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
                text: i18n("Workspace 1")
                icon.name: "folder"
                onTriggered: {
                    console.log("Workspace 1 clicked")
                }
            },
            Kirigami.Action {
                text: i18n("Workspace 2")
                icon.name: "folder"
                onTriggered: {
                    console.log("Workspace 2 clicked")
                }
            },
            Kirigami.Action {
                text: i18n("Workspace 3")
                icon.name: "folder"
                onTriggered: {
                    console.log("Workspace 3 clicked")
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
                    console.log("Add Service button clicked")
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
