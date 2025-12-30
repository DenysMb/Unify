import QtQuick
import QtQuick.Controls as QQC2
import QtQuick.Layouts
import org.kde.kirigami as Kirigami

Kirigami.GlobalDrawer {
    id: drawer

    // Public API
    property var workspaces: []
    property string currentWorkspace: ""

    signal switchToWorkspace(string name)
    signal addWorkspaceRequested
    signal editWorkspaceRequested(int index)
    signal tipsRequested

    function buildActions() {
        var acts = [];

        // Special workspaces at the top
        acts.push(Qt.createQmlObject(`
            import org.kde.kirigami as Kirigami
            Kirigami.Action {
                text: i18n("Favorites (Ctrl+B)")
                icon.name: "starred-symbolic"
                checkable: true
                checked: drawer.currentWorkspace === "__favorites__"
                onTriggered: drawer.switchToWorkspace("__favorites__")
            }
        `, drawer));

        acts.push(Qt.createQmlObject(`
            import org.kde.kirigami as Kirigami
            Kirigami.Action {
                text: i18n("All Services")
                icon.name: "applications-all-symbolic"
                checkable: true
                checked: drawer.currentWorkspace === "__all_services__"
                onTriggered: drawer.switchToWorkspace("__all_services__")
            }
        `, drawer));

        // Separator between special and regular workspaces
        acts.push(Qt.createQmlObject(`
            import org.kde.kirigami as Kirigami
            Kirigami.Action { separator: true }
        `, drawer));

        // Regular workspaces
        for (var i = 0; i < workspaces.length; i++) {
            var ws = workspaces[i];
            acts.push(Qt.createQmlObject(`
                import org.kde.kirigami as Kirigami
                Kirigami.Action {
                    text: i18n("${ws}") + " (Ctrl+Shift+${i + 1})"
                    icon.name: (configManager && configManager.workspaceIcons && configManager.workspaceIcons["${ws}"]) ? configManager.workspaceIcons["${ws}"] : "folder"
                    checkable: true
                    checked: drawer.currentWorkspace === "${ws}"
                    onTriggered: drawer.switchToWorkspace("${ws}")
                }
            `, drawer));
        }

        // separator
        acts.push(Qt.createQmlObject(`import org.kde.kirigami as Kirigami
Kirigami.Action { separator: true }
`, drawer));

        // Edit Workspace (disabled for special workspaces)
        acts.push(Qt.createQmlObject(`
            import org.kde.kirigami as Kirigami
            Kirigami.Action {
              text: i18n("Edit Workspace")
              icon.name: "document-edit"
              enabled: drawer.currentWorkspace !== "" && configManager && !configManager.isSpecialWorkspace(drawer.currentWorkspace)
              onTriggered: drawer.editWorkspaceRequested(drawer.workspaces.indexOf(drawer.currentWorkspace))
            }
        `, drawer));

        // Add Workspace
        acts.push(Qt.createQmlObject(`
            import org.kde.kirigami as Kirigami
            Kirigami.Action {
              text: i18n("Add Workspace")
              icon.name: "folder-new"
              onTriggered: drawer.addWorkspaceRequested()
            }
        `, drawer));

        // separator
        acts.push(Qt.createQmlObject(`import org.kde.kirigami as Kirigami
Kirigami.Action { separator: true }
`, drawer));

        // Horizontal Sidebar toggle
        acts.push(Qt.createQmlObject(`
            import org.kde.kirigami as Kirigami
            Kirigami.Action {
              text: i18n("Horizontal Sidebar")
              icon.name: "object-rows"
              checkable: true
              checked: configManager && configManager.horizontalSidebar
              onTriggered: {
                  if (configManager) {
                      configManager.horizontalSidebar = !configManager.horizontalSidebar
                  }
              }
            }
        `, drawer));

        // Show Workspaces Bar toggle
        acts.push(Qt.createQmlObject(`
            import org.kde.kirigami as Kirigami
            Kirigami.Action {
              text: i18n("Show Workspaces Bar")
              icon.name: "view-file-columns"
              checkable: true
              checked: configManager && configManager.alwaysShowWorkspacesBar
              onTriggered: {
                  if (configManager) {
                      configManager.alwaysShowWorkspacesBar = !configManager.alwaysShowWorkspacesBar
                  }
              }
            }
        `, drawer));

        // separator
        acts.push(Qt.createQmlObject(`import org.kde.kirigami as Kirigami
Kirigami.Action { separator: true }
`, drawer));

        // Tips
        acts.push(Qt.createQmlObject(`
            import org.kde.kirigami as Kirigami
            Kirigami.Action {
              text: i18n("Tips")
              icon.name: "help-contextual"
              onTriggered: drawer.tipsRequested()
            }
        `, drawer));

        return acts;
    }

    // Keep as binding so changes in workspaces rebuild the list
    actions: buildActions()

    Kirigami.Dialog {
        id: tipsDialog
        title: i18n("Tips & Settings")
        padding: Kirigami.Units.largeSpacing
        preferredWidth: Kirigami.Units.gridUnit * 30
        standardButtons: Kirigami.Dialog.Ok

        QQC2.ScrollView {
            implicitWidth: Kirigami.Units.gridUnit * 28
            implicitHeight: Kirigami.Units.gridUnit * 24

            ColumnLayout {
                width: parent.width
                spacing: Kirigami.Units.largeSpacing

                // DRM Content Section
                Kirigami.Heading {
                    level: 4
                    text: i18n("DRM Content (Widevine)")
                }

                QQC2.Label {
                    Layout.preferredWidth: parent.width - 20
                    Layout.fillWidth: true
                    wrapMode: QQC2.Label.WordWrap
                    text: i18n("Some streaming services (Spotify, Netflix, Prime Video, etc.) require Widevine CDM to play DRM-protected content.")
                }

                QQC2.Label {
                    Layout.preferredWidth: parent.width - 20
                    Layout.fillWidth: true
                    wrapMode: QQC2.Label.WordWrap
                    text: i18n("Widevine is a Google proprietary library that cannot be bundled with the app.")
                }

                // Status indicator
                RowLayout {
                    Layout.fillWidth: true
                    spacing: Kirigami.Units.smallSpacing

                    Kirigami.Icon {
                        source: widevineManager && widevineManager.isInstalled ? "dialog-ok-apply" : "dialog-warning"
                        color: widevineManager && widevineManager.isInstalled ? Kirigami.Theme.positiveTextColor : Kirigami.Theme.neutralTextColor
                        Layout.preferredWidth: Kirigami.Units.iconSizes.small
                        Layout.preferredHeight: Kirigami.Units.iconSizes.small
                    }

                    QQC2.Label {
                        Layout.fillWidth: true
                        text: {
                            if (!widevineManager) {
                                return i18n("Status: Unknown");
                            }
                            if (widevineManager.isInstalling) {
                                return i18n("Status: Installing...");
                            }
                            if (widevineManager.isInstalled) {
                                return i18n("Status: Installed (version %1)", widevineManager.installedVersion);
                            }
                            return i18n("Status: Not installed");
                        }
                        color: widevineManager && widevineManager.isInstalled ? Kirigami.Theme.positiveTextColor : Kirigami.Theme.neutralTextColor
                    }
                }

                // Install/Uninstall buttons
                RowLayout {
                    Layout.fillWidth: true
                    spacing: Kirigami.Units.smallSpacing

                    QQC2.Button {
                        text: widevineManager && widevineManager.isInstalled ? i18n("Reinstall Widevine") : i18n("Install Widevine")
                        icon.name: "download"
                        enabled: widevineManager && !widevineManager.isInstalling
                        onClicked: {
                            if (widevineManager) {
                                widevineManager.install();
                            }
                        }

                        QQC2.BusyIndicator {
                            anchors.centerIn: parent
                            running: widevineManager && widevineManager.isInstalling
                            visible: running
                        }
                    }

                    QQC2.Button {
                        text: i18n("Uninstall")
                        icon.name: "edit-delete"
                        visible: widevineManager && widevineManager.isInstalled
                        enabled: widevineManager && !widevineManager.isInstalling
                        onClicked: {
                            if (widevineManager) {
                                widevineManager.uninstall();
                            }
                        }
                    }
                }

                QQC2.Label {
                    Layout.fillWidth: true
                    wrapMode: QQC2.Label.WordWrap
                    font.pointSize: Kirigami.Theme.smallFont.pointSize
                    opacity: 0.7
                    text: i18n("Note: After installing or uninstalling Widevine, you need to restart Unify for changes to take effect.")
                }

                Kirigami.Separator {
                    Layout.fillWidth: true
                }

                // Keyboard Shortcuts Section
                Kirigami.Heading {
                    level: 4
                    text: i18n("Keyboard Shortcuts")
                }

                QQC2.Label {
                    Layout.fillWidth: true
                    wrapMode: QQC2.Label.WordWrap
                    textFormat: QQC2.Label.RichText
                    text: i18n("<b>Ctrl + 1, 2, 3...</b> — Switch between services in the current workspace<br>" + "<b>Ctrl + Shift + 1, 2, 3...</b> — Switch between workspaces<br>" + "<b>Ctrl + B</b> — Go to Favorites workspace<br>" + "<b>Ctrl + Tab</b> — Go to the next service<br>" + "<b>Ctrl + Shift + Tab</b> — Go to the next workspace<br>" + "<b>Double-tap Ctrl</b> — Toggle between the last two services<br>" + "<b>Escape</b> — Close overlay/dialog")
                }

                Kirigami.Separator {
                    Layout.fillWidth: true
                }

                Kirigami.Heading {
                    level: 4
                    text: i18n("Link Handling")
                }

                QQC2.Label {
                    Layout.preferredWidth: parent.width - 20
                    Layout.fillWidth: true
                    wrapMode: QQC2.Label.WordWrap
                    textFormat: QQC2.Label.RichText
                    text: i18n("When you click a link in a service, it opens in an <b>overlay</b> where you can choose to:<br>" + "• <b>Open in Service</b> — Navigate the service to that URL<br>" + "• <b>Open in Browser</b> — Open in your default browser<br><br>" + "<b>Tip:</b> Hold <b>Ctrl</b> while clicking a link to open it directly in your browser, bypassing the overlay.")
                }

                Kirigami.Separator {
                    Layout.fillWidth: true
                }

                Kirigami.Heading {
                    level: 4
                    text: i18n("Other Tips")
                }

                QQC2.Label {
                    Layout.fillWidth: true
                    wrapMode: QQC2.Label.WordWrap
                    textFormat: QQC2.Label.RichText
                    text: i18n("• <b>Right-click</b> a service icon to access quick actions (edit, disable, delete)<br>" + "• <b>Disabled services</b> won't load until re-enabled, saving resources<br>" + "• The app keeps running in the <b>system tray</b> when you close the window<br>" + "• <b>Notification badges</b> appear on service icons when there are unread messages")
                }
            }
        }
    }

    // Handle Widevine installation signals
    Connections {
        target: widevineManager
        function onInstallationStarted() {
            // Access showPassiveNotification from the root ApplicationWindow
            if (drawer.Kirigami.ApplicationWindow.window) {
                drawer.Kirigami.ApplicationWindow.window.showPassiveNotification(i18n("Widevine installation started. This may take a moment..."), "long");
            }
        }
        function onInstallationFinished(success, message) {
            if (drawer.Kirigami.ApplicationWindow.window) {
                drawer.Kirigami.ApplicationWindow.window.showPassiveNotification(message, "long");
            }
        }
        function onUninstallationFinished(success, message) {
            if (drawer.Kirigami.ApplicationWindow.window) {
                drawer.Kirigami.ApplicationWindow.window.showPassiveNotification(message, "long");
            }
        }
    }

    onTipsRequested: {
        tipsDialog.open();
    }
}
