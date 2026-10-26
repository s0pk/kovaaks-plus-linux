import QtQuick
import Kplus
import QtQuick.Layouts
import "js/Fmt.js" as Fmt

PageScroll {
    id: page
    property var overview: null
    property var bench: null
    property string benchError: ""

    readonly property string greeting: {
        var hr = new Date().getHours()
        return hr < 5 ? "Late night grind" : hr < 12 ? "Good morning" : hr < 18 ? "Good afternoon" : "Good evening"
    }

    function dayKey(d) {
        var p = function (n) { return n < 10 ? "0" + n : "" + n }
        return d.getFullYear() + "-" + p(d.getMonth() + 1) + "-" + p(d.getDate())
    }
    function lastWeek(daily) {
        var cutoff = new Date(); cutoff.setDate(cutoff.getDate() - 6)
        var key = dayKey(cutoff)
        return (daily || []).filter(function (d) { return d.day >= key })
    }
    function sum(list, f) { var t = 0; for (var i = 0; i < list.length; i++) t += list[i][f]; return t }
    function streak(daily) {
        var days = {}
        ;(daily || []).forEach(function (d) { if (d.runs > 0) days[d.day] = true })
        var d = new Date()
        if (!days[dayKey(d)]) d.setDate(d.getDate() - 1)
        var n = 0
        while (days[dayKey(d)]) { n++; d.setDate(d.getDate() - 1) }
        return n
    }

    function load() {
        Backend.call("stats.overview", {}, function (o) { overview = o; loadBench() }, function (e) { Store.toast(e, "error") })
    }
    function loadBench() {
        var id = Store.config.activeBenchmark || (Store.config.pinnedBenchmarks || [])[0]
        bench = null; benchError = ""
        if (!id) return
        Backend.call("evxl.benchmark", { id: id }, function (b) { bench = b; bench.id = id }, function (e) { benchError = e })
    }
    Component.onCompleted: load()
    Connections { target: Store; function onStatsReadyChanged() { page.load() } }

    PageHead {
        title: page.greeting + (Store.config.steamName ? ", " + Store.config.steamName : "")
        subtitle: "Pick a scenario and KovaaK's comes forward. Pause or finish and you're back here."
    }

    // indexing progress
    Card {
        visible: !!Store.statsProgress && Store.statsProgress.done < Store.statsProgress.total
        width: parent.width; pad: 18
        height: 74
        ColumnLayout {
            anchors.fill: parent; spacing: 10
            RowLayout { spacing: 10; Spinner {}
                Txt { text: "Indexing your run history"; w: 700 }
                Txt { color: Theme.muted; font.pixelSize: 12; text: Store.statsProgress ? Store.statsProgress.done.toLocaleString() + " / " + Store.statsProgress.total.toLocaleString() : "" } }
            Progress { Layout.fillWidth: true; value: Store.statsProgress && Store.statsProgress.total ? Store.statsProgress.done / Store.statsProgress.total : 0 }
        }
    }

    // ---- scoreline ----
    RowLayout {
        visible: !!page.overview
        width: parent.width; spacing: 30
        StatTile { Layout.fillWidth: true; Layout.preferredWidth: 1; label: "Time today"; value: page.overview ? Fmt.fmtDuration(page.overview.today.seconds) : ""
                   note: page.overview ? page.overview.today.runs + (page.overview.today.runs === 1 ? " run" : " runs") : "" }
        StatTile { Layout.fillWidth: true; Layout.preferredWidth: 1; label: "Total time aiming"; value: page.overview ? Fmt.fmtDuration(page.overview.totalSeconds) : ""
                   note: page.overview ? page.overview.totalRuns.toLocaleString() + " runs · " + page.overview.totalScenarios.toLocaleString() + " scenarios" : "" }
        StatTile { Layout.fillWidth: true; Layout.preferredWidth: 1; label: "PBs today"; value: page.overview ? String(page.overview.today.pbs) : ""; valueColor: page.overview && page.overview.today.pbs ? Theme.gold : Theme.text }
        StatTile { Layout.fillWidth: true; Layout.preferredWidth: 1; label: "Day streak"; value: page.overview ? String(page.streak(page.overview.daily)) : ""
                   note: page.overview ? (page.streak(page.overview.daily) ? "Keep it going" : "Play today to start one") : "" }
        StatTile { Layout.fillWidth: true; Layout.preferredWidth: 1; label: "This week"; value: page.overview ? Fmt.fmtDuration(page.sum(page.lastWeek(page.overview.daily), "seconds")) : ""
                   note: page.overview ? page.sum(page.lastWeek(page.overview.daily), "runs") + " runs in the last 7 days" : "" }
    }

    // ---- continue + favorites ----
    RowLayout {
        id: contRow
        visible: !!page.overview
        width: parent.width; spacing: 16
        readonly property var lastRun: page.overview && page.overview.recent.length ? page.overview.recent[0] : null
        readonly property var lastScen: lastRun ? Store.scenario(lastRun.scenario) : null

        Card {
            Layout.fillWidth: true; Layout.preferredWidth: 1; Layout.preferredHeight: 190
            Row {
                anchors.fill: parent
                Thumb {
                    width: parent.width * 0.52; height: parent.height; fill: true
                    name: contRow.lastRun ? contRow.lastRun.scenario : ""
                    media: contRow.lastScen ? (contRow.lastScen.thumbnail || "") : ""
                    tagColor: Store.primaryTagColor(contRow.lastScen)
                    info: Store.artInfo(contRow.lastScen)
                }
                Column {
                    width: parent.width * 0.48; height: parent.height
                    padding: 22; spacing: 8
                    Txt { visible: !!contRow.lastRun; text: "Continue where you left off"; font.pixelSize: 12; color: Theme.muted }
                    Txt { visible: !!contRow.lastRun; width: parent.width - 44; wrapMode: Text.WordWrap; maximumLineCount: 2; elide: Text.ElideRight
                          text: contRow.lastRun ? (Store.displayName(contRow.lastScen) || contRow.lastRun.scenario) : ""
                          display: true; w: 700; font.pixelSize: 24; lineHeight: 0.95 }
                    Txt { visible: !!contRow.lastRun; font.pixelSize: 13; color: Theme.muted
                          text: contRow.lastScen ? "PB " + Fmt.fmtScore(contRow.lastScen.pb) + "   " + (contRow.lastScen.plays || 0) + " plays   " + Fmt.timeAgo(contRow.lastRun.date) : "" }
                    Row {
                        visible: !!contRow.lastRun; spacing: 8; topPadding: 12
                        Btn { kind: "primary"; icon: "play"; text: "Play"; onClicked: Store.play(contRow.lastRun.scenario) }
                        Btn { kind: "ghost"; text: "Details"; onClicked: Store.openScenario(contRow.lastRun.scenario) }
                    }
                    Txt { visible: !contRow.lastRun; text: "No runs yet. Head to Scenarios and launch one."; color: Theme.muted }
                }
            }
        }

        Card {
            id: favCard
            Layout.fillWidth: true; Layout.preferredWidth: 1; Layout.preferredHeight: 190
            pad: 18
            readonly property var favs: Store.scenarios.filter(function (s) { return s.favorite })
                .sort(function (a, b) { return new Date(b.lastPlayed || 0) - new Date(a.lastPlayed || 0) }).slice(0, 8)
            ColumnLayout {
                anchors.fill: parent; spacing: 8
                RowLayout {
                    Layout.fillWidth: true
                    Icon { name: "star"; size: 16; color: Theme.gold }
                    Txt { text: "Favorites"; display: true; w: 600; font.pixelSize: 20; Layout.fillWidth: true }
                    Btn { kind: "ghost"; small: true; text: "View all"; onClicked: Store.go("library?fav=1") }
                }
                Txt { visible: favCard.favs.length === 0; text: "Star scenarios in the library to pin them here."; color: Theme.muted; font.pixelSize: 13 }
                Flickable {
                    Layout.fillWidth: true; Layout.fillHeight: true; visible: favCard.favs.length > 0
                    contentHeight: favCol.implicitHeight; clip: true; boundsBehavior: Flickable.StopAtBounds
                    Column { id: favCol; width: parent.width; spacing: 2
                        Repeater { model: favCard.favs; delegate: MiniRow { required property var modelData; width: favCol.width; sc: modelData } } }
                }
            }
        }
    }

    // ---- recent runs + benchmark progress ----
    RowLayout {
        visible: !!page.overview
        width: parent.width; spacing: 16

        Card {
            Layout.fillWidth: true; Layout.preferredWidth: 1; Layout.alignment: Qt.AlignTop
            pad: 18
            implicitHeight: runsCol.implicitHeight + 36
            ColumnLayout {
                id: runsCol; width: parent.width; spacing: 6
                RowLayout {
                    Layout.fillWidth: true
                    Txt { text: "Recent runs"; display: true; w: 600; font.pixelSize: 20; Layout.fillWidth: true }
                    Btn { kind: "ghost"; small: true; text: "All stats"; onClicked: Store.go("stats") }
                }
                Txt { visible: !page.overview || page.overview.recent.length === 0; text: "Nothing yet."; color: Theme.muted; font.pixelSize: 13 }
                Repeater {
                    model: page.overview ? page.overview.recent.slice(0, 12) : []
                    delegate: RunRow { required property var modelData; required property int index
                        Layout.fillWidth: true; run: modelData
                        showHeader: index === 0 || Fmt.isToday(page.overview.recent[index - 1].date) !== Fmt.isToday(modelData.date) }
                }
            }
        }

        Card {
            Layout.fillWidth: true; Layout.preferredWidth: 1; Layout.alignment: Qt.AlignTop
            pad: 18
            implicitHeight: benchCol.implicitHeight + 36
            ColumnLayout {
                id: benchCol; width: parent.width; spacing: 8
                RowLayout {
                    Layout.fillWidth: true
                    Icon { name: "trophy"; size: 16; color: Theme.muted }
                    Txt { text: page.bench ? page.bench.name + (page.bench.difficulty ? " · " + page.bench.difficulty : "") : "Benchmark progress"; display: true; w: 600; font.pixelSize: 20; Layout.fillWidth: true; elide: Text.ElideRight }
                    Btn { visible: !!page.bench; kind: "ghost"; small: true; text: "Open"; onClicked: Store.go("benchmarks/" + page.bench.id) }
                }
                Txt { visible: !Store.config.activeBenchmark && !(Store.config.pinnedBenchmarks || []).length; text: "Pin a benchmark to track your ranks here."; color: Theme.muted; font.pixelSize: 13 }
                Btn { visible: !Store.config.activeBenchmark && !(Store.config.pinnedBenchmarks || []).length; text: "Browse benchmarks"; onClicked: Store.go("benchmarks") }
                Txt { visible: page.benchError !== ""; text: page.benchError; color: Theme.muted; font.pixelSize: 13 }
                Repeater {
                    model: page.bench ? page.benchRows(page.bench) : []
                    delegate: BenchMiniRow { required property var modelData; Layout.fillWidth: true; row: modelData; bench: page.bench }
                }
            }
        }
    }

    // ---- most played ----
    Card {
        visible: !!page.overview && page.overview.top.length > 0
        width: parent.width; pad: 18
        implicitHeight: topCol.implicitHeight + 36
        ColumnLayout {
            id: topCol; width: parent.width; spacing: 12
            Txt { text: "Most played"; display: true; w: 600; font.pixelSize: 20 }
            CardGrid {
                Layout.fillWidth: true
                model: page.overview ? page.overview.top.slice(0, 6) : []
                delegate: ScenCard {
                    required property var modelData
                    width: parent.cellWidth
                    sc: Store.scenario(modelData.scenario) || ({ name: modelData.scenario, tags: [], pb: modelData.pb, plays: modelData.plays })
                    onActivated: Store.openScenario(modelData.scenario)
                    onPlayRequested: Store.play(modelData.scenario)
                    onMenuRequested: function (x, y) { Store.scenarioMenu(modelData.scenario, x, y) }
                }
            }
        }
    }

    function benchRows(b) {
        var rows = []
        for (var ci = 0; ci < b.categories.length; ci++) {
            var c = b.categories[ci]
            for (var si = 0; si < c.scenarios.length; si++) {
                var s = c.scenarios[si]
                var best = Math.max(s.localBest || 0, s.remoteScore || 0)
                var r = s.rankMaxes ? s.rankMaxes.filter(function (t) { return best >= t }).length : 0
                rows.push({ s: s, best: best, r: r })
            }
        }
        return rows.slice(0, 12)
    }
}
