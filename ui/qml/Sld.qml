import QtQuick
import Kplus

// A slim slider. value in [from, to].
Item {
    id: root
    property real from: 0
    property real to: 100
    property real step: 1
    property real value: 0
    signal moved(real value)
    implicitWidth: 150; implicitHeight: 22
    readonly property real pos: to === from ? 0 : (value - from) / (to - from)
    Rectangle { x: 0; y: 9; width: parent.width; height: 4; radius: 2; color: Theme.surface3 }
    Rectangle { x: 0; y: 9; width: parent.width * root.pos; height: 4; radius: 2; color: Theme.accent }
    Rectangle { x: (parent.width - 14) * root.pos; y: 4; width: 14; height: 14; radius: 7; color: Theme.accent; border.width: 2; border.color: Theme.bg }
    MouseArea {
        anchors.fill: parent; cursorShape: Qt.PointingHandCursor
        function setFrom(mx) {
            var p = Math.max(0, Math.min(1, (mx - 7) / (width - 14)))
            var v = root.from + p * (root.to - root.from)
            v = Math.round(v / root.step) * root.step
            v = Math.max(root.from, Math.min(root.to, v))
            if (v !== root.value) { root.value = v; root.moved(v) }
        }
        onPressed: function (m) { setFrom(m.x) }
        onPositionChanged: function (m) { if (pressed) setFrom(m.x) }
    }
}
