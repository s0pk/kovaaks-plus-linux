import QtQuick
import QtQuick.Layouts
import Kplus

// Import dialog: what the pack contains, tick what to install.
Item {
    id: root
    property var dialog
    property var preview: ({ scenarios: [], presets: [] })
    property var selS: ({})
    property var selP: ({})
    property bool overwrite: false
    implicitHeight: col.implicitHeight
    Component.onCompleted: {
        var s = {}, p = {}
        preview.scenarios.forEach(function (x) { if (!x.identical || x.tags.length || x.customName) s[x.name] = true })
        preview.presets.forEach(function (x) { p[x.id] = true })
        selS = s; selP = p
    }
    function flip(map, key) { var m = {}; for (var k in map) m[k] = map[k]; m[key] = !m[key]; return m }
    function run() {
        var sc = Object.keys(selS).filter(function (k) { return selS[k] }), pr = Object.keys(selP).filter(function (k) { return selP[k] })
        Backend.call("packs.import", { path: preview.path, scenarios: sc, presets: pr, overwrite: overwrite }, function (r) {
            Store.loadLibrary()
            Store.loadPresets()
            Store.toast("Imported: " + r.installed + " scenario file(s) installed, " + r.skipped + " skipped, " + r.metaUpdated + " updated with tags/names, " + r.presetsAdded + " preset(s)", "ok")
        }, function (e) { Store.toast(e, "error") })
        return true
    }
    component Check: Rectangle {
        property bool on: false
        width: 18; height: 18; radius: 3; color: on ? Theme.accent : "transparent"; border.width: 1; border.color: on ? Theme.accent : Theme.border2
        Icon { visible: parent.on; anchors.centerIn: parent; name: "check"; size: 12; color: Theme.onAccent }
    }
    component Badge: Rectangle {
        property string text: ""
        property color tone: Theme.muted
        implicitWidth: bt.implicitWidth + 14; implicitHeight: 20; radius: 3; color: Theme.alpha(tone, 0.16); border.width: 1; border.color: Theme.alpha(tone, 0.3)
        Txt { id: bt; anchors.centerIn: parent; text: parent.text; font.pixelSize: 11; w: 600; color: parent.tone }
    }
    ColumnLayout {
        id: col; width: parent.width; spacing: 12
        Txt { Layout.fillWidth: true; wrapMode: Text.WordWrap; color: Theme.muted; textFormat: Text.StyledText
              text: (root.preview.author ? "by <b><font color='" + Theme.text + "'>" + root.preview.author + "</font></b> · " : "") + root.preview.scenarios.length + " scenarios · " + root.preview.presets.length + " presets" }
        Rectangle { visible: !!root.preview.description; Layout.fillWidth: true; implicitHeight: dt.implicitHeight + 24; radius: Theme.radiusSm; color: Theme.bg2; border.width: 1; border.color: Theme.border
                    Txt { id: dt; x: 12; y: 12; width: parent.width - 24; wrapMode: Text.WordWrap; text: root.preview.description || "" } }
        Rectangle {
            Layout.fillWidth: true; Layout.preferredHeight: Math.min(330, (root.preview.scenarios.length + root.preview.presets.length) * 44 + 2)
            radius: Theme.radiusSm; color: Theme.bg2; border.width: 1; border.color: Theme.border; clip: true
            ListView {
                anchors.fill: parent; anchors.margins: 1; boundsBehavior: Flickable.StopAtBounds; clip: true
                model: root.preview.scenarios.map(function (s) { return { kind: "s", s: s } }).concat(root.preview.presets.map(function (p) { return { kind: "p", p: p } }))
                delegate: Rectangle {
                    id: item
                    required property var modelData
                    readonly property bool isS: modelData.kind === "s"
                    readonly property string key: isS ? modelData.s.name : modelData.p.id
                    width: ListView.view.width; height: 44; color: ma.containsMouse ? Theme.surface2 : "transparent"
                    RowLayout {
                        anchors.fill: parent; anchors.leftMargin: 10; anchors.rightMargin: 10; spacing: 10
                        Check { on: item.isS ? !!root.selS[item.key] : !!root.selP[item.key] }
                        Icon { visible: !item.isS; name: "sliders"; size: 15; color: Theme.muted }
                        ColumnLayout { Layout.fillWidth: true; spacing: 0
                            Txt { Layout.fillWidth: true; elide: Text.ElideRight; w: 600; text: item.isS ? (item.modelData.s.customName || item.modelData.s.name) : item.modelData.p.name }
                            Txt { visible: item.isS && !!item.modelData.s.customName; Layout.fillWidth: true; elide: Text.ElideRight; font.pixelSize: 11; color: Theme.muted; text: item.isS ? item.modelData.s.name : "" } }
                        Repeater { model: item.isS ? item.modelData.s.tags.slice(0, 3) : []; delegate: Chip { required property string modelData; small: true; text: modelData; chipColor: "#64748b" } }
                        Badge { visible: item.isS; text: !item.isS ? "" : !item.modelData.s.hasFile ? "metadata only" : !item.modelData.s.exists ? "new" : item.modelData.s.identical ? "already installed" : "different version"
                                tone: !item.isS ? Theme.muted : (item.modelData.s.hasFile && !item.modelData.s.exists) ? Theme.accent2 : (item.modelData.s.hasFile && !item.modelData.s.identical) ? Theme.gold : Theme.muted }
                        Badge { visible: !item.isS; text: !item.isS && item.modelData.p.exists ? "preset · exists" : "preset" }
                    }
                    MouseArea { id: ma; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor
                                onClicked: { if (item.isS) root.selS = root.flip(root.selS, item.key); else root.selP = root.flip(root.selP, item.key) } }
                }
            }
        }
        RowLayout { Layout.fillWidth: true; spacing: 12
            Toggle { checked: root.overwrite; onToggled: function (v) { root.overwrite = v } }
            ColumnLayout { Layout.fillWidth: true; spacing: 1
                Txt { text: "Overwrite existing"; w: 600 }
                Txt { Layout.fillWidth: true; wrapMode: Text.WordWrap; font.pixelSize: 12; color: Theme.muted; text: "Replace scenario files with different versions and use the pack's names, notes and thumbnails for scenarios you already have." } } }
    }
}
