import QtQuick
import QtQuick.Layouts
import Kplus
import "js/Fmt.js" as Fmt
import "js/BenchCalc.js" as BC

// What score do I need? For a target score, a rank (from a benchmark that includes the scenario) or a leaderboard spot.
ColumnLayout {
    id: root
    property string name: ""
    property real pb: 0
    property var benchmarks: []          // [{id, name, difficulty}]
    property string mode: "score"
    property var bench: null             // {b, s}
    property var rankOptions: []
    property int rankPick: 1
    property int benchId: benchmarks.length ? benchmarks[0].id : 0
    property var lines: []
    property var tiles: []
    property string posEst: "…"
    property string message: ""
    property bool busy: false
    spacing: 10

    function loadBench(then) {
        if (!benchId) { bench = null; return }
        Backend.call("evxl.benchmark", { id: benchId }, function (b) {
            var s = null
            b.categories.forEach(function (c) { c.scenarios.forEach(function (x) { if (x.name.toLowerCase() === root.name.toLowerCase()) s = x }) })
            root.bench = s ? { b: b, s: s } : null
            if (s) {
                root.rankOptions = s.rankMaxes.map(function (t, i) { return { value: i + 1, label: BC.rankEntry(i + 1, b).name + " (" + Fmt.fmtScore(t) + ")" } })
                root.rankPick = Math.min(s.rankMaxes.length, BC.rankOf(root.pb, s.rankMaxes).baseRank + 1)
            } else root.rankOptions = []
            if (then) then()
        }, function () { root.bench = null })
    }
    Component.onCompleted: { scoreIn.text = pb ? String(Math.round(pb * 1.05)) : ""; if (benchmarks.length) loadBench() }

    function run() {
        message = ""; lines = []; tiles = []
        var need = null
        if (mode === "score") need = parseFloat(scoreIn.text)
        else if (mode === "rank") {
            if (!bench) { message = "No thresholds for this scenario."; return }
            need = bench.s.rankMaxes[rankPick - 1]
        } else {
            var pos = parseInt(posIn.text, 10), top = parseFloat(topIn.text)
            if (!pos && !top) { Store.toast("Enter a position or a top %"); return }
            busy = true
            Backend.call("lb.scoreAt", { name: name, position: pos || 0, percent: pos ? null : top }, function (res) {
                busy = false
                if (!res || res.score === null || res.score === undefined) { message = "Couldn't read that leaderboard position."; return }
                var n2 = Math.round((res.score + 0.01) * 100) / 100
                finish(n2, ["#" + Number(res.position).toLocaleString() + " of " + Number(res.total).toLocaleString() + " currently has " + Fmt.fmtScore(res.score) + " (" + res.name + ")."])
            }, function () { busy = false; message = "Couldn't read that leaderboard position." })
            return
        }
        if (!need || isNaN(need)) { Store.toast("Enter a score"); return }
        finish(need, [])
    }

    function finish(need, extra) {
        lines = extra
        var diff = need - pb
        var rk = null
        if (bench) {
            var r = BC.rankOf(need, bench.s.rankMaxes).baseRank
            var e = BC.rankEntry(r, bench.b)
            rk = { name: e.name, color: Fmt.rankColor(e, r) }
        }
        var t = [{ k: "Target score", v: Fmt.fmtScore(need) },
                 { k: "Vs your PB", v: pb ? (diff <= 0 ? "Already beaten" : "+" + Fmt.fmtScore(diff) + " (" + (diff / pb * 100).toFixed(1) + "%)") : "No PB yet" }]
        if (rk) t.push({ k: "Rank", v: rk.name, color: rk.color })
        t.push({ k: "Leaderboard", v: "…", est: true })
        tiles = t
        Backend.call("lb.position", { name: name, score: need }, function (p) {
            root.posEst = p ? "#" + Number(p.position).toLocaleString() + " (top " + (p.position / p.total * 100).toFixed(p.position / p.total < 0.01 ? 2 : 1) + "%)" : "no online board"
        }, function () { root.posEst = "—" })
    }

    RowLayout {
        Layout.fillWidth: true; spacing: 8
        Seg {
            options: root.benchmarks.length ? [{ value: "score", label: "Score" }, { value: "rank", label: "Rank" }, { value: "lb", label: "Leaderboard" }] : [{ value: "score", label: "Score" }, { value: "lb", label: "Leaderboard" }]
            value: root.mode
            onPicked: function (v) { root.mode = v; root.tiles = []; root.message = ""; if (v === "rank") root.run() }
        }
        Field { id: scoreIn; visible: root.mode === "score"; implicitWidth: 120; placeholder: "Score"; inputMethodHints: Qt.ImhFormattedNumbersOnly; onAccepted: root.run() }
        Select { visible: root.mode === "rank" && root.benchmarks.length > 1; implicitWidth: 220
                 options: root.benchmarks.map(function (b) { return { value: b.id, label: (b.name || "Benchmark") + (b.difficulty ? " · " + b.difficulty : "") } })
                 value: root.benchId; onPicked: function (v) { root.benchId = v; root.loadBench(function () { root.run() }) } }
        Select { visible: root.mode === "rank"; implicitWidth: 180; options: root.rankOptions; value: root.rankPick; onPicked: function (v) { root.rankPick = v; root.run() } }
        RowLayout {
            visible: root.mode === "lb"; spacing: 8
            Field { id: posIn; implicitWidth: 110; placeholder: "#1000"; inputMethodHints: Qt.ImhDigitsOnly; onAccepted: root.run() }
            Txt { text: "or"; color: Theme.muted; font.pixelSize: 12 }
            Field { id: topIn; implicitWidth: 90; placeholder: "top %"; inputMethodHints: Qt.ImhFormattedNumbersOnly; onAccepted: root.run() }
        }
        Btn { visible: root.mode !== "rank"; kind: "primary"; small: true; text: "Calculate"; onClicked: root.run() }
        Item { Layout.fillWidth: true }
    }
    RowLayout { visible: root.busy; spacing: 10; Spinner {} Txt { text: "Checking the leaderboard…"; color: Theme.muted; font.pixelSize: 12 } }
    Txt { visible: root.message !== ""; text: root.message; color: Theme.muted; font.pixelSize: 12 }
    Repeater { model: root.lines; delegate: Txt { required property string modelData; text: modelData; color: Theme.muted; font.pixelSize: 12; Layout.fillWidth: true; wrapMode: Text.WordWrap } }
    GridLayout {
        visible: root.tiles.length > 0
        Layout.fillWidth: true; columns: Math.max(1, Math.min(root.tiles.length, Math.floor(width / 150))); rowSpacing: 10; columnSpacing: 10
        Repeater {
            model: root.tiles
            delegate: Rectangle {
                required property var modelData
                Layout.fillWidth: true; Layout.preferredHeight: 60
                color: Theme.bg2; border.width: 1; border.color: Theme.border; radius: Theme.radiusSm
                Column { x: 12; y: 10; spacing: 2
                    Txt { text: modelData.k; font.pixelSize: 12; color: Theme.muted }
                    Txt { text: modelData.est ? root.posEst : modelData.v; display: true; w: 700; font.pixelSize: 20; color: modelData.color ? modelData.color : Theme.text }
                }
            }
        }
    }
}
