import QtQuick
import QtQuick.Controls as Controls
import org.kde.kirigami as Kirigami
import org.kde.iconthemes as IconThemes

Kirigami.Dialog {
    id: root

    // Public API
    property bool isEditMode: false
    property string initialName: ""
    property string initialIcon: "folder"

    // Selected icon state
    property string selectedIconName: initialIcon || "folder"

    // New signal carrying name and icon
    signal acceptedWorkspace(string name, string icon)
    signal deleteRequested()

    title: isEditMode ? i18n("Edit Workspace") : i18n("Add Workspace")
    standardButtons: Kirigami.Dialog.Ok | Kirigami.Dialog.Cancel
    padding: Kirigami.Units.largeSpacing
    preferredWidth: Kirigami.Units.gridUnit * 20

    function populateFields(name) {
        workspaceNameField.text = name || ""
        root.selectedIconName = root.initialIcon || "folder"
    }
    function clearFields() {
        workspaceNameField.text = ""
        root.selectedIconName = "folder"
    }

    onAccepted: {
        var workspaceName = (workspaceNameField.text || "").trim()
        var iconName = (root.selectedIconName || "").trim() || "folder"
        if (workspaceName === "") {
            console.log("Workspace name cannot be empty")
            return
        }
        acceptedWorkspace(workspaceName, iconName)
        clearFields()
    }

    Kirigami.FormLayout {
        Controls.TextField {
            id: workspaceNameField
            Kirigami.FormData.label: i18n("Workspace Name:")
            placeholderText: i18n("Enter workspace name")
            text: root.initialName
        }

        Controls.ToolButton {
            id: iconPreview
            Kirigami.FormData.label: i18n("Icon:")
            icon.name: root.selectedIconName || "folder"
            text: i18n("Choose…")
            display: Controls.AbstractButton.TextBesideIcon
            onClicked: iconDialog.open()
            Controls.ToolTip.visible: hovered
            Controls.ToolTip.text: i18n("Choose icon")
        }

        // Delete button appears only in edit mode
        Controls.Button {
            visible: root.isEditMode
            Kirigami.FormData.label: ""
            text: i18n("Delete Workspace")
            icon.name: "edit-delete"
            onClicked: root.deleteRequested()
        }
    }

    // Icon picker dialog from org.kde.iconthemes
    IconThemes.IconDialog {
        id: iconDialog
        onAccepted: {
            if (typeof iconName !== "undefined" && iconName) {
                root.selectedIconName = iconName
            }
        }
    }
}
