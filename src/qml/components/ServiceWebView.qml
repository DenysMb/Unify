import QtQuick
import QtWebEngine

WebEngineView {
    id: view

    // Public API
    property string serviceTitle: ""
    property string serviceId: ""
    property url initialUrl: "about:blank"

    // Set the service URL immediately when created
    url: initialUrl

    // Enable settings required for screen sharing, media capture and notifications
    settings.screenCaptureEnabled: true
    settings.webRTCPublicInterfacesOnly: false
    settings.javascriptCanAccessClipboard: true
    settings.allowWindowActivationFromJavaScript: true
    settings.showScrollBars: false

    // Handle permission requests: auto-grant required permissions
    onPermissionRequested: function(permission) {
        var requiredPermissions = [
            WebEnginePermission.PermissionType.Geolocation,
            WebEnginePermission.PermissionType.MediaAudioCapture,
            WebEnginePermission.PermissionType.MediaVideoCapture,
            WebEnginePermission.PermissionType.MediaAudioVideoCapture,
            WebEnginePermission.PermissionType.Notifications,
            WebEnginePermission.PermissionType.DesktopVideoCapture,
            WebEnginePermission.PermissionType.DesktopAudioVideoCapture,
            WebEnginePermission.PermissionType.MouseLock,
            WebEnginePermission.PermissionType.ClipboardReadWrite
        ]

        if (requiredPermissions.indexOf(permission.permissionType) >= 0) {
            permission.grant()
            console.log("✅ Permission granted:", permission.permissionType, "for", view.serviceTitle)
        } else {
            permission.deny()
            console.log("❌ Permission denied:", permission.permissionType, "for", view.serviceTitle)
        }
    }

    onLinkHovered: function(hoveredUrl) {
        if (hoveredUrl.toString() !== "") {
            // reserved for status handling
        }
    }

    onLoadingChanged: function(loadRequest) {
        if (loadRequest.status === WebEngineView.LoadSucceededStatus) {
            console.log("Service loaded: " + view.serviceTitle + " - " + view.url)
        }
    }
}
