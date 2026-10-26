import QtQuick
import Kplus
import QtQuick.Layouts

// Segmented control. options: [{value, label, icon, title}]
Rectangle {
    id: root
    property var options: []
    property var value
    signal picked(var value)
    implicitHeight: 34
    implicitWidth: row.implicitWidth + 6
    radius: Theme.radiusSm
    color: Theme.bg2
    border.width: 1; border.color: Theme.border2

    Row {
        id: row
        anchors.centerIn: parent
        spacing: 2
        Repeater {
            model: root.options
            delegate: Rectangle {
                required property var modelData
                readonly property bool on: modelData.value === root.value
                height: 28; width: content.implicitWidth + 24
                radius: 2
                color: on ? Theme.surface3 : (area.containsMouse ? Theme.surface2 : "transparent")
                Rectangle { visible: parent.on; anchors.bottom: parent.bottom; width: parent.width; height: 2; color: Theme.text }
                RowLayout {
                    id: content
                    anchors.centerIn: parent
                    spacing: 6
                    Icon { visible: !!modelData.icon; name: modelData.icon || "dot"; size: 15; color: on ? Theme.text : Theme.text2 }
                    Txt { visible: !!modelData.label; text: modelData.label || ""; w: 600; font.pixelSize: 12; color: on ? Theme.text : Theme.text2 }
                }
                MouseArea { id: area; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onClicked: { root.value = modelData.value; root.picked(modelData.value) } }
            }
        }
    }
}
