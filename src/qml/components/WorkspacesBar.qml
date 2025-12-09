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
        anchors.fill: parent
        anchors.leftMargin: Kirigami.Units.smallSpacing
        anchors.rightMargin: Kirigami.Units.smallSpacing
        spacing: Kirigami.Units.smallSpacing

        // Favorites button
        Controls.ToolButton {
            Layout.preferredWidth: 128
            icon.name: "starred-symbolic"
            text: i18n("Favorites")
            display: Controls.AbstractButton.TextBesideIcon
            checked: root.currentWorkspace === "__favorites__"
            checkable: true
            onClicked: root.switchToWorkspace("__favorites__")
        }

        // All Services button
        Controls.ToolButton {
            Layout.preferredWidth: 128
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
                Layout.preferredWidth: implicitWidth
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

        // Spacer
        Item {
            Layout.fillWidth: true
        }
    }
}
