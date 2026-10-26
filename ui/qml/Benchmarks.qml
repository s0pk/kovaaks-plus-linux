import QtQuick
import QtQuick.Layouts
import Kplus
import "js/Fmt.js" as Fmt

// Benchmarks: the catalog (one card per benchmark, like evxl.app) or, with a route argument, one benchmark's detail page.
Item {
    id: root
    Loader {
        anchors.fill: parent
        sourceComponent: Store.routeArg !== "" ? detail : catalog
    }
    Component { id: detail; BenchmarkDetail {} }
    Component {
        id: catalog
        PageScroll {
            id: page
            property var groups: []
            property bool resolving: false
            property var ranks: ({})            // "benchmark|difficulty" -> evxl rank result
            property var played: ({})           // lower-case scenario name -> true
            property string sortBy: "played"
            property string filter: ""
            property string status: ""
            property string profileError: ""

            function pinned(g) { return g.difficulties.some(function (d) { return (Store.config.pinnedBenchmarks || []).indexOf(d.id) >= 0 }) }
            function togglePin(g) {
                var pins = (Store.config.pinnedBenchmarks || []).slice()
                var on = pinned(g)
                var ids = g.difficulties.map(function (d) { return d.id })
                pins = pins.filter(function (x) { return ids.indexOf(x) < 0 })
                if (!on) pins.push(g.difficulties[0].id)
                var patch = { pinnedBenchmarks: pins }
                if (on && ids.indexOf(Store.config.activeBenchmark) >= 0) patch.activeBenchmark = null
                if (!on && !Store.config.activeBenchmark) patch.activeBenchmark = g.difficulties[0].id
                Store.saveConfig(patch)
            }
            function rankOf(g, d) { return ranks[g.name + "|" + d.name] }
            function isRanked(r) { return !!(r && r.rankName && !/unranked|no data|not complete/i.test(r.rankName)) }
            function bestDifficulty(g) {
                var withRank = g.difficulties.filter(function (d) { return page.isRanked(page.rankOf(g, d)) })
                return withRank.length ? withRank[withRank.length - 1] : g.difficulties[0]
            }
            function playedCount(g) {
                var n = 0
                g.difficulties.forEach(function (d) { d.scenarios.forEach(function (s) { if (played[s.toLowerCase()]) n++ }) })
                return n
            }
            readonly property var shown: {
                var q = filter.trim().toLowerCase()
                var list = groups.filter(function (g) {
                    return !q || (g.name + " " + (g.abbreviation || "")).toLowerCase().indexOf(q) >= 0 || g.difficulties.some(function (d) { return d.scenarios.some(function (s) { return s.toLowerCase().indexOf(q) >= 0 }) })
                })
                var by = {
                    played: function (a, b) { return page.playedCount(b) - page.playedCount(a) || a.name.localeCompare(b.name) },
                    name: function (a, b) { return a.name.localeCompare(b.name) },
                    "new": function (a, b) { return (b.dateAdded || "").localeCompare(a.dateAdded || "") }
                }[sortBy]
                return list.sort(by)
            }
            readonly property var pins: shown.filter(function (g) { return page.pinned(g) })
            readonly property var rest: shown.filter(function (g) { return !page.pinned(g) })

            function load(refresh) {
                Backend.call("evxl.catalog", { refresh: !!refresh }, function (c) {
                    page.groups = c.groups || []
                    page.resolving = !!c.resolving
                    if (c.resolving && page.status === "") page.status = "Updating benchmark catalog…"
                    Store.loadLibrary(function () {
                        var p = {}
                        Store.scenarios.forEach(function (s) { if (s.plays > 0) p[s.name.toLowerCase()] = true })
                        page.played = p
                    })
                    page.loadProfile(refresh)
                }, function (e) { page.status = e })
            }
            function loadProfile(refresh) {
                if (!Store.config.steamId && !Store.viewing) return
                Backend.call("evxl.profile", { refresh: !!refresh, steamId: Store.viewing ? Store.viewing.steamId : null }, function (prof) {
                    var m = {}
                    ;((prof && prof.results) || []).forEach(function (r) { m[r.benchmarkName + "|" + r.difficultyName] = r })
                    page.ranks = m
                }, function () {})
            }
            Component.onCompleted: load(false)
            Connections {
                target: Store
                function onCatalogProgressChanged() {
                    var d = Store.catalogProgress
                    if (!d) return
                    if (d.total > 0 && d.done >= 0) page.status = "Fetching benchmark names… " + d.done + "/" + d.total
                    if (d.done === -1) { page.status = ""; page.load(false) }
                }
                function onViewingChanged() { page.ranks = ({}); page.loadProfile(false) }
            }

            RowLayout { width: parent.width; FavoritesStrip { Layout.fillWidth: true; onFindRequested: Modals.findPlayer() } }
            ViewingBanner { width: parent.width }

            PageHead {
                title: "Benchmarks"
                subtitle: "Same benchmarks, layouts and scoring as evxl.app, combined with your local PBs so ranks update the moment a run ends."
                Btn { kind: "ghost"; icon: "user"; text: "Find player"; tip: "View another player's benchmarks"; onClicked: Modals.findPlayer() }
                Btn { kind: "ghost"; icon: "refresh"; text: "Refresh"; onClicked: page.load(true) }
            }

            Card {
                visible: !Store.config.steamId && !Store.viewing
                width: parent.width; height: 70
                RowLayout { anchors.fill: parent; anchors.leftMargin: 16; anchors.rightMargin: 12; spacing: 12
                    Icon { name: "trophy"; size: 20; color: Theme.muted }
                    Column { Layout.fillWidth: true
                        Txt { text: "Add your Steam ID"; w: 700 }
                        Txt { text: "See your evxl.app ranks on every benchmark."; font.pixelSize: 12; color: Theme.muted } }
                    Btn { text: "Open settings"; onClicked: Store.go("settings") } }
            }

            RowLayout {
                width: parent.width; spacing: 10
                Field { implicitWidth: 320; icon: "search"; placeholder: "Search benchmarks or scenarios…"; text: page.filter; onEdited: function (t) { fdebounce.restart() }
                        Timer { id: fdebounce; interval: 120; onTriggered: page.filter = parent.text } }
                Seg { options: [{ value: "played", label: "Most played" }, { value: "name", label: "A–Z" }, { value: "new", label: "Newest" }]; value: page.sortBy; onPicked: function (v) { page.sortBy = v } }
                Item { Layout.fillWidth: true }
                Txt { text: page.status; font.pixelSize: 12; color: Theme.muted }
            }

            Column {
                width: parent.width; spacing: 12
                visible: page.pins.length > 0
                Txt { text: "Pinned"; display: true; w: 600; font.pixelSize: 24 }
                CardGrid { width: parent.width; minWidth: 260; gap: 12; model: page.pins; delegate: BenchCard { required property var modelData; g: modelData; width: parent.cellWidth } }
            }
            Column {
                width: parent.width; spacing: 12
                Txt { text: "All benchmarks · " + page.rest.length; display: true; w: 600; font.pixelSize: 24 }
                CardGrid { visible: page.rest.length > 0; width: parent.width; minWidth: 260; gap: 12; model: page.rest; delegate: BenchCard { required property var modelData; g: modelData; width: parent.cellWidth } }
                Txt { visible: page.rest.length === 0; text: page.groups.length ? "No benchmarks match." : "Loading benchmarks…"; color: Theme.muted }
            }

            component BenchCard: Rectangle {
                id: bc
                property var g: ({})
                readonly property bool isPinned: page.pinned(g)
                readonly property int nPlayed: page.playedCount(g)
                height: 28 + dcol.implicitHeight + 24
                radius: Theme.radius; color: Theme.surface; border.width: 1; border.color: ma.containsMouse ? Theme.border2 : Theme.border
                clip: true
                Rectangle { width: 4; height: parent.height; color: g.color ? g.color : Theme.accent }
                Column {
                    id: dcol
                    x: 18; y: 12; width: parent.width - 30; spacing: 8
                    RowLayout { width: parent.width; spacing: 8
                        Txt { text: bc.g.name; w: 700; elide: Text.ElideRight; Layout.fillWidth: true }
                        Txt { visible: !!bc.g.abbreviation; text: bc.g.abbreviation || ""; font.pixelSize: 11; w: 700; color: bc.g.color ? bc.g.color : Theme.muted }
                        Btn { small: true; kind: "ghost"; icon: "pin"; tip: bc.isPinned ? "Unpin" : "Pin"; onClicked: page.togglePin(bc.g) } }
                    Flow { width: parent.width; spacing: 6
                        Repeater { model: bc.g.difficulties
                            delegate: Rectangle {
                                required property var modelData
                                readonly property var r: page.rankOf(bc.g, modelData)
                                readonly property bool ranked: page.isRanked(r)
                                height: 22; width: dr.implicitWidth + 16; radius: Theme.radiusSm; color: Theme.bg2; border.width: 1; border.color: Theme.border
                                Row { id: dr; anchors.centerIn: parent; spacing: 5
                                    Txt { text: modelData.name; font.pixelSize: 11; w: 700; color: Theme.text2 }
                                    Txt { visible: parent.parent.ranked; text: parent.parent.r ? parent.parent.r.rankName : ""; font.pixelSize: 11; w: 700; color: Fmt.rankColor({ name: parent.parent.r ? parent.parent.r.rankName.replace(/ complete$/i, "") : "" }, 3) } }
                                MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor; onClicked: Store.go("benchmarks/" + modelData.id) } } }
                    }
                    RowLayout { width: parent.width; spacing: 12
                        Txt { text: bc.g.difficulties.reduce(function (a, d) { return a + d.scenarioCount }, 0) + " scenarios"; font.pixelSize: 12; color: Theme.muted }
                        Txt { visible: bc.nPlayed > 0; text: bc.nPlayed + " played"; font.pixelSize: 12; color: Theme.good }
                        Item { Layout.fillWidth: true }
                        Txt { visible: !!bc.g.rankCalculation; text: bc.g.rankCalculation || ""; font.pixelSize: 11; color: Theme.muted } }
                }
                Brackets { opacity: ma.containsMouse ? 1 : 0 }
                MouseArea {
                    id: ma; anchors.fill: parent; z: -1; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; acceptedButtons: Qt.LeftButton | Qt.RightButton
                    onClicked: function (m) {
                        if (m.button === Qt.RightButton) {
                            var p = mapToItem(Modals.menuHost, m.x, m.y)
                            Modals.menu([{ header: bc.g.name }].concat(bc.g.difficulties.map(function (d) { return { label: "Open " + d.name, icon: "trophy", onClick: function () { Store.go("benchmarks/" + d.id) } } }),
                                         [{ sep: true }, { label: bc.isPinned ? "Unpin" : "Pin", icon: "pin", onClick: function () { page.togglePin(bc.g) } }]), p.x, p.y)
                        } else Store.go("benchmarks/" + page.bestDifficulty(bc.g).id)
                    }
                }
            }
        }
    }
}
