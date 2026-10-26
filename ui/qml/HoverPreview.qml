import QtQuick
import Kplus

// Put inside a row or card: after a short hover it asks the app to show the scenario's preview pop-up next to the cursor.
Item {
    id: root
    property string name: ""
    property bool active: true
    anchors.fill: parent
    HoverHandler {
        id: hh
        onHoveredChanged: { if (hovered && root.active && root.name !== "") delay.restart(); else { delay.stop(); Store.hideHover() } }
        onPointChanged: if (Store.hover && hovered) root.place()
    }
    function place() { var p = root.mapToItem(Modals.menuHost, hh.point.position.x, hh.point.position.y); Store.showHover(root.name, p.x, p.y) }
    // a short delay so sweeping the mouse across a list stays calm
    Timer { id: delay; interval: 260; onTriggered: if (hh.hovered) root.place() }
    Component.onDestruction: if (Store.hover && Store.hover.name === root.name) Store.hideHover()
}
