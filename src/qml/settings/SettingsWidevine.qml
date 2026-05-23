import QtQuick
import QtQuick.Controls as QQC2
import QtQuick.Layouts

import org.kde.kirigami as Kirigami

Kirigami.ScrollablePage {
    id: root

    title: i18nc("@title", "Widevine (DRM)")

    Kirigami.ColumnView.fillWidth: true

    ColumnLayout {
        anchors.fill: parent
        anchors.margins: Kirigami.Units.largeSpacing
        spacing: Kirigami.Units.largeSpacing

        Kirigami.Heading {
            level: 3
            text: i18n("DRM Content (Widevine)")
            Layout.fillWidth: true
        }

        QQC2.Label {
            Layout.fillWidth: true
            wrapMode: QQC2.Label.WordWrap
            text: i18n("Some streaming services (Spotify, Netflix, Prime Video, etc.) require Widevine CDM to play DRM-protected content.")
        }

        QQC2.Label {
            Layout.fillWidth: true
            wrapMode: QQC2.Label.WordWrap
            text: i18n("Widevine is a Google proprietary library that cannot be bundled with the app.")
        }

        Kirigami.Separator {
            Layout.fillWidth: true
        }

        Kirigami.FormLayout {
            Layout.fillWidth: true

            Kirigami.Separator {
                Kirigami.FormData.label: i18nc("@title:group", "Installation Status:")
                Kirigami.FormData.isSection: true
            }
        }

        RowLayout {
            Layout.fillWidth: true
            spacing: Kirigami.Units.smallSpacing

            Kirigami.Icon {
                source: widevineManager && widevineManager.isInstalled ? "dialog-ok-apply" : "dialog-warning"
                color: widevineManager && widevineManager.isInstalled ? Kirigami.Theme.positiveTextColor : Kirigami.Theme.neutralTextColor
                Layout.preferredWidth: Kirigami.Units.iconSizes.small
                Layout.preferredHeight: Kirigami.Units.iconSizes.small
            }

            QQC2.Label {
                Layout.fillWidth: true
                text: {
                    if (!widevineManager) {
                        return i18n("Status: Unknown");
                    }
                    if (widevineManager.isInstalling) {
                        return i18n("Status: Installing...");
                    }
                    if (widevineManager.isInstalled) {
                        return i18n("Status: Installed (version %1)", widevineManager.installedVersion);
                    }
                    return i18n("Status: Not installed");
                }
                color: widevineManager && widevineManager.isInstalled ? Kirigami.Theme.positiveTextColor : Kirigami.Theme.neutralTextColor
            }
        }

        RowLayout {
            Layout.fillWidth: true
            spacing: Kirigami.Units.smallSpacing

            QQC2.Button {
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
            text: i18n("Note: After installing or uninstalling Widevine, you need to restart Unify for changes to take effect.")
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
