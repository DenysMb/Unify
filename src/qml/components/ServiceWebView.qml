import QtQuick
import QtQuick.Window
import QtQuick.Controls as QQC2
import QtWebEngine
import org.kde.kirigami as Kirigami
import "AntiDetection.js" as AntiDetection
import "Services.js" as Services

Item {
    id: view

    // Public API
    property string serviceTitle: ""
    property string serviceId: ""
    property url initialUrl: "about:blank"
    property url configuredUrl: "about:blank"
    property WebEngineProfile webProfile
    property bool isServiceDisabled: false
    property alias contents: webView
    property var onTitleUpdated: null
    property int stackIndex: 0

    // Signal to request updating service URL
    signal updateServiceUrlRequested(string serviceId, string newUrl)

    // Internal state tracking
    property bool profileReady: webProfile !== null
    property bool urlLoaded: false
    property bool hasLoadedOnce: false  // Track if service has completed loading at least once

    // Check if current URL is outside the service's base URL
    property bool isNavigatedAway: {
        if (!hasLoadedOnce || isServiceDisabled)
            return false;
        var currentUrl = webView.url.toString();
        var baseUrl = configuredUrl.toString();
        if (currentUrl === "about:blank" || baseUrl === "about:blank")
            return false;
        // Extract origin (protocol + host) from both URLs
        try {
            var currentOrigin = currentUrl.replace(/^(https?:\/\/[^\/]+).*$/, "$1");
            var baseOrigin = baseUrl.replace(/^(https?:\/\/[^\/]+).*$/, "$1");
            return currentOrigin !== baseOrigin;
        } catch (e) {
            return false;
        }
    }

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

        // Set background color to match theme, preventing white flash
        backgroundColor: Kirigami.Theme.backgroundColor

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
                view.hasLoadedOnce = true;
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

        // Handle popup windows - Ctrl+Click opens directly in browser, otherwise overlay
        onNewWindowRequested: function (request) {
            console.log("🪟 Link requested:", request.requestedUrl, "from service:", view.serviceTitle);

            var requestedUrl = request.requestedUrl;

            // Check for OAuth/Auth popup
            if (Services.isOAuthUrl(requestedUrl)) {
                console.log("🔐 Auth popup detected - opening in separate window");

                // Create a new window instance for this popup request
                var popup = popupComponent.createObject(null, {
                    "parentService": view.serviceTitle,
                    "webProfile": view.webProfile
                    // Do NOT set requestedUrl here, let openIn handle it
                });

                if (popup) {
                    // Destroy the popup when it closes to free resources
                    popup.closing.connect(function () {
                        popup.destroy();
                    });

                    // Ensure window is visible before attaching
                    popup.show();

                    if (popup.webView) {
                        console.log("🔐 calling request.openIn(popup.webView)");
                        request.openIn(popup.webView);
                    } else {
                        console.warn("🔐 popup.webView is null!");
                    }
                    return;
                } else {
                    console.error("❌ Failed to create auth popup window");
                }
            }

            webView.runJavaScript("window.__unifyCtrlPressed || false", function (ctrlPressed) {
                if (ctrlPressed) {
                    console.log("🌐 Ctrl+Click - opening directly in browser");
                    Qt.openUrlExternally(requestedUrl);
                } else {
                    console.log("🔗 Opening link in overlay for user choice");
                    internalLinkOverlay.open(requestedUrl);
                }
            });
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

        // Handle desktop media requests for screen/window sharing (Qt 6.7+)
        onDesktopMediaRequested: function (request) {
            console.log("🖥️ Desktop media requested for:", view.serviceTitle);
            console.log("   Windows available:", request.windowsModel.rowCount());
            console.log("   Screens available:", request.screensModel.rowCount());
            desktopMediaDialog.show(request);
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

    // Inline message shown when navigated away from service URL
    Kirigami.InlineMessage {
        id: navigatedAwayMessage
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.top: parent.top
        anchors.margins: Kirigami.Units.smallSpacing
        z: 10
        visible: view.isNavigatedAway
        type: Kirigami.MessageType.Information
        text: i18n("You are browsing outside of %1", view.serviceTitle)
        actions: [
            Kirigami.Action {
                text: i18n("Return to %1", view.serviceTitle)
                icon.name: "go-home"
                onTriggered: {
                    webView.url = view.configuredUrl;
                }
            },
            Kirigami.Action {
                text: i18n("Set as New URL")
                icon.name: "document-save"
                onTriggered: {
                    view.updateServiceUrlRequested(view.serviceId, webView.url.toString());
                }
            }
        ]
    }

    Component {
        id: popupComponent
        PopupWindow {}
    }

    DesktopMediaDialog {
        id: desktopMediaDialog
    }

    InternalLinkOverlay {
        id: internalLinkOverlay
        anchors.fill: parent
        parentService: view.serviceTitle
        webProfile: view.webProfile
        z: 50

        onOpenInServiceView: function (urlToOpen) {
            console.log("🔗 Opening in service view:", urlToOpen);
            webView.url = urlToOpen;
        }
    }

    // Loading overlay - only shows on initial load, not on subsequent navigations
    // This prevents the white flash when switching to a service that already loaded in background
    Rectangle {
        anchors.fill: parent
        visible: !view.isServiceDisabled && !view.hasLoadedOnce && webView.loading
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
