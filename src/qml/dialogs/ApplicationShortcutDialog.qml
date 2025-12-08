import QtQuick
import QtQuick.Layouts
import QtQuick.Controls as Controls
import org.kde.kirigami as Kirigami
import org.kde.iconthemes as IconThemes

Kirigami.Dialog {
    id: root

    property bool isEditMode: false
    property var workspaces: []
    property string currentWorkspace: ""
    property var shortcutData: ({})

    signal acceptedShortcut(var data)
    signal deleteRequested

    property string selectedDesktopFile: ""
    property string selectedIcon: ""
    property string selectedAppName: ""

    readonly property bool isFormValid: selectedDesktopFile !== ""

    title: isEditMode ? i18n("Edit Application Shortcut") : i18n("Create Application Shortcut")
    standardButtons: Kirigami.Dialog.Cancel
    padding: Kirigami.Units.largeSpacing
    preferredWidth: Kirigami.Units.gridUnit * 28
    preferredHeight: Kirigami.Units.gridUnit * 28

    customFooterActions: [
        Kirigami.Action {
            text: root.isEditMode ? i18n("Save") : i18n("Add")
            icon.name: root.isEditMode ? "document-save" : "list-add"
            enabled: root.isFormValid
            onTriggered: root.accept()
        }
    ]

    function filteredWorkspaces() {
        var filtered = []
        for (var i = 0; i < workspaces.length; i++) {
            if (workspaces[i] !== "__favorites__" && workspaces[i] !== "__all_services__") {
                filtered.push(workspaces[i])
            }
        }
        return filtered
    }

    function clearFields() {
        searchField.text = ""
        root.selectedDesktopFile = ""
        root.selectedIcon = ""
        root.selectedAppName = ""
        titleField.text = ""
        customIconField.text = ""
        var filtered = filteredWorkspaces()
        var wsIndex = root.currentWorkspace ? Math.max(0, filtered.indexOf(root.currentWorkspace)) : 0
        workspaceComboBox.currentIndex = wsIndex
    }

    function populateFields(shortcut) {
        root.selectedDesktopFile = shortcut.desktopFileName || ""
        root.selectedIcon = shortcut.customIcon || shortcut.icon || ""
        root.selectedAppName = shortcut.title || ""
        titleField.text = shortcut.title || ""
        customIconField.text = shortcut.customIcon || ""

        var filtered = filteredWorkspaces()
        workspaceComboBox.currentIndex = Math.max(0, filtered.indexOf(shortcut.workspace || filtered[0]))
    }

    onAccepted: {
        var filtered = filteredWorkspaces()
        var data = {
            desktopFileName: root.selectedDesktopFile,
            title: titleField.text.trim() || root.selectedAppName,
            icon: root.selectedIcon,
            customIcon: customIconField.text.trim(),
            workspace: filtered[workspaceComboBox.currentIndex]
        }
        acceptedShortcut(data)
        clearFields()
    }

    onRejected: clearFields()

    ColumnLayout {
        spacing: Kirigami.Units.largeSpacing

        Kirigami.SearchField {
            id: searchField
            Layout.fillWidth: true
            placeholderText: i18n("Search applications...")
            onTextChanged: {
                if (typeof applicationShortcutManager !== "undefined") {
                    applicationsList.model = applicationShortcutManager.searchApplications(text)
                }
            }
        }

        Controls.ScrollView {
            Layout.fillWidth: true
            Layout.fillHeight: true
            Layout.preferredHeight: Kirigami.Units.gridUnit * 12

            ListView {
                id: applicationsList
                model: typeof applicationShortcutManager !== "undefined" ? applicationShortcutManager.installedApplications : []
                clip: true

                delegate: Controls.ItemDelegate {
                    width: ListView.view.width
                    highlighted: modelData.desktopFileName === root.selectedDesktopFile

                    contentItem: RowLayout {
                        spacing: Kirigami.Units.smallSpacing

                        Kirigami.Icon {
                            source: modelData.icon || "application-x-executable"
                            Layout.preferredWidth: Kirigami.Units.iconSizes.medium
                            Layout.preferredHeight: Kirigami.Units.iconSizes.medium
                        }

                        ColumnLayout {
                            spacing: 0
                            Layout.fillWidth: true

                            Controls.Label {
                                text: modelData.name
                                elide: Text.ElideRight
                                Layout.fillWidth: true
                            }

                            Controls.Label {
                                text: modelData.genericName || modelData.comment || ""
                                font.pointSize: Kirigami.Theme.smallFont.pointSize
                                opacity: 0.7
                                elide: Text.ElideRight
                                Layout.fillWidth: true
                                visible: text !== ""
                            }
                        }
                    }

                    onClicked: {
                        root.selectedDesktopFile = modelData.desktopFileName
                        root.selectedIcon = modelData.icon
                        root.selectedAppName = modelData.name
                        if (!root.isEditMode || titleField.text === "") {
                            titleField.text = modelData.name
                        }
                    }
                }
            }
        }

        Kirigami.Separator {
            Layout.fillWidth: true
            visible: root.selectedDesktopFile !== ""
        }

        RowLayout {
            visible: root.selectedDesktopFile !== ""
            spacing: Kirigami.Units.smallSpacing

            Kirigami.Icon {
                source: customIconField.text.trim() || root.selectedIcon || "application-x-executable"
                Layout.preferredWidth: Kirigami.Units.iconSizes.large
                Layout.preferredHeight: Kirigami.Units.iconSizes.large
            }

            Controls.Label {
                text: root.selectedAppName
                font.bold: true
            }
        }

        Kirigami.FormLayout {
            Layout.fillWidth: true
            visible: root.selectedDesktopFile !== ""

            Controls.TextField {
                id: titleField
                Kirigami.FormData.label: i18n("Display Name:")
                placeholderText: i18n("Custom name (optional)")
                Layout.fillWidth: true
            }

            Controls.TextField {
                id: customIconField
                Kirigami.FormData.label: i18n("Custom Icon:")
                placeholderText: i18n("Icon name or leave empty for default")
                Layout.fillWidth: true
            }

            Controls.Button {
                Kirigami.FormData.label: ""
                text: i18n("Choose Icon...")
                icon.name: customIconField.text.trim() || root.selectedIcon || "preferences-desktop-icons"
                onClicked: iconDialog.open()
            }

            Controls.ComboBox {
                id: workspaceComboBox
                Kirigami.FormData.label: i18n("Workspace:")
                model: root.filteredWorkspaces()
                Layout.fillWidth: true
            }

            Rectangle {
                visible: root.isEditMode
                Layout.fillWidth: true
                height: 1
                color: Qt.rgba(Kirigami.Theme.textColor.r, Kirigami.Theme.textColor.g, Kirigami.Theme.textColor.b, 0.2)
            }

            Controls.Button {
                visible: root.isEditMode
                text: i18n("Delete Shortcut")
                icon.name: "edit-delete"
                Layout.fillWidth: true
                onClicked: confirmDeleteDialog.open()
            }
        }
    }

    IconThemes.IconDialog {
        id: iconDialog
        onAccepted: {
            if (typeof iconName !== "undefined" && iconName) {
                customIconField.text = iconName
                root.selectedIcon = iconName
            }
        }
    }

    Kirigami.Dialog {
        id: confirmDeleteDialog
        title: i18n("Delete Shortcut")
        standardButtons: Kirigami.Dialog.Ok | Kirigami.Dialog.Cancel
        padding: Kirigami.Units.largeSpacing
        onAccepted: root.deleteRequested()

        Controls.Label {
            text: i18n("Are you sure you want to delete this shortcut?")
            wrapMode: Text.WordWrap
        }
    }
}
