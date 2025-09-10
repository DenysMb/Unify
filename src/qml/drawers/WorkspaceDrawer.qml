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

        return acts;
    }

    // Keep as binding so changes in workspaces rebuild the list
    actions: buildActions()
}
