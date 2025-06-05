// Includes relevant modules used by the QML
import QtQuick
import QtQuick.Layouts
import QtQuick.Controls as Controls
import org.kde.kirigami as Kirigami

// Provides basic features needed for all kirigami applications
Kirigami.ApplicationWindow {
    // Unique identifier to reference this object
    id: root

    width: 800
    height: 600

    property int iconSize: 64
    property int sidebarWidth: iconSize + Kirigami.Units.smallSpacing * 2

    // Current selected service name for the header
    property string currentServiceName: i18n("Unify - Web app aggregator")

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

                        Controls.Button {
                            text: i18n("Service 1")
                            icon.name: "internet-web-browser-symbolic"
                            display: Controls.AbstractButton.IconOnly
                            Layout.fillWidth: true
                            onClicked: {
                                root.currentServiceName = text
                                console.log("Service 1 clicked")
                            }
                        }

                        Controls.Button {
                            text: i18n("Service 2")
                            icon.name: "internet-web-browser-symbolic"
                            display: Controls.AbstractButton.IconOnly
                            Layout.fillWidth: true
                            onClicked: {
                                root.currentServiceName = text
                                console.log("Service 2 clicked")
                            }
                        }

                        Controls.Button {
                            text: i18n("Service 3")
                            icon.name: "internet-web-browser-symbolic"
                            display: Controls.AbstractButton.IconOnly
                            Layout.fillWidth: true
                            onClicked: {
                                root.currentServiceName = text
                                console.log("Service 3 clicked")
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

                Controls.Label {
                    // Center label horizontally and vertically within parent object
                    anchors.centerIn: parent
                    text: i18n("Select a service from the sidebar")
                }
            }
        }
    }
}
