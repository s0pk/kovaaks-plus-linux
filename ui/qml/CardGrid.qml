import QtQuick
import Kplus

// Responsive grid for a handful of items (up to a few dozen): as many columns as fit at `minWidth`.
// Delegates size themselves with `width: parent.cellWidth`.
Flow {
    id: g
    property real minWidth: Theme.cardMin
    property real gap: 14
    property alias model: rep.model
    property alias delegate: rep.delegate
    readonly property int cols: Math.max(1, Math.floor((width + gap) / (minWidth + gap)))
    readonly property real cellWidth: Math.floor((width - gap * (cols - 1)) / cols)
    spacing: gap
    Repeater { id: rep }
}
