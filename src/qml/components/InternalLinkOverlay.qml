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

        // Ensure the old page is not visible while the new one is still loading.
        // We deliberately avoid navigating to about:blank during close; instead we temporarily hide the view.
        overlayWebView.visible = true;
        overlayWebView.opacity = 0;

        overlayWebView.url = url;
        visible = true;
        openAnimation.start();
    }

    function close() {
        closeAnimation.start();
    }

    function forceClose() {
        if (!overlay.visible) {
            return;
        }
        closeAnimation.stop();
        openAnimation.stop();

        // Stop any in-flight work and hide the view so old content never flashes on next open.
        overlayWebView.stop();
        overlayWebView.visible = false;
        overlayWebView.opacity = 0;

        overlay.requestedUrl = "about:blank";
        overlay.visible = false;
        overlay.closed();
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
            // Avoid forcing a navigation during teardown; it can be fragile with QtWebEngine.
            overlayWebView.stop();
            overlayWebView.visible = false;
            overlayWebView.opacity = 0;
            overlay.requestedUrl = "about:blank";
            overlay.visible = false;
            overlay.closed();
        }
    }

    MouseArea {
        anchors.fill: parent
        onClicked: overlay.forceClose()
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
                        onClicked: overlay.forceClose()
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

                    // Intentionally hidden until the first non-blank frame of the next page.
                    visible: overlay.visible
                    opacity: 1

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
                            // Hide until a new page starts producing frames.
                            overlayWebView.opacity = 0;
                            overlayWebView.runJavaScript(AntiDetection.getScript());
                        }
                        if (loadRequest.status === WebEngineView.LoadSucceededStatus) {
                            overlayWebView.runJavaScript(AntiDetection.getScript());
                            overlayWebView.opacity = 1;
                        }
                        if (loadRequest.status === WebEngineView.LoadFailedStatus) {
                            overlayWebView.opacity = 1;
                        }
                    }

                    onNewWindowRequested: function (request) {
                        console.log("🔗 Overlay: Navigating to:", request.requestedUrl);
                        overlayWebView.url = request.requestedUrl;
                    }

                    onWindowCloseRequested: {
                        overlay.forceClose();
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
        onActivated: overlay.forceClose()
    }
}
