import QtQuick
import org.kde.kirigami as Kirigami

Kirigami.GlobalDrawer {
    id: drawer

    // Public API
    property var workspaces: []
    property string currentWorkspace: ""

    signal switchToWorkspace(string name)
    signal addWorkspaceRequested
    signal editWorkspaceRequested(int index)

    // OAuth dialog
    property var oauthDialog: null

    function openOAuthDialog() {
        if (!oauthDialog) {
            var component = Qt.createComponent("../dialogs/OAuth2Dialog.qml");
            if (component.status === Component.Ready) {
                oauthDialog = component.createObject(drawer);
            } else {
                console.log("❌ Failed to load OAuth2Dialog:", component.errorString());
                return;
            }
        }
        oauthDialog.open();
    }

    function buildActions() {
        var acts = [];
        for (var i = 0; i < workspaces.length; i++) {
            var ws = workspaces[i];
            acts.push(Qt.createQmlObject(`
                import org.kde.kirigami as Kirigami
                Kirigami.Action {
                    text: i18n("${ws}")
                    icon.name: "folder"
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

        // Another separator
        acts.push(Qt.createQmlObject(`import org.kde.kirigami as Kirigami
Kirigami.Action { separator: true }
`, drawer));

        // OAuth Test
        acts.push(Qt.createQmlObject(`
            import org.kde.kirigami as Kirigami
            Kirigami.Action {
              text: i18n("OAuth Test")
              icon.name: "internet-web-browser"
              onTriggered: drawer.openOAuthDialog()
            }
        `, drawer));

        return acts;
    }

    // Keep as binding so changes in workspaces rebuild the list
    actions: buildActions()
}
