import QtQuick
import org.kde.kirigami as Kirigami

Item {
    id: root
    property string text: ""
    property string explanation: ""
    property string iconName: ""

    Kirigami.PlaceholderMessage {
        anchors.centerIn: parent
        width: parent.width - Kirigami.Units.gridUnit * 4
        icon.name: root.iconName
        text: root.text
        explanation: root.explanation
    }
}
