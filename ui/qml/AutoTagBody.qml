import QtQuick
import QtQuick.Layouts
import QtQuick.Controls
import Kplus

// Auto-tag wizard: pick sources → review proposals (reuse an existing tag or create a new one) → apply.
Item {
    id: root
    property var dialog
    property var scopes: ({})
    property string step: "setup"          // setup | scan | review
    property string scope: "all"
    property var sources: ({ skills: true, gametag: true })
    property int minCount: 3
    property var cands: []
    property var dec: ({})                 // candidate key -> {action: "use"|"create"|"skip"|"", tagId, name, group, color}
    implicitHeight: col.implicitHeight

    readonly property var sourceLabel: ({ skills: "Aim type", gametag: "In-game tag", difficulty: "Difficulty", benchmark: "Benchmark" })
    readonly property var colors: ["#f97316", "#22d3ee", "#a3e635", "#e879f9", "#38bdf8", "#facc15", "#f472b6", "#2dd4bf", "#818cf8", "#fb7185"]
    readonly property int pending: cands.filter(function (c) { return !dec[c.key].action }).length
    readonly property int nUse: cands.filter(function (c) { return dec[c.key].action === "use" }).length
    readonly property int nCreate: cands.filter(function (c) { return dec[c.key].action === "create" }).length

    Component.onCompleted: scope = scopes.selected && scopes.selected.length ? "selected" : "all"
    function tagById(id) { for (var i = 0; i < Store.tags.length; i++) if (Store.tags[i].id === id) return Store.tags[i]; return null }
    function setDec(key, patch) { var m = {}; for (var k in dec) m[k] = dec[k]; var d = {}; for (var p in m[key]) d[p] = m[key][p]; for (var q in patch) d[q] = patch[q]; m[key] = d; dec = m }
    function setAll(fn) { var m = {}; cands.forEach(function (c) { var d = dec[c.key], n = fn(c, d); m[c.key] = n || d }); dec = m }
    function toggleSource(k) { var s = {}; for (var x in sources) s[x] = sources[x]; if (s[k]) delete s[k]; else s[k] = true; sources = s }

    function scan() {
        var src = Object.keys(sources)
        if (!src.length) { Store.toast("Pick at least one source"); return }
        step = "scan"
        var names = scope === "selected" ? scopes.selected : scope === "filtered" ? scopes.filtered : null
        Backend.call("library.autoTagScan", { names: names, sources: src, minCount: minCount }, function (c) {
            cands = c
            var m = {}
            // exact matches reuse the tag; similar ones must be decided; new aim types are created; unmatched in-game tags start unchecked
            c.forEach(function (x, i) {
                m[x.key] = { action: x.matchKind === "exact" ? "use" : x.matchKind ? "" : (x.source === "skills" || x.source === "benchmark" ? "create" : "skip"),
                             tagId: x.matchTagId, name: x.name, group: x.group, color: colors[i % colors.length] }
            })
            dec = m
            step = "review"
        }, function (e) { Store.toast(e, "error"); step = "setup" })
    }
    function apply() {
        var items = []
        cands.forEach(function (c) {
            var d = dec[c.key]
            if (d.action === "use") items.push({ names: c.names, tagId: d.tagId })
            else if (d.action === "create") items.push({ names: c.names, create: { name: d.name, group: d.group, color: d.color } })
        })
        if (!items.length) { Store.toast("Nothing to apply"); return }
        Backend.call("library.autoTagApply", { items: items }, function (r) {
            Store.loadLibrary()
            Store.toast("Tagged: " + r.assigned + " tag assignments, " + r.created + " new tag" + (r.created === 1 ? "" : "s"), "ok")
            root.dialog.close(null)
        }, function (e) { Store.toast(e, "error") })
    }
    component Check: Rectangle {
        property bool on: false
        width: 18; height: 18; radius: 3; color: on ? Theme.accent : "transparent"; border.width: 1; border.color: on ? Theme.accent : Theme.border2
        Icon { visible: parent.on; anchors.centerIn: parent; name: "check"; size: 12; color: Theme.onAccent }
    }

    ColumnLayout {
        id: col; width: parent.width; spacing: 14

        // ---------------- setup ----------------
        ColumnLayout {
            visible: root.step === "setup"; Layout.fillWidth: true; spacing: 14
            Txt { Layout.fillWidth: true; wrapMode: Text.WordWrap; color: Theme.text2
                  text: "Kovaak's Plus proposes tags from the sources below. You review every proposal first: where a similar tag already exists, you choose whether to use it or create a new one." }
            Txt { text: "Which scenarios"; w: 700; color: Theme.text2; font.pixelSize: 13 }
            Flow { Layout.fillWidth: true; spacing: 8
                Btn { small: true; kind: root.scope === "all" ? "primary" : ""; text: "All scenarios"; onClicked: root.scope = "all" }
                Btn { visible: !!root.scopes.filtered; small: true; kind: root.scope === "filtered" ? "primary" : ""; text: "Currently shown (" + (root.scopes.filtered ? root.scopes.filtered.length : 0) + ")"; onClicked: root.scope = "filtered" }
                Btn { visible: !!(root.scopes.selected && root.scopes.selected.length); small: true; kind: root.scope === "selected" ? "primary" : ""; text: "Selected (" + (root.scopes.selected ? root.scopes.selected.length : 0) + ")"; onClicked: root.scope = "selected" } }
            Txt { text: "Sources"; w: 700; color: Theme.text2; font.pixelSize: 13; Layout.topMargin: 4 }
            Repeater {
                model: [["skills", "Aim type (evxl.app classification)", "Dynamic Clicking, Reactive Tracking, Speed Switching… for ~2,000 popular scenarios"],
                        ["gametag", "In-game scenario tags", "The tags authors put in the scenario file (e.g. \"Flick\", \"Overwatch\", \"Track\"). Synonyms like Track/Tracking or OW/Overwatch are merged"],
                        ["difficulty", "In-game difficulty (1–5)", "Suggests your Easy / Medium / Hard / Extreme tags"],
                        ["benchmark", "Benchmark scenarios", "Adds \"Benchmark\" to scenarios that appear in any benchmark"]]
                delegate: Rectangle {
                    required property var modelData
                    Layout.fillWidth: true; implicitHeight: sr.implicitHeight + 18; radius: Theme.radiusSm; color: sa.containsMouse ? Theme.surface2 : "transparent"
                    RowLayout { id: sr; anchors.fill: parent; anchors.margins: 9; spacing: 12
                        Check { on: !!root.sources[modelData[0]]; Layout.alignment: Qt.AlignTop }
                        ColumnLayout { Layout.fillWidth: true; spacing: 1
                            Txt { text: modelData[1]; w: 600; Layout.fillWidth: true }
                            Txt { text: modelData[2]; font.pixelSize: 12; color: Theme.muted; Layout.fillWidth: true; wrapMode: Text.WordWrap } } }
                    MouseArea { id: sa; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onClicked: root.toggleSource(modelData[0]) }
                }
            }
            RowLayout { spacing: 10
                Txt { text: "Ignore in-game tags used by fewer than"; w: 700; font.pixelSize: 13; color: Theme.text2 }
                Field { implicitWidth: 70; text: String(root.minCount); onEdited: function (t) { root.minCount = Math.max(1, parseInt(t, 10) || 1) } }
                Txt { text: "scenarios"; font.pixelSize: 13; color: Theme.muted } }
            RowLayout { Layout.fillWidth: true; Layout.topMargin: 6
                Item { Layout.fillWidth: true }
                Btn { kind: "ghost"; text: "Cancel"; onClicked: root.dialog.close(null) }
                Btn { kind: "primary"; icon: "search"; text: "Find tags"; onClicked: root.scan() } }
        }

        // ---------------- scanning ----------------
        RowLayout { visible: root.step === "scan"; spacing: 12; Spinner {} Txt { text: "Scanning scenarios…"; color: Theme.muted } }

        // ---------------- review ----------------
        ColumnLayout {
            visible: root.step === "review"; Layout.fillWidth: true; spacing: 12
            Txt { visible: root.cands.length > 0; Layout.fillWidth: true; wrapMode: Text.WordWrap; font.pixelSize: 13; color: Theme.muted
                  text: "Highlighted rows matched a tag you already have. Choose whether to use it or create a new tag." }
            Txt { visible: root.cands.length === 0; Layout.fillWidth: true; horizontalAlignment: Text.AlignHCenter; topPadding: 20; bottomPadding: 20; color: Theme.muted
                  text: "No tag proposals for these scenarios. Try more sources or a lower minimum." }
            Flow { visible: root.cands.length > 0; Layout.fillWidth: true; spacing: 8
                Btn { small: true; text: "Use suggested tag for all similar"; onClicked: root.setAll(function (c, d) { return !d.action && d.tagId ? { action: "use", tagId: d.tagId, name: d.name, group: d.group, color: d.color } : null }) }
                Btn { small: true; text: "Create new for all undecided"; onClicked: root.setAll(function (c, d) { return !d.action ? { action: "create", tagId: d.tagId, name: d.name, group: d.group, color: d.color } : null }) }
                Btn { small: true; kind: "ghost"; text: "Skip undecided"; onClicked: root.setAll(function (c, d) { return !d.action ? { action: "skip", tagId: d.tagId, name: d.name, group: d.group, color: d.color } : null }) } }
            Rectangle {
                visible: root.cands.length > 0; Layout.fillWidth: true; Layout.preferredHeight: Math.min(380, root.cands.length * 52 + 2)
                radius: Theme.radiusSm; color: Theme.bg2; border.width: 1; border.color: Theme.border; clip: true
                ListView {
                    anchors.fill: parent; anchors.margins: 1; model: root.cands; clip: true; boundsBehavior: Flickable.StopAtBounds; ScrollBar.vertical: ThinScroll {}
                    delegate: Rectangle {
                        id: row
                        required property var modelData
                        readonly property var c: modelData
                        readonly property var d: root.dec[c.key] || ({ action: "" })
                        readonly property var existing: d.tagId ? root.tagById(d.tagId) : null
                        width: ListView.view.width; height: Math.max(52, rl.implicitHeight + 14)
                        color: !d.action ? Theme.alpha(Theme.gold, 0.08) : "transparent"
                        Rectangle { anchors.bottom: parent.bottom; width: parent.width; height: 1; color: Theme.border }
                        RowLayout {
                            id: rl; anchors.fill: parent; anchors.leftMargin: 12; anchors.rightMargin: 12; spacing: 12
                            Check { on: row.d.action !== "skip"; MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor; onClicked: root.setDec(row.c.key, { action: row.d.action === "skip" ? (row.existing ? "use" : "create") : "skip" }) } }
                            ColumnLayout { Layout.preferredWidth: 200; Layout.maximumWidth: 200; spacing: 0
                                Txt { text: row.c.name; w: 600; elide: Text.ElideRight; Layout.fillWidth: true }
                                Txt { font.pixelSize: 11; color: Theme.muted; elide: Text.ElideRight; Layout.fillWidth: true
                                      text: (root.sourceLabel[row.c.source] || row.c.source) + (row.c.variants && row.c.variants.length > 1 ? " · also " + row.c.variants.filter(function (v) { return v !== row.c.name }).slice(0, 3).join(", ") : "") } }
                            Txt { text: row.c.count + " scenario" + (row.c.count === 1 ? "" : "s"); font.pixelSize: 12; color: Theme.muted; Layout.preferredWidth: 90 }
                            Flow {
                                Layout.fillWidth: true; spacing: 6
                                Row { visible: row.c.matchKind === "exact"; spacing: 6
                                    Txt { text: "Existing tag"; font.pixelSize: 12; color: Theme.muted; anchors.verticalCenter: parent.verticalCenter }
                                    Chip { visible: !!row.existing; small: true; text: row.existing ? row.existing.name : ""; chipColor: row.existing ? row.existing.color : Theme.accent } }
                                Txt { visible: row.c.matchKind !== "exact" && !row.d.action && !!row.existing; font.pixelSize: 12; color: Theme.gold; height: 30; verticalAlignment: Text.AlignVCenter
                                      text: row.c.matchKind === "suggested" ? "Map to" : "Similar to" }
                                Btn { visible: row.c.matchKind !== "exact" && !!row.existing; small: true; selected: row.d.action === "use"; text: "Use " + (row.existing ? row.existing.name : ""); onClicked: root.setDec(row.c.key, { action: "use" }) }
                                Select { visible: row.c.matchKind !== "exact" && !!row.c.similar && row.c.similar.length > 1; implicitWidth: 150; implicitHeight: 30
                                         options: (row.c.similar || []).map(function (id) { var t = root.tagById(id); return { value: id, label: t ? t.name : id } }); value: row.d.tagId
                                         onPicked: function (v) { root.setDec(row.c.key, { tagId: v, action: "use" }) } }
                                Btn { visible: row.c.matchKind !== "exact"; small: true; selected: row.d.action === "create"; text: "Create new"; onClicked: root.setDec(row.c.key, { action: "create" }) }
                                Field { visible: row.c.matchKind !== "exact" && row.d.action === "create"; implicitWidth: 140; implicitHeight: 30; text: row.d.name || ""; onEdited: function (t) { root.setDec(row.c.key, { name: t.trim() || row.c.name }) } }
                                Btn { visible: row.c.matchKind !== "exact"; small: true; kind: "ghost"; selected: row.d.action === "skip"; text: "Skip"; onClicked: root.setDec(row.c.key, { action: "skip" }) }
                            }
                        }
                    }
                }
            }
            RowLayout { Layout.fillWidth: true; spacing: 8
                Txt { Layout.fillWidth: true; font.pixelSize: 12; color: Theme.muted; textFormat: Text.StyledText
                      text: (root.pending ? "<font color='" + Theme.gold + "'>" + root.pending + " need a decision · </font>" : "") + root.nUse + " use existing · " + root.nCreate + " new tags · " + (root.cands.length - root.nUse - root.nCreate - root.pending) + " skipped" }
                Btn { kind: "ghost"; text: "Back"; onClicked: root.step = "setup" }
                Btn { visible: root.cands.length > 0; kind: "primary"; icon: "check"; text: "Apply tags"; enabled: root.pending === 0; onClicked: root.apply() } }
        }
    }
}
