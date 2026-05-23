import QtQuick
import QtQuick.Controls as QQC2
import QtQuick.Layouts

import org.kde.kirigami as Kirigami

Kirigami.ScrollablePage {
    id: root

    title: i18nc("@title", "Widevine (DRM)")

    Kirigami.ColumnView.fillWidth: true

    Kirigami.FormLayout {
        anchors.fill: parent

        Kirigami.Separator {
            Kirigami.FormData.label: i18nc("@title:group", "Status:")
            Kirigami.FormData.isSection: true
        }

        RowLayout {
            Kirigami.FormData.label: i18nc("@label", "Installation:")
            spacing: Kirigami.Units.smallSpacing

            Kirigami.Icon {
                source: widevineManager && widevineManager.isInstalled ? "dialog-ok-apply" : "dialog-warning"
                color: widevineManager && widevineManager.isInstalled ? Kirigami.Theme.positiveTextColor : Kirigami.Theme.neutralTextColor
                Layout.preferredWidth: Kirigami.Units.iconSizes.small
                Layout.preferredHeight: Kirigami.Units.iconSizes.small
            }

            QQC2.Label {
                text: {
                    if (!widevineManager) return i18n("Unknown");
                    if (widevineManager.isInstalling) return i18n("Installing...");
                    if (widevineManager.isInstalled) return i18n("Installed (version %1)", widevineManager.installedVersion);
                    return i18n("Not installed");
                }
                color: widevineManager && widevineManager.isInstalled ? Kirigami.Theme.positiveTextColor : Kirigami.Theme.neutralTextColor
            }
        }

        Kirigami.Separator {
            Kirigami.FormData.label: i18nc("@title:group", "Actions:")
            Kirigami.FormData.isSection: true
        }

        RowLayout {
            Kirigami.FormData.label: i18nc("@label", "Widevine CDM:")
            spacing: Kirigami.Units.smallSpacing

            QQC2.Button {
                text: widevineManager && widevineManager.isInstalled ? i18n("Reinstall") : i18n("Install")
                icon.name: "download"
                enabled: widevineManager && !widevineManager.isInstalling
                onClicked: {
                    if (widevineManager) {
                        widevineManager.install();
                    }
                }

                QQC2.BusyIndicator {
                    anchors.centerIn: parent
                    running: widevineManager && widevineManager.isInstalling
                    visible: running
                }
            }

            QQC2.Button {
                text: i18n("Uninstall")
                icon.name: "edit-delete"
                visible: widevineManager && widevineManager.isInstalled
                enabled: widevineManager && !widevineManager.isInstalling
                onClicked: {
                    if (widevineManager) {
                        widevineManager.uninstall();
                    }
                }
            }
        }

        QQC2.Label {
            Kirigami.FormData.label: ""
            Layout.fillWidth: true
            wrapMode: QQC2.Label.WordWrap
            font: Kirigami.Theme.smallFont
            color: Kirigami.Theme.disabledTextColor
            text: i18n("After installing or uninstalling, restart Unify for changes to take effect.")
        }

        Kirigami.Separator {
            Kirigami.FormData.label: i18nc("@title:group", "Info:")
            Kirigami.FormData.isSection: true
        }

        QQC2.Label {
            Kirigami.FormData.label: ""
            Layout.fillWidth: true
            wrapMode: QQC2.Label.WordWrap
            text: i18n("Some streaming services (Spotify, Netflix, Prime Video, etc.) require Widevine CDM to play DRM-protected content. Widevine is a Google proprietary library that cannot be bundled with the app.")
        }
    }

    Connections {
        target: widevineManager
        function onInstallationStarted() {
            applicationWindow().showPassiveNotification(i18n("Widevine installation started. This may take a moment..."), "long");
        }
        function onInstallationFinished(success, message) {
            applicationWindow().showPassiveNotification(message, "long");
        }
        function onUninstallationFinished(success, message) {
            applicationWindow().showPassiveNotification(message, "long");
        }
    }
}
