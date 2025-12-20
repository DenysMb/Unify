import QtQuick
import QtQuick.Window
import QtWebEngine
import "AntiDetection.js" as AntiDetection

Window {
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
    visible: false

    title: webEngineView.title || qsTr("Authentication - %1").arg(parentService)

    // Make it a popup-style window
    modality: Qt.ApplicationModal
    flags: Qt.Dialog

    // Timer to delay closing, allowing final scripts (like postMessage) to execute
    Timer {
        id: closeTimer
        interval: 2000
        repeat: false
        onTriggered: {
            console.log("⏰ Auth complete timer triggered - closing popup now");
            popupWindow.close();
        }
    }

    // Close when authentication is complete (detect common success patterns)
    function checkForAuthComplete() {
        var url = webEngineView.url.toString();
        
        // Ignore initial empty/blank states
        if (url === "about:blank" || url === "") return;

        // Strict check for OAuth response parameters
        var hasAuthToken = url.includes("code=") || 
                          url.includes("access_token=") || 
                          url.includes("id_token=");

        if (hasAuthToken) {
            if (!closeTimer.running) {
                console.log("🎉 Authentication appears complete (token detected). Waiting for scripts to finalize before closing... URL:", url);
                closeTimer.start();
            }
        }
    }

    WebEngineView {
        id: webEngineView
        anchors.fill: parent

        // url property is NOT bound here to avoid conflict with openIn()
        // It will be set either by request.openIn() or manually via property update if needed
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
            console.log("🪟 Nested popup requested:", request.requestedUrl);

            var requestedUrl = request.requestedUrl.toString();
            var currentUrl = webEngineView.url.toString();

            function extractDomain(url) {
                try {
                    var matches = url.match(/^https?:\/\/([^\/]+)/i);
                    return matches ? matches[1].toLowerCase() : "";
                } catch (e) {
                    return "";
                }
            }

            var requestedDomain = extractDomain(requestedUrl);
            var currentDomain = extractDomain(currentUrl);

            var oauthDomains = ["accounts.google.com"];

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
                console.log("🔐 Nested OAuth popup - navigating in same window:", requestedDomain);
                webEngineView.url = request.requestedUrl;
            } else if (isInternal) {
                console.log("🔗 Nested internal link - navigating in same window:", requestedDomain);
                webEngineView.url = request.requestedUrl;
            } else {
                console.log("🌐 Opening external link in system browser:", requestedUrl);
                Qt.openUrlExternally(request.requestedUrl);
            }
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
