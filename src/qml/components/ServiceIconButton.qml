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
    property bool useDefaultIcon: !root.image
    property bool active: false

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

        // Render the provided image at high quality (fixed iconSize, centered)
        Image {
            id: imageItem
            anchors.centerIn: parent
            width: iconSize
            height: iconSize
            source: root.image
            fillMode: Image.PreserveAspectFit
            smooth: true
            mipmap: true
            cache: true
            sourceSize: Qt.size(Math.ceil(iconSize * Screen.devicePixelRatio), Math.ceil(iconSize * Screen.devicePixelRatio))
            opacity: root.disabledVisual ? 0.3 : 1.0
            visible: !useDefaultIcon
        }

        // Fallback: themed symbolic icon
        Kirigami.Icon {
            id: iconItem
            anchors.centerIn: parent
            width: iconSize
            height: iconSize
            source: "internet-web-browser-symbolic"
            isMask: true
            opacity: root.disabledVisual ? 0.3 : 1.0
            visible: useDefaultIcon
        }
    }
}
