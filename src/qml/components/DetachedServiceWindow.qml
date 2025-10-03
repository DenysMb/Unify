import QtQuick
import QtQuick.Window
import QtWebEngine
import org.kde.kirigami as Kirigami

Kirigami.ApplicationWindow {
    id: detachedWindow

    // Properties
    property string serviceId: ""
    property string serviceTitle: ""
    property url serviceUrl: "about:blank"
    property WebEngineProfile webProfile
    property alias webView: serviceWebView

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
                onTriggered: {
                    serviceWebView.reload();
                    console.log("Refreshing detached service: " + serviceTitle);
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

        // Service WebView
        ServiceWebView {
            id: serviceWebView
            anchors.fill: parent

            serviceTitle: detachedWindow.serviceTitle
            serviceId: detachedWindow.serviceId
            initialUrl: detachedWindow.serviceUrl
            webProfile: detachedWindow.webProfile

            // Handle new window requests in the detached window context
            onNewWindowRequested: function (request) {
                console.log("New window requested in detached service:", request.requestedUrl, "from:", serviceTitle);

                // Create a popup window for authentication flows etc.
                var popupComponent = Qt.createComponent("PopupWindow.qml");
                if (popupComponent.status === Component.Ready) {
                    var popup = popupComponent.createObject(detachedWindow, {
                        "requestedUrl": request.requestedUrl,
                        "parentService": serviceTitle,
                        "webProfile": webProfile
                    });

                    if (popup) {
                        request.openIn(popup.webView);
                        popup.show();
                        console.log("Popup window created for detached service");
                    } else {
                        console.log("Failed to create popup window for detached service");
                    }
                } else {
                    console.log("Failed to load popup component for detached service:", popupComponent.errorString());
                }
            }
        }
    }

    // Handle window lifecycle
    Component.onCompleted: {
        console.log("Detached service window created for:", serviceTitle);
        // Ensure the WebView loads the correct URL
        serviceWebView.url = serviceUrl;
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
        onActivated: serviceWebView.reload()
    }

    Shortcut {
        sequence: "Ctrl+R"
        onActivated: serviceWebView.reload()
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
