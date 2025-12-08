import QtQuick
import QtQuick.Layouts
import QtQuick.Window
import QtQuick.Controls as Controls
import QtQuick.Effects
import org.kde.kirigami as Kirigami

Controls.Button {
    id: root

    // Public API
    property string title: ""
    property string image: ""
    property string serviceUrl: ""
    property bool useFavicon: false
    property int buttonSize: 64
    property int iconSize: 48
    property bool disabledVisual: false
    property bool active: false
    property int notificationCount: 0
    property bool isDisabled: false
    property bool isDetached: false
    property bool isFavorite: false
    property bool isInFavoritesTab: false
    property string serviceId: ""
    property string currentWorkspace: ""

    signal editServiceRequested
    signal toggleFavoriteRequested
    signal moveUpRequested
    signal moveDownRequested
    signal disableServiceRequested
    signal detachServiceRequested

    readonly property string faviconUrl: {
        if (!root.useFavicon || !root.serviceUrl)
            return "";
        // Extract domain from service URL and use Google's favicon service
        try {
            var url = new URL(root.serviceUrl);
            return "https://www.google.com/s2/favicons?domain=" + url.hostname + "&sz=128";
        } catch (e) {
            return "";
        }
    }

    readonly property bool isUrl: {
        if (!root.image)
            return false;
        return root.image.startsWith("http://") || root.image.startsWith("https://") || root.image.startsWith("file://") || root.image.startsWith("qrc:/");
    }

    readonly property bool hasImage: root.image && root.image.trim() !== ""
    readonly property bool shouldShowFavicon: root.useFavicon && root.faviconUrl !== ""
    readonly property bool shouldShowImage: !shouldShowFavicon && hasImage && isUrl
    readonly property bool shouldShowIcon: !shouldShowFavicon && hasImage && !isUrl
    readonly property bool shouldShowFallback: !shouldShowFavicon && !hasImage

    text: i18n(title)
    display: Controls.AbstractButton.IconOnly
    checkable: true
    checked: active
    autoExclusive: true
    Layout.preferredWidth: buttonSize
    Layout.preferredHeight: buttonSize
    Layout.alignment: Qt.AlignHCenter

    // Handle right click - show context menu
    MouseArea {
        anchors.fill: parent
        acceptedButtons: Qt.RightButton
        onClicked: contextMenu.popup()
    }

    // Context menu
    Controls.Menu {
        id: contextMenu

        Controls.MenuItem {
            text: root.isFavorite ? i18n("Remove from Favorites") : i18n("Add to Favorites")
            icon.name: root.isFavorite ? "starred-symbolic" : "non-starred-symbolic"
            onTriggered: {
                console.log("ServiceIconButton: Favorite menu item clicked for", root.title);
                root.toggleFavoriteRequested();
            }
        }

        Controls.MenuSeparator {}

        Controls.MenuItem {
            text: i18n("Edit Service")
            icon.name: "document-edit"
            onTriggered: root.editServiceRequested()
        }

        Controls.MenuSeparator {
            visible: {
                if (typeof configManager === "undefined" || configManager === null)
                    return true;
                return !configManager.isSpecialWorkspace(root.currentWorkspace);
            }
        }

        Controls.MenuItem {
            text: i18n("Move Service Up")
            icon.name: "go-up"
            visible: {
                if (typeof configManager === "undefined" || configManager === null)
                    return true;
                return !configManager.isSpecialWorkspace(root.currentWorkspace);
            }
            onTriggered: root.moveUpRequested()
        }

        Controls.MenuItem {
            text: i18n("Move Service Down")
            icon.name: "go-down"
            visible: {
                if (typeof configManager === "undefined" || configManager === null)
                    return true;
                return !configManager.isSpecialWorkspace(root.currentWorkspace);
            }
            onTriggered: root.moveDownRequested()
        }

        Controls.MenuSeparator {}

        Controls.MenuItem {
            text: root.isDetached ? i18n("Reattach Service") : i18n("Detach Service")
            icon.name: root.isDetached ? "view-restore" : "view-split-left-right"
            enabled: !root.isDisabled
            onTriggered: root.detachServiceRequested()
        }

        Controls.MenuItem {
            text: root.isDisabled ? i18n("Enable Service") : i18n("Disable Service")
            icon.name: root.isDisabled ? "media-playback-start" : "media-playback-pause"
            enabled: !root.isDetached
            onTriggered: root.disableServiceRequested()
        }
    }

    contentItem: Item {
        id: buttonItem
        width: iconSize
        height: iconSize
        anchors.horizontalCenter: parent.horizontalCenter
        anchors.verticalCenter: parent.verticalCenter

        Item {
            id: faviconContainer
            anchors.centerIn: parent
            width: iconSize
            height: iconSize
            visible: shouldShowFavicon

            Image {
                id: faviconItem
                anchors.fill: parent
                source: shouldShowFavicon ? root.faviconUrl : ""
                fillMode: Image.PreserveAspectFit
                smooth: true
                mipmap: true
                cache: true
                sourceSize: Qt.size(Math.ceil(iconSize * Screen.devicePixelRatio), Math.ceil(iconSize * Screen.devicePixelRatio))
                visible: false
            }

            MultiEffect {
                anchors.fill: faviconItem
                source: faviconItem
                maskEnabled: true
                maskSource: roundedMask
                maskSpreadAtMin: 1.0
                maskSpreadAtMax: 1.0
                maskThresholdMin: 0.5
                maskThresholdMax: 1.0
                opacity: root.disabledVisual ? 0.3 : 1.0
            }
        }

        Item {
            id: imageContainer
            anchors.centerIn: parent
            width: iconSize
            height: iconSize
            visible: shouldShowImage

            Image {
                id: imageItem
                anchors.fill: parent
                source: shouldShowImage ? root.image : ""
                fillMode: Image.PreserveAspectFit
                smooth: true
                mipmap: true
                cache: true
                sourceSize: Qt.size(Math.ceil(iconSize * Screen.devicePixelRatio), Math.ceil(iconSize * Screen.devicePixelRatio))
                visible: false
            }

            MultiEffect {
                anchors.fill: imageItem
                source: imageItem
                maskEnabled: true
                maskSource: roundedMask
                maskSpreadAtMin: 1.0
                maskSpreadAtMax: 1.0
                maskThresholdMin: 0.5
                maskThresholdMax: 1.0
                opacity: root.disabledVisual ? 0.3 : 1.0
            }
        }

        Rectangle {
            id: roundedMask
            anchors.centerIn: parent
            width: iconSize
            height: iconSize
            radius: Kirigami.Units.mediumSpacing
            visible: false
            layer.enabled: true
            layer.smooth: true
            layer.samples: 4
            antialiasing: true
        }

        Kirigami.Icon {
            id: systemIconItem
            anchors.centerIn: parent
            width: iconSize
            height: iconSize
            source: shouldShowIcon ? root.image : ""
            opacity: root.disabledVisual ? 0.3 : 1.0
            visible: shouldShowIcon
        }

        Kirigami.Icon {
            id: fallbackIconItem
            anchors.centerIn: parent
            width: iconSize
            height: iconSize
            source: "internet-web-browser-symbolic"
            opacity: root.disabledVisual ? 0.3 : 1.0
            visible: shouldShowFallback
        }

        Kirigami.Icon {
            id: favoriteIndicator
            visible: root.isFavorite && !root.isInFavoritesTab
            anchors.bottom: parent.bottom
            anchors.left: parent.left
            anchors.margins: -Kirigami.Units.smallSpacing
            width: Kirigami.Units.iconSizes.small
            height: Kirigami.Units.iconSizes.small
            source: "starred-symbolic"
            color: Kirigami.Theme.neutralTextColor
        }

        // Notification badge
        Rectangle {
            id: badge
            visible: root.notificationCount > 0
            anchors.top: parent.top
            anchors.right: parent.right
            anchors.margins: -Kirigami.Units.smallSpacing / 2
            height: Kirigami.Units.gridUnit
            width: Math.max(height, badgeText.implicitWidth + Kirigami.Units.smallSpacing)
            radius: height / 2
            color: Kirigami.Theme.highlightColor
            // border.color: Kirigami.Theme.backgroundColor
            // border.width: visible ? 1 : 0

            Text {
                id: badgeText
                anchors.centerIn: parent
                text: root.notificationCount > 99 ? "99+" : root.notificationCount.toString()
                color: Kirigami.Theme.highlightedTextColor
                font.pixelSize: Kirigami.Units.smallSpacing * 2
                horizontalAlignment: Text.AlignHCenter
                verticalAlignment: Text.AlignVCenter
            }
        }
    }
}
