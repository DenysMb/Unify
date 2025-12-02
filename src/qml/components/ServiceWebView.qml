import QtQuick
import QtQuick.Window
import QtWebEngine
import org.kde.kirigami as Kirigami
import "AntiDetection.js" as AntiDetection

Item {
    id: view

    // Public API
    property string serviceTitle: ""
    property string serviceId: ""
    property url initialUrl: "about:blank"
    property WebEngineProfile webProfile
    property bool isServiceDisabled: false
    property alias contents: webView
    property var onTitleUpdated: null
    property int stackIndex: 0

    // Internal state tracking
    property bool profileReady: webProfile !== null
    property bool urlLoaded: false

    // Anti-detection script for Google OAuth compatibility
    // Injected via runJavaScript on each page load

    // Monitor profile readiness
    onProfileReadyChanged: {
        if (profileReady && !urlLoaded && !isServiceDisabled && initialUrl.toString() !== "about:blank") {
            console.log("Profile ready, loading URL for:", serviceTitle);
            loadUrlWhenReady();
        }
    }

    // Delay URL loading to ensure profile is fully initialized
    function loadUrlWhenReady() {
        if (!webProfile) {
            console.warn("Cannot load URL - profile not ready for:", serviceTitle);
            return;
        }

        if (webView.url.toString() === "about:blank" && initialUrl.toString() !== "about:blank") {
            urlLoadTimer.start();
        }
    }

    // Timer to delay URL loading slightly
    Timer {
        id: urlLoadTimer
        interval: 50
        repeat: false
        onTriggered: {
            if (!view.isServiceDisabled && view.initialUrl.toString() !== "about:blank") {
                console.log("Timer triggered, loading:", view.initialUrl, "for:", view.serviceTitle);
                webView.url = view.initialUrl;
                view.urlLoaded = true;
            }
        }
    }

    // Timeout timer to detect stuck loading
    Timer {
        id: loadTimeoutTimer
        interval: 30000  // 30 seconds timeout
        repeat: false
        onTriggered: {
            if (webView.loading) {
                console.warn("Load timeout for:", view.serviceTitle, "- stopping and retrying");
                webView.stop();
                // Retry after a short delay
                retryTimer.start();
            }
        }
    }

    Timer {
        id: retryTimer
        interval: 1000
        repeat: false
        onTriggered: {
            if (!view.isServiceDisabled && view.initialUrl.toString() !== "about:blank") {
                console.log("Retrying load for:", view.serviceTitle);
                webView.reload();
            }
        }
    }

    // Show either the WebView or placeholder based on service state
    WebEngineView {
        id: webView
        anchors.fill: parent
        visible: !view.isServiceDisabled
        z: 0

        // Use provided persistent profile
        profile: view.webProfile

        // Start with about:blank, URL will be set when profile is ready
        url: "about:blank"

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
            // Inject anti-detection script as early as possible
            if (loadRequest.status === WebEngineView.LoadStartedStatus) {
                webView.runJavaScript(AntiDetection.getScript());
                loadTimeoutTimer.restart();
            }
            if (loadRequest.status === WebEngineView.LoadSucceededStatus) {
                loadTimeoutTimer.stop();
                console.log("Service loaded: " + view.serviceTitle + " - " + webView.url);
                // Re-inject after load to ensure it's applied
                webView.runJavaScript(AntiDetection.getScript());
            }
            if (loadRequest.status === WebEngineView.LoadFailedStatus) {
                loadTimeoutTimer.stop();
                console.warn("Service load failed: " + view.serviceTitle + " - " + loadRequest.errorString);
            }
            if (loadRequest.status === WebEngineView.LoadStoppedStatus) {
                loadTimeoutTimer.stop();
                console.log("Service load stopped: " + view.serviceTitle);
            }
        }

        // Monitor title changes to extract notification badges
        onTitleChanged: {
            if (view.onTitleUpdated && typeof view.onTitleUpdated === "function") {
                view.onTitleUpdated(view.serviceId, webView.title);
            }
        }

        // Handle popup windows (required for OAuth authentication flows)
        onNewWindowRequested: function (request) {
            console.log("🪟 Popup window requested for:", request.requestedUrl, "from service:", view.serviceTitle);

            var requestedUrl = request.requestedUrl.toString();
            var currentUrl = webView.url.toString();

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

            if (isInternal || isOAuth) {
                console.log("🔐 Opening in popup (internal/OAuth):", requestedDomain);
                var popupComponent = Qt.createComponent("PopupWindow.qml");
                if (popupComponent.status === Component.Ready) {
                    var popup = popupComponent.createObject(view, {
                        "requestedUrl": request.requestedUrl,
                        "parentService": view.serviceTitle,
                        "webProfile": view.webProfile
                    });

                    if (popup) {
                        request.openIn(popup.webView);
                        popup.show();
                        console.log("✅ Popup window created and shown");
                    } else {
                        console.log("⛔ Failed to create popup window object");
                    }
                } else {
                    console.log("⛔ Failed to load popup component:", popupComponent.errorString());
                }
            } else {
                console.log("🌐 Opening external link in system browser:", requestedUrl);
                Qt.openUrlExternally(request.requestedUrl);
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

    // Initialize URL loading when component is ready
    Component.onCompleted: {
        if (webProfile && !isServiceDisabled && initialUrl.toString() !== "about:blank") {
            loadUrlWhenReady();
        }
    }

    // Placeholder for disabled services
    Kirigami.PlaceholderMessage {
        anchors.centerIn: parent
        width: parent.width - Kirigami.Units.gridUnit * 4
        visible: view.isServiceDisabled
        z: 1
        text: i18n("Service Disabled")
        explanation: i18n("This service is currently disabled. Enable it to use this web service.")
        icon.name: "offline"
    }

    // Loading overlay - shows while page is loading
    Rectangle {
        anchors.fill: parent
        visible: !view.isServiceDisabled && webView.loading && webView.loadProgress < 100
        z: 2
        color: Kirigami.Theme.backgroundColor

        Kirigami.LoadingPlaceholder {
            anchors.centerIn: parent
            text: i18n("Loading %1...", view.serviceTitle)
        }

        // Show progress bar at the top
        Rectangle {
            anchors.top: parent.top
            anchors.left: parent.left
            anchors.right: parent.right
            height: 3
            color: Kirigami.Theme.backgroundColor

            Rectangle {
                anchors.top: parent.top
                anchors.bottom: parent.bottom
                anchors.left: parent.left
                width: parent.width * (webView.loadProgress / 100)
                color: Kirigami.Theme.highlightColor

                Behavior on width {
                    NumberAnimation {
                        duration: Kirigami.Units.shortDuration
                    }
                }
            }
        }
    }
}
