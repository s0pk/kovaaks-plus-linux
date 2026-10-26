import QtQuick
import Kplus
import QtQuick.Controls

// Shows a small tooltip after the pointer rests on the target MouseArea.
Item {
    id: root
    property string text: ""
    property var target: null
    ToolTip {
        visible: root.text !== "" && root.target && root.target.containsMouse
        delay: 600
        text: root.text
        contentItem: Txt { text: root.text; font.pixelSize: 12 }
        background: Rectangle { color: Theme.surface3; border.color: Theme.border2; radius: Theme.radiusSm }
    }
}
