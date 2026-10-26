import QtQuick
import Kplus

// A framed panel. `pad` adds inner padding around the content.
Rectangle {
    id: root
    property real pad: 0
    default property alias content: inner.data
    color: Theme.surface
    border.width: 1
    border.color: Theme.border
    radius: Theme.radius
    Item {
        id: inner
        anchors.fill: parent
        anchors.margins: root.pad
    }
}
