import QtQuick
import QtQuick.Layouts
import QtQuick.Window
import QtQuick.Controls as Controls
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

    signal rightClicked

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

    // Handle right click
    MouseArea {
        anchors.fill: parent
        acceptedButtons: Qt.RightButton
        onClicked: root.rightClicked()
    }

    contentItem: Item {
        id: buttonItem
        width: iconSize
        height: iconSize
        anchors.horizontalCenter: parent.horizontalCenter
        anchors.verticalCenter: parent.verticalCenter

        Image {
            id: faviconItem
            anchors.centerIn: parent
            width: iconSize
            height: iconSize
            source: shouldShowFavicon ? root.faviconUrl : ""
            fillMode: Image.PreserveAspectFit
            smooth: true
            mipmap: true
            cache: true
            sourceSize: Qt.size(Math.ceil(iconSize * Screen.devicePixelRatio), Math.ceil(iconSize * Screen.devicePixelRatio))
            opacity: root.disabledVisual ? 0.3 : 1.0
            visible: shouldShowFavicon
        }

        Image {
            id: imageItem
            anchors.centerIn: parent
            width: iconSize
            height: iconSize
            source: shouldShowImage ? root.image : ""
            fillMode: Image.PreserveAspectFit
            smooth: true
            mipmap: true
            cache: true
            sourceSize: Qt.size(Math.ceil(iconSize * Screen.devicePixelRatio), Math.ceil(iconSize * Screen.devicePixelRatio))
            opacity: root.disabledVisual ? 0.3 : 1.0
            visible: shouldShowImage
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
