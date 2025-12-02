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
        for (var i = 0; i < workspaces.length; i++) {
            var ws = workspaces[i];
            acts.push(Qt.createQmlObject(`
                import org.kde.kirigami as Kirigami
                Kirigami.Action {
                    text: i18n("${ws}") + " (Ctrl+Shift+${i + 1})"
                    icon.name: (configManager && configManager.workspaceIcons && configManager.workspaceIcons["${ws}"]) ? configManager.workspaceIcons["${ws}"] : "folder"
                    onTriggered: drawer.switchToWorkspace("${ws}")
                }
            `, drawer));
        }

        // separator
        acts.push(Qt.createQmlObject(`import org.kde.kirigami as Kirigami
Kirigami.Action { separator: true }
`, drawer));

        // Edit Workspace
        acts.push(Qt.createQmlObject(`
            import org.kde.kirigami as Kirigami
            Kirigami.Action {
              text: i18n("Edit Workspace")
              icon.name: "document-edit"
              enabled: drawer.currentWorkspace !== ""
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
        title: i18n("Tips & Shortcuts")
        padding: Kirigami.Units.largeSpacing
        preferredWidth: Kirigami.Units.gridUnit * 28
        standardButtons: Kirigami.Dialog.Ok

        ColumnLayout {
            spacing: Kirigami.Units.largeSpacing

            Kirigami.Heading {
                level: 4
                text: i18n("Keyboard Shortcuts")
            }

            QQC2.Label {
                Layout.fillWidth: true
                wrapMode: QQC2.Label.WordWrap
                textFormat: QQC2.Label.RichText
                text: i18n("<b>Ctrl + 1, 2, 3...</b> — Switch between services in the current workspace<br>" + "<b>Ctrl + Shift + 1, 2, 3...</b> — Switch between workspaces<br>" + "<b>Ctrl + Tab</b> — Go to the next service<br>" + "<b>Ctrl + Shift + Tab</b> — Go to the next workspace<br>" + "<b>Escape</b> — Close overlay/dialog")
            }

            Kirigami.Separator {
                Layout.fillWidth: true
            }

            Kirigami.Heading {
                level: 4
                text: i18n("Link Handling")
            }

            QQC2.Label {
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

    onTipsRequested: {
        tipsDialog.open();
    }
}
