import QtQuick
import QtQuick.Layouts
import QtQuick.Controls as Controls
import org.kde.kirigami as Kirigami

Controls.ToolButton {
    id: root

    property string serviceName: ""
    property string serviceId: ""
    property string mediaTitle: ""
    property string mediaArtist: ""
    property bool isPlaying: false

    signal switchToService(string serviceId)

    visible: isPlaying && serviceName !== ""

    contentItem: RowLayout {
        spacing: Kirigami.Units.smallSpacing

        Kirigami.Icon {
            source: "player-volume"
            Layout.preferredWidth: Kirigami.Units.iconSizes.small
            Layout.preferredHeight: Kirigami.Units.iconSizes.small
            color: Kirigami.Theme.textColor
        }

        Controls.Label {
            text: {
                var displayText = root.serviceName;
                if (root.mediaArtist && root.mediaTitle) {
                    displayText += ": " + root.mediaArtist + " - " + root.mediaTitle;
                } else if (root.mediaTitle) {
                    displayText += ": " + root.mediaTitle;
                }
                return displayText;
            }
            elide: Text.ElideRight
            Layout.maximumWidth: 300
        }
    }

    onClicked: {
        if (root.serviceId) {
            root.switchToService(root.serviceId);
        }
    }

    Controls.ToolTip.visible: hovered && (mediaTitle || mediaArtist)
    Controls.ToolTip.text: {
        var tip = root.serviceName;
        if (root.mediaArtist && root.mediaTitle) {
            tip += "\n" + root.mediaArtist + " - " + root.mediaTitle;
        } else if (root.mediaTitle) {
            tip += "\n" + root.mediaTitle;
        }
        return tip;
    }
    Controls.ToolTip.delay: 500
}
