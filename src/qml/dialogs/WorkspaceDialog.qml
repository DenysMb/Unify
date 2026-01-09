import QtQuick
import QtQuick.Layouts
import QtQuick.Controls as Controls
import org.kde.kirigami as Kirigami
import org.kde.iconthemes as IconThemes

Kirigami.Dialog {
    id: root

    // Public API
    property bool isEditMode: false
    property string initialName: ""
    property string initialIcon: "folder"
    property bool initialIsolatedStorage: false

    // Selected icon state
    property string selectedIconName: initialIcon || "folder"
    // Isolated storage state
    property bool isolatedStorage: initialIsolatedStorage

    // New signal carrying name, icon, and isolated storage
    signal acceptedWorkspace(string name, string icon, bool isolatedStorage)
    signal deleteRequested

    title: isEditMode ? i18n("Edit Workspace") : i18n("Add Workspace")
    standardButtons: Kirigami.Dialog.Cancel
    padding: Kirigami.Units.largeSpacing
    preferredWidth: Kirigami.Units.gridUnit * 20

    customFooterActions: [
        Kirigami.Action {
            text: root.isEditMode ? i18n("Save") : i18n("Add")
            icon.name: root.isEditMode ? "document-save" : "list-add"
            enabled: workspaceNameField.text.trim().length > 0
            onTriggered: root.accept()
        }
    ]

    function populateFields(name) {
        workspaceNameField.text = name || "";
        root.selectedIconName = root.initialIcon || "folder";
        root.isolatedStorage = root.initialIsolatedStorage;
    }
    function clearFields() {
        workspaceNameField.text = "";
        root.selectedIconName = "folder";
        root.isolatedStorage = false;
    }

    onAccepted: {
        var workspaceName = (workspaceNameField.text || "").trim();
        var iconName = (root.selectedIconName || "").trim() || "folder";
        if (workspaceName === "") {
            console.log("Workspace name cannot be empty");
            return;
        }
        acceptedWorkspace(workspaceName, iconName, root.isolatedStorage);
        clearFields();
    }
    onRejected: {
        clearFields();
    }

    Kirigami.FormLayout {
        Controls.TextField {
            id: workspaceNameField
            Kirigami.FormData.label: i18n("Workspace Name:")
            placeholderText: i18n("Enter workspace name")
            text: root.initialName
            Layout.fillWidth: true
        }

        Controls.ToolButton {
            id: iconPreview
            Kirigami.FormData.label: i18n("Icon:")
            icon.name: root.selectedIconName || "folder"
            text: i18n("Choose…")
            display: Controls.AbstractButton.TextBesideIcon
            Layout.fillWidth: true
            onClicked: iconDialog.open()
            Controls.ToolTip.visible: hovered
            Controls.ToolTip.text: i18n("Choose icon")
        }

        // Isolated storage checkbox - only show when creating new workspace
        Controls.CheckBox {
            id: isolatedStorageCheckBox
            Kirigami.FormData.label: i18n("Isolated Storage:")
            text: i18n("Use isolated storage for this workspace")
            checked: root.isolatedStorage
            visible: !root.isEditMode
            onCheckedChanged: root.isolatedStorage = checked
            Controls.ToolTip.visible: hovered
            Controls.ToolTip.delay: 500
            Controls.ToolTip.text: i18n("Services in this workspace will have separate cookies, storage, and authentication from other workspaces. This cannot be changed after creation.")
        }

        // Info label for edit mode
        Controls.Label {
            visible: root.isEditMode && root.initialIsolatedStorage
            Kirigami.FormData.label: i18n("Isolated Storage:")
            text: i18n("Enabled (cannot be changed)")
            font.italic: true
            opacity: 0.7
        }

        // Separator before destructive actions (only in edit mode)
        Rectangle {
            visible: root.isEditMode
            Kirigami.FormData.label: ""
            Layout.fillWidth: true
            height: 1
            color: Qt.rgba(Kirigami.Theme.textColor.r, Kirigami.Theme.textColor.g, Kirigami.Theme.textColor.b, 0.2)
        }

        // Delete button appears only in edit mode
        Controls.Button {
            visible: root.isEditMode
            Kirigami.FormData.label: ""
            text: i18n("Delete Workspace")
            icon.name: "edit-delete"
            Layout.fillWidth: true
            onClicked: confirmDeleteDialog.open()
        }
    }

    // Icon picker dialog from org.kde.iconthemes
    IconThemes.IconDialog {
        id: iconDialog
        onAccepted: {
            if (typeof iconName !== "undefined" && iconName) {
                root.selectedIconName = iconName;
            }
        }
    }

    // Confirmation dialog for deletion
    Kirigami.Dialog {
        id: confirmDeleteDialog
        title: i18n("Delete Workspace")
        standardButtons: Kirigami.Dialog.Ok | Kirigami.Dialog.Cancel
        padding: Kirigami.Units.largeSpacing
        onAccepted: root.deleteRequested()
        Controls.Label {
            text: i18n("Are you sure you want to delete this workspace? All services within it will also be removed. This action cannot be undone.")
            wrapMode: Text.WordWrap
            horizontalAlignment: Text.AlignLeft
        }
    }
}
