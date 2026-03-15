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
        anchors.leftMargin: Kirigami.Units.smallSpacing
        anchors.rightMargin: Kirigami.Units.smallSpacing
        spacing: 1

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

                    Kirigami.Icon {
                        source: "internet-services"
                        Layout.preferredWidth: Kirigami.Units.iconSizes.small
                        Layout.preferredHeight: Kirigami.Units.iconSizes.small
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
                        Layout.preferredWidth: Kirigami.Units.iconSizes.small + Kirigami.Units.smallSpacing
                        Layout.preferredHeight: Kirigami.Units.iconSizes.small + Kirigami.Units.smallSpacing
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