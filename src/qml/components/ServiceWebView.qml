import QtQuick
import QtQuick.Window
import QtWebEngine
import org.kde.kirigami as Kirigami

Item {
    id: view

    // Public API
    property string serviceTitle: ""
    property string serviceId: ""
    property url initialUrl: "about:blank"
    property WebEngineProfile webProfile
    property bool isServiceDisabled: false

    // Show either the WebView or placeholder based on service state
    WebEngineView {
        id: webView
        anchors.fill: parent
        visible: !view.isServiceDisabled
        // Use provided persistent profile
        profile: view.webProfile
        url: view.initialUrl

        // Enable settings required for screen sharing, media capture, notifications and OAuth
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
        // Ensure page-initiated fullscreen is supported
        settings.fullScreenSupportEnabled: true

        // Track window state so we can restore it properly
        property bool _wasWindowFullScreenBeforeRequest: false

        // Handle permission requests: auto-grant required permissions
        onPermissionRequested: function (permission) {
            var requiredPermissions = [WebEnginePermission.PermissionType.Geolocation, WebEnginePermission.PermissionType.MediaAudioCapture, WebEnginePermission.PermissionType.MediaVideoCapture, WebEnginePermission.PermissionType.MediaAudioVideoCapture, WebEnginePermission.PermissionType.Notifications, WebEnginePermission.PermissionType.DesktopVideoCapture, WebEnginePermission.PermissionType.DesktopAudioVideoCapture, WebEnginePermission.PermissionType.MouseLock, WebEnginePermission.PermissionType.ClipboardReadWrite];

            if (requiredPermissions.indexOf(permission.permissionType) >= 0) {
                permission.grant();
                console.log("✅ Permission granted:", permission.permissionType, "for", view.serviceTitle);
            } else {
                permission.deny();
                console.log("⛔ Permission denied:", permission.permissionType, "for", view.serviceTitle);
            }
        }

        onLinkHovered: function (hoveredUrl) {
            if (hoveredUrl.toString() !== "")
            // reserved for status handling
            {}
        }

        onLoadingChanged: function (loadRequest) {
            if (loadRequest.status === WebEngineView.LoadSucceededStatus) {
                console.log("Service loaded: " + view.serviceTitle + " - " + view.url);
            }
        }

        // Handle popup windows (required for OAuth authentication flows)
        onNewWindowRequested: function (request) {
            console.log("🪟 Popup window requested for:", request.requestedUrl, "from service:", view.serviceTitle);

            // Create a new popup window
            var popupComponent = Qt.createComponent("PopupWindow.qml");
            if (popupComponent.status === Component.Ready) {
                var popup = popupComponent.createObject(view, {
                    "requestedUrl": request.requestedUrl,
                    "parentService": view.serviceTitle,
                    "webProfile": view.profile
                });

                if (popup) {
                    // Accept the request and assign the new view
                    request.openIn(popup.webView);
                    popup.show();
                    console.log("✅ Popup window created and shown");
                } else {
                    console.log("⛔ Failed to create popup window object");
                }
            } else {
                console.log("⛔ Failed to load popup component:", popupComponent.errorString());
            }
        }

        // Handle page-initiated fullscreen requests (e.g., video players)
        onFullScreenRequested: function (request) {
            // Accept and sync the application window visibility
            request.accept();
            var win = view.window; // owning Window
            if (!win)
                return;

            if (request.toggleOn) {
                view._wasWindowFullScreenBeforeRequest = (win.visibility === Window.FullScreen);
                if (!view._wasWindowFullScreenBeforeRequest)
                    win.showFullScreen();
            } else {
                if (!view._wasWindowFullScreenBeforeRequest)
                    win.showNormal();
                view._wasWindowFullScreenBeforeRequest = false;
            }
        }
    }

    // Placeholder for disabled services
    Kirigami.PlaceholderMessage {
        anchors.centerIn: parent
        width: parent.width - Kirigami.Units.gridUnit * 4
        visible: view.isServiceDisabled
        text: i18n("Service Disabled")
        explanation: i18n("This service is currently disabled. Enable it to use this web service.")
        icon.name: "offline"
    }
}
