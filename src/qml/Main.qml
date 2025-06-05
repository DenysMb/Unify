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

        Controls.Label {
            // Center label horizontally and vertically within parent object
            anchors.centerIn: parent
            text: i18n("Welcome to Unify!")
        }
    }
}
