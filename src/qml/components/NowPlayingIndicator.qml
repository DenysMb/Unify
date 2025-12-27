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

    padding: Kirigami.Units.smallSpacing * 2

    // Maximum width for the text label
    readonly property int maxTextWidth: 200

    background: Rectangle {
        color: "#0d120f"
        radius: Kirigami.Units.smallSpacing
        opacity: 0.5
    }

    contentItem: RowLayout {
        spacing: Kirigami.Units.smallSpacing

        Kirigami.Icon {
            source: "player-volume"
            Layout.preferredWidth: Kirigami.Units.iconSizes.small
            Layout.preferredHeight: Kirigami.Units.iconSizes.small
            color: Kirigami.Theme.textColor
        }

        // Container for scrolling text
        Item {
            Layout.preferredWidth: maxTextWidth
            Layout.preferredHeight: scrollLabel.height
            clip: true

            Controls.Label {
                id: scrollLabel

                // Full text without elision
                text: {
                    var displayText = root.serviceName;
                    if (root.mediaArtist && root.mediaTitle) {
                        displayText += ": " + root.mediaArtist + " - " + root.mediaTitle;
                    } else if (root.mediaTitle) {
                        displayText += ": " + root.mediaTitle;
                    }
                    return displayText;
                }

                // Position changes for scrolling effect
                x: {
                    if (scrollLabel.width <= maxTextWidth) {
                        return 0;
                    }
                    return scrollAnim.running ? scrollAnim.xPos : 0;
                }

                // Determine if text needs scrolling
                readonly property bool needsScroll: width > maxTextWidth

                // Start scrolling after a delay when content changes
                onTextChanged: {
                    scrollAnim.stop();
                    if (needsScroll) {
                        scrollDelayTimer.restart();
                    }
                }

                onNeedsScrollChanged: {
                    if (needsScroll) {
                        scrollDelayTimer.restart();
                    } else {
                        scrollAnim.stop();
                        x = 0;
                    }
                }
            }

            // Delay before starting scroll (so user can read beginning first)
            Timer {
                id: scrollDelayTimer
                interval: 1500
                onTriggered: {
                    if (scrollLabel.needsScroll) {
                        scrollAnim.start();
                    }
                }
            }

            // Animation that scrolls text
            SequentialAnimation {
                id: scrollAnim

                property real xPos: 0

                loops: Animation.Infinite

                // Scroll from left until last character is visible on the right
                NumberAnimation {
                    target: scrollLabel
                    property: "x"
                    from: 0
                    to: maxTextWidth - scrollLabel.width - 10
                    duration: Math.max(5000, Math.abs(maxTextWidth - scrollLabel.width - 10) * 20)
                    easing.type: Easing.Linear
                }

                // Small pause when fully visible
                PauseAnimation {
                    duration: 1000
                }
            }
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
