import QtQuick
import QtQuick.Controls as QQC2
import QtQuick.Layouts

import org.kde.kirigami as Kirigami

Kirigami.ScrollablePage {
    id: root

    title: i18nc("@title", "Appearance")

    Kirigami.ColumnView.fillWidth: true

    Kirigami.FormLayout {
        anchors.fill: parent

        Kirigami.Separator {
            Kirigami.FormData.label: i18nc("@title:group", "Sidebar:")
            Kirigami.FormData.isSection: true
        }

        QQC2.CheckBox {
            Kirigami.FormData.label: i18nc("@label:checkbox", "Horizontal Sidebar:")
            text: i18nc("@option:check", "Place sidebar on top")
            checked: configManager ? configManager.horizontalSidebar : false
            onCheckedChanged: {
                if (configManager) {
                    configManager.horizontalSidebar = checked;
                }
            }
        }

        QQC2.ComboBox {
            Kirigami.FormData.label: i18nc("@label:combobox", "Sidebar Size:")
            model: [
                { text: i18nc("Sidebar size preset", "Tiny"), value: "tiny" },
                { text: i18nc("Sidebar size preset", "Small"), value: "small" },
                { text: i18nc("Sidebar size preset", "Normal"), value: "normal" },
                { text: i18nc("Sidebar size preset", "Big"), value: "big" }
            ]
            textRole: "text"
            valueRole: "value"
            currentIndex: {
                var preset = configManager ? configManager.sidebarSizePreset : "normal";
                for (var i = 0; i < model.length; i++) {
                    if (model[i].value === preset) return i;
                }
                return 2;
            }
            onActivated: function (index) {
                if (configManager) {
                    configManager.sidebarSizePreset = model[index].value;
                }
            }
        }

        Kirigami.Separator {
            Kirigami.FormData.label: i18nc("@title:group", "Header:")
            Kirigami.FormData.isSection: true
        }

        QQC2.CheckBox {
            Kirigami.FormData.label: i18nc("@label:checkbox", "Hide Header:")
            text: i18nc("@option:check", "Hide application header (Ctrl+H)")
            checked: configManager ? configManager.hideHeader : false
            onCheckedChanged: {
                if (configManager) {
                    configManager.hideHeader = checked;
                }
            }
        }

        QQC2.CheckBox {
            Kirigami.FormData.label: i18nc("@label:checkbox", "Show Zoom Controls:")
            text: i18nc("@option:check", "Zoom buttons in header")
            checked: configManager ? configManager.showZoomInHeader : false
            onCheckedChanged: {
                if (configManager) {
                    configManager.showZoomInHeader = checked;
                    if (!checked) {
                        applicationWindow().showPassiveNotification(
                            i18n("You can still zoom using Ctrl + Mouse Scroll"),
                            3000
                        );
                    }
                }
            }
        }

        Kirigami.Separator {
            Kirigami.FormData.label: i18nc("@title:group", "Workspaces:")
            Kirigami.FormData.isSection: true
        }

        QQC2.CheckBox {
            Kirigami.FormData.label: i18nc("@label:checkbox", "Show Workspaces Bar:")
            text: i18nc("@option:check", "Always visible")
            checked: configManager ? configManager.alwaysShowWorkspacesBar : false
            onCheckedChanged: {
                if (configManager) {
                    configManager.alwaysShowWorkspacesBar = checked;
                }
            }
        }
    }
}
