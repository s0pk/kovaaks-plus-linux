import QtQuick
import QtQuick.Layouts
import Kplus

// Choose a default settings preset ('' = none). `choice` holds the selection.
Item {
    id: root
    property var dialog
    property string choice: ""
    property string hint: ""
    property var presets: []
    implicitHeight: col.implicitHeight
    Component.onCompleted: Backend.call("presets.list", {}, function (r) { presets = r })

    ColumnLayout {
        id: col; width: parent.width; spacing: 10
        Txt { visible: root.presets.length === 0; text: "You have no presets yet. Create one under Settings & Presets."; color: Theme.muted; font.pixelSize: 12; wrapMode: Text.WordWrap; Layout.fillWidth: true }
        Repeater {
            model: [{ id: "", name: "No default preset", sub: root.hint || "Play with whatever settings are active" }].concat(root.presets.map(function (p) { return { id: p.id, name: p.name, sub: p.description || (p.categories || []).join(", ") } }))
            delegate: Rectangle {
                required property var modelData
                Layout.fillWidth: true; Layout.preferredHeight: 52; radius: Theme.radiusSm
                color: root.choice === modelData.id ? Theme.surface3 : (a.containsMouse ? Theme.surface2 : "transparent")
                RowLayout {
                    anchors.fill: parent; anchors.leftMargin: 12; anchors.rightMargin: 12; spacing: 12
                    Rectangle { width: 16; height: 16; radius: 8; color: "transparent"; border.width: 2; border.color: root.choice === modelData.id ? Theme.accent : Theme.border2
                                Rectangle { anchors.centerIn: parent; width: 8; height: 8; radius: 4; color: Theme.accent; visible: root.choice === modelData.id } }
                    Column { Layout.fillWidth: true
                        Txt { text: modelData.name; w: 600; width: parent.width; elide: Text.ElideRight }
                        Txt { text: modelData.sub; font.pixelSize: 12; color: Theme.muted; width: parent.width; elide: Text.ElideRight } }
                }
                MouseArea { id: a; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onClicked: root.choice = modelData.id }
            }
        }
        Txt { text: "When you press Play, the preset is applied first if your current settings differ."; font.pixelSize: 12; color: Theme.muted; wrapMode: Text.WordWrap; Layout.fillWidth: true }
    }
}
