import QtQuick
import QtQuick.Layouts
import Kplus
import "js/Fmt.js" as Fmt
import "js/BenchCalc.js" as BC
import "js/BenchTable.js" as BT

// One benchmark difficulty: header, overall rank, the evxl-style table, calculator and leaderboards.
PageScroll {
    id: page
    property int benchId: parseInt(Store.routeArg) || 0
    property var raw: null
    property string error: ""
    property bool calcOpen: Store.benchCalcOpen
    readonly property var viewer: Store.viewing
    readonly property string customKey: (viewer ? viewer.steamId : "me") + "|" + benchId
    readonly property var customs: Store.benchCustoms[customKey] || ({})
    readonly property int customCount: Object.keys(customs).length
    readonly property var b: raw ? BT.withCustoms(raw, customs) : null
    readonly property var res: b ? BC.computeBenchmark(b) : null
    readonly property var ts: BT.settings((Store.config.ui || {}).benchTable)
    readonly property var tableModel: b && res ? BT.build(b, res, ts) : null
    readonly property int ranksN: b ? ((b.rankNames || []).length || Math.max(0, (b.ranks || []).length - 1)) : 0
    readonly property var diffs: raw ? (raw.difficulties || []).filter(function (d) { return d.id > 0 }) : []
    readonly property bool isPinned: raw ? ((Store.config.pinnedBenchmarks || []).some(function (x) { return diffs.some(function (d) { return d.id === x }) }) || (Store.config.pinnedBenchmarks || []).indexOf(benchId) >= 0) : false
    readonly property bool isActive: Store.config.activeBenchmark === benchId

    // overall rank: our own computation when supported, else evxl's server rank
    readonly property var overall: {
        if (!b || !res) return { label: "", color: Theme.muted, icon: "" }
        var evxl = b.evxlRank
        if (res.supported) { var e = BC.rankEntry(res.rank, b); return { label: res.display, color: Fmt.rankColor(e, res.rank), icon: e.icon || "" } }
        if (evxl && evxl.rankName) {
            var base = evxl.rankName.replace(/ complete$/i, "")
            var idx = (b.rankNames || []).findIndex(function (r) { return r.name.toLowerCase() === base.toLowerCase() })
            var e2 = idx >= 0 ? BC.rankEntry(idx + 1, b) : { name: base }
            return { label: evxl.rankName, color: Fmt.rankColor(e2, idx + 1), icon: e2.icon || "" }
        }
        return { label: "Unranked", color: "#6b7280", icon: "" }
    }

    function load(refresh) {
        var id = benchId
        if (!id) return
        error = ""
        Backend.call("evxl.benchmark", { id: id, refresh: !!refresh, steamId: viewer ? viewer.steamId : null }, function (r) { if (id === page.benchId) page.raw = r },
                     function (e) { page.error = e })
    }
    onBenchIdChanged: { raw = null; load(false) }
    Component.onCompleted: { load(false); Store.loadLibrary() }
    Connections { target: Store; function onRunCompleted() { page.load(false) } function onViewingChanged() { page.raw = null; page.load(false) } }

    function setCustom(name, value) {
        var all = {}
        for (var k in Store.benchCustoms) all[k] = Store.benchCustoms[k]
        var mine = {}
        for (var n in customs) mine[n] = customs[n]
        if (value === null || value === undefined || isNaN(value)) delete mine[name]; else mine[name] = value
        all[customKey] = mine
        Store.benchCustoms = all
    }
    function resetCustoms() { var all = {}; for (var k in Store.benchCustoms) all[k] = Store.benchCustoms[k]; delete all[customKey]; Store.benchCustoms = all }

    function pin() {
        var pins = (Store.config.pinnedBenchmarks || []).slice()
        if (isPinned) { var ids = diffs.map(function (d) { return d.id }); pins = pins.filter(function (x) { return ids.indexOf(x) < 0 && x !== benchId }) }
        else pins.push(benchId)
        Store.saveConfig({ pinnedBenchmarks: pins })
    }
    function moreMenu(x, y) {
        var list = Store.config.benchmarkFilters || []
        var on = list.indexOf(benchId) >= 0
        Modals.menu([
            { label: "View another player's scores…", icon: "user", onClick: Modals.findPlayer },
            viewer ? { label: "Back to my scores", icon: "arrowLeft", onClick: function () { Store.viewPlayer(null) } } : null,
            { sep: true },
            { label: "Auto-tag these scenarios", icon: "tag", onClick: function () {
                Backend.call("library.autoTag", { ids: [benchId] }, function (r) { Store.loadLibrary(function () { Store.toast("Tagged " + r.tagged + " scenarios", "ok") }) }, function (e) { Store.toast(e, "error") }) } },
            { label: on ? "Remove scenario filter" : "Show as scenario filter", icon: "library", onClick: function () {
                Store.saveConfig({ benchmarkFilters: on ? list.filter(function (x) { return x !== benchId }) : list.concat([benchId]) }, function () { Store.toast(on ? "Removed from the Scenarios sidebar" : "Added to the Scenarios sidebar under Benchmarks", "ok") }) } },
            { label: "View its scenarios in the library", icon: "search", onClick: function () { Store.go("library?bench=" + benchId) } },
            { label: isActive ? "Remove from home screen" : "Show on home screen", icon: "home", onClick: function () {
                var pins = (Store.config.pinnedBenchmarks || []).slice(); if (pins.indexOf(benchId) < 0) pins.push(benchId)
                Store.saveConfig({ activeBenchmark: isActive ? null : benchId, pinnedBenchmarks: pins }) } },
            { label: isPinned ? "Unpin" : "Pin", icon: "pin", onClick: page.pin },
            viewer || Store.config.steamId ? { label: viewer ? "Open " + viewer.name + "'s page on evxl.app" : "Open my page on evxl.app", icon: "external", onClick: function () {
                Backend.send("app.openUrl", { url: "https://evxl.app/u/" + (viewer ? viewer.steamId : Store.config.steamId) + "/" + encodeURIComponent(raw.name) + "/" + encodeURIComponent(raw.difficulty || "") }) } } : null
        ], x, y)
    }
    Clipboard { id: clip }

    // ---- back + favourites ----
    RowLayout {
        width: parent.width; spacing: 12
        Btn { small: true; kind: "ghost"; icon: "arrowLeft"; text: "All benchmarks"; onClicked: Store.go("benchmarks") }
        FavoritesStrip { Layout.fillWidth: true; onFindRequested: Modals.findPlayer() }
    }

    Txt { visible: !page.raw && page.error === ""; text: "Loading benchmark…"; color: Theme.muted; width: parent.width; horizontalAlignment: Text.AlignHCenter; topPadding: 40 }
    ColumnLayout { visible: page.error !== ""; width: parent.width; spacing: 6
        Txt { text: "Couldn't load this benchmark"; display: true; w: 600; font.pixelSize: 24; Layout.alignment: Qt.AlignHCenter }
        Txt { text: page.error; color: Theme.muted; Layout.alignment: Qt.AlignHCenter } }

    ViewingBanner { width: parent.width; extraUrl: page.raw && page.viewer ? "https://evxl.app/u/" + page.viewer.steamId + "/" + encodeURIComponent(page.raw.name) + "/" + encodeURIComponent(page.raw.difficulty || "") : "" }

    // ---- header ----
    RowLayout {
        visible: !!page.raw; width: parent.width; spacing: 14
        Rectangle { visible: !!(page.raw && page.raw.abbreviation); width: ab.implicitWidth + 16; height: 24; radius: 3; color: page.raw && page.raw.color ? page.raw.color : Theme.accent
                    Txt { id: ab; anchors.centerIn: parent; text: page.raw ? (page.raw.abbreviation || "") : ""; w: 700; font.pixelSize: 12; color: "#0b0d12" } }
        Txt { text: page.raw ? page.raw.name : ""; display: true; w: 700; font.pixelSize: 44; lineHeight: 0.92; elide: Text.ElideRight; Layout.maximumWidth: page.width * 0.5 }
        Rectangle {   // difficulty tabs
            visible: page.diffs.length > 1; implicitWidth: dRow.implicitWidth + 6; implicitHeight: 36; radius: Theme.radiusSm; color: Theme.bg2; border.width: 1; border.color: Theme.border2
            Row { id: dRow; anchors.centerIn: parent; spacing: 2
                Repeater { model: page.diffs
                    delegate: Rectangle { required property var modelData; readonly property bool on: modelData.id === page.benchId
                        width: dt.implicitWidth + 28; height: 30; radius: 2; color: on ? Theme.surface3 : (da.containsMouse ? Theme.surface2 : "transparent")
                        Txt { id: dt; anchors.centerIn: parent; text: modelData.name; w: 600; color: on ? Theme.text : Theme.text2 }
                        Rectangle { visible: parent.on; anchors.bottom: parent.bottom; anchors.bottomMargin: 2; x: 10; width: parent.width - 20; height: 2; radius: 1; color: page.raw && page.raw.color ? page.raw.color : Theme.accent }
                        MouseArea { id: da; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onClicked: Store.go("benchmarks/" + modelData.id) } } } }
        }
        Chip { visible: page.diffs.length <= 1 && !!(page.raw && page.raw.difficulty); text: page.raw ? (page.raw.difficulty || "") : ""; chipColor: Theme.accent }
        Item { Layout.fillWidth: true }
        Btn { visible: !!(page.raw && page.raw.sharecode); icon: "play"; text: "Playlist"; tip: "Open the benchmark playlist inside KovaaK's"; onClicked: Backend.call("game.playPlaylist", { sharecode: page.raw.sharecode }, null, function (e) { Store.toast(e, "error") }) }
        Btn { kind: "ghost"; icon: "refresh"; text: "Refresh"; onClicked: page.load(true) }
        Btn { visible: !!(page.raw && page.raw.sharecode); kind: "ghost"; icon: "copy"; text: "Sharecode"; tip: "Copy playlist share code"; onClicked: { clip.copy(page.raw.sharecode); Store.toast("Copied to clipboard", "ok") } }
        Btn { visible: !!(page.raw && page.raw.spreadsheetUrl); kind: "ghost"; icon: "external"; tip: "Original spreadsheet"; onClicked: Backend.send("app.openUrl", { url: page.raw.spreadsheetUrl }) }
        Btn { kind: "ghost"; icon: "sliders"; tip: "Table settings"; onClicked: Modals.tableSettings() }
        Btn { kind: "ghost"; icon: "settings"; tip: "More"; onClicked: { var p = mapToItem(Modals.menuHost, width - 240, height + 4); page.moreMenu(p.x, p.y) } }
    }

    // ---- summary ----
    Card {
        visible: !!page.raw; width: parent.width; height: 72
        RowLayout {
            anchors.fill: parent; anchors.leftMargin: 18; anchors.rightMargin: 18; spacing: 18
            RankPill { compact: false; implicitHeight: 36; text: page.overall.label; rc: page.overall.color; iconSource: page.overall.icon }
            Row { visible: !!(page.res && page.res.supported && page.res.energy !== undefined && page.res.energy !== null); spacing: 6
                  Icon { name: "bolt"; size: 18; color: "#facc15"; anchors.verticalCenter: parent.verticalCenter }
                  Txt { text: page.res && page.res.energy !== undefined ? String(Math.round(page.res.energy)) : ""; display: true; w: 700; font.pixelSize: 24; anchors.verticalCenter: parent.verticalCenter } }
            ColumnLayout { visible: !!(page.res && page.res.supported && page.res.progress !== undefined && page.res.progress !== null && page.res.rank < page.ranksN); Layout.preferredWidth: 200; spacing: 4
                Progress { Layout.fillWidth: true; value: page.res ? Math.min(1, page.res.progress) : 0; fill: page.overall.color }
                Txt { text: page.res && page.b ? Math.round(Math.min(1, page.res.progress) * 100) + "% to " + BC.rankEntry(page.res.rank + 1, page.b).name : ""; font.pixelSize: 12; color: Theme.muted } }
            Txt { visible: !!(page.b && page.b.evxlRank && page.b.evxlRank.rankName && page.res && page.res.supported && page.b.evxlRank.rankName !== page.res.display); text: "evxl.app: " + (page.b && page.b.evxlRank ? page.b.evxlRank.rankName : ""); font.pixelSize: 12; color: Theme.muted }
            Item { Layout.fillWidth: true }
            Txt { visible: !!(page.b && page.b.offline); text: "offline (cached)"; font.pixelSize: 12; color: Theme.bad }
            Rectangle { implicitWidth: cc.implicitWidth + 20; implicitHeight: 28; radius: Theme.radiusSm; color: Theme.bg2; border.width: 1; border.color: Theme.border
                        Row { id: cc; anchors.centerIn: parent; spacing: 4
                              Txt { text: "Calc:"; font.pixelSize: 12; color: Theme.muted }
                              Txt { text: page.res ? page.res.method + (BC.CALC_INFO[page.res.method] ? "" : " (evxl)") : ""; font.pixelSize: 12; w: 700; color: Theme.accent2 } } }
        }
    }

    // what-if bar
    Rectangle {
        visible: page.customCount > 0; width: parent.width; height: 46; radius: Theme.radiusSm
        color: Theme.alpha(Theme.accent2, 0.1); border.width: 1; border.color: Theme.alpha(Theme.accent2, 0.35)
        RowLayout { anchors.fill: parent; anchors.leftMargin: 14; anchors.rightMargin: 10; spacing: 10
            Icon { name: "edit"; size: 16; color: Theme.accent2 }
            Txt { Layout.fillWidth: true; text: "Showing " + page.customCount + " custom score" + (page.customCount === 1 ? "" : "s") + ". Ranks, energy and the calculator use these what-if values."; elide: Text.ElideRight }
            Btn { small: true; icon: "refresh"; text: "Reset all"; onClicked: page.resetCustoms() } }
    }

    // ---- the table ----
    Card {
        visible: !!page.tableModel; width: parent.width
        height: (tbl.implicitHeight || 0) + 16
        BenchTable {
            id: tbl
            x: 0; y: 4; width: parent.width - 0
            model: page.tableModel
            onEditScore: function (name, value) { page.setCustom(name, value) }
            onPlayRequested: function (name) { Store.play(name, null, { queue: page.res ? page.res.list.map(function (s) { return s.name }) : [] }) }
            onOpenRequested: function (name) { Store.openScenario(name) }
            onLeaderboardRequested: function (name, display) { Modals.scenarioLeaderboard(name, display) }
            onMenuRequested: function (name, x, y) { Store.scenarioMenu(name, x, y) }
        }
    }

    // ---- rank calculator (collapsed until opened) ----
    Card {
        visible: !!page.res; width: parent.width; pad: 18
        height: calcCol.implicitHeight + 36
        ColumnLayout {
            id: calcCol; width: parent.width; spacing: 12
            Item {
                Layout.fillWidth: true; Layout.preferredHeight: 30
                RowLayout {
                    anchors.fill: parent; spacing: 8
                    Icon { name: "target"; size: 16; color: Theme.muted }
                    Txt { text: "Rank calculator"; display: true; w: 600; font.pixelSize: 20 }
                    Item { Layout.fillWidth: true }
                    Txt { text: "What it takes to reach a rank, an energy, or a leaderboard spot"; font.pixelSize: 12; color: Theme.muted }
                    Icon { name: "chevron"; size: 16; color: Theme.muted; flipY: page.calcOpen }
                }
                MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor; onClicked: Store.benchCalcOpen = !Store.benchCalcOpen }
            }
            Loader { Layout.fillWidth: true; active: page.calcOpen && !!page.res; visible: active
                     sourceComponent: BenchmarkCalculator { b: page.b; res: page.res } }
        }
    }

    // ---- leaderboards ----
    Card {
        visible: !!page.raw; width: parent.width; pad: 18
        height: lbCol.implicitHeight + 36
        ColumnLayout {
            id: lbCol; width: parent.width; spacing: 12
            RowLayout { spacing: 8; Icon { name: "medal"; size: 16; color: Theme.muted } Txt { text: "Leaderboards"; display: true; w: 600; font.pixelSize: 20 } }
            Loader { Layout.fillWidth: true; active: !!page.raw; sourceComponent: BenchmarkLeaderboard { b: page.raw } }
        }
    }
}
