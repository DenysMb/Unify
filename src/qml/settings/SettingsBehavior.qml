import QtQuick
import QtQuick.Controls as QQC2
import QtQuick.Layouts

import org.kde.kirigami as Kirigami

Kirigami.ScrollablePage {
    id: root

    title: i18nc("@title", "Behavior")

    Kirigami.ColumnView.fillWidth: true

    Kirigami.FormLayout {
        anchors.fill: parent

        Kirigami.Separator {
            Kirigami.FormData.label: i18nc("@title:group", "Audio:")
            Kirigami.FormData.isSection: true
        }

        QQC2.CheckBox {
            Kirigami.FormData.label: i18nc("@label:checkbox", "Mute All:")
            text: configManager && configManager.globalMute
                ? i18nc("@option:check", "All services are muted")
                : i18nc("@option:check", "Mute all services at once")
            checked: configManager ? configManager.globalMute : false
            onCheckedChanged: {
                if (configManager) {
                    configManager.globalMute = checked;
                }
            }
        }

        Kirigami.Separator {
            Kirigami.FormData.label: i18nc("@title:group", "Downloads:")
            Kirigami.FormData.isSection: true
        }

        QQC2.CheckBox {
            Kirigami.FormData.label: i18nc("@label:checkbox", "Confirm Downloads:")
            text: i18nc("@option:check", "Ask before downloading files")
            checked: configManager ? configManager.confirmDownloads : false
            onCheckedChanged: {
                if (configManager) {
                    configManager.confirmDownloads = checked;
                }
            }
        }

        Kirigami.Separator {
            Kirigami.FormData.label: i18nc("@title:group", "System:")
            Kirigami.FormData.isSection: true
        }

        QQC2.CheckBox {
            Kirigami.FormData.label: i18nc("@label:checkbox", "System Tray:")
            text: i18nc("@option:check", "Keep running in background")
            checked: configManager ? configManager.systemTrayEnabled : false
            onCheckedChanged: {
                if (configManager) {
                    configManager.systemTrayEnabled = checked;
                }
                if (trayIconManager) {
                    if (checked) {
                        trayIconManager.show();
                    } else {
                        trayIconManager.hide();
                    }
                }
            }
        }

        QQC2.CheckBox {
            Kirigami.FormData.label: i18nc("@label:checkbox", "Autostart:")
            text: i18nc("@option:check", "Launch on system start")
            checked: configManager ? configManager.autostartEnabled : false
            onCheckedChanged: {
                if (configManager) {
                    configManager.autostartEnabled = checked;
                }
            }
        }
    }
}
