import QtQuick
import Kplus

// The reticle: four corner brackets that mark what is hovered, selected or current.
Item {
    id: root
    property real len: 12
    property real thick: 2
    property color color: Theme.text
    property real pad: 0
    anchors.fill: parent
    anchors.margins: -pad
    visible: opacity > 0
    Behavior on opacity { NumberAnimation { duration: Theme.animMs } }

    Repeater {
        model: 4
        delegate: Item {
            required property int index
            readonly property bool atRight: index === 1 || index === 3
            readonly property bool atBottom: index === 2 || index === 3
            x: atRight ? root.width - root.len : 0
            y: atBottom ? root.height - root.len : 0
            width: root.len; height: root.len
            Rectangle { color: root.color; height: root.thick; width: root.len; y: parent.atBottom ? parent.height - root.thick : 0 }
            Rectangle { color: root.color; width: root.thick; height: root.len; x: parent.atRight ? parent.width - root.thick : 0 }
        }
    }
}
