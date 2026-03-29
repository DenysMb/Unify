import QtQuick
import QtQuick.Window
import QtQuick.Controls as QQC2
import QtWebEngine
import org.kde.kirigami as Kirigami
import "AntiDetection.js" as AntiDetection
import "Services.js" as Services

WebEngineView {
    id: webView

    property string tabId: ""
    property string serviceId: ""
    property url initialUrl: "about:blank"
    property WebEngineProfile webProfile
    property bool isMuted: false
    property bool globalMute: false
    property string querySelector: ""

    signal tabTitleChanged(string title)
    signal audioStateChanged(string serviceId, bool isPlaying)
    signal fullscreenRequested(var webEngineView, bool toggleOn)
    signal newTabRequested(url url)
    signal zoomUpdated(real zoomFactor)
    signal notificationCountFromContent(string serviceId, int count)

    anchors.fill: parent
    visible: false
    backgroundColor: Kirigami.Theme.backgroundColor
    profile: webView.webProfile
    url: webView.initialUrl
    audioMuted: webView.isMuted || webView.globalMute

    onZoomFactorChanged: {
        webView.zoomUpdated(webView.zoomFactor);
    }

    settings.screenCaptureEnabled: true
    settings.webRTCPublicInterfacesOnly: false
    settings.javascriptCanAccessClipboard: true
    settings.allowWindowActivationFromJavaScript: true
    settings.showScrollBars: false
    settings.javascriptEnabled: true
    settings.localStorageEnabled: true
    settings.localContentCanAccessRemoteUrls: false
    settings.localContentCanAccessFileUrls: false
    settings.allowRunningInsecureContent: false
    settings.dnsPrefetchEnabled: true
    settings.fullScreenSupportEnabled: true

    onPermissionRequested: function (permission) {
        var requiredPermissions = [WebEnginePermission.PermissionType.Geolocation, WebEnginePermission.PermissionType.MediaAudioCapture, WebEnginePermission.PermissionType.MediaVideoCapture, WebEnginePermission.PermissionType.MediaAudioVideoCapture, WebEnginePermission.PermissionType.Notifications, WebEnginePermission.PermissionType.DesktopVideoCapture, WebEnginePermission.PermissionType.DesktopAudioVideoCapture, WebEnginePermission.PermissionType.MouseLock, WebEnginePermission.PermissionType.ClipboardReadWrite];

        if (requiredPermissions.indexOf(permission.permissionType) >= 0) {
            permission.grant();
        } else {
            permission.deny();
        }
    }

    onLoadingChanged: function (loadRequest) {
        if (loadRequest.status === WebEngineView.LoadStartedStatus) {
            webView.runJavaScript(AntiDetection.getScript());
        }
        if (loadRequest.status === WebEngineView.LoadSucceededStatus) {
            webView.runJavaScript(AntiDetection.getScript());
            // Extract notification count from content using querySelector
            extractNotificationCount();
            // Start the periodic timer
            notificationTimer.restart();
        }
    }

    onTitleChanged: {
        webView.tabTitleChanged(webView.title);
    }

    onRecentlyAudibleChanged: {
        webView.audioStateChanged(webView.serviceId, webView.recentlyAudible);
    }

    onNewWindowRequested: function (request) {
        var requestedUrl = request.requestedUrl;

        if (Services.isOAuthUrl(requestedUrl)) {
            var popupComponent = Qt.createComponent("PopupWindow.qml");
            if (popupComponent.status === Component.Ready) {
                var popup = popupComponent.createObject(null, {
                    "parentService": webView.serviceId,
                    "webProfile": webView.webProfile
                });
                if (popup) {
                    popup.show();
                    if (popup.webView) {
                        request.openIn(popup.webView);
                    }
                    popup.closing.connect(function () {
                        popup.destroy();
                    });
                }
            }
            return;
        }

        var ctrlPressed = typeof keyEventFilter !== 'undefined' && keyEventFilter && keyEventFilter.ctrlPressed;
        if (ctrlPressed) {
            Qt.openUrlExternally(requestedUrl);
        } else {
            webView.newTabRequested(requestedUrl);
        }
    }

    onFullScreenRequested: function (request) {
        request.accept();
        webView.fullscreenRequested(webView, request.toggleOn);
    }

    onDesktopMediaRequested: function (request) {
        var dialog = Qt.createComponent("DesktopMediaDialog.qml");
        if (dialog.status === Component.Ready) {
            var dialogInstance = dialog.createObject(webView);
            dialogInstance.show(request);
        }
    }

    onPrintRequested: function () {
        webView.printPage();
    }

    function printPage() {
        var printHandler = Qt.createComponent("PrintHandler.qml");
        if (printHandler.status === Component.Ready) {
            var pdfPath = "/tmp/unify_print_" + Date.now() + ".pdf";
            webView.printToPdf(pdfPath);
        }
    }

    Component.onCompleted: {
        webView.runJavaScript(AntiDetection.getScript());
    }

    // Extract notification count from page content using querySelector
    function extractNotificationCount() {
        if (!webView.querySelector || webView.querySelector === "") {
            return;
        }

        // The querySelector should be the full expression including .textContent
        // e.g., document.querySelector('span.counter').textContent
        var script = "(function() { " +
            "try { " +
            "    var result = " + webView.querySelector + "; " +
            "    if (result) { " +
            "        var text = typeof result === 'string' ? result : (result.textContent || result.innerText || ''); " +
            "        var match = text.match(/\\d+/); " +
            "        return match ? parseInt(match[0], 10) : 0; " +
            "    } " +
            "    return 0; " +
            "} catch (e) { " +
            "    return 0; " +
            "} })()";

        webView.runJavaScript(script, function(result) {
            if (result !== undefined && result !== null) {
                webView.notificationCountFromContent(webView.serviceId, result);
            }
        });
    }

    // Timer to periodically extract notification count
    Timer {
        id: notificationTimer
        interval: 5000 // 5 seconds
        repeat: true
        onTriggered: {
            if (webView.visible && webView.querySelector && webView.querySelector !== "") {
                extractNotificationCount();
            }
        }
    }
}