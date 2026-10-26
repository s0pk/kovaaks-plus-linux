import QtQuick
import Kplus

// A keyboard key cap.
Rectangle {
    property alias text: label.text
    implicitWidth: label.implicitWidth + 12; implicitHeight: 20
    radius: 3; color: Theme.surface3
    border.width: 1; border.color: Theme.border2
    Txt { id: label; anchors.centerIn: parent; w: 600; font.pixelSize: 11; color: Theme.text2 }
}
