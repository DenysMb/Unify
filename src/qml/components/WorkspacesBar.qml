import QtQuick
import QtQuick.Layouts
import QtQuick.Controls as Controls
import org.kde.kirigami as Kirigami

Rectangle {
    id: root

    property var workspaces: []
    property string currentWorkspace: ""
    property int barHeight: Kirigami.Units.gridUnit * 2.5
    property bool showBar: true

    signal switchToWorkspace(string name)

    Layout.fillWidth: true
    Layout.preferredHeight: showBar && workspaces.length > 0 ? barHeight : 0
    height: showBar && workspaces.length > 0 ? barHeight : 0
    visible: showBar && workspaces.length > 0
    color: Kirigami.Theme.alternateBackgroundColor

    // Top border
    Rectangle {
        anchors.top: parent.top
        anchors.left: parent.left
        anchors.right: parent.right
        height: 1
        color: {
            const textColor = Kirigami.Theme.textColor;
            Qt.rgba(textColor.r, textColor.g, textColor.b, 0.2);
        }
    }

    RowLayout {
        id: mainLayout
        anchors.fill: parent
        anchors.leftMargin: Kirigami.Units.smallSpacing
        anchors.rightMargin: Kirigami.Units.smallSpacing
        spacing: Kirigami.Units.smallSpacing

        readonly property real buttonWidth: 128
        readonly property real fixedButtonsWidth: buttonWidth * 2
        readonly property real separatorWidth: 1
        readonly property real totalSpacing: spacing * (4 + root.workspaces.length - 1)
        readonly property real availableWidth: parent.width - fixedButtonsWidth - separatorWidth - totalSpacing - anchors.leftMargin - anchors.rightMargin
        readonly property real workspaceButtonWidth: root.workspaces.length > 0 ? availableWidth / root.workspaces.length : 0

        // Favorites button
        Controls.ToolButton {
            Layout.preferredWidth: mainLayout.buttonWidth
            icon.name: "starred-symbolic"
            text: i18n("Favorites")
            display: Controls.AbstractButton.TextBesideIcon
            checked: root.currentWorkspace === "__favorites__"
            checkable: true
            onClicked: root.switchToWorkspace("__favorites__")
        }

        // All Services button
        Controls.ToolButton {
            Layout.preferredWidth: mainLayout.buttonWidth
            icon.name: "applications-all-symbolic"
            text: i18n("All Services")
            display: Controls.AbstractButton.TextBesideIcon
            checked: root.currentWorkspace === "__all_services__"
            checkable: true
            onClicked: root.switchToWorkspace("__all_services__")
        }

        // Separator
        Rectangle {
            Layout.preferredWidth: 1
            Layout.preferredHeight: root.barHeight - Kirigami.Units.largeSpacing
            Layout.alignment: Qt.AlignVCenter
            color: {
                const textColor = Kirigami.Theme.textColor;
                Qt.rgba(textColor.r, textColor.g, textColor.b, 0.2);
            }
        }

        // Regular workspaces
        Repeater {
            model: root.workspaces

            Controls.ToolButton {
                Layout.preferredWidth: mainLayout.workspaceButtonWidth
                Layout.fillWidth: false
                icon.name: {
                    if (typeof configManager !== "undefined" && configManager && configManager.workspaceIcons) {
                        return configManager.workspaceIcons[modelData] || "folder";
                    }
                    return "folder";
                }
                text: modelData
                display: Controls.AbstractButton.TextBesideIcon
                checked: root.currentWorkspace === modelData
                checkable: true
                onClicked: root.switchToWorkspace(modelData)
            }
        }
    }
}
