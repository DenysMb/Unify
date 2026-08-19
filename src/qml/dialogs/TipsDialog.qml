import QtQuick
import QtQuick.Controls as QQC2
import QtQuick.Layouts
import org.kde.kirigami as Kirigami

Kirigami.Dialog {
    id: root

    title: i18n("Tips & Settings")
    padding: Kirigami.Units.largeSpacing
    preferredWidth: Kirigami.Units.gridUnit * 30
    standardButtons: Kirigami.Dialog.Ok

    QQC2.ScrollView {
        implicitWidth: Kirigami.Units.gridUnit * 28
        implicitHeight: Kirigami.Units.gridUnit * 24

        ColumnLayout {
            width: parent.width
            spacing: Kirigami.Units.largeSpacing

            Kirigami.Heading {
                level: 4
                text: i18n("Keyboard Shortcuts")
            }

            QQC2.Label {
                Layout.fillWidth: true
                wrapMode: QQC2.Label.WordWrap
                textFormat: QQC2.Label.RichText
                text: i18n("<b>Ctrl + 1, 2, 3...</b> — Switch between services in the current workspace<br>" +
                    "<b>Ctrl + Shift + 1, 2, 3...</b> — Switch between workspaces<br>" +
                    "<b>Ctrl + K</b> — Open the global service switcher<br>" +
                    "<b>Ctrl + B</b> — Go to Favorites workspace<br>" +
                    "<b>Ctrl + Tab</b> — Go to the next service<br>" +
                    "<b>Ctrl + Shift + Tab</b> — Go to the next workspace<br>" +
                    "<b>Double-tap Ctrl</b> — Toggle between the last two services<br>" +
                    "<b>Escape</b> — Close overlay/dialog")
            }

            Kirigami.Separator {
                Layout.fillWidth: true
            }

            Kirigami.Heading {
                level: 4
                text: i18n("Link Handling")
            }

            QQC2.Label {
                Layout.fillWidth: true
                wrapMode: QQC2.Label.WordWrap
                textFormat: QQC2.Label.RichText
                text: i18n("When you click a link in a service, it opens in an <b>overlay</b> where you can choose to:<br>" +
                    "• <b>Open in Service</b> — Navigate the service to that URL<br>" +
                    "• <b>Open in Browser</b> — Open in your default browser<br><br>" +
                    "<b>Tip:</b> Hold <b>Ctrl</b> while clicking a link to open it directly in your browser, bypassing the overlay.")
            }

            Kirigami.Separator {
                Layout.fillWidth: true
            }

            Kirigami.Heading {
                level: 4
                text: i18n("Other Tips")
            }

            QQC2.Label {
                Layout.fillWidth: true
                wrapMode: QQC2.Label.WordWrap
                textFormat: QQC2.Label.RichText
                text: i18n("• <b>Right-click</b> a service icon to access quick actions (edit, disable, delete)<br>" +
                    "• <b>Disabled services</b> won't load until re-enabled, saving resources<br>" +
                    "• Enable <b>System Tray</b> to keep the app running in the background when you close the window<br>" +
                    "• <b>Notification badges</b> appear on service icons when there are unread messages")
            }
        }
    }
}
