import QtQuick
import Kplus

// Thin progress bar. value 0..1.
Rectangle {
    id: root
    property real value: 0
    property color fill: Theme.text
    implicitHeight: 6
    implicitWidth: 120
    radius: 2
    color: Theme.surface3
    Rectangle {
        height: parent.height; radius: 2; color: root.fill
        width: parent.width * Math.max(0, Math.min(1, root.value))
        Behavior on width { NumberAnimation { duration: Theme.motion ? 300 : 0 } }
    }
}
