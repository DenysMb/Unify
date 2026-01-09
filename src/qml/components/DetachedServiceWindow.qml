import QtQuick
import QtQuick.Window
import QtWebEngine
import org.kde.kirigami as Kirigami

Kirigami.ApplicationWindow {
    id: detachedWindow

    // Properties
    property string serviceId: ""
    property string serviceTitle: ""

    // The existing ServiceWebView that will be reparented here
    // This preserves the WebEngineView state (video playback, calls, etc.)
    property var existingWebView: null

    // Container where the reparented WebView will be placed
    property alias webViewContainer: webViewContainerItem

    // Fullscreen state tracking for page-initiated fullscreen
    property bool isContentFullscreen: false
    property var fullscreenWebView: null
    property var fullscreenOriginalParent: null
    property bool wasWindowFullScreenBeforeContent: false
    property color fullscreenOriginalBgColor: "transparent"

    // Signal emitted when window is closed
    signal windowClosed(string serviceId)

    // Window configuration
    width: 1200
    height: 800
    minimumWidth: 600
    minimumHeight: 400

    title: serviceTitle + " - " + i18n("Detached")

    // Make it a normal window (not modal)
    modality: Qt.NonModal
    flags: Qt.Window

    // Custom header with service info
    globalDrawer: null
    contextDrawer: null

    // Function to enter fullscreen mode for a WebEngineView
    function enterContentFullscreen(webEngineView) {
        if (isContentFullscreen || !webEngineView) {
            return;
        }

        fullscreenWebView = webEngineView;
        fullscreenOriginalParent = webEngineView.parent;
        wasWindowFullScreenBeforeContent = (detachedWindow.visibility === Window.FullScreen);

        // Store original background color and set to black to prevent white flash
        fullscreenOriginalBgColor = webEngineView.backgroundColor;
        webEngineView.backgroundColor = "black";

        // Show the fullscreen container first (black background visible immediately)
        isContentFullscreen = true;

        if (!wasWindowFullScreenBeforeContent) {
            detachedWindow.showFullScreen();
        }

        // Reparent WebView to fullscreen container
        webEngineView.parent = fullscreenContainer;
        webEngineView.anchors.fill = fullscreenContainer;
        webEngineView.z = 1;  // Above the black background

        // Ensure the WebEngineView has focus to receive ESC key
        webEngineView.forceActiveFocus();

        console.log("Detached window: Entered content fullscreen mode");
    }

    // Function to exit fullscreen mode
    function exitContentFullscreen() {
        if (!isContentFullscreen || !fullscreenWebView) {
            return;
        }

        // Restore original background color
        fullscreenWebView.backgroundColor = fullscreenOriginalBgColor;

        if (fullscreenOriginalParent) {
            fullscreenWebView.parent = fullscreenOriginalParent;
            fullscreenWebView.anchors.fill = fullscreenOriginalParent;
        }

        isContentFullscreen = false;

        if (!wasWindowFullScreenBeforeContent) {
            detachedWindow.showNormal();
        }

        fullscreenWebView = null;
        fullscreenOriginalParent = null;
        wasWindowFullScreenBeforeContent = false;
        fullscreenOriginalBgColor = "transparent";

        console.log("Detached window: Exited content fullscreen mode");
    }

    // Main page content
    pageStack.initialPage: Kirigami.Page {
        title: serviceTitle
        padding: 0

        // Actions for the detached window
        actions: [
            Kirigami.Action {
                text: i18n("Refresh")
                icon.name: "view-refresh"
                enabled: existingWebView !== null
                onTriggered: {
                    if (existingWebView && existingWebView.contents) {
                        existingWebView.contents.reload();
                        console.log("Refreshing detached service: " + serviceTitle);
                    }
                }
            },
            Kirigami.Action {
                text: i18n("Reattach")
                icon.name: "view-restore"
                onTriggered: {
                    console.log("Reattaching service: " + serviceTitle);
                    detachedWindow.close();
                }
            }
        ]

        // Container for the reparented ServiceWebView
        // The existingWebView will have its parent changed to this Item
        Item {
            id: webViewContainerItem
            anchors.fill: parent
        }
    }

    // Fullscreen container that overlays the entire window
    Item {
        id: fullscreenContainer
        parent: detachedWindow.contentItem
        anchors.fill: parent
        visible: detachedWindow.isContentFullscreen
        z: 999999

        // Black background to prevent white flash
        Rectangle {
            anchors.fill: parent
            color: "black"
            z: 0
        }

        // WebEngineView will be reparented here with z: 1
    }

    // Reparent the existing WebView when it's set and connect fullscreen signal
    onExistingWebViewChanged: {
        if (existingWebView) {
            console.log("Reparenting WebView for service:", serviceTitle);
            // Reparent the ServiceWebView to this window's container
            existingWebView.parent = webViewContainerItem;
            // Reset anchors to fill the new container
            existingWebView.anchors.fill = webViewContainerItem;
            existingWebView.visible = true;

            // Connect fullscreen signal for this detached window
            existingWebView.fullscreenRequested.connect(function(webEngineView, toggleOn) {
                if (toggleOn) {
                    detachedWindow.enterContentFullscreen(webEngineView);
                } else {
                    detachedWindow.exitContentFullscreen();
                }
            });
        }
    }

    // Handle window lifecycle
    Component.onCompleted: {
        console.log("Detached service window created for:", serviceTitle);
    }

    onClosing: {
        console.log("Detached service window closing:", serviceTitle);
        // Emit signal so main window can re-enable the service
        windowClosed(serviceId);
    }

    // Handle window visibility changes
    onVisibilityChanged: {
        if (detachedWindow.visibility === Window.Hidden || detachedWindow.visibility === Window.Minimized)
        // Window is hidden/minimized, but service continues running
        {}
        
        // If window exits fullscreen (e.g. via OS gesture or Alt-Tab) while we are in content fullscreen mode,
        // we need to tell the web content to exit fullscreen too.
        if (isContentFullscreen && visibility !== Window.FullScreen && visibility !== Window.Minimized && visibility !== Window.Hidden) {
            console.log("Detached window exited fullscreen (OS/User action) - syncing web content");
            if (fullscreenWebView) {
                fullscreenWebView.triggerWebAction(WebEngineView.ExitFullScreen);
            }
        }
    }

    // Keyboard shortcuts for common actions
    Shortcut {
        sequence: "F5"
        onActivated: {
            if (existingWebView && existingWebView.contents) {
                existingWebView.contents.reload();
            }
        }
    }

    Shortcut {
        sequence: "Ctrl+R"
        onActivated: {
            if (existingWebView && existingWebView.contents) {
                existingWebView.contents.reload();
            }
        }
    }

    Shortcut {
        sequence: "F11"
        onActivated: {
            if (detachedWindow.visibility === Window.FullScreen) {
                detachedWindow.showNormal();
            } else {
                detachedWindow.showFullScreen();
            }
        }
    }

    // ESC key shortcut to exit page-initiated fullscreen
    // This tells the web page to exit fullscreen, which triggers onFullScreenRequested(false)
    Shortcut {
        sequence: "Escape"
        enabled: detachedWindow.isContentFullscreen && detachedWindow.fullscreenWebView
        onActivated: {
            if (detachedWindow.fullscreenWebView) {
                console.log("Detached window: ESC pressed - triggering ExitFullScreen web action");
                detachedWindow.fullscreenWebView.triggerWebAction(WebEngineView.ExitFullScreen);
            }
        }
    }
}
