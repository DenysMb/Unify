import QtQuick
import QtQuick.Layouts
import QtQuick.Controls as Controls
import org.kde.kirigami as Kirigami

Controls.ToolButton {
    id: root

    // Legacy properties for single service (for backward compatibility)
    property string serviceName: ""
    property string serviceId: ""
    property string mediaTitle: ""
    property string mediaArtist: ""
    property bool isPlaying: false

    // New: list of playing services with metadata
    // Format: [{ serviceId: string, serviceName: string, mediaTitle: string, mediaArtist: string, mediaAlbum: string }]
    property var playingServices: []

    signal switchToService(string serviceId)

    // Computed: check if we have multiple services playing
    readonly property bool hasMultiplePlaying: playingServices.length > 1

    // Visible if we have services playing (either legacy or new mode)
    visible: (isPlaying && serviceName !== "") || playingServices.length > 0

    padding: Kirigami.Units.smallSpacing * 2

    // Maximum width for the text label
    readonly property int maxTextWidth: hasMultiplePlaying ? 150 : 200

    // Get display text based on mode
    readonly property string displayText: {
        if (hasMultiplePlaying) {
            // Show count in new mode
            return i18nc("@label:button Number of services playing audio", "%1 playing", playingServices.length);
        } else {
            // Use legacy single service properties or first from playingServices
            var name = serviceName !== "" ? serviceName : (playingServices.length > 0 ? playingServices[0].serviceName : "");
            var title = mediaTitle !== "" ? mediaTitle : (playingServices.length > 0 ? playingServices[0].mediaTitle : "");
            var artist = mediaArtist !== "" ? mediaArtist : (playingServices.length > 0 ? playingServices[0].mediaArtist : "");

            if (artist && title) {
                return name + ": " + artist + " - " + title;
            } else if (title) {
                return name + ": " + title;
            }
            return name;
        }
    }

    // Get tooltip text based on mode
    readonly property string tooltipText: {
        if (hasMultiplePlaying) {
            var tip = i18n("Playing:");
            for (var i = 0; i < playingServices.length; i++) {
                var svc = playingServices[i];
                var line = "\n• " + svc.serviceName;
                if (svc.mediaArtist && svc.mediaTitle) {
                    line += " - " + svc.mediaArtist + " - " + svc.mediaTitle;
                } else if (svc.mediaTitle) {
                    line += " - " + svc.mediaTitle;
                }
                tip += line;
            }
            return tip;
        } else {
            var name = serviceName !== "" ? serviceName : (playingServices.length > 0 ? playingServices[0].serviceName : "");
            var title = mediaTitle !== "" ? mediaTitle : (playingServices.length > 0 ? playingServices[0].mediaTitle : "");
            var artist = mediaArtist !== "" ? mediaArtist : (playingServices.length > 0 ? playingServices[0].mediaArtist : "");
            var tip = name;
            if (artist && title) {
                tip += "\n" + artist + " - " + title;
            } else if (title) {
                tip += "\n" + title;
            }
            return tip;
        }
    }

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
            Layout.preferredWidth: Math.min(scrollLabel.implicitWidth, maxTextWidth)
            Layout.preferredHeight: scrollLabel.height
            clip: true

            Controls.Label {
                id: scrollLabel

                text: root.displayText

                // Position changes for scrolling effect
                x: {
                    if (scrollLabel.width <= maxTextWidth || hasMultiplePlaying) {
                        return 0;
                    }
                    return scrollAnim.running ? scrollAnim.xPos : 0;
                }

                // Determine if text needs scrolling
                readonly property bool needsScroll: width > maxTextWidth && !hasMultiplePlaying

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
                interval: 500
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

                // Pause at the beginning (before scrolling starts)
                PauseAnimation {
                    duration: 1000
                }

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

                // Return to beginning instantly
                NumberAnimation {
                    target: scrollLabel
                    property: "x"
                    to: 0
                    duration: 0
                }
            }
        }

        // Dropdown arrow for multiple services
        Kirigami.Icon {
            source: hasMultiplePlaying ? "arrow-down" : ""
            Layout.preferredWidth: hasMultiplePlaying ? Kirigami.Units.iconSizes.small : 0
            Layout.preferredHeight: hasMultiplePlaying ? Kirigami.Units.iconSizes.small : 0
            color: Kirigami.Theme.textColor
            visible: hasMultiplePlaying
        }
    }

    onClicked: {
        if (hasMultiplePlaying) {
            // Open menu for multiple services
            multipleServicesMenu.open();
        } else {
            // Direct switch for single service
            var targetId = serviceId !== "" ? serviceId : (playingServices.length > 0 ? playingServices[0].serviceId : "");
            if (targetId) {
                root.switchToService(targetId);
            }
        }
    }

    Controls.ToolTip.visible: hovered && (hasMultiplePlaying || mediaTitle || mediaArtist || (playingServices.length > 0 && playingServices[0].mediaTitle))
    Controls.ToolTip.text: root.tooltipText
    Controls.ToolTip.delay: 500

    // Menu for multiple playing services
    Controls.Menu {
        id: multipleServicesMenu

        title: i18nc("@title:menu", "Playing Services")

        Instantiator {
            model: playingServices
            delegate: Controls.MenuItem {
                text: {
                    var display = modelData.serviceName;
                    if (modelData.mediaArtist && modelData.mediaTitle) {
                        display += " - " + modelData.mediaArtist + " - " + modelData.mediaTitle;
                    } else if (modelData.mediaTitle) {
                        display += " - " + modelData.mediaTitle;
                    }
                    return display;
                }
                onTriggered: {
                    root.switchToService(modelData.serviceId);
                }
            }
            onObjectAdded: multipleServicesMenu.insertItem(index, object)
            onObjectRemoved: multipleServicesMenu.removeItem(object)
        }
    }
}
