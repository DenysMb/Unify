import QtQuick
import QtQuick.Controls as Controls
import org.kde.kirigami as Kirigami

Kirigami.Dialog {
    id: root

    // Public API
    property bool isEditMode: false
    property var workspaces: []
    property var serviceData: ({ title: "", url: "", image: "", workspace: "" })

    signal acceptedData(var data)
    signal deleteRequested()

    title: isEditMode ? i18n("Edit Service") : i18n("Add Service")
    standardButtons: Kirigami.Dialog.Ok | Kirigami.Dialog.Cancel
    padding: Kirigami.Units.largeSpacing
    preferredWidth: Kirigami.Units.gridUnit * 20

    function populateFields(service) {
        serviceNameField.text = service.title || ""
        iconUrlField.text = service.image || ""
        serviceUrlField.text = service.url || ""
        workspaceComboBox.currentIndex = Math.max(0, workspaces.indexOf(service.workspace || workspaces[0]))
    }

    function clearFields() {
        serviceNameField.text = ""
        iconUrlField.text = ""
        serviceUrlField.text = ""
        workspaceComboBox.currentIndex = 0
    }

    onAccepted: {
        var data = {
            title: serviceNameField.text,
            url: serviceUrlField.text,
            image: iconUrlField.text,
            workspace: workspaces[workspaceComboBox.currentIndex]
        }
        acceptedData(data)
        clearFields()
    }

    Kirigami.FormLayout {
        Controls.TextField {
            id: serviceNameField
            Kirigami.FormData.label: i18n("Service Name:")
            placeholderText: i18n("Enter service name")
        }

        Controls.TextField {
            id: iconUrlField
            Kirigami.FormData.label: i18n("Icon URL:")
            placeholderText: i18n("Enter icon URL")
        }

        Controls.TextField {
            id: serviceUrlField
            Kirigami.FormData.label: i18n("Service URL:")
            placeholderText: i18n("Enter service URL")
        }

        Controls.ComboBox {
            id: workspaceComboBox
            Kirigami.FormData.label: i18n("Workspace:")
            model: root.workspaces
        }

        // Delete button appears only in edit mode
        Controls.Button {
            visible: root.isEditMode
            Kirigami.FormData.label: ""
            text: i18n("Delete Service")
            icon.name: "edit-delete"
            onClicked: root.deleteRequested()
        }
    }
}
