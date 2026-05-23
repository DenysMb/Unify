import QtQuick
import QtQuick.Controls as QQC2
import QtQuick.Layouts

import org.kde.kirigami as Kirigami

Kirigami.Page {
    id: root

    title: i18nc("@title", "Widevine (DRM)")

    Kirigami.ColumnView.fillWidth: true

    ColumnLayout {
        anchors.fill: parent
        anchors.margins: Kirigami.Units.largeSpacing
        spacing: Kirigami.Units.largeSpacing

        QQC2.Label {
            Layout.fillWidth: true
            wrapMode: QQC2.Label.WordWrap
            text: i18n("Some streaming services (Spotify, Netflix, Prime Video, etc.) require Widevine CDM to play DRM-protected content. Widevine is a Google proprietary library that cannot be bundled with the app.")
        }

        Kirigami.InlineMessage {
            Layout.fillWidth: true
            visible: true
            type: widevineManager && widevineManager.isInstalled ? Kirigami.MessageType.Positive : Kirigami.MessageType.Information
            icon.name: widevineManager && widevineManager.isInstalled ? "dialog-ok-apply" : "dialog-warning"

            text: {
                if (!widevineManager) return i18n("Status: Unknown");
                if (widevineManager.isInstalling) return i18n("Status: Installing...");
                if (widevineManager.isInstalled) return i18n("Status: Installed (version %1)", widevineManager.installedVersion);
                return i18n("Status: Not installed");
            }
        }

        RowLayout {
            Layout.fillWidth: true
            spacing: Kirigami.Units.smallSpacing

            QQC2.Button {
                Layout.fillWidth: true
                text: widevineManager && widevineManager.isInstalled ? i18n("Reinstall Widevine") : i18n("Install Widevine")
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
                Layout.fillWidth: true
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
            Layout.fillWidth: true
            wrapMode: QQC2.Label.WordWrap
            font: Kirigami.Theme.smallFont
            color: Kirigami.Theme.disabledTextColor
            text: i18n("After installing or uninstalling, restart Unify for changes to take effect.")
        }

        Item {
            Layout.fillHeight: true
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
