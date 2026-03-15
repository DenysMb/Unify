import QtQuick
import QtQuick.Controls as Controls
import QtQuick.Layouts
import org.kde.kirigami as Kirigami

Rectangle {
    id: tabBar

    property var tabs: []
    property int activeIndex: 0
    property bool showTabBar: tabs.length > 1

    signal tabSelected(int index)
    signal tabClosed(int index)
    signal openInServiceRequested(int index)
    signal openInBrowserRequested(int index)

    implicitHeight: showTabBar ? Kirigami.Units.gridUnit * 2 : 0
    height: implicitHeight
    color: Kirigami.Theme.alternateBackgroundColor
    visible: showTabBar
    clip: true

    Behavior on implicitHeight {
        NumberAnimation {
            duration: Kirigami.Units.shortDuration
            easing.type: Easing.OutCubic
        }
    }

    RowLayout {
        id: tabRow
        anchors.fill: parent

        Repeater {
            model: tabBar.tabs

            Rectangle {
                id: tabItem

                required property int index
                required property var modelData

                Layout.fillHeight: true
                Layout.fillWidth: true
                Layout.minimumWidth: Kirigami.Units.gridUnit * 6
                implicitWidth: tabRow.width / tabBar.tabs.length
                color: index === tabBar.activeIndex ? Kirigami.Theme.backgroundColor : "transparent"

                RowLayout {
                    id: tabContent
                    anchors.fill: parent
                    anchors.leftMargin: Kirigami.Units.smallSpacing
                    anchors.rightMargin: Kirigami.Units.smallSpacing
                    spacing: Kirigami.Units.smallSpacing

                    Controls.ToolButton {
                        id: tabIcon
                        Layout.preferredWidth: tabItem.index > 0 ? -1 : 0
                        icon.name: "overflow-menu"
                        icon.width: Kirigami.Units.iconSizes.small
                        icon.height: Kirigami.Units.iconSizes.small
                        opacity: tabItem.index > 0 ? (hovered ? 1 : 0.7) : 0.5
                        visible: tabItem.index > 0

                        onClicked: {
                            tabContextMenu.popup()
                        }

                        onPressAndHold: {
                            tabContextMenu.popup()
                        }

                        Controls.Menu {
                            id: tabContextMenu

                            Controls.MenuItem {
                                text: i18n("Open in Main Service Tab")
                                icon.name: "debug-run"
                                onTriggered: {
                                    tabBar.openInServiceRequested(tabItem.index)
                                }
                            }

                            Controls.MenuItem {
                                text: i18n("Open in External Browser")
                                icon.name: "internet-web-browser-symbolic"
                                onTriggered: {
                                    tabBar.openInBrowserRequested(tabItem.index)
                                }
                            }
                        }
                    }

                    Item {
                        Layout.preferredWidth: Kirigami.Units.smallSpacing
                        visible: tabItem.index === 0
                    }

                    Controls.Label {
                        id: tabLabel
                        text: tabItem.modelData.title || i18n("Loading...")
                        elide: Text.ElideRight
                        Layout.fillWidth: true
                        maximumLineCount: 1
                        color: tabItem.index === tabBar.activeIndex ? Kirigami.Theme.textColor : Kirigami.Theme.disabledTextColor

                        MouseArea {
                            anchors.fill: parent
                            cursorShape: Qt.PointingHandCursor
                            onClicked: {
                                if (tabItem.index !== tabBar.activeIndex) {
                                    tabBar.tabSelected(tabItem.index)
                                }
                            }
                        }
                    }

                    Controls.ToolButton {
                        id: closeButton
                        icon.name: "tab-close"
                        icon.width: Kirigami.Units.iconSizes.small
                        icon.height: Kirigami.Units.iconSizes.small
                        visible: tabBar.tabs.length > 1 && tabItem.index > 0
                        opacity: hovered ? 1 : 0.6
                        onClicked: {
                            tabBar.tabClosed(tabItem.index)
                        }
                    }
                }
            }
        }
    }

    Rectangle {
        anchors.bottom: parent.bottom
        anchors.left: parent.left
        anchors.right: parent.right
        height: 1
        color: Kirigami.Theme.textColor
        opacity: 0.2
    }
}