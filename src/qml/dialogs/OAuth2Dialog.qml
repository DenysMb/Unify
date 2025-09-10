import QtQuick
import QtQuick.Layouts
import QtQuick.Controls as QQC2
import org.kde.kirigami as Kirigami

Kirigami.Dialog {
    id: oauthDialog

    title: i18n("Google Authentication")

    standardButtons: Kirigami.Dialog.NoButton

    ColumnLayout {
        spacing: Kirigami.Units.largeSpacing

        Kirigami.Icon {
            source: "google"
            Layout.alignment: Qt.AlignHCenter
            Layout.preferredWidth: 64
            Layout.preferredHeight: 64
        }

        Kirigami.Heading {
            level: 3
            text: oauthManager.isAuthenticated ? i18n("Signed in as %1", oauthManager.userName) : i18n("Sign in with Google")
            Layout.alignment: Qt.AlignHCenter
        }

        Kirigami.SelectableLabel {
            text: oauthManager.isAuthenticated ? i18n("Email: %1", oauthManager.userEmail) : i18n("Click the button below to sign in with your Google account. This will open your default browser.")
            wrapMode: Text.WordWrap
            Layout.fillWidth: true
        }

        RowLayout {
            Layout.fillWidth: true

            QQC2.Button {
                visible: !oauthManager.isAuthenticated
                text: i18n("Sign in with Google")
                icon.name: "internet-web-browser"
                Layout.fillWidth: true
                onClicked: {
                    console.log("🔐 Starting Google OAuth2 authentication");
                    oauthManager.authenticateWithGoogle();
                }
            }

            QQC2.Button {
                visible: oauthManager.isAuthenticated
                text: i18n("Sign Out")
                icon.name: "system-log-out"
                Layout.fillWidth: true
                onClicked: {
                    oauthManager.logout();
                }
            }
        }

        QQC2.Button {
            text: i18n("Close")
            Layout.fillWidth: true
            onClicked: oauthDialog.close()
        }
    }

    Connections {
        target: oauthManager

        function onAuthenticationSucceeded() {
            console.log("✅ OAuth authentication succeeded");
        }

        function onAuthenticationFailed(error) {
            console.log("❌ OAuth authentication failed:", error);
        }
    }
}
