import QtQuick
import QtQuick.Dialogs
import QtQuick.Layouts

// Colour choice: a row of swatches plus the system colour dialog.
Flow {
    id: root
    property color value: "#8b5cf6"
    property var swatches: ["#f97316", "#fb923c", "#facc15", "#a3e635", "#4ade80", "#22c55e", "#2dd4bf", "#22d3ee", "#38bdf8", "#60a5fa", "#818cf8", "#8b5cf6", "#c084fc", "#e879f9", "#f472b6", "#f87171", "#dc2626", "#94a3b8"]
    signal picked(color value)
    spacing: 6
    Rectangle {   // current colour + custom
        width: 28; height: 28; radius: Theme.radiusSm; color: root.value; border.width: 1; border.color: Theme.border2
        MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor; onClicked: { dlg.selectedColor = root.value; dlg.open() } }
        Icon { anchors.centerIn: parent; name: "edit"; size: 13; color: Theme.lum(root.value) > 0.4 ? "#141513" : "#ffffff" }
    }
    Repeater {
        model: root.swatches
        delegate: Rectangle {
            required property string modelData
            width: 20; height: 20; radius: 10; color: modelData; anchors.verticalCenter: undefined
            border.width: Qt.colorEqual(modelData, root.value) ? 2 : 0; border.color: Theme.text
            MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor; onClicked: root.picked(modelData) }
        }
    }
    ColorDialog { id: dlg; onAccepted: root.picked(selectedColor) }
}
