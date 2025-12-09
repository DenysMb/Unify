import QtQuick
import QtQuick.Layouts
import QtQuick.Controls as Controls
import org.kde.kirigami as Kirigami

Controls.Button {
    id: root

    property string title: ""
    property string iconName: "application-x-executable"
    property string desktopFileName: ""
    property int buttonSize: 64
    property int iconSize: 48

    signal editRequested

    text: title
    display: Controls.AbstractButton.IconOnly

    Controls.ToolTip.visible: hovered
    Controls.ToolTip.text: title
    Controls.ToolTip.delay: 500

    MouseArea {
        anchors.fill: parent
        acceptedButtons: Qt.RightButton
        onClicked: contextMenu.popup()
    }

    Controls.Menu {
        id: contextMenu

        Controls.MenuItem {
            text: i18n("Edit Shortcut")
            icon.name: "document-edit"
            onTriggered: root.editRequested()
        }
    }

    contentItem: Item {
        width: root.iconSize
        height: root.iconSize
        anchors.centerIn: parent

        Kirigami.Icon {
            anchors.centerIn: parent
            width: root.iconSize
            height: root.iconSize
            source: root.iconName || "application-x-executable"
        }

        Rectangle {
            anchors.bottom: parent.bottom
            anchors.right: parent.right
            anchors.margins: -Kirigami.Units.smallSpacing
            width: Kirigami.Units.iconSizes.small
            height: Kirigami.Units.iconSizes.small
            radius: Kirigami.Units.smallSpacing
            color: Kirigami.Theme.highlightColor
            // border.color: Kirigami.Theme.textColor
            // border.width: 1

            Kirigami.Icon {
                anchors.centerIn: parent
                width: parent.width - 4
                height: parent.height - 4
                source: "external-link-symbolic"
                color: Kirigami.Theme.highlightedTextColor
            }
        }
    }
}
