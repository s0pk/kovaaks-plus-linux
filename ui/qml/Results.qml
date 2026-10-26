import QtQuick
import QtQuick.Layouts
import QtQuick.Controls
import QtMultimedia
import Kplus
import "js/Fmt.js" as Fmt
import "js/BenchCalc.js" as BC
import "js/ChartMath.js" as CM

// The post-run results screen, with a celebration for a new personal best.
Rectangle {
    id: root
    property var d: null                       // the run.completed payload
    readonly property var r: d.run
    readonly property bool pb: !!d.isPb && !d.isFirst
    readonly property bool celebrate: pb && Store.config.celebratePB !== false
    readonly property var sc: Store.scenario(r.scenario) || { name: r.scenario, tags: [] }
    readonly property var prev: d.previousBest
    readonly property bool hasPrev: prev !== null && prev !== undefined
    readonly property real delta: hasPrev ? r.score - prev : 0
    readonly property color heroColor: pb ? Theme.gold : Theme.accent
    readonly property string afterRun: Store.config.afterRun || "restart"
    readonly property var nextName: Store.nextInQueue(r.scenario)
    readonly property bool spaceIsNext: afterRun === "next" && !!nextName
    property var thr: []
    property var chosenBench: null
    property var position: undefined           // undefined = loading, null = no leaderboard
    property real shownScore: hasPrev && pb ? prev : 0
    readonly property var hist: d.history || []

    color: Theme.bg
    focus: true
    z: 50

    function shortName(n) { var x = Store.scenario(n); var t = (x && x.customName) || n; return t.length > 26 ? t.slice(0, 25) + "…" : t }
    function close() { Store.results = null }
    function spaceAction() {
        close()
        if (spaceIsNext) Store.play(nextName, null)
        else if (afterRun === "focus") Backend.send("game.focus", { resuming: false })
        else Backend.send("game.focus", { action: "restart" })
    }
    function playNext() { close(); Store.play(nextName, null) }

    Keys.onPressed: function (e) {
        if (Modals.host && Modals.host.visible) return
        if (e.key === Qt.Key_Escape) { close(); e.accepted = true }
        else if (e.key === Qt.Key_Space || e.key === Qt.Key_Return || e.key === Qt.Key_Enter) { spaceAction(); e.accepted = true }
        else if (e.key === Qt.Key_N && nextName) { playNext(); e.accepted = true }
    }

    Component.onCompleted: {
        forceActiveFocus()
        console.info("results shown pb=" + pb + " isPb=" + d.isPb + " prev=" + prev + " score=" + r.score)
        count.start()
        if (celebrate) { confetti.start(); if (Store.config.sounds !== false) chime.play() }
        Backend.call("bench.thresholds", { name: r.scenario }, function (list) {
            root.thr = list
            var p = (Store.config.ui && Store.config.ui.chartThresholds) || "auto"
            root.chosenBench = p === "off" || !list.length ? null : (list.filter(function (b) { return b.id === p })[0] || list[0])
        }, function () {})
        Backend.call("lb.position", { name: r.scenario, score: r.score }, function (p) { root.position = p }, function () { root.position = null })
    }
    SoundEffect { id: chime; source: Theme.assets + "pb-chime.wav"; volume: 0.6 }
    NumberAnimation { id: count; target: root; property: "shownScore"; to: root.r.score; duration: root.pb ? 1400 : 700; easing.type: Easing.OutCubic }

    // pb wash
    Rectangle { visible: root.pb; anchors.fill: parent
                gradient: Gradient { GradientStop { position: 0; color: Theme.alpha(Theme.gold, 0.12) } GradientStop { position: 0.45; color: "transparent" } } }

    Flickable {
        id: flick
        anchors.fill: parent
        contentWidth: width; contentHeight: col.implicitHeight + 70
        boundsBehavior: Flickable.StopAtBounds; clip: true
        ScrollBar.vertical: ThinScroll {}
        ColumnLayout {
            id: col
            x: Math.max(24, (flick.width - Math.min(1120, flick.width - 48)) / 2); y: 28
            width: Math.min(1120, flick.width - 48)
            spacing: 22

            // ---- top ----
            RowLayout {
                Layout.fillWidth: true; spacing: 18
                Thumb {
                    Layout.preferredWidth: 128; name: root.r.scenario; media: root.d.thumbnail || ""; label: false
                    tagColor: Store.primaryTagColor(root.sc); info: Store.artInfo(root.sc); tagMedia: root.d.thumbnail ? [] : Store.tagThumbs(root.sc)
                }
                ColumnLayout { Layout.fillWidth: true; spacing: 4
                    Txt { text: root.d.displayName; display: true; w: 700; font.pixelSize: 40; lineHeight: 0.92; Layout.fillWidth: true; elide: Text.ElideRight }
                    Txt { text: root.r.mode + " · " + Fmt.fmtDateTime(root.r.date); color: Theme.muted; font.pixelSize: 13 } }
                Btn { kind: "ghost"; icon: "library"; text: "Scenario details"; onClicked: { var n = root.r.scenario; root.close(); Store.openScenario(n) } }
                Btn { kind: "ghost"; icon: "x"; tip: "Close (Esc)"; onClicked: root.close() }
            }

            // ---- hero ----
            ColumnLayout {
                Layout.fillWidth: true; spacing: 8
                Rectangle {
                    visible: root.pb; Layout.alignment: Qt.AlignHCenter; implicitWidth: pbRow.implicitWidth + 36; implicitHeight: 32; radius: Theme.radiusSm
                    color: Theme.alpha(Theme.gold, 0.16); border.width: 1; border.color: Theme.alpha(Theme.gold, 0.5)
                    Row { id: pbRow; anchors.centerIn: parent; spacing: 10
                        Icon { name: "trophy"; size: 15; color: Theme.gold; anchors.verticalCenter: parent.verticalCenter }
                        Txt { text: "New personal best"; w: 700; color: Theme.gold; anchors.verticalCenter: parent.verticalCenter }
                        Icon { name: "trophy"; size: 15; color: Theme.gold; anchors.verticalCenter: parent.verticalCenter } }
                }
                Txt { Layout.fillWidth: true; horizontalAlignment: Text.AlignHCenter; text: Fmt.fmtScore(root.shownScore); display: true; w: 800; font.pixelSize: 120; lineHeight: 0.9; color: root.pb ? Theme.gold : Theme.text }
                Txt {
                    Layout.fillWidth: true; horizontalAlignment: Text.AlignHCenter; font.pixelSize: 15
                    color: root.d.isFirst || !root.hasPrev ? Theme.muted : (root.delta >= 0 ? Theme.good : Theme.bad)
                    text: root.d.isFirst ? "First recorded run — this is your baseline"
                        : root.pb ? "+" + Fmt.fmtScore(root.delta) + " over your previous best (" + Fmt.fmtScore(root.prev) + ")"
                        : root.hasPrev ? (root.delta >= 0 ? "+" : "") + Fmt.fmtScore(root.delta) + " vs PB " + Fmt.fmtScore(root.prev) + " · " + (root.r.score / root.prev * 100).toFixed(1) + "% of your best" : ""
                }
                // benchmark rank
                Loader {
                    Layout.alignment: Qt.AlignHCenter; Layout.topMargin: 10
                    active: !!(root.d.rank && root.d.rank.ranks && root.d.rank.ranks.length)
                    sourceComponent: ColumnLayout {
                        id: rk
                        readonly property var rank: root.d.rank
                        readonly property var after: rank.ranks[rank.rankAfter] || rank.ranks[0]
                        readonly property color rc: Fmt.rankColor(after, rank.rankAfter)
                        readonly property real next: rank.rankMaxes[rank.rankAfter] || 0
                        readonly property real lower: rank.rankAfter > 0 ? rank.rankMaxes[rank.rankAfter - 1] : 0
                        readonly property real best: Math.max(root.r.score, root.prev || 0)
                        readonly property real prog: next ? Math.max(0, Math.min(1, (best - lower) / (next - lower))) : 1
                        spacing: 10
                        RankPill { Layout.alignment: Qt.AlignHCenter; compact: false; implicitHeight: rk.rank.rankAfter > rk.rank.rankBefore ? 46 : 28
                                   text: (rk.rank.rankAfter > rk.rank.rankBefore ? "Rank up · " : "") + rk.after.name; rc: rk.rc; iconSource: BC.evxlRankIcon(rk.rank.benchmark, rk.after.name) || "" }
                        Txt { Layout.alignment: Qt.AlignHCenter; font.pixelSize: 13; color: Theme.muted; text: (rk.rank.benchmark || "Benchmark") + (rk.rank.difficulty ? " " + rk.rank.difficulty : "") + " · " + (rk.rank.category || "") }
                        ColumnLayout { visible: rk.next > 0; Layout.alignment: Qt.AlignHCenter; Layout.preferredWidth: 340; spacing: 4
                            Progress { Layout.fillWidth: true; value: rk.prog; fill: rk.rc }
                            RowLayout { Layout.fillWidth: true
                                Txt { text: Fmt.fmtScore(rk.lower); font.pixelSize: 11; color: Theme.muted; Layout.fillWidth: true }
                                Txt { text: Fmt.fmtScore(rk.next - rk.best) + " to " + ((rk.rank.ranks[rk.rank.rankAfter + 1] || {}).name || "next rank"); font.pixelSize: 11; color: Theme.muted }
                                Txt { text: Fmt.fmtScore(rk.next); font.pixelSize: 11; color: Theme.muted; Layout.fillWidth: true; horizontalAlignment: Text.AlignRight } } }
                        Txt { visible: rk.next <= 0; Layout.alignment: Qt.AlignHCenter; font.pixelSize: 13; color: Theme.good; text: "Top rank reached" }
                    }
                }
            }

            // ---- actions ----
            Flow {
                Layout.alignment: Qt.AlignHCenter; Layout.maximumWidth: parent.width; spacing: 10
                Btn { large: true; kind: "primary"; icon: root.spaceIsNext ? "play" : root.afterRun === "focus" ? "target" : "refresh"
                      text: (root.spaceIsNext ? "Next: " + root.shortName(root.nextName) : root.afterRun === "focus" ? "Back to KovaaK's" : "Restart run") + "   Space"; onClicked: root.spaceAction() }
                Btn { visible: !!root.nextName && root.afterRun !== "next"; large: true; icon: "arrowLeft"; iconFlip: true; text: "Next: " + (root.nextName ? root.shortName(root.nextName) : "") + "   N"; onClicked: root.playNext() }
                Btn { visible: root.afterRun !== "focus"; large: true; icon: "target"; text: "Back to KovaaK's"; onClicked: { root.close(); Backend.send("game.focus", { resuming: false }) } }
                Btn { large: true; kind: "ghost"; text: "Choose another"; onClicked: { root.close(); Store.go("library") } }
            }

            // ---- tiles ----
            GridLayout {
                Layout.fillWidth: true; columns: 4; rowSpacing: 14; columnSpacing: 28
                Repeater {
                    model: [["Accuracy", Fmt.fmtPct(root.r.accuracy)], ["Kills", String(root.r.kills)], ["Avg TTK", root.r.avgTtk ? root.r.avgTtk.toFixed(3) + "s" : "—"],
                            ["Hits / Shots", root.r.hits + "/" + root.r.shots], ["Sensitivity", root.r.sens ? (+root.r.sens.toFixed(2)) + " " + (root.r.sensScale || "") : "—"],
                            ["FOV", root.r.fov ? String(root.r.fov) : "—"], ["Avg FPS", root.r.avgFps ? String(Math.round(root.r.avgFps)) : "—"], ["Pauses", String(root.r.pauseCount || 0)]]
                    delegate: StatTile { required property var modelData; Layout.fillWidth: true; Layout.preferredWidth: 1; label: modelData[0]; value: modelData[1] }
                }
            }

            // ---- this run ----
            Card {
                id: runCard
                Layout.fillWidth: true; pad: 18; visible: rd.detail && (rd.detail.kills || []).length > 0
                Layout.preferredHeight: visible ? rd.implicitHeight + 70 : 0
                ColumnLayout { width: parent.width; spacing: 10
                    RowLayout { spacing: 8; Icon { name: "chart"; size: 16; color: Theme.muted } Txt { text: "This run"; display: true; w: 600; font.pixelSize: 20 } }
                    RunDetail { id: rd; Layout.fillWidth: true; file: root.r.file; showSummary: false; color: root.heroColor } }
            }

            // ---- history ----
            Card {
                visible: root.hist.length > 1
                Layout.fillWidth: true; pad: 18; Layout.preferredHeight: visible ? hc.implicitHeight + 36 : 0
                ColumnLayout { id: hc; width: parent.width; spacing: 10
                    RowLayout { Layout.fillWidth: true; spacing: 10
                        Txt { text: "Recent history"; display: true; w: 600; font.pixelSize: 20 }
                        Item { Layout.fillWidth: true }
                        Select { visible: root.thr.length > 0; implicitWidth: 220; implicitHeight: 26
                                 options: [{ value: "off", label: "No rank lines" }].concat(root.thr.map(function (b) { return { value: b.id, label: b.name + (b.difficulty ? " · " + b.difficulty : "") } }))
                                 value: root.chosenBench ? root.chosenBench.id : "off"
                                 onPicked: function (v) { root.chosenBench = v === "off" ? null : root.thr.filter(function (b) { return b.id === v })[0] } }
                        Txt { text: "click a point for details"; font.pixelSize: 12; color: Theme.muted } }
                    LineChart {
                        id: hchart
                        Layout.fillWidth: true; chartHeight: 220
                        readonly property var overlay: CM.thresholdOverlay(root.chosenBench, root.hist.map(function (x) { return x.score }), BC.rankEntry, Fmt.rankColor)
                        readonly property real best: Math.max.apply(null, root.hist.map(function (x) { return x.score }))
                        series: [{ points: root.hist.map(function (x, i) { return { x: i, y: x.score, pb: x.pb && i > 0, file: x.file, tip: "<b>" + Fmt.fmtScore(x.score) + "</b> · " + Fmt.fmtPct(x.accuracy) + "<br>" + Fmt.fmtDateTime(x.date) } }), color: root.heroColor.toString(), area: true, dots: true }]
                        hLines: overlay.hLines.concat([{ y: best, label: "PB " + Fmt.fmtScore(best) }])
                        bands: overlay.bands
                        onPointClicked: function (p) { if (p.file) Modals.runDetail(p.file, root.d.displayName) }
                    }
                }
            }

            // ---- leaderboard ----
            Card {
                Layout.fillWidth: true; pad: 18; Layout.preferredHeight: lc.implicitHeight + 36
                ColumnLayout { id: lc; width: parent.width; spacing: 12
                    RowLayout { spacing: 8; Icon { name: "medal"; size: 16; color: Theme.muted } Txt { text: "Leaderboard"; display: true; w: 600; font.pixelSize: 20 } }
                    RowLayout { spacing: 10; visible: root.position === undefined; Spinner {} Txt { text: "Checking global position…"; color: Theme.muted; font.pixelSize: 13 } }
                    Txt { visible: root.position === null; text: "This scenario has no online leaderboard."; color: Theme.muted; font.pixelSize: 13 }
                    RowLayout { visible: !!root.position; spacing: 10
                        Icon { name: "medal"; size: 16; color: Theme.gold }
                        Txt { textFormat: Text.StyledText; font.pixelSize: 15
                              text: root.position ? "This run would place <b>#" + root.position.position.toLocaleString() + "</b> <font color='" + Theme.muted + "'>of " + root.position.total.toLocaleString()
                                    + " · top " + (function (p) { return p < 1 ? p.toFixed(2) : p.toFixed(1) })(root.position.position / Math.max(1, root.position.total) * 100) + "%</font>" : "" }
                        Txt { text: "KovaaK's may take a moment to show it on the official board."; font.pixelSize: 12; color: Theme.muted } }
                    ScenarioLeaderboard {
                        Layout.fillWidth: true; name: root.r.scenario; compact: true; maxRows: 10
                        scope: Store.config.steamId ? "friends" : "global"
                        rankMaxes: root.d.rank ? root.d.rank.rankMaxes : null; ranks: root.d.rank ? root.d.rank.ranks : []
                    }
                }
            }
        }
    }

    // ---- confetti ----
    Canvas {
        id: cv
        anchors.fill: parent; visible: confetti.running; z: 5
        property var parts: []
        onPaint: {
            var ctx = getContext("2d"); ctx.clearRect(0, 0, width, height)
            var t = confetti.t
            for (var i = 0; i < parts.length; i++) {
                var p = parts[i]
                ctx.save(); ctx.globalAlpha = Math.max(0, p.life); ctx.translate(p.x, p.y); ctx.rotate(p.r)
                ctx.fillStyle = p.c; ctx.fillRect(-p.w / 2, -p.h / 2, p.w, p.h * Math.abs(Math.cos(p.r * 2))); ctx.restore()
            }
        }
    }
    QtObject {
        id: confetti
        property bool running: false
        property real t: 0
        property real t0: 0
        readonly property var colors: ["#fbbf24", "#fde68a", "#f59e0b", Theme.accent.toString(), "#22d3ee", "#ffffff", "#f472b6"]
        function burst(x, y, n, spread, dir, speed) {
            for (var i = 0; i < n; i++) {
                var a = dir + (Math.random() - 0.5) * spread, v = (7 + Math.random() * 12) * speed
                cv.parts.push({ x: x, y: y, vx: Math.cos(a) * v, vy: Math.sin(a) * v, w: 6 + Math.random() * 8, h: 3 + Math.random() * 5, r: Math.random() * 6, vr: (Math.random() - 0.5) * 0.3, sway: Math.random() * 6, c: colors[Math.floor(Math.random() * colors.length)], life: 1 })
            }
        }
        function rain() {
            for (var i = 0; i < 18; i++) cv.parts.push({ x: Math.random() * cv.width, y: -20, vx: (Math.random() - 0.5) * 2, vy: 1 + Math.random() * 2, w: 6 + Math.random() * 8, h: 3 + Math.random() * 5, r: Math.random() * 6, vr: (Math.random() - 0.5) * 0.3, sway: Math.random() * 6, c: colors[Math.floor(Math.random() * colors.length)], life: 1 })
        }
        function start() {
            running = true; t0 = Date.now(); cv.parts = []
            burst(cv.width * 0.5, cv.height * 0.38, 160, Math.PI * 1.7, -Math.PI / 2, 1)
            side.start(); rainT.start(); tick.start()
        }
        property Timer side: Timer { id: side; interval: 220; onTriggered: { confetti.burst(0, cv.height * 0.75, 80, 0.5, -Math.PI / 3, 1.3); confetti.burst(cv.width, cv.height * 0.75, 80, 0.5, -Math.PI * 2 / 3, 1.3) } }
        property Timer rainT: Timer { id: rainT; interval: 400; repeat: true; property int n: 0; onTriggered: { confetti.rain(); if (++n >= 6) stop() } }
        property Timer tick: Timer {
            id: tick; interval: 16; repeat: true
            onTriggered: {
                var now = Date.now() - confetti.t0; confetti.t = now
                var keep = []
                for (var i = 0; i < cv.parts.length; i++) {
                    var p = cv.parts[i]
                    p.vy += 0.16; p.vx *= 0.975; p.vy *= 0.975
                    p.x += p.vx + Math.sin(now / 260 + p.sway) * 0.6; p.y += p.vy; p.r += p.vr
                    if (now > 3800) p.life -= 0.01
                    if (p.life > 0 && p.y < cv.height + 40) keep.push(p)
                }
                cv.parts = keep
                cv.requestPaint()
                if (now > 6500 || !keep.length && now > 1500) { confetti.running = false; tick.stop() }
            }
        }
    }
}
