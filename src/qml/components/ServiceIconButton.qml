import QtQuick
import QtQuick.Layouts
import QtQuick.Effects
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

    text: i18n(title)
    display: Controls.AbstractButton.IconOnly
    Layout.preferredWidth: buttonSize
    Layout.preferredHeight: buttonSize
    Layout.alignment: Qt.AlignHCenter

    contentItem: Item {
        id: buttonItem

        MultiEffect {
            source: useDefaultIcon ? iconItem : imageItem
            anchors.fill: useDefaultIcon ? iconItem : imageItem
            maskEnabled: true
            maskSource: mask
        }

        Image {
            id: imageItem
            anchors.centerIn: parent
            width: iconSize
            height: iconSize
            source: root.image
            fillMode: Image.PreserveAspectFit
            smooth: true
            opacity: root.disabledVisual ? 0.3 : 1.0
            visible: false
        }

        Kirigami.Icon {
            id: iconItem
            anchors.centerIn: parent
            width: iconSize
            height: iconSize
            source: "internet-web-browser-symbolic"
            isMask: true
            opacity: root.disabledVisual ? 0.3 : 1.0
            visible: false
        }

        Item {
            id: mask
            anchors.fill: imageItem
            layer.enabled: true
            visible: false
            Rectangle {
                anchors.fill: parent
                radius: 8
            }
        }
    }
}
