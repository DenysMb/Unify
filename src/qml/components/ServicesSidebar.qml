import QtQuick
import QtQuick.Layouts
import QtQuick.Controls as Controls
import org.kde.kirigami as Kirigami

import "./" as Components

Rectangle {
    id: root

    // Public API
    property var services: [] // array of service objects with { id, title, image, url }
    property var disabledServices: ({})
    property var detachedServices: ({})
    property string currentServiceId: ""
    property int sidebarWidth: 80
    property int buttonSize: 64
    property int iconSize: 48

    signal serviceSelected(string id)

    Layout.preferredWidth: sidebarWidth
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

                Components.ServiceIconButton {
                    title: modelData.title
                    image: modelData.image
                    buttonSize: root.buttonSize
                    iconSize: root.iconSize
                    active: modelData.id === root.currentServiceId
                    disabledVisual: (root.disabledServices && root.disabledServices.hasOwnProperty(modelData.id)) || (root.detachedServices && root.detachedServices.hasOwnProperty(modelData.id))
                    onClicked: root.serviceSelected(modelData.id)
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
        color: {
            const textColor = Kirigami.Theme.textColor;
            Qt.rgba(textColor.r, textColor.g, textColor.b, 0.2);
        }
    }
}
