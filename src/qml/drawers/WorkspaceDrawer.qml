import QtQuick
import QtQuick.Controls as QQC2
import QtQuick.Layouts
import org.kde.kirigami as Kirigami

Kirigami.GlobalDrawer {
    id: drawer

    property var workspaces: []
    property string currentWorkspace: ""

    signal switchToWorkspace(string name)
    signal addWorkspaceRequested
    signal editWorkspaceRequested(int index)
    signal tipsRequested
    signal settingsRequested

    function buildActions() {
        var acts = [];

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

        acts.push(Qt.createQmlObject(`
            import org.kde.kirigami as Kirigami
            Kirigami.Action { separator: true }
        `, drawer));

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

        acts.push(Qt.createQmlObject(`import org.kde.kirigami as Kirigami
Kirigami.Action { separator: true }
`, drawer));

        acts.push(Qt.createQmlObject(`
            import org.kde.kirigami as Kirigami
            Kirigami.Action {
              text: i18n("Edit Workspace")
              icon.name: "document-edit"
              enabled: drawer.currentWorkspace !== "" && configManager && !configManager.isSpecialWorkspace(drawer.currentWorkspace)
              onTriggered: drawer.editWorkspaceRequested(drawer.workspaces.indexOf(drawer.currentWorkspace))
            }
        `, drawer));

        acts.push(Qt.createQmlObject(`
            import org.kde.kirigami as Kirigami
            Kirigami.Action {
              text: i18n("Add Workspace")
              icon.name: "folder-new"
              onTriggered: drawer.addWorkspaceRequested()
            }
        `, drawer));

        acts.push(Qt.createQmlObject(`import org.kde.kirigami as Kirigami
Kirigami.Action { separator: true }
`, drawer));

        acts.push(Qt.createQmlObject(`
            import org.kde.kirigami as Kirigami
            Kirigami.Action {
              text: i18n("Settings")
              icon.name: "settings-configure"
              onTriggered: drawer.settingsRequested()
            }
        `, drawer));

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

    actions: buildActions()
}
