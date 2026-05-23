import QtQuick
import QtQuick.Controls as QQC2
import QtQuick.Layouts

import org.kde.kirigami as Kirigami
import org.kde.kirigamiaddons.formcard as FormCard

Kirigami.ScrollablePage {
    id: root

    title: i18nc("@title", "Settings")

    padding: 0

    Kirigami.ColumnView.pinned: true
    Kirigami.ColumnView.preferredWidth: Kirigami.Units.gridUnit * 18
    Kirigami.ColumnView.minimumWidth: Kirigami.Units.gridUnit * 12
    Kirigami.ColumnView.maximumWidth: Kirigami.Units.gridUnit * 22

    Component {
        id: appearancePage
        SettingsAppearance {}
    }

    Component {
        id: behaviorPage
        SettingsBehavior {}
    }

    Component {
        id: widevinePage
        SettingsWidevine {}
    }

    FormCard.FormCard {
        id: formCard
        width: parent.width

        states: [
            State {
                name: "centered"
                when: !applicationWindow().pageStack.wideMode
                AnchorChanges {
                    target: formCard
                    anchors.verticalCenter: formCard.parent.verticalCenter
                }
            },
            State {
                name: "top"
                when: applicationWindow().pageStack.wideMode
                AnchorChanges {
                    target: formCard
                    anchors.top: formCard.parent.top
                }
            }
        ]

        FormCard.FormButtonDelegate {
            id: appearanceButton
            text: i18nc("@action:button", "Appearance")
            description: i18nc("@info:whatsthis", "Sidebar, header, and visual layout")
            icon.name: "preferences-desktop-theme"
            onClicked: Kirigami.PageStack.push(appearancePage)
        }

        FormCard.FormDelegateSeparator {
            above: appearanceButton
            below: behaviorButton
        }

        FormCard.FormButtonDelegate {
            id: behaviorButton
            text: i18nc("@action:button", "Behavior")
            description: i18nc("@info:whatsthis", "Audio, downloads, tray, and autostart")
            icon.name: "preferences-system"
            onClicked: Kirigami.PageStack.push(behaviorPage)
        }

        FormCard.FormDelegateSeparator {
            above: behaviorButton
            below: widevineButton
        }

        FormCard.FormButtonDelegate {
            id: widevineButton
            text: i18nc("@action:button", "Widevine (DRM)")
            description: i18nc("@info:whatsthis", "Install and manage Widevine CDM")
            icon.name: "shield"
            onClicked: Kirigami.PageStack.push(widevinePage)
        }
    }
}
