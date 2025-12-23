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

    // Reparent the existing WebView when it's set
    onExistingWebViewChanged: {
        if (existingWebView) {
            console.log("Reparenting WebView for service:", serviceTitle);
            // Reparent the ServiceWebView to this window's container
            existingWebView.parent = webViewContainerItem;
            // Reset anchors to fill the new container
            existingWebView.anchors.fill = webViewContainerItem;
            existingWebView.visible = true;
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
}
