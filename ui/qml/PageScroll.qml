import QtQuick
import Kplus
import QtQuick.Controls

// The scrolling container every page lives in: padded, max-width, with the slim scrollbar.
Flickable {
    id: root
    default property alias content: col.data
    property real maxWidth: 1680
    property bool wide: false
    property alias spacing: col.spacing
    contentWidth: width
    contentHeight: col.implicitHeight + topPad + 40
    readonly property real topPad: Theme.density === "compact" ? 18 : Theme.density === "spacious" ? 34 : 30
    readonly property real sidePad: Theme.density === "compact" ? 22 : Theme.density === "spacious" ? 44 : 32
    boundsBehavior: Flickable.StopAtBounds
    clip: true
    flickableDirection: Flickable.VerticalFlick
    maximumFlickVelocity: 5000
    flickDeceleration: 4000
    ScrollBar.vertical: ThinScroll {}

    Column {
        id: col
        x: Math.max(root.sidePad, (root.width - (root.wide ? root.width - 2 * root.sidePad : Math.min(root.maxWidth, root.width - 2 * root.sidePad))) / 2)
        y: root.topPad
        width: root.wide ? root.width - 2 * root.sidePad : Math.min(root.maxWidth, root.width - 2 * root.sidePad)
        spacing: 18
    }
    function scrollToTop() { contentY = 0 }
}
