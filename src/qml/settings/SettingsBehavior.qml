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

        Kirigami.Separator {
            Kirigami.FormData.label: i18nc("@title:group", "Experimental:")
            Kirigami.FormData.isSection: true
        }

        QQC2.CheckBox {
            Kirigami.FormData.label: i18nc("@label:checkbox", "Experimental Features:")
            text: i18nc("@option:check", "Enable experimental features")
            checked: configManager ? configManager.experimentalFeaturesEnabled : false
            onCheckedChanged: {
                if (configManager) {
                    configManager.experimentalFeaturesEnabled = checked;
                }
            }
        }

        QQC2.ComboBox {
            Kirigami.FormData.label: i18nc("@label:combobox", "Voice Chat Service:")
            visible: configManager ? configManager.experimentalFeaturesEnabled : false

            model: [
                { text: i18nc("@item:inlistbox", "ChatGPT"), value: "chatgpt" },
                { text: i18nc("@item:inlistbox", "Perplexity"), value: "perplexity" }
            ]
            textRole: "text"
            valueRole: "value"

            currentIndex: {
                var current = configManager ? configManager.voiceChatService : "perplexity";
                for (var i = 0; i < model.length; i++) {
                    if (model[i].value === current) {
                        return i;
                    }
                }
                return 1;
            }

            onActivated: function (index) {
                if (configManager) {
                    configManager.voiceChatService = model[index].value;
                }
            }

            QQC2.ToolTip.visible: hovered
            QQC2.ToolTip.delay: Kirigami.Units.toolTipDelay
            QQC2.ToolTip.text: i18nc("@info:tooltip", "Select which AI service the tray quick action opens")
        }

        Kirigami.InlineMessage {
            // Kirigami.FormData.isSpanning: true
            Layout.fillWidth: true
            visible: configManager ? configManager.experimentalFeaturesEnabled : false
            type: Kirigami.MessageType.Information
            icon.name: "audio-input-microphone"
            text: i18nc("@info", "Adds a quick action to the system tray menu that opens the selected AI service and starts a voice conversation.")
        }
    }
}
