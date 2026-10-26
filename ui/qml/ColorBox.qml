import QtQuick
import Kplus

// A colour swatch that opens the system colour dialog.
Rectangle {
    id: root
    property color value: "#8b5cf6"
    signal picked(color value)
    implicitWidth: 44; implicitHeight: 26
    radius: Theme.radiusSm; color: value; border.width: 1; border.color: Theme.border2
    MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor; onClicked: { dlg.selectedColor = root.value; dlg.open() } }
    ColorPickerDialog { id: dlg; onPicked: function (c) { root.picked(c) } }
}
