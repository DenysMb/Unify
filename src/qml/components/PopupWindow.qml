import QtQuick
import QtQuick.Window
import QtWebEngine
import org.kde.kirigami as Kirigami
import "AntiDetection.js" as AntiDetection

Kirigami.ApplicationWindow {
    id: popupWindow

    // Properties
    property url requestedUrl: "about:blank"
    property string parentService: ""
    property alias webView: webEngineView
    property WebEngineProfile webProfile

    // Anti-detection script for Google OAuth compatibility
    // Injected via runJavaScript on each page load

    // Window configuration
    width: 800
    height: 600
    minimumWidth: 400
    minimumHeight: 300

    title: webEngineView.title || i18n("Authentication - %1", parentService)

    // Make it a popup-style window
    modality: Qt.ApplicationModal
    flags: Qt.Dialog

    // Close when authentication is complete (detect common success patterns)
    function checkForAuthComplete() {
        var url = webEngineView.url.toString();

        // Common patterns that indicate successful authentication
        if (url.includes("code=") || url.includes("access_token=") || url.includes("auth_success") || url.includes("login_success") || url.includes("/success") || url.includes("close") || url.includes("callback")) {
            console.log("🎉 Authentication appears complete, closing popup");
            popupWindow.close();
        }
    }

    WebEngineView {
        id: webEngineView
        anchors.fill: parent

        url: popupWindow.requestedUrl
        profile: popupWindow.webProfile

        // Enable necessary settings for authentication and OAuth compatibility
        settings.javascriptCanAccessClipboard: true
        settings.allowWindowActivationFromJavaScript: true
        settings.javascriptCanOpenWindows: true
        settings.javascriptEnabled: true
        settings.localStorageEnabled: true
        settings.localContentCanAccessRemoteUrls: false
        settings.localContentCanAccessFileUrls: false
        settings.allowRunningInsecureContent: false
        settings.dnsPrefetchEnabled: true
        settings.fullScreenSupportEnabled: true

        // Track window state for proper restore on exit
        property bool _wasWindowFullScreenBeforeRequest: false

        // Handle permission requests (similar to main ServiceWebView)
        onPermissionRequested: function (permission) {
            var authPermissions = [WebEnginePermission.PermissionType.ClipboardReadWrite, WebEnginePermission.PermissionType.Notifications];

            if (authPermissions.indexOf(permission.permissionType) >= 0) {
                permission.grant();
                console.log("✅ Auth popup permission granted:", permission.permissionType);
            } else {
                permission.deny();
                console.log("❌ Auth popup permission denied:", permission.permissionType);
            }
        }

        onLoadingChanged: function (loadRequest) {
            // Inject anti-detection script as early as possible
            if (loadRequest.status === WebEngineView.LoadStartedStatus) {
                webEngineView.runJavaScript(AntiDetection.getScript());
            }
            if (loadRequest.status === WebEngineView.LoadSucceededStatus) {
                console.log("📱 Popup loaded:", webEngineView.url);
                // Re-inject after load to ensure it's applied
                webEngineView.runJavaScript(AntiDetection.getScript());
                // Check if authentication is complete
                popupWindow.checkForAuthComplete();
            }
        }

        onUrlChanged: {
            // Continuously check for authentication completion
            popupWindow.checkForAuthComplete();
        }

        // Handle window close requests from JavaScript
        onWindowCloseRequested: {
            console.log("🚪 Popup window close requested by JavaScript");
            popupWindow.close();
        }

        // Handle nested popups (just in case)
        onNewWindowRequested: function (request) {
            console.log("🪟 Nested popup requested, opening in same window");
            // For nested popups in auth flows, replace current URL
            webEngineView.url = request.requestedUrl;
        }

        // Handle fullscreen requests inside the auth popup if any
        onFullScreenRequested: function (request) {
            request.accept();
            var win = popupWindow; // this WebView fills the popup window
            if (!win)
                return;

            if (request.toggleOn) {
                webEngineView._wasWindowFullScreenBeforeRequest = (win.visibility === Window.FullScreen);
                if (!webEngineView._wasWindowFullScreenBeforeRequest)
                    win.showFullScreen();
            } else {
                if (!webEngineView._wasWindowFullScreenBeforeRequest)
                    win.showNormal();
                webEngineView._wasWindowFullScreenBeforeRequest = false;
            }
        }
    }

    // Add a close button in case auto-detection fails
    Component.onCompleted: {
        console.log("🪟 Popup window created for:", requestedUrl, "from service:", parentService);
    }

    onClosing: {
        console.log("🚪 Popup window closing");
    }
}
