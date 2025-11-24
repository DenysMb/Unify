import QtQuick
import QtQuick.Layouts
import QtQuick.Controls as Controls
import org.kde.kirigami as Kirigami
import org.kde.iconthemes as IconThemes

Kirigami.Dialog {
    id: root

    // Public API
    property bool isEditMode: false
    property var workspaces: []
    property string currentWorkspace: ""
    property var serviceData: ({
            title: "",
            url: "",
            image: "",
            workspace: "",
            useFavicon: false
        })

    signal acceptedData(var data)
    signal deleteRequested

    property string selectedIconName: "internet-web-browser-symbolic"
    property bool useFavicon: true

    title: isEditMode ? i18n("Edit Service") : i18n("Add Service")
    standardButtons: Kirigami.Dialog.Ok | Kirigami.Dialog.Cancel
    padding: Kirigami.Units.largeSpacing
    preferredWidth: Kirigami.Units.gridUnit * 20

    function populateFields(service) {
        serviceNameField.text = service.title || "";
        iconUrlField.text = service.image || "";
        serviceUrlField.text = service.url || "";
        workspaceComboBox.currentIndex = Math.max(0, workspaces.indexOf(service.workspace || workspaces[0]));
        root.selectedIconName = service.image || "internet-web-browser-symbolic";
        root.useFavicon = service.useFavicon || false;
    }

    function clearFields() {
        serviceNameField.text = "";
        iconUrlField.text = "";
        serviceUrlField.text = "";
        // Set to current workspace if available, otherwise default to first
        var wsIndex = root.currentWorkspace ? Math.max(0, workspaces.indexOf(root.currentWorkspace)) : 0;
        workspaceComboBox.currentIndex = wsIndex;
        root.selectedIconName = "internet-web-browser-symbolic";
        root.useFavicon = true;
    }

    onAccepted: {
        var data = {
            title: serviceNameField.text,
            url: serviceUrlField.text,
            image: iconUrlField.text.trim() || "internet-web-browser-symbolic",
            workspace: workspaces[workspaceComboBox.currentIndex],
            useFavicon: root.useFavicon
        };
        acceptedData(data);
        clearFields();
    }
    onRejected: {
        clearFields();
    }

    Kirigami.FormLayout {
        Controls.TextField {
            id: serviceNameField
            Kirigami.FormData.label: i18n("Service Name:")
            placeholderText: i18n("Enter service name")
            Layout.fillWidth: true
        }

        Controls.TextField {
            id: serviceUrlField
            Kirigami.FormData.label: i18n("Service URL:")
            placeholderText: i18n("Enter service URL")
            Layout.fillWidth: true
        }

        Controls.CheckBox {
            id: useFaviconCheckbox
            Kirigami.FormData.label: ""
            text: i18n("Use service favicon in sidebar")
            checked: root.useFavicon
            onCheckedChanged: root.useFavicon = checked
            Controls.ToolTip.visible: hovered
            Controls.ToolTip.text: i18n("When enabled, the service's favicon will be displayed in the sidebar instead of the selected icon")
        }

        Controls.TextField {
            id: iconUrlField
            Kirigami.FormData.label: i18n("Icon URL:")
            placeholderText: i18n("Enter icon URL")
            Layout.fillWidth: true
            enabled: !useFaviconCheckbox.checked
        }

        Controls.Button {
            id: iconButton
            Kirigami.FormData.label: ""
            Layout.fillWidth: true
            Layout.topMargin: Kirigami.Units.smallSpacing

            readonly property bool hasCustomIcon: {
                var text = iconUrlField.text.trim();
                return text && !(text.startsWith("http://") || text.startsWith("https://") || text.startsWith("file://") || text.startsWith("qrc:/"));
            }

            text: hasCustomIcon ? "" : i18n("Or select a custom icon")
            icon.name: hasCustomIcon ? (iconUrlField.text.trim() || root.selectedIconName) : ""
            display: hasCustomIcon ? Controls.AbstractButton.IconOnly : Controls.AbstractButton.TextOnly

            onClicked: iconDialog.open()
            enabled: !useFaviconCheckbox.checked

            Controls.ToolTip.visible: hovered
            Controls.ToolTip.text: i18n("Choose icon from system")
        }

        Controls.ComboBox {
            id: workspaceComboBox
            Kirigami.FormData.label: i18n("Workspace:")
            model: root.workspaces
            Layout.fillWidth: true
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
            text: i18n("Delete Service")
            icon.name: "edit-delete"
            Layout.fillWidth: true
            onClicked: confirmDeleteDialog.open()
        }
    }

    IconThemes.IconDialog {
        id: iconDialog
        onAccepted: {
            if (typeof iconName !== "undefined" && iconName) {
                root.selectedIconName = iconName;
                iconUrlField.text = iconName;
            }
        }
    }

    Kirigami.Dialog {
        id: confirmDeleteDialog
        title: i18n("Delete Service")
        standardButtons: Kirigami.Dialog.Ok | Kirigami.Dialog.Cancel
        padding: Kirigami.Units.largeSpacing
        onAccepted: root.deleteRequested()
        Controls.Label {
            text: i18n("Are you sure you want to delete this service? This action cannot be undone.")
            wrapMode: Text.WordWrap
            horizontalAlignment: Text.AlignLeft
        }
    }
}
