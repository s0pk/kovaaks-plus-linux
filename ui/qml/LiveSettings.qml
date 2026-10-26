import QtQuick
import QtQuick.Layouts
import Kplus
import "js/PresetLogic.js" as PL

// Every KovaaK's setting, grouped like the game groups them, with friendly labels for the common ones.
Item {
    id: root
    implicitHeight: Math.max(layout.implicitHeight, 360)
    property var snap: null
    property var rows: []
    property var pending: ({})       // row id -> new value
    property int gen: 0              // bump to rebuild the list (discard / reload)
    property string query: ""
    readonly property int changedCount: Object.keys(pending).length

    function load() {
        Backend.call("settings.get", {}, function (s) { root.snap = s; root.rows = PL.rows(s); root.pending = ({}); root.gen++ }, function (e) { Store.toast(e, "error") })
    }
    Component.onCompleted: load()

    function setPending(r, v) {
        var p = {}
        for (var k in pending) p[k] = pending[k]
        if (JSON.stringify(v) === JSON.stringify(r.value)) delete p[r.id]; else p[r.id] = v
        pending = p
    }
    function apply() {
        var primary = {}, weapon = {}
        root.rows.forEach(function (r) {
            if (pending[r.id] === undefined) return
            if (r.src === "primary") { (primary[r.section] = primary[r.section] || {})[r.key] = pending[r.id] } else weapon[r.key] = pending[r.id]
        })
        Store.withRestart("settings.apply", { primary: primary, weapon: weapon }, "Settings applied", function (ok) { if (ok) root.load() })
    }
    readonly property var counts: { var c = {}; rows.forEach(function (r) { c[r.cat] = (c[r.cat] || 0) + 1 }); return c }
    readonly property var shown: {
        gen
        var q = query.trim().toLowerCase()
        var list = q ? rows.filter(function (r) { return (PL.short(r.key) + " " + PL.humanize(r.key) + " " + PL.label(r)).toLowerCase().indexOf(q) >= 0 })
                     : rows.filter(function (r) { return r.cat === Store.liveCat })
        list = list.slice().sort(function (a, b) {
            var pa = PL.PRIORITY.indexOf(PL.short(a.key)), pb = PL.PRIORITY.indexOf(PL.short(b.key))
            return (pa < 0 ? 999 : pa) - (pb < 0 ? 999 : pb) || PL.humanize(a.key).localeCompare(PL.humanize(b.key))
        })
        return list.slice(0, 400)
    }
    function kind(r) {
        var k = PL.short(r.key)
        if (/^(SensScaleString|FOVScaleString|OverrideSensScaleString|OverrideFovScaleString)$/.test(k)) return "scale"
        if (k === "CurrentThemeName") return "theme"
        if (/^(CrosshairFile|HitmarkerFile|HeadHitmarkerFile)$/.test(k)) return "crosshair"
        if (/Sound$/.test(k) && (r.type === "string" || r.type === "inistring") && snap && snap.sounds.length) return "sound"
        if (/Volume$/.test(k) && (r.type === "float" || r.type === "ininum")) return "volume"
        return r.type
    }
    function opts(list, cur) {
        var all = list.indexOf(cur) >= 0 ? list : [cur].concat(list)
        return all.map(function (o) { return { value: o, label: String(o) } })
    }
    function cur(r) { var v = pending[r.id]; return v !== undefined ? v : r.value }

    RowLayout {
        id: layout
        width: parent.width; spacing: 24
        // ---- left: search + categories ----
        ColumnLayout {
            Layout.preferredWidth: 250; Layout.maximumWidth: 250; Layout.alignment: Qt.AlignTop; spacing: 12
            Field { Layout.fillWidth: true; icon: "search"; placeholder: "Search all settings…"; onEdited: function (t) { root.query = t } }
            Repeater {
                model: PL.CAT_ORDER.filter(function (c) { return root.counts[c] })
                delegate: Rectangle {
                    required property string modelData
                    readonly property bool on: Store.liveCat === modelData && root.query === ""
                    Layout.fillWidth: true; height: 32; radius: Theme.radiusSm
                    color: on ? Theme.surface3 : (ma.containsMouse ? Theme.surface : "transparent")
                    RowLayout { anchors.fill: parent; anchors.leftMargin: 9; anchors.rightMargin: 9; spacing: 9
                        Icon { name: PL.CAT_ICONS[modelData]; size: 15; color: Theme.text2; opacity: 0.75 }
                        Txt { text: PL.CAT_LABELS[modelData]; w: parent.parent.on ? 600 : 400; color: parent.parent.on ? Theme.text : Theme.text2; Layout.fillWidth: true }
                        Txt { text: String(root.counts[modelData]); font.pixelSize: 11; color: Theme.muted } }
                    MouseArea { id: ma; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onClicked: Store.liveCat = modelData }
                }
            }
        }
        // ---- right: the settings ----
        ColumnLayout {
            Layout.fillWidth: true; Layout.alignment: Qt.AlignTop; spacing: 12
            Rectangle {
                visible: !!(root.snap && root.snap.running)
                Layout.fillWidth: true; Layout.preferredHeight: 54; radius: Theme.radius; color: Theme.surface
                border.width: 1; border.color: Theme.alpha(Theme.gold, 0.4)
                RowLayout { anchors.fill: parent; anchors.leftMargin: 16; anchors.rightMargin: 16; spacing: 10
                    Icon { name: "bolt"; size: 16; color: Theme.gold }
                    Txt { Layout.fillWidth: true; wrapMode: Text.WordWrap; color: Theme.muted; textFormat: Text.StyledText
                          text: "<b><font color='" + Theme.text + "'>KovaaK's is running.</font></b> When you apply, Kovaak's Plus closes the game, writes your changes and relaunches it." } }
            }
            Card {
                Layout.fillWidth: true; pad: 18
                implicitHeight: list.implicitHeight + 36
                ColumnLayout {
                    id: list; width: parent.width; spacing: 0
                    RowLayout {
                        Layout.fillWidth: true; Layout.bottomMargin: 10
                        Txt { Layout.fillWidth: true; display: true; w: 600; font.pixelSize: 20; elide: Text.ElideRight
                              text: root.query ? "Results for \"" + root.query + "\"" : PL.CAT_LABELS[Store.liveCat] }
                        Btn { small: true; icon: "plus"; text: "Save as preset"; onClicked: Modals.capturePreset() }
                    }
                    Txt { visible: !root.snap; text: "Loading settings…"; color: Theme.muted; Layout.topMargin: 10 }
                    Repeater {
                        model: root.shown
                        delegate: SettingRow { required property var modelData; r: modelData; Layout.fillWidth: true }
                    }
                    Txt { visible: !!root.snap && root.shown.length === 0; text: "No settings match."; color: Theme.muted; Layout.topMargin: 10 }
                    // apply bar
                    Rectangle {
                        visible: root.changedCount > 0
                        Layout.fillWidth: true; Layout.topMargin: 14; Layout.preferredHeight: 54; radius: Theme.radiusSm; color: Theme.surface3; border.width: 1; border.color: Theme.border2
                        RowLayout { anchors.fill: parent; anchors.leftMargin: 16; anchors.rightMargin: 10; spacing: 10
                            Txt { Layout.fillWidth: true; w: 700; text: root.changedCount + " unsaved change" + (root.changedCount === 1 ? "" : "s") }
                            Btn { kind: "ghost"; text: "Discard"; onClicked: { root.pending = ({}); root.gen++ } }
                            Btn { kind: "primary"; icon: "check"; text: "Apply to KovaaK's"; onClicked: root.apply() } }
                    }
                }
            }
        }
    }

    component SettingRow: Rectangle {
        id: sr
        property var r: ({})
        readonly property bool changed: root.pending[r.id] !== undefined
        readonly property string k: root.kind(r)
        readonly property var value: root.cur(r)
        implicitHeight: Math.max(50, hl.implicitHeight + 18)
        color: "transparent"
        Rectangle { anchors.fill: parent; color: sr.changed ? Theme.alpha(Theme.accent, 0.07) : "transparent" }
        Rectangle { visible: sr.changed; width: 3; height: parent.height; color: Theme.accent }
        Rectangle { anchors.bottom: parent.bottom; width: parent.width; height: 1; color: Theme.border }
        RowLayout {
            id: hl
            anchors.fill: parent; anchors.leftMargin: 12; anchors.rightMargin: 4; anchors.topMargin: 6; anchors.bottomMargin: 6; spacing: 16
            ColumnLayout { Layout.fillWidth: true; Layout.preferredWidth: 1; spacing: 1
                Txt { text: PL.label(sr.r); Layout.fillWidth: true; elide: Text.ElideRight }
                Txt { text: PL.hint(sr.r); font.pixelSize: 11; color: Theme.muted; Layout.fillWidth: true; elide: Text.ElideRight } }
            Loader {
                Layout.preferredWidth: 300; Layout.alignment: Qt.AlignVCenter | Qt.AlignRight
                sourceComponent: ({ "scale": selectC, "theme": selectC, "sound": selectC, "crosshair": crosshairC, "volume": volumeC, "bool": boolC, "inibool": boolC,
                                    "int": numC, "float": numC, "ininum": numC, "string": strC, "inistring": strC, "vector": colorC, "inivector": colorC, "color": colorC })[sr.k] || jsonC
            }
        }
        // each control reads `sr.value` and reports through root.setPending
        Component { id: selectC; Select {
            implicitWidth: 300
            options: root.opts(sr.k === "scale" ? root.snap.scales : sr.k === "theme" ? root.snap.themes : ["None"].concat(root.snap.sounds), sr.value)
            value: sr.value; onPicked: function (v) { root.setPending(sr.r, v) } } }
        Component { id: crosshairC; CrosshairPicker { files: root.snap.crosshairs; value: sr.value; onPicked: function (f) { root.setPending(sr.r, f) } } }
        Component { id: volumeC; RowLayout { spacing: 10
            property real num: sr.r.type === "ininum" ? parseFloat(sr.value) : sr.value
            Sld { Layout.fillWidth: true; from: 0; to: 1; step: 0.01; value: parent.num; onMoved: function (v) { root.setPending(sr.r, sr.r.type === "ininum" ? String(v) : v) } }
            Txt { text: Math.round(parent.num * 100) + "%"; font.pixelSize: 12; color: Theme.muted; Layout.preferredWidth: 38; horizontalAlignment: Text.AlignRight } } }
        Component { id: boolC; Item { implicitHeight: 22
            Toggle { anchors.right: parent.right; checked: sr.k === "inibool" ? /true/i.test(sr.value) : !!sr.value
                onToggled: function (on) { root.setPending(sr.r, sr.k === "inibool" ? (on ? "true" : "false") : on) } } } }
        Component { id: numC; Field { implicitWidth: 130; Component.onCompleted: text = String(sr.value)
            onEdited: function (t) {
                var v = sr.k === "int" ? parseInt(t, 10) : parseFloat(t)
                if (isNaN(v)) return
                root.setPending(sr.r, sr.k === "ininum" ? t : v) } } }
        Component { id: strC; Field { implicitWidth: 260; Component.onCompleted: text = String(sr.value); onEdited: function (t) { root.setPending(sr.r, t) } } }
        Component { id: jsonC; Txt { text: JSON.stringify(sr.value); color: Theme.muted; font.pixelSize: 12; elide: Text.ElideRight; width: 300 } }
        Component { id: colorC; Item {
            implicitWidth: 56; implicitHeight: 28
            readonly property color col: sr.k === "color" ? PL.rgbToHex(sr.value) : PL.vecToHex(sr.k === "vector" ? sr.value : PL.iniToVec(sr.value))
            Rectangle { anchors.right: parent.right; width: 52; height: 28; radius: Theme.radiusSm; color: parent.col; border.width: 1; border.color: Theme.border2
                        MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor; onClicked: { dlg.selectedColor = parent.parent.col; dlg.open() } } }
            ColorPickerDialog { id: dlg
                onPicked: function (c) {
                    var hx = String(c)
                    if (sr.k === "color") root.setPending(sr.r, { r: parseInt(hx.slice(1, 3), 16), g: parseInt(hx.slice(3, 5), 16), b: parseInt(hx.slice(5, 7), 16), a: sr.value.a !== undefined ? sr.value.a : 255 })
                    else if (sr.k === "vector") root.setPending(sr.r, PL.hexToVec(hx))
                    else root.setPending(sr.r, PL.vecToIni(PL.hexToVec(hx))) } } } }
    }
}
