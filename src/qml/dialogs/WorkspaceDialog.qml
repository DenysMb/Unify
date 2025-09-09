import QtQuick
import QtQuick.Controls as Controls
import org.kde.kirigami as Kirigami

Kirigami.Dialog {
    id: root

    // Public API
    property bool isEditMode: false
    property string initialName: ""

    signal acceptedName(string name)

    title: isEditMode ? i18n("Edit Workspace") : i18n("Add Workspace")
    standardButtons: Kirigami.Dialog.Ok | Kirigami.Dialog.Cancel
    padding: Kirigami.Units.largeSpacing
    preferredWidth: Kirigami.Units.gridUnit * 20

    function populateFields(name) { workspaceNameField.text = name || "" }
    function clearFields() { workspaceNameField.text = "" }

    onAccepted: {
        var workspaceName = (workspaceNameField.text || "").trim()
        if (workspaceName === "") {
            console.log("Workspace name cannot be empty")
            return
        }
        acceptedName(workspaceName)
        clearFields()
    }

    Kirigami.FormLayout {
        Controls.TextField {
            id: workspaceNameField
            Kirigami.FormData.label: i18n("Workspace Name:")
            placeholderText: i18n("Enter workspace name")
            text: root.initialName
        }
    }
}

