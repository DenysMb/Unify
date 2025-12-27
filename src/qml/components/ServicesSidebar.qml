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
    property var audibleServices: ({})
    property string currentServiceId: ""
    property int sidebarWidth: 80
    property int buttonSize: 64
    property int iconSize: 48
    property string currentWorkspace: ""
    property bool horizontal: false
    property int minButtonWidth: 64

    property int favoriteVersion: 0

    signal serviceSelected(string id)
    signal editServiceRequested(string id)
    signal moveServiceUp(string id)
    signal moveServiceDown(string id)
    signal refreshService(string id)
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
    Layout.preferredWidth: services.length > 0 ? (horizontal ? -1 : sidebarWidth) : 0
    Layout.preferredHeight: services.length > 0 ? (horizontal ? sidebarWidth : -1) : 0
    Layout.fillWidth: horizontal
    Layout.fillHeight: !horizontal
    color: Kirigami.Theme.alternateBackgroundColor
    visible: services.length > 0

    Controls.ScrollView {
        id: scrollView
        anchors.fill: parent
        anchors.topMargin: horizontal ? 0 : Kirigami.Units.smallSpacing
        anchors.bottomMargin: horizontal ? 0 : Kirigami.Units.smallSpacing
        anchors.leftMargin: horizontal ? Kirigami.Units.smallSpacing : 0
        anchors.rightMargin: horizontal ? Kirigami.Units.smallSpacing : 0

        Controls.ScrollBar.vertical.policy: Controls.ScrollBar.AlwaysOff
        Controls.ScrollBar.horizontal.policy: Controls.ScrollBar.AlwaysOff
        contentWidth: horizontal ? contentLoader.item.implicitWidth : root.sidebarWidth
        contentHeight: horizontal ? root.sidebarWidth : contentLoader.item.implicitHeight

        Loader {
            id: contentLoader
            sourceComponent: horizontal ? horizontalLayout : verticalLayout
        }

        NumberAnimation {
            id: scrollAnimation
            target: scrollView.contentItem
            property: "contentX"
            duration: 100
            easing.type: Easing.OutQuad
        }

        MouseArea {
            enabled: root.horizontal
            anchors.fill: parent
            propagateComposedEvents: true

            onWheel: function (wheel) {
                if (wheel.angleDelta.y !== 0) {
                    const delta = wheel.angleDelta.y;
                    const scrollAmount = delta;
                    const newX = scrollView.contentItem.contentX - scrollAmount;
                    const clampedX = Math.max(0, Math.min(scrollView.contentItem.contentWidth - scrollView.width, newX));

                    scrollAnimation.stop();
                    scrollAnimation.to = clampedX;
                    scrollAnimation.start();

                    wheel.accepted = true;
                } else {
                    wheel.accepted = false;
                }
            }

            onPressed: function (mouse) {
                mouse.accepted = false;
            }

            onReleased: function (mouse) {
                mouse.accepted = false;
            }

            onClicked: function (mouse) {
                mouse.accepted = false;
            }
        }
    }

    // Vertical layout (default - sidebar on left)
    Component {
        id: verticalLayout
        ColumnLayout {
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

                    Components.ServiceIconButton {
                        visible: modelData.itemType === "service" || !modelData.itemType
                        width: parent.width
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
                        isPlayingAudio: root.audibleServices && root.audibleServices.hasOwnProperty(modelData.id)
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
                        onRefreshServiceRequested: root.refreshService(modelData.id)
                        onDisableServiceRequested: root.disableService(modelData.id)
                        onDetachServiceRequested: root.detachService(modelData.id)
                        onToggleFavoriteRequested: {
                            root.toggleFavoriteRequested(modelData.id);
                        }
                    }

                    Components.ShortcutIconButton {
                        visible: modelData.itemType === "shortcut"
                        width: parent.width
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

    // Horizontal layout (sidebar on top)
    Component {
        id: horizontalLayout
        RowLayout {
            height: root.sidebarWidth
            spacing: Kirigami.Units.smallSpacing

            readonly property int serviceCount: {
                let count = 0;
                for (let i = 0; i < root.services.length; i++) {
                    if (root.services[i].itemType !== "separator") {
                        count++;
                    }
                }
                return count;
            }

            readonly property int separatorCount: {
                let count = 0;
                for (let i = 0; i < root.services.length; i++) {
                    if (root.services[i].itemType === "separator") {
                        count++;
                    }
                }
                return count;
            }

            readonly property real separatorItemWidth: 1 + Kirigami.Units.smallSpacing
            readonly property real totalSpacing: spacing * (root.services.length - 1)
            readonly property real totalSeparatorsWidth: separatorCount * separatorItemWidth
            readonly property real availableWidth: scrollView.width - totalSpacing - totalSeparatorsWidth
            readonly property real calculatedButtonWidth: serviceCount > 0 ? availableWidth / serviceCount : root.minButtonWidth
            readonly property int baseButtonWidth: Math.max(root.minButtonWidth, Math.floor(calculatedButtonWidth))
            readonly property int remainingPixels: Math.max(0, Math.floor(availableWidth - (baseButtonWidth * serviceCount)))

            function getButtonWidth(serviceIndex) {
                if (serviceIndex < remainingPixels) {
                    return baseButtonWidth + 1;
                }
                return baseButtonWidth;
            }

            Repeater {
                model: root.services

                Item {
                    readonly property int serviceIndex: {
                        let idx = 0;
                        for (let i = 0; i < index; i++) {
                            if (root.services[i].itemType !== "separator") {
                                idx++;
                            }
                        }
                        return idx;
                    }

                    Layout.preferredWidth: {
                        if (modelData.itemType === "separator") {
                            return 1 + Kirigami.Units.smallSpacing;
                        }
                        return parent.getButtonWidth(serviceIndex);
                    }
                    Layout.preferredHeight: root.buttonSize
                    Layout.alignment: Qt.AlignVCenter

                    Rectangle {
                        visible: modelData.itemType === "separator"
                        anchors.horizontalCenter: parent.horizontalCenter
                        width: 1
                        height: root.sidebarWidth - Kirigami.Units.smallSpacing * 2
                        color: {
                            const textColor = Kirigami.Theme.textColor;
                            Qt.rgba(textColor.r, textColor.g, textColor.b, 0.2);
                        }
                    }

                    Components.ServiceIconButton {
                        visible: modelData.itemType === "service" || !modelData.itemType
                        width: parent.width
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
                        isPlayingAudio: root.audibleServices && root.audibleServices.hasOwnProperty(modelData.id)
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
                        onRefreshServiceRequested: root.refreshService(modelData.id)
                        onDisableServiceRequested: root.disableService(modelData.id)
                        onDetachServiceRequested: root.detachService(modelData.id)
                        onToggleFavoriteRequested: {
                            root.toggleFavoriteRequested(modelData.id);
                        }
                    }

                    Components.ShortcutIconButton {
                        visible: modelData.itemType === "shortcut"
                        width: parent.width
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
        }
    }

    // Border line (right for vertical, bottom for horizontal)
    Rectangle {
        anchors.right: horizontal ? undefined : parent.right
        anchors.bottom: horizontal ? parent.bottom : undefined
        anchors.left: horizontal ? parent.left : undefined
        anchors.top: horizontal ? undefined : parent.top
        width: horizontal ? parent.width : 1
        height: horizontal ? 1 : parent.height
        color: {
            const textColor = Kirigami.Theme.textColor;
            Qt.rgba(textColor.r, textColor.g, textColor.b, 0.2);
        }
    }
}
