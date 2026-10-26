import QtQuick
import Kplus

// One figure of the scoreline: a rule, a quiet label, a large condensed numeral, a note.
Item {
    id: root
    property string label: ""
    property string value: ""
    property string note: ""
    property color valueColor: Theme.text
    implicitHeight: col.implicitHeight + 18
    Rectangle { width: parent.width; height: 1; color: Theme.border2 }
    Column {
        id: col
        y: 14; x: 2; width: parent.width - 4
        spacing: 12
        Txt { text: root.label; color: Theme.muted; font.pixelSize: 13; w: 500 }
        Txt { text: root.value; display: true; w: 700; color: root.valueColor; font.pixelSize: Math.max(34, Math.min(58, root.width * 0.3)); lineHeight: 0.9; lineHeightMode: Text.ProportionalHeight }
        Txt { visible: root.note !== ""; text: root.note; color: Theme.muted; font.pixelSize: 13; width: parent.width; elide: Text.ElideRight }
    }
}
