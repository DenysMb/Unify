import QtQuick
import QtQuick.Controls as QQC2
import QtQuick.Layouts
import QtWebEngine
import org.kde.kirigami as Kirigami
import "AntiDetection.js" as AntiDetection

Rectangle {
    id: overlay

    property url requestedUrl: "about:blank"
    property string parentService: ""
    property WebEngineProfile webProfile

    signal closed
    signal openInServiceView(url urlToOpen)

    anchors.fill: parent
    color: Qt.rgba(0, 0, 0, 0.6)
    visible: false
    z: 100

    function open(url) {
        requestedUrl = url;
        overlayWebView.url = url;
        visible = true;
        openAnimation.start();
    }

    function close() {
        closeAnimation.start();
    }

    NumberAnimation {
        id: openAnimation
        target: contentContainer
        property: "scale"
        from: 0.9
        to: 1.0
        duration: 150
        easing.type: Easing.OutCubic
    }

    NumberAnimation {
        id: closeAnimation
        target: contentContainer
        property: "scale"
        from: 1.0
        to: 0.9
        duration: 100
        easing.type: Easing.InCubic
        onFinished: {
            overlay.visible = false;
            overlayWebView.url = "about:blank";
            overlay.closed();
        }
    }

    MouseArea {
        anchors.fill: parent
        onClicked: overlay.close()
    }

    Rectangle {
        id: contentContainer
        anchors.centerIn: parent
        width: parent.width * 0.9
        height: parent.height * 0.9
        radius: Kirigami.Units.largeSpacing
        color: Kirigami.Theme.backgroundColor
        clip: true

        MouseArea {
            anchors.fill: parent
            onClicked: {}
        }

        ColumnLayout {
            anchors.fill: parent
            spacing: 0

            Rectangle {
                Layout.fillWidth: true
                Layout.preferredHeight: Kirigami.Units.gridUnit * 2.5
                color: Kirigami.Theme.alternateBackgroundColor
                radius: Kirigami.Units.largeSpacing

                Rectangle {
                    anchors.left: parent.left
                    anchors.right: parent.right
                    anchors.bottom: parent.bottom
                    height: Kirigami.Units.largeSpacing
                    color: parent.color
                }

                RowLayout {
                    anchors.fill: parent
                    anchors.leftMargin: Kirigami.Units.largeSpacing
                    anchors.rightMargin: Kirigami.Units.smallSpacing
                    spacing: Kirigami.Units.smallSpacing

                    Kirigami.Icon {
                        source: "internet-services"
                        Layout.preferredWidth: Kirigami.Units.iconSizes.small
                        Layout.preferredHeight: Kirigami.Units.iconSizes.small
                    }

                    QQC2.Label {
                        Layout.fillWidth: true
                        text: overlayWebView.title || overlay.requestedUrl.toString()
                        elide: Text.ElideMiddle
                        font.weight: Font.Medium
                    }

                    QQC2.ToolButton {
                        icon.name: "debug-run"
                        text: i18n("Open in Service")
                        display: QQC2.AbstractButton.TextBesideIcon
                        onClicked: {
                            var urlToOpen = overlayWebView.url;
                            overlay.close();
                            overlay.openInServiceView(urlToOpen);
                        }
                    }

                    QQC2.ToolButton {
                        icon.name: "window-new"
                        text: i18n("Open in Browser")
                        display: QQC2.AbstractButton.TextBesideIcon
                        onClicked: {
                            Qt.openUrlExternally(overlayWebView.url);
                            overlay.close();
                        }
                    }

                    QQC2.ToolButton {
                        icon.name: "view-refresh"
                        text: i18n("Refresh")
                        display: QQC2.AbstractButton.TextBesideIcon
                        onClicked: overlayWebView.reload()
                    }

                    QQC2.ToolButton {
                        icon.name: "window-close"
                        text: i18n("Close")
                        display: QQC2.AbstractButton.TextBesideIcon
                        onClicked: overlay.close()
                    }
                }
            }

            Rectangle {
                Layout.fillWidth: true
                Layout.preferredHeight: 3
                color: Kirigami.Theme.backgroundColor

                Rectangle {
                    anchors.left: parent.left
                    anchors.top: parent.top
                    anchors.bottom: parent.bottom
                    width: parent.width * (overlayWebView.loadProgress / 100)
                    color: Kirigami.Theme.highlightColor
                    visible: overlayWebView.loading

                    Behavior on width {
                        NumberAnimation {
                            duration: Kirigami.Units.shortDuration
                        }
                    }
                }
            }

            Item {
                Layout.fillWidth: true
                Layout.fillHeight: true

                WebEngineView {
                    id: overlayWebView
                    anchors.fill: parent

                    profile: overlay.webProfile
                    url: "about:blank"

                    settings.javascriptEnabled: true
                    settings.localStorageEnabled: true
                    settings.fullScreenSupportEnabled: true
                    settings.screenCaptureEnabled: true
                    settings.webRTCPublicInterfacesOnly: false
                    settings.javascriptCanAccessClipboard: true
                    settings.allowWindowActivationFromJavaScript: true
                    settings.showScrollBars: true
                    settings.dnsPrefetchEnabled: true

                    onLoadingChanged: function (loadRequest) {
                        if (loadRequest.status === WebEngineView.LoadStartedStatus) {
                            overlayWebView.runJavaScript(AntiDetection.getScript());
                        }
                        if (loadRequest.status === WebEngineView.LoadSucceededStatus) {
                            overlayWebView.runJavaScript(AntiDetection.getScript());
                        }
                    }

                    onNewWindowRequested: function (request) {
                        var requestedUrl = request.requestedUrl.toString();

                        function extractDomain(url) {
                            try {
                                var matches = url.match(/^https?:\/\/([^\/]+)/i);
                                return matches ? matches[1].toLowerCase() : "";
                            } catch (e) {
                                return "";
                            }
                        }

                        var requestedDomain = extractDomain(requestedUrl);
                        var currentDomain = extractDomain(overlayWebView.url.toString());

                        var oauthDomains = ["accounts.google.com", "login.microsoftonline.com", "login.live.com", "appleid.apple.com", "facebook.com", "www.facebook.com", "github.com", "api.twitter.com", "discord.com", "id.twitch.tv", "login.yahoo.com", "auth.atlassian.com", "slack.com", "login.salesforce.com", "accounts.spotify.com", "oauth.telegram.org", "web.telegram.org", "web.whatsapp.com"];

                        function isOAuthDomain(domain) {
                            for (var i = 0; i < oauthDomains.length; i++) {
                                if (domain === oauthDomains[i] || domain.endsWith("." + oauthDomains[i])) {
                                    return true;
                                }
                            }
                            return false;
                        }

                        function isSameDomainOrSubdomain(domain1, domain2) {
                            if (!domain1 || !domain2)
                                return false;
                            if (domain1 === domain2)
                                return true;
                            var rootDomain1 = domain1.split('.').slice(-2).join('.');
                            var rootDomain2 = domain2.split('.').slice(-2).join('.');
                            return rootDomain1 === rootDomain2;
                        }

                        var isInternal = isSameDomainOrSubdomain(requestedDomain, currentDomain);
                        var isOAuth = isOAuthDomain(requestedDomain);

                        if (isOAuth) {
                            console.log("🔐 Overlay: OAuth link, navigating in overlay:", requestedDomain);
                            overlayWebView.url = request.requestedUrl;
                        } else if (isInternal) {
                            console.log("🔗 Overlay: Internal link, navigating in overlay:", requestedDomain);
                            overlayWebView.url = request.requestedUrl;
                        } else {
                            console.log("🌐 Overlay: External link, opening in browser:", requestedUrl);
                            Qt.openUrlExternally(request.requestedUrl);
                        }
                    }

                    onWindowCloseRequested: {
                        overlay.close();
                    }
                }

                Kirigami.LoadingPlaceholder {
                    anchors.centerIn: parent
                    visible: overlayWebView.loading && overlayWebView.loadProgress < 30
                    text: i18n("Loading...")
                }
            }
        }
    }

    Shortcut {
        sequence: "Escape"
        enabled: overlay.visible
        onActivated: overlay.close()
    }
}
