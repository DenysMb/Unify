import QtQuick
import QtQuick.Controls as QQC2
import QtQuick.Layouts
import org.kde.kirigami as Kirigami

Kirigami.Dialog {
    id: root

    property var mediaRequest: null

    title: i18n("Share Your Screen")
    standardButtons: Kirigami.Dialog.Cancel
    preferredWidth: Kirigami.Units.gridUnit * 20
    padding: Kirigami.Units.largeSpacing

    onRejected: {
        if (mediaRequest)
            mediaRequest.cancel();
    }

    onClosed: {
        mediaRequest = null;
    }

    function show(request) {
        mediaRequest = request;
        open();
    }

    ColumnLayout {
        spacing: Kirigami.Units.largeSpacing

        QQC2.Label {
            Layout.fillWidth: true
            text: i18n("What do you want to share?")
            wrapMode: Text.WordWrap
            horizontalAlignment: Text.AlignHCenter
        }

        QQC2.Button {
            Layout.fillWidth: true
            Layout.preferredHeight: Kirigami.Units.gridUnit * 4
            icon.name: "window"
            text: i18n("A Window")
            onClicked: {
                if (root.mediaRequest && root.mediaRequest.windowsModel) {
                    var modelIndex = root.mediaRequest.windowsModel.index(0, 0);
                    root.mediaRequest.selectWindow(modelIndex);
                    root.close();
                }
            }
        }

        QQC2.Button {
            Layout.fillWidth: true
            Layout.preferredHeight: Kirigami.Units.gridUnit * 4
            icon.name: "monitor"
            text: i18n("A Screen")
            onClicked: {
                if (root.mediaRequest && root.mediaRequest.screensModel) {
                    var modelIndex = root.mediaRequest.screensModel.index(0, 0);
                    root.mediaRequest.selectScreen(modelIndex);
                    root.close();
                }
            }
        }
    }
}
