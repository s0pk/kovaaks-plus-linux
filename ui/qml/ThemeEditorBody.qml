import QtQuick
import QtQuick.Layouts
import Kplus
import "js/Appearance.js" as AP

// Create or edit a user theme: a name and the eight colours it is made of, with a live preview.
Item {
    id: root
    property var dialog
    property var work: ({})          // {id, name, colors, accent, accent2}
    property bool existing: false
    property var onSave
    implicitHeight: col.implicitHeight
    Component.onCompleted: nameIn.text = work.name

    function setColor(key, v) {
        var w = AP.copy(work)
        if (key === "accent" || key === "accent2") w[key] = String(v); else w.colors[key] = String(v)
        work = w
    }
    function save() {
        var w = AP.copy(work)
        w.name = nameIn.text.trim() || "My theme"
        onSave(w)
        return true
    }
    ColumnLayout {
        id: col; width: parent.width; spacing: 14
        ColumnLayout { Layout.fillWidth: true; spacing: 6
            Txt { text: "Name"; w: 600; color: Theme.text2; font.pixelSize: 13 }
            Field { id: nameIn; Layout.fillWidth: true } }
        Rectangle {   // preview
            Layout.fillWidth: true; Layout.preferredHeight: 120; radius: Theme.radius; color: root.work.colors.bg; border.width: 1; border.color: root.work.colors.border; clip: true
            Rectangle { width: 70; height: parent.height; color: root.work.colors.sidebar; Rectangle { anchors.right: parent.right; width: 1; height: parent.height; color: root.work.colors.border } }
            Column { x: 86; y: 12; spacing: 8
                Rectangle { width: 240; height: 56; radius: Theme.radiusSm; color: root.work.colors.surface; border.width: 1; border.color: root.work.colors.border
                    Column { x: 10; y: 8; spacing: 3
                        Txt { text: "Panel title"; w: 600; color: root.work.colors.text }
                        Txt { text: "Muted secondary text"; font.pixelSize: 12; color: root.work.colors.muted } } }
                Row { spacing: 12
                    Rectangle { width: 58; height: 24; radius: Theme.radiusSm; color: root.work.accent; Txt { anchors.centerIn: parent; text: "Accent"; font.pixelSize: 12; color: Theme.lum(root.work.accent) > 0.4 ? "#141513" : "#ffffff" } }
                    Txt { text: "Secondary"; font.pixelSize: 12; color: root.work.accent2; anchors.verticalCenter: parent.verticalCenter } } }
        }
        GridLayout {
            Layout.fillWidth: true; columns: 2; columnSpacing: 28; rowSpacing: 8
            Repeater {
                model: [["accent", "Accent"], ["accent2", "Secondary"]].concat(AP.BASE_KEYS)
                delegate: RowLayout {
                    required property var modelData
                    Layout.fillWidth: true
                    Txt { text: modelData[1]; font.pixelSize: 13; Layout.fillWidth: true }
                    ColorBox { value: modelData[0] === "accent" || modelData[0] === "accent2" ? root.work[modelData[0]] : root.work.colors[modelData[0]]; onPicked: function (c) { root.setColor(modelData[0], c) } }
                }
            }
        }
    }
}
