import QtQuick
import QtQuick.Controls as Controls
import QtQuick.Layouts
import org.kde.kirigami as Kirigami
import QtWebEngine

Kirigami.Dialog {
    id: root

    // Public API
    property var pendingPermission: null
    property string serviceName: ""

    title: i18n("Permission Request")
    standardButtons: Kirigami.Dialog.Ok | Kirigami.Dialog.Cancel
    padding: Kirigami.Units.largeSpacing
    preferredWidth: Kirigami.Units.gridUnit * 25

    onAccepted: {
        if (pendingPermission) pendingPermission.grant()
    }
    onRejected: {
        if (pendingPermission) pendingPermission.deny()
    }

    function showPermissionRequest(permission, serviceTitle) {
        pendingPermission = permission
        serviceName = serviceTitle
        permissionText.text = questionForPermissionType(permission, serviceTitle)
        open()
    }

    function questionForPermissionType(permission, serviceTitle) {
        var question = i18n("Allow %1 to ", serviceTitle)
        switch (permission.permissionType) {
        case WebEnginePermission.PermissionType.Geolocation:
            question += i18n("access your location information?"); break
        case WebEnginePermission.PermissionType.MediaAudioCapture:
            question += i18n("access your microphone?"); break
        case WebEnginePermission.PermissionType.MediaVideoCapture:
            question += i18n("access your webcam?"); break
        case WebEnginePermission.PermissionType.MediaAudioVideoCapture:
            question += i18n("access your microphone and webcam?"); break
        case WebEnginePermission.PermissionType.Notifications:
            question += i18n("show notifications on your desktop?"); break
        case WebEnginePermission.PermissionType.DesktopAudioVideoCapture:
            question += i18n("capture audio and video of your desktop?"); break
        default:
            question += i18n("access unknown or unsupported permission type [%1]?", permission.permissionType); break
        }
        return question
    }

    Controls.Label {
        id: permissionText
        Layout.fillWidth: true
        wrapMode: Text.WordWrap
        horizontalAlignment: Text.AlignLeft
    }
}
