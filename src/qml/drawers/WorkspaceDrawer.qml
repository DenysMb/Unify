import QtQuick
import QtQuick.Controls as QQC2
import QtQuick.Layouts
import org.kde.kirigami as Kirigami

Kirigami.GlobalDrawer {
    id: drawer

    property var activeWorkspaces: []
    property var disabledWorkspaces: []
    property string currentWorkspace: ""

    signal switchToWorkspace(string name)
    signal addWorkspaceRequested
    signal editWorkspaceRequested(string name)
    signal toggleWorkspaceDisabledRequested(string name)
    signal moveWorkspaceUpRequested(string name)
    signal moveWorkspaceDownRequested(string name)
    signal tipsRequested
    signal settingsRequested

    Component {
        id: activeMenuComponent
        QQC2.Menu {
            property string wsName: ""
            property bool canMoveUp: false
            property bool canMoveDown: false

            QQC2.MenuItem {
                text: i18n("Edit Workspace")
                icon.name: "document-edit"
                onTriggered: drawer.editWorkspaceRequested(wsName)
            }

            QQC2.MenuItem {
                enabled: canMoveUp
                text: i18n("Move Up")
                icon.name: "go-up"
                onTriggered: drawer.moveWorkspaceUpRequested(wsName)
            }

            QQC2.MenuItem {
                enabled: canMoveDown
                text: i18n("Move Down")
                icon.name: "go-down"
                onTriggered: drawer.moveWorkspaceDownRequested(wsName)
            }

            QQC2.MenuSeparator {}

            QQC2.MenuItem {
                text: i18n("Disable Workspace")
                icon.name: "media-playback-pause"
                onTriggered: drawer.toggleWorkspaceDisabledRequested(wsName)
            }
        }
    }

    Component {
        id: disabledMenuComponent
        QQC2.Menu {
            property string wsName: ""

            QQC2.MenuItem {
                text: i18n("Edit Workspace")
                icon.name: "document-edit"
                onTriggered: drawer.editWorkspaceRequested(wsName)
            }

            QQC2.MenuItem {
                text: i18n("Enable Workspace")
                icon.name: "media-playback-start"
                onTriggered: drawer.toggleWorkspaceDisabledRequested(wsName)
            }
        }
    }

    topContent: [
        QQC2.ItemDelegate {
            anchors {
                left: parent?.left
                right: parent?.right
            }
            icon.name: "starred-symbolic"
            text: i18n("Favorites (Ctrl+B)")
            checkable: true
            checked: drawer.currentWorkspace === "__favorites__"
            onClicked: drawer.switchToWorkspace("__favorites__")
        },

        QQC2.ItemDelegate {
            anchors {
                left: parent?.left
                right: parent?.right
            }
            icon.name: "applications-all-symbolic"
            text: i18n("All Services")
            checkable: true
            checked: drawer.currentWorkspace === "__all_services__"
            onClicked: drawer.switchToWorkspace("__all_services__")
        },

        Kirigami.Separator {
            width: parent?.width ?? 0
            visible: activeWorkspaces.length > 0 || disabledWorkspaces.length > 0
        },

        QQC2.Label {
            width: parent?.width ?? 0
            visible: activeWorkspaces.length > 0
            leftPadding: Kirigami.Units.largeSpacing
            rightPadding: Kirigami.Units.largeSpacing
            topPadding: Kirigami.Units.smallSpacing
            bottomPadding: Kirigami.Units.smallSpacing
            text: i18n("Enabled Workspaces")
            font.pointSize: Kirigami.Theme.defaultFont.pointSize * 0.85
            opacity: 0.6
            elide: Text.ElideRight
        },

        Repeater {
            model: activeWorkspaces

            delegate: RowLayout {
                width: parent?.width ?? 0
                spacing: 0

                QQC2.ItemDelegate {
                    Layout.fillWidth: true
                    property string wsName: modelData

                    readonly property string iconSource: {
                        if (typeof configManager !== "undefined" && configManager && configManager.workspaceIcons) {
                            return configManager.workspaceIcons[wsName] || "folder";
                        }
                        return "folder";
                    }
                    icon.name: iconSource
                    text: (index < 9) ? (wsName + " (Ctrl+Shift+" + (index + 1) + ")") : wsName
                    checkable: true
                    checked: drawer.currentWorkspace === wsName
                    onClicked: drawer.switchToWorkspace(wsName)
                }

                QQC2.ToolButton {
                    Layout.preferredWidth: implicitHeight
                    Layout.rightMargin: Kirigami.Units.largeSpacing
                    Layout.topMargin: Kirigami.Units.smallSpacing
                    icon.name: "overflow-menu"
                    onClicked: {
                        var menu = activeMenuComponent.createObject(this, {
                            wsName: modelData,
                            canMoveUp: (index > 0),
                            canMoveDown: (index < activeWorkspaces.length - 1)
                        });
                        menu.closed.connect(function () { menu.destroy(); });
                        menu.popup(this, this.width, 0);
                    }
                }
            }
        },

        Kirigami.Separator {
            width: parent?.width ?? 0
            visible: disabledWorkspaces.length > 0
        },

        QQC2.Label {
            width: parent?.width ?? 0
            visible: disabledWorkspaces.length > 0
            leftPadding: Kirigami.Units.largeSpacing
            rightPadding: Kirigami.Units.largeSpacing
            topPadding: Kirigami.Units.smallSpacing
            bottomPadding: Kirigami.Units.smallSpacing
            text: i18n("Disabled Workspaces")
            font.pointSize: Kirigami.Theme.defaultFont.pointSize * 0.85
            opacity: 0.6
            elide: Text.ElideRight
        },

        Repeater {
            model: disabledWorkspaces

            delegate: RowLayout {
                width: parent?.width ?? 0
                spacing: 0

                QQC2.ItemDelegate {
                    Layout.fillWidth: true
                    property string wsName: modelData

                    readonly property string iconSource: {
                        if (typeof configManager !== "undefined" && configManager && configManager.workspaceIcons) {
                            return configManager.workspaceIcons[wsName] || "folder";
                        }
                        return "folder";
                    }
                    icon.name: iconSource
                    text: wsName
                    checkable: true
                    checked: drawer.currentWorkspace === wsName
                    opacity: 0.5
                    onClicked: drawer.switchToWorkspace(wsName)
                }

                QQC2.ToolButton {
                    Layout.preferredWidth: implicitHeight
                    Layout.rightMargin: Kirigami.Units.largeSpacing
                    Layout.topMargin: Kirigami.Units.smallSpacing
                    icon.name: "overflow-menu"
                    onClicked: {
                        var menu = disabledMenuComponent.createObject(this, {
                            wsName: modelData
                        });
                        menu.closed.connect(function () { menu.destroy(); });
                        menu.popup(this, this.width, 0);
                    }
                }
            }
        }
    ]

    actions: [
        Kirigami.Action { separator: true },
        Kirigami.Action {
            text: i18n("Add Workspace")
            icon.name: "folder-new"
            onTriggered: drawer.addWorkspaceRequested()
        },
        Kirigami.Action { separator: true },
        Kirigami.Action {
            text: i18n("Settings")
            icon.name: "settings-configure"
            onTriggered: drawer.settingsRequested()
        },
        Kirigami.Action {
            text: i18n("Tips")
            icon.name: "help-contextual"
            onTriggered: drawer.tipsRequested()
        }
    ]
}
