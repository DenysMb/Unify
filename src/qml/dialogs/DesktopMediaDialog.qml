import QtQuick
import QtQuick.Controls as QQC2
import QtQuick.Layouts
import org.kde.kirigami as Kirigami

Kirigami.Dialog {
    id: root

    property var mediaRequest: null

    title: i18n("Share Your Screen")
    standardButtons: Kirigami.Dialog.Cancel
    preferredWidth: Kirigami.Units.gridUnit * 40
    preferredHeight: Kirigami.Units.gridUnit * 28
    padding: Kirigami.Units.largeSpacing

    onRejected: {
        if (mediaRequest)
            mediaRequest.cancel();
    }

    onClosed: {
        mediaRequest = null;
    }

    function show(request) {
        mediaRequest = request;
        tabBar.currentIndex = 0;
        open();
    }

    ColumnLayout {
        spacing: Kirigami.Units.largeSpacing

        QQC2.TabBar {
            id: tabBar
            Layout.fillWidth: true

            QQC2.TabButton {
                text: i18n("Windows (%1)", windowsGrid.count)
                icon.name: "window"
            }
            QQC2.TabButton {
                text: i18n("Screens (%1)", screensGrid.count)
                icon.name: "monitor"
            }
        }

        StackLayout {
            currentIndex: tabBar.currentIndex
            Layout.fillWidth: true
            Layout.fillHeight: true

            QQC2.ScrollView {
                Layout.fillWidth: true
                Layout.fillHeight: true

                GridView {
                    id: windowsGrid
                    model: root.mediaRequest ? root.mediaRequest.windowsModel : null
                    cellWidth: Kirigami.Units.gridUnit * 12
                    cellHeight: Kirigami.Units.gridUnit * 9

                    delegate: QQC2.ItemDelegate {
                        id: windowDelegate
                        width: windowsGrid.cellWidth - Kirigami.Units.smallSpacing
                        height: windowsGrid.cellHeight - Kirigami.Units.smallSpacing

                        contentItem: ColumnLayout {
                            spacing: Kirigami.Units.smallSpacing

                            Rectangle {
                                Layout.fillWidth: true
                                Layout.fillHeight: true
                                color: Kirigami.Theme.backgroundColor
                                border.color: windowDelegate.hovered ? Kirigami.Theme.highlightColor : Kirigami.Theme.disabledTextColor
                                border.width: windowDelegate.hovered ? 2 : 1
                                radius: Kirigami.Units.smallSpacing

                                Kirigami.Icon {
                                    anchors.centerIn: parent
                                    width: Kirigami.Units.iconSizes.huge
                                    height: Kirigami.Units.iconSizes.huge
                                    source: "window"
                                }
                            }

                            QQC2.Label {
                                Layout.fillWidth: true
                                text: model.display
                                elide: Text.ElideMiddle
                                horizontalAlignment: Text.AlignHCenter
                            }
                        }

                        onClicked: {
                            if (root.mediaRequest && root.mediaRequest.windowsModel) {
                                var modelIndex = root.mediaRequest.windowsModel.index(index, 0);
                                root.mediaRequest.selectWindow(modelIndex);
                                root.close();
                            }
                        }
                    }

                    Kirigami.PlaceholderMessage {
                        anchors.centerIn: parent
                        visible: windowsGrid.count === 0
                        text: i18n("No windows available")
                        icon.name: "window"
                    }
                }
            }

            QQC2.ScrollView {
                Layout.fillWidth: true
                Layout.fillHeight: true

                GridView {
                    id: screensGrid
                    model: root.mediaRequest ? root.mediaRequest.screensModel : null
                    cellWidth: Kirigami.Units.gridUnit * 12
                    cellHeight: Kirigami.Units.gridUnit * 9

                    delegate: QQC2.ItemDelegate {
                        id: screenDelegate
                        width: screensGrid.cellWidth - Kirigami.Units.smallSpacing
                        height: screensGrid.cellHeight - Kirigami.Units.smallSpacing

                        contentItem: ColumnLayout {
                            spacing: Kirigami.Units.smallSpacing

                            Rectangle {
                                Layout.fillWidth: true
                                Layout.fillHeight: true
                                color: Kirigami.Theme.backgroundColor
                                border.color: screenDelegate.hovered ? Kirigami.Theme.highlightColor : Kirigami.Theme.disabledTextColor
                                border.width: screenDelegate.hovered ? 2 : 1
                                radius: Kirigami.Units.smallSpacing

                                Kirigami.Icon {
                                    anchors.centerIn: parent
                                    width: Kirigami.Units.iconSizes.huge
                                    height: Kirigami.Units.iconSizes.huge
                                    source: "monitor"
                                }
                            }

                            QQC2.Label {
                                Layout.fillWidth: true
                                text: model.display
                                elide: Text.ElideMiddle
                                horizontalAlignment: Text.AlignHCenter
                            }
                        }

                        onClicked: {
                            if (root.mediaRequest && root.mediaRequest.screensModel) {
                                var modelIndex = root.mediaRequest.screensModel.index(index, 0);
                                root.mediaRequest.selectScreen(modelIndex);
                                root.close();
                            }
                        }
                    }

                    Kirigami.PlaceholderMessage {
                        anchors.centerIn: parent
                        visible: screensGrid.count === 0
                        text: i18n("No screens available")
                        icon.name: "monitor"
                    }
                }
            }
        }

        QQC2.Label {
            Layout.fillWidth: true
            text: i18n("Select a window or screen to share")
            wrapMode: Text.WordWrap
            horizontalAlignment: Text.AlignHCenter
            color: Kirigami.Theme.disabledTextColor
        }
    }
}
