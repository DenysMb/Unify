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
    property int buttonSize: 64
    property int iconSize: 48
    property bool disabledVisual: false
    property bool active: false
    property int notificationCount: 0

    readonly property bool isUrl: {
        if (!root.image)
            return false;
        return root.image.startsWith("http://") || root.image.startsWith("https://") || root.image.startsWith("file://") || root.image.startsWith("qrc:/");
    }

    readonly property bool hasImage: root.image && root.image.trim() !== ""
    readonly property bool shouldShowImage: hasImage && isUrl
    readonly property bool shouldShowIcon: hasImage && !isUrl
    readonly property bool shouldShowFallback: !hasImage

    text: i18n(title)
    display: Controls.AbstractButton.IconOnly
    checkable: true
    checked: active
    autoExclusive: true
    Layout.preferredWidth: buttonSize
    Layout.preferredHeight: buttonSize
    Layout.alignment: Qt.AlignHCenter

    contentItem: Item {
        id: buttonItem
        width: iconSize
        height: iconSize
        anchors.horizontalCenter: parent.horizontalCenter
        anchors.verticalCenter: parent.verticalCenter

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
            anchors.right: parent.right
            anchors.top: parent.top
            anchors.rightMargin: -Kirigami.Units.smallSpacing
            anchors.topMargin: -Kirigami.Units.smallSpacing
            width: badgeText.width + Kirigami.Units.smallSpacing * 2
            height: Math.max(Kirigami.Units.gridUnit, badgeText.height + Kirigami.Units.smallSpacing)
            radius: height / 2
            color: Kirigami.Theme.negativeBackgroundColor
            border.color: Kirigami.Theme.backgroundColor
            border.width: 2

            Controls.Label {
                id: badgeText
                anchors.centerIn: parent
                text: root.notificationCount > 99 ? "99+" : root.notificationCount.toString()
                color: Kirigami.Theme.negativeTextColor
                font.pixelSize: Kirigami.Theme.smallFont.pixelSize
                font.bold: true
            }
        }
    }
}
