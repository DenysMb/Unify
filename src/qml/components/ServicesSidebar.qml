import QtQuick
import QtQuick.Layouts
import QtQuick.Controls as Controls
import org.kde.kirigami as Kirigami

import "./" as Components

Rectangle {
    id: root

    property var services: []
    property var disabledServices: ({})
    property var detachedServices: ({})
    property var notificationCounts: ({})
    property string currentServiceId: ""
    property int sidebarWidth: 80
    property int buttonSize: 64
    property int iconSize: 48
    property string currentWorkspace: ""

    property int favoriteVersion: 0

    signal serviceSelected(string id)
    signal editServiceRequested(string id)
    signal moveServiceUp(string id)
    signal moveServiceDown(string id)
    signal disableService(string id)
    signal detachService(string id)
    signal toggleFavoriteRequested(string id)
    signal shortcutClicked(string desktopFileName)
    signal editShortcutRequested(string id)

    Connections {
        target: typeof configManager !== "undefined" ? configManager : null
        function onServicesChanged() {
            root.favoriteVersion++;
        }
    }

    // Hide sidebar when there are no services
    Layout.preferredWidth: services.length > 0 ? sidebarWidth : 0
    Layout.fillHeight: true
    color: Kirigami.Theme.alternateBackgroundColor
    visible: services.length > 0

    Controls.ScrollView {
        anchors.fill: parent
        anchors.topMargin: Kirigami.Units.smallSpacing

        Controls.ScrollBar.vertical.policy: Controls.ScrollBar.AlwaysOff
        Controls.ScrollBar.horizontal.policy: Controls.ScrollBar.AlwaysOff
        contentWidth: root.sidebarWidth

        ColumnLayout {
            anchors.horizontalCenter: parent.horizontalCenter
            width: root.sidebarWidth
            spacing: Kirigami.Units.smallSpacing

            Repeater {
                model: root.services

                Item {
                    Layout.preferredWidth: root.buttonSize
                    Layout.preferredHeight: {
                        if (modelData.itemType === "separator") {
                            return 1 + Kirigami.Units.smallSpacing;
                        }
                        return root.buttonSize;
                    }
                    Layout.alignment: Qt.AlignHCenter

                    // Separator component
                    Rectangle {
                        visible: modelData.itemType === "separator"
                        anchors.verticalCenter: parent.verticalCenter
                        width: root.sidebarWidth - Kirigami.Units.smallSpacing * 2
                        height: 1
                        color: {
                            const textColor = Kirigami.Theme.textColor;
                            Qt.rgba(textColor.r, textColor.g, textColor.b, 0.2);
                        }
                    }

                    // Service button component
                    Components.ServiceIconButton {
                        visible: modelData.itemType === "service" || !modelData.itemType
                        width: root.buttonSize
                        height: root.buttonSize

                        title: modelData.title || ""
                        image: modelData.image || ""
                        serviceUrl: modelData.url || ""
                        useFavicon: modelData.useFavicon || false
                        buttonSize: root.buttonSize
                        iconSize: root.iconSize
                        active: modelData.id === root.currentServiceId
                        disabledVisual: (root.disabledServices && root.disabledServices.hasOwnProperty(modelData.id)) || (root.detachedServices && root.detachedServices.hasOwnProperty(modelData.id))
                        notificationCount: (root.notificationCounts && root.notificationCounts.hasOwnProperty(modelData.id)) ? root.notificationCounts[modelData.id] : 0
                        isDisabled: root.disabledServices && root.disabledServices.hasOwnProperty(modelData.id)
                        isDetached: root.detachedServices && root.detachedServices.hasOwnProperty(modelData.id)
                        isFavorite: {
                            var v = root.favoriteVersion;
                            if (typeof configManager === "undefined" || configManager === null)
                                return false;
                            return configManager.isServiceFavorite(modelData.id);
                        }
                        isInFavoritesTab: root.currentWorkspace === "__favorites__"
                        currentWorkspace: root.currentWorkspace

                        onClicked: root.serviceSelected(modelData.id)
                        onEditServiceRequested: root.editServiceRequested(modelData.id)
                        onMoveUpRequested: root.moveServiceUp(modelData.id)
                        onMoveDownRequested: root.moveServiceDown(modelData.id)
                        onDisableServiceRequested: root.disableService(modelData.id)
                        onDetachServiceRequested: root.detachService(modelData.id)
                        onToggleFavoriteRequested: {
                            root.toggleFavoriteRequested(modelData.id);
                        }
                    }

                    // Shortcut button component
                    Components.ShortcutIconButton {
                        visible: modelData.itemType === "shortcut"
                        width: root.buttonSize
                        height: root.buttonSize

                        title: modelData.title || ""
                        iconName: modelData.customIcon || modelData.icon || "application-x-executable"
                        desktopFileName: modelData.desktopFileName || ""
                        buttonSize: root.buttonSize
                        iconSize: root.iconSize

                        onClicked: root.shortcutClicked(modelData.desktopFileName)
                        onEditRequested: root.editShortcutRequested(modelData.id)
                    }
                }
            }

            Item {
                Layout.fillHeight: true
            }
        }
    }

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
