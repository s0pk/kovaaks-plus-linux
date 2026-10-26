import QtQuick
import QtQuick.Layouts
import Kplus
import "js/Fmt.js" as Fmt
import "js/ChartMath.js" as CM

// A run's Kovaak's-style graphs and summary (dialog body; also embedded in the results screen).
ColumnLayout {
    id: root
    property var dialog
    property var detail: null
    property string file: ""
    property bool showSummary: true
    property string which: "score"
    property real chartHeight: 210
    property color color: Theme.accent
    spacing: 16
    implicitHeight: childrenRect.height

    Component.onCompleted: if (file !== "" && !detail) Backend.call("stats.run", { file: file }, function (d) { detail = d }, function (e) { Store.toast(e, "error") })

    readonly property var tl: detail ? CM.runTimeline(detail) : ({ pts: [], end: 0 })
    readonly property var s: detail ? detail.summary : ({})
    readonly property var graphs: [["score", "Score"], ["spm", "Score / min"], ["kills", "Kills"], ["kps", "Kills / sec"], ["acc", "Accuracy"], ["ttk", "TTK"], ["dmg", "Damage"]]

    property var chartSeries: []
    property var chartLines: []
    property var yTickFn: null
    function rebuild() {
        if (!detail) return
        var pts = tl.pts, end = tl.end, col = color
        var series, hl = [], yt = null
        if (which === "score") series = [{ points: pts.map(function (p) { return { x: p.t, y: p.score, tip: "<b>" + Fmt.fmtScore(p.score) + "</b> at " + p.t.toFixed(1) + "s" } }), color: col, area: true, dots: false }]
        else if (which === "spm") {
            var r = CM.rate(pts, "score", 10, 60), avg = end ? pts[pts.length - 1].score / end * 60 : 0
            series = [{ points: r.map(function (p) { return { x: p.x, y: p.y, tip: "<b>" + Fmt.fmtScore(p.y) + "</b> /min at " + p.x.toFixed(1) + "s" } }), color: col, area: true, dots: false }]
            hl = [{ y: avg, label: "avg " + Fmt.fmtScore(avg), color: "#94a3b8" }]
        } else if (which === "kills") series = [{ points: pts.map(function (p) { return { x: p.t, y: p.kills, tip: "<b>" + p.kills + "</b> kills at " + p.t.toFixed(1) + "s" } }), color: col, area: true, dots: false }]
        else if (which === "kps") {
            var r2 = CM.rate(pts, "kills", 5, 1)
            series = [{ points: r2.map(function (p) { return { x: p.x, y: p.y, tip: "<b>" + p.y.toFixed(2) + "</b> kills/s at " + p.x.toFixed(1) + "s" } }), color: col, area: true, dots: false }]
            yt = function (v) { return v.toFixed(1) }
        } else if (which === "acc") {
            series = [{ points: pts.filter(function (p) { return p.acc !== null }).map(function (p) { return { x: p.t, y: p.acc * 100, tip: "<b>" + (p.acc * 100).toFixed(1) + "%</b> at " + p.t.toFixed(1) + "s" } }), color: Theme.accent2.toString(), area: true, dots: false }]
            yt = function (v) { return v.toFixed(0) + "%" }
        } else if (which === "ttk") {
            var k = pts.filter(function (p) { return p.ttk !== null && p.ttk !== undefined })
            var sm = CM.movingAverage(k.map(function (p) { return p.ttk }), 5)
            series = [{ points: k.map(function (p, i) { return { x: p.t, y: p.ttk, tip: "Kill #" + (i + 1) + " · <b>" + p.ttk.toFixed(3) + "s</b>" } }), color: "#64748b", width: 1, dots: false },
                      { points: k.map(function (p, i) { return { x: p.t, y: sm[i] } }), color: col, width: 2.5, dots: false }]
            yt = function (v) { return v.toFixed(2) + "s" }
        } else series = [{ points: pts.map(function (p) { return { x: p.t, y: p.dmg, tip: "<b>" + Fmt.fmtScore(p.dmg) + "</b> damage at " + p.t.toFixed(1) + "s" } }), color: col, area: true, dots: false }]
        chartSeries = series; chartLines = hl; yTickFn = yt
    }
    onDetailChanged: rebuild()
    onWhichChanged: rebuild()
    onColorChanged: rebuild()

    GridLayout {
        visible: root.showSummary && !!root.detail
        Layout.fillWidth: true; columns: 4; rowSpacing: 12; columnSpacing: 12
        Repeater {
            model: root.detail ? [["Score", Fmt.fmtScore(root.s.score)], ["Accuracy", Fmt.fmtPct(root.s.accuracy)], ["Kills", String(root.s.kills)], ["Avg TTK", root.s.avgTtk ? root.s.avgTtk.toFixed(3) + "s" : "—"],
                                  ["Shots", root.s.hits + "/" + root.s.shots], ["Sens", root.s.sens ? (+root.s.sens.toFixed(3)) + " " + (root.s.sensScale || "") : "—"], ["FOV", root.s.fov ? root.s.fov + " " + (root.s.fovScale || "") : "—"], ["Avg FPS", root.s.avgFps ? String(root.s.avgFps) : "—"]] : []
            delegate: Column { required property var modelData; Layout.fillWidth: true; Layout.preferredWidth: 1
                Txt { text: modelData[0]; font.pixelSize: 12; color: Theme.muted }
                Txt { text: modelData[1]; display: true; w: 700; font.pixelSize: 28; elide: Text.ElideRight; width: parent.width } }
        }
    }
    Card {
        Layout.fillWidth: true; Layout.preferredHeight: gcol.implicitHeight + 36; pad: 18
        ColumnLayout {
            id: gcol; width: parent.width; spacing: 10
            Flow {
                Layout.fillWidth: true; spacing: 8
                Seg { options: root.graphs.map(function (g) { return { value: g[0], label: g[1] } }); value: root.which; onPicked: function (v) { root.which = v } }
                Txt { text: root.detail && root.detail.scoring ? "Score over time is rebuilt from the scenario's scoring rules" : "Score over time is estimated from kills"; font.pixelSize: 12; color: Theme.muted; anchors.verticalCenter: undefined }
            }
            Txt { visible: !!root.detail && (root.detail.kills || []).length === 0; text: "This run file has no per-kill data."; color: Theme.muted; font.pixelSize: 12 }
            LineChart {
                visible: !!root.detail && (root.detail.kills || []).length > 0
                Layout.fillWidth: true; chartHeight: root.chartHeight
                series: root.chartSeries; hLines: root.chartLines; yTick: root.yTickFn
                xLabels: function (x) { return x.toFixed(0) + "s" }
            }
        }
    }
}
