import QtQuick
import Kplus

Item {
    id: root
    property real size: 18
    implicitWidth: size; implicitHeight: size
    Rectangle {
        anchors.fill: parent; radius: width / 2; color: "transparent"
        border.width: 2; border.color: Theme.border2
    }
    Canvas {
        anchors.fill: parent
        onPaint: {
            var c = getContext("2d"); c.reset(); c.strokeStyle = Theme.text; c.lineWidth = 2
            c.beginPath(); c.arc(width / 2, height / 2, width / 2 - 1, -Math.PI / 2, 0); c.stroke()
        }
        RotationAnimator on rotation { from: 0; to: 360; duration: 800; loops: Animation.Infinite; running: root.visible }
    }
}
