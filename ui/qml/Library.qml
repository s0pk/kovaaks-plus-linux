import QtQuick
import QtQuick.Layouts
import QtQuick.Controls
import Kplus
import "js/LibraryLogic.js" as LL

// The Scenarios page: filters on the left; search, sort and a virtualised grid or list on the right.
Item {
    id: page

    readonly property var ui: Store.libUi
    property string sortBy: Store.config.librarySort || "recent"
    readonly property string viewMode: Store.config.libraryView || "grid"
    property bool selecting: false
    property var selectedNames: ({})
    property string lastClicked: ""
    readonly property var list: LL.compute(Store.scenarios, Store.tags, Store.groups, Store.config, ui, sortBy)
    readonly property int selectedCount: Object.keys(selectedNames).length
    readonly property var filterChips: LL.activeFilters(ui, Store.tags, Store.benchNames)
    readonly property bool anyTags: list.some(function (s) { return s.tags && s.tags.length })
    property string searchText: ui.search

    function applyRoute() {
        var p = Store.routeParams
        if (p.fav) Store.setLib({ quick: "fav" })
        if (p.bench) Store.setLib({ bench: parseInt(p.bench), quick: "all" })
        if (p.tag) Store.setLib({ tags: [p.tag], quick: "all" })
    }
    Component.onCompleted: {
        applyRoute()
        if ((Store.config.benchmarkFilters || []).length || ui.bench) Store.loadBenchNames()
        if (!Store.libraryLoaded) Store.loadLibrary()
    }

    function clearSelection() { selectedNames = ({}); selecting = false }
    function toggleSelect(name) {
        var n = {}
        for (var k in selectedNames) n[k] = true
        if (n[name]) delete n[name]; else n[name] = true
        selectedNames = n
    }
    function selectRange(a, b) {
        var ia = list.findIndex(function (s) { return s.name === a }), ib = list.findIndex(function (s) { return s.name === b })
        if (ia < 0 || ib < 0) return
        var n = {}
        for (var k in selectedNames) n[k] = true
        for (var i = Math.min(ia, ib); i <= Math.max(ia, ib); i++) n[list[i].name] = true
        selectedNames = n
    }
    function activate(sc, modifiers) {
        if (selecting || (modifiers & (Qt.ControlModifier | Qt.ShiftModifier))) {
            selecting = true
            if ((modifiers & Qt.ShiftModifier) && lastClicked) selectRange(lastClicked, sc.name)
            else toggleSelect(sc.name)
            lastClicked = sc.name
            return
        }
        Store.openScenario(sc.name)
    }
    function menuFor(sc, x, y) {
        if (selecting && selectedCount > 1 && selectedNames[sc.name]) page.bulkMenu(x, y)
        else Store.scenarioMenu(sc.name, x, y)
    }
    function queue() { return list.map(function (s) { return s.name }) }
    function play(sc) { Store.play(sc.name, null, { queue: queue() }) }

    function bulk(params, msg) {
        var names = Object.keys(selectedNames)
        params.names = names
        Backend.call("library.bulk", params, function () { Store.loadLibrary(function () { Store.toast(msg, "ok") }) }, function (e) { Store.toast(e, "error") })
    }
    function bulkMenu(x, y) {
        var n = selectedCount
        Modals.menu([
            { header: n + " scenarios selected" },
            { label: "Add tags…", icon: "tag", onClick: function () { Modals.pickTags("Add tags to " + n + " scenarios", [], function (ids) { page.bulk({ addTags: ids }, "Tags added") }) } },
            { label: "Remove tags…", icon: "tag", onClick: function () { Modals.pickTags("Remove tags from " + n + " scenarios", [], function (ids) { page.bulk({ removeTags: ids }, "Tags removed") }) } },
            { label: "Add to favorites", icon: "star", onClick: function () { page.bulk({ favorite: true }, "Added to favorites") } },
            { label: "Remove from favorites", icon: "star", onClick: function () { page.bulk({ favorite: false }, "Removed from favorites") } },
            { label: "Hide", icon: "eyeOff", onClick: function () { page.bulk({ hidden: true }, "Hidden") } },
            { label: "Unhide", icon: "eye", onClick: function () { page.bulk({ hidden: false }, "Unhidden") } },
            { sep: true },
            { label: "Export " + n + " as pack…", icon: "download", onClick: function () { Store.exportItems({ scenarios: Object.keys(page.selectedNames), name: n + " scenarios" }) } }
        ], x, y)
    }

    function rescan() {
        Backend.call("library.rescan", {}, function (res) { Store.applyLibrary(res); Store.toast("Library rescanned: " + Store.scenarios.length.toLocaleString() + " scenarios", "ok") }, function (e) { Store.toast(e, "error") })
    }
    function importFavorites() {
        Backend.call("library.gameFavorites", {}, function (favs) {
            if (!favs.length) { Store.toast("No favorites found in KovaaK's"); return }
            Modals.confirm("Import favorites?", "Mark " + favs.length + " scenario" + (favs.length === 1 ? "" : "s") + " you favorited inside KovaaK's as favorites here?", "Import", "primary", function (ok) {
                if (!ok) return
                Backend.call("library.importGameFavorites", {}, function (r) { Store.loadLibrary(function () { Store.toast("Imported " + r.imported + " favorites", "ok") }) })
            })
        })
    }
    function resetFilters() { Store.libUi = LL.defaultUi(); search.text = "" }
    function clearChip(f) {
        var u = page.ui
        if (f.kind === "quick") Store.setLib({ quick: "all" })
        else if (f.kind === "tag") Store.setLib({ tags: u.tags.filter(function (x) { return x !== f.id }) })
        else if (f.kind === "mode") Store.setLib({ tagMode: "any" })
        else if (f.kind === "source") Store.setLib({ source: "any" })
        else if (f.kind === "search") { Store.setLib({ search: "" }); search.text = "" }
        else if (f.kind === "bench") Store.setLib({ bench: null })
    }

    readonly property real sidePad: 32

    ColumnLayout {
        anchors.fill: parent
        anchors.leftMargin: page.sidePad; anchors.rightMargin: page.sidePad; anchors.topMargin: 30
        spacing: 22

        PageHead {
            title: "Scenarios"
            subtitle: "Custom names and tags live in Kovaak's Plus, so your scenario files stay untouched and keep working in KovaaK's."
            Layout.fillWidth: true
            Btn { icon: "tag"; text: "Auto-tag"; onClicked: Modals.autoTag({ filtered: page.list.map(function (s) { return s.name }), selected: Object.keys(page.selectedNames) }) }
            Btn { icon: "check"; text: "Select"; selected: page.selecting; onClicked: { if (page.selecting) page.clearSelection(); else page.selecting = true } }
            Btn {
                kind: "ghost"; icon: "settings"; tip: "More"
                onClicked: {
                    var p = mapToItem(Modals.menuHost, width - 240, height + 4)
                    Modals.menu([
                        { label: "Auto-tag scenarios…", icon: "tag", onClick: function () { Modals.autoTag({ filtered: page.list.map(function (s) { return s.name }), selected: Object.keys(page.selectedNames) }) } },
                        { label: "Manage tags…", icon: "edit", onClick: Modals.manageTags },
                        { label: "Import favorites from KovaaK's", icon: "star", onClick: page.importFavorites },
                        { sep: true },
                        { label: "Rescan scenario folders", icon: "refresh", onClick: page.rescan }
                    ], p.x, p.y)
                }
            }
        }

        RowLayout {
            Layout.fillWidth: true; Layout.fillHeight: true
            spacing: 20

            LibraryFilters { Layout.preferredWidth: 220; Layout.fillHeight: true }

            ColumnLayout {
                Layout.fillWidth: true; Layout.fillHeight: true
                spacing: 14

                // toolbar
                RowLayout {
                    Layout.fillWidth: true; spacing: 10
                    Field {
                        id: search
                        Layout.preferredWidth: 280
                        icon: "search"; placeholder: "Search name, author, tag…"
                        text: page.searchText
                        onEdited: function (t) { debounce.restart() }
                        Keys.onEscapePressed: { text = ""; Store.setLib({ search: "" }) }
                        Timer { id: debounce; interval: 120; onTriggered: Store.setLib({ search: search.text }) }
                    }
                    Select { options: LL.SORTS; value: page.sortBy; onPicked: function (v) { page.sortBy = v; Store.saveConfig({ librarySort: v }) } }
                    Seg {
                        options: [{ value: "grid", icon: "grid", title: "Grid" }, { value: "list", icon: "list", title: "List" }]
                        value: page.viewMode
                        onPicked: function (v) { Store.config.libraryView = v; Store.configChanged(); Store.saveConfig({ libraryView: v }) }
                    }
                    Item { Layout.fillWidth: true }
                    Txt { text: page.list.length.toLocaleString() + " scenario" + (page.list.length === 1 ? "" : "s"); color: Theme.muted; font.pixelSize: 12 }
                }

                // active filters
                Rectangle {
                    visible: page.filterChips.length > 0
                    Layout.fillWidth: true; Layout.preferredHeight: 42
                    radius: Theme.radiusSm; color: Theme.accentSoft; border.width: 1; border.color: Theme.accentLine
                    RowLayout {
                        anchors.fill: parent; anchors.leftMargin: 12; anchors.rightMargin: 8; spacing: 8
                        Txt { text: "Filtered by"; font.pixelSize: 12; color: Theme.muted }
                        Repeater {
                            model: page.filterChips
                            delegate: Chip { required property var modelData; text: modelData.label; chipColor: modelData.color ? Qt.color(modelData.color) : Theme.muted; removable: true; clickable: true
                                             onClicked: page.clearChip(modelData); onRemoved: page.clearChip(modelData) }
                        }
                        Item { Layout.fillWidth: true }
                        Btn { kind: "ghost"; small: true; text: "Clear all"; onClicked: page.resetFilters() }
                    }
                }

                // benchmark banner
                Card {
                    visible: !!page.ui.bench
                    Layout.fillWidth: true; Layout.preferredHeight: 56
                    readonly property var info: (Store.benchNames || ({}))[page.ui.bench] || null
                    RowLayout {
                        anchors.fill: parent; anchors.leftMargin: 16; anchors.rightMargin: 12; spacing: 12
                        Icon { name: "trophy"; size: 20; color: "#eab308" }
                        Column { Layout.fillWidth: true
                            Txt { text: parent.parent.parent.info ? parent.parent.parent.info.name + (parent.parent.parent.info.difficulty ? " · " + parent.parent.parent.info.difficulty : "") : "Benchmark"; w: 700 }
                            Txt { text: page.list.length + " scenarios in this benchmark"; font.pixelSize: 12; color: Theme.muted } }
                        Btn { small: true; kind: "primary"; text: "Open benchmark page"; onClicked: Store.go("benchmarks/" + page.ui.bench) }
                    }
                }

                // empty states
                Card {
                    visible: page.list.length === 0 && Store.libraryLoaded
                    Layout.fillWidth: true; Layout.preferredHeight: 200
                    ColumnLayout {
                        anchors.centerIn: parent; spacing: 10; width: parent.width - 60
                        Icon { name: "search"; size: 36; color: Theme.muted; Layout.alignment: Qt.AlignHCenter; opacity: 0.5 }
                        Txt { text: Store.scenarios.length ? "No scenarios match these filters" : "No scenarios found"; display: true; w: 600; font.pixelSize: 22; Layout.alignment: Qt.AlignHCenter }
                        Txt { Layout.fillWidth: true; horizontalAlignment: Text.AlignHCenter; wrapMode: Text.WordWrap; color: Theme.muted
                              text: Store.scenarios.length ? "You have " + Store.scenarios.length.toLocaleString() + " scenarios, but the filters above hide all of them."
                                                           : "Kovaak's Plus couldn't find any scenario files. Check the KovaaK's folder in App Settings, then rescan." }
                        Btn { Layout.alignment: Qt.AlignHCenter; kind: "primary"; text: Store.scenarios.length ? "Show all scenarios" : "Rescan"; icon: Store.scenarios.length ? "" : "refresh"; onClicked: Store.scenarios.length ? page.resetFilters() : page.rescan() }
                    }
                }
                Item { visible: !Store.libraryLoaded; Layout.fillWidth: true; Layout.preferredHeight: 120
                    ColumnLayout { anchors.centerIn: parent; spacing: 10; Spinner { Layout.alignment: Qt.AlignHCenter } Txt { text: "Loading your library…"; color: Theme.muted } } }

                // the scenarios
                Loader {
                    Layout.fillWidth: true; Layout.fillHeight: true
                    visible: page.list.length > 0
                    sourceComponent: page.viewMode === "list" ? listView : gridView
                }
            }
        }
    }

    Component {
        id: gridView
        GridView {
            id: grid
            clip: true
            boundsBehavior: Flickable.StopAtBounds
            ScrollBar.vertical: ThinScroll {}
            readonly property int gap: 14
            readonly property int cols: Math.max(1, Math.floor((width + gap) / (Theme.cardMin + gap)))
            cellWidth: Math.floor(width / cols)
            readonly property real cardW: cellWidth - gap
            cellHeight: cardW * 9 / 16 + 92 + (page.anyTags ? 26 : 0) + gap
            model: page.list
            cacheBuffer: 600
            delegate: Item {
                id: cell
                required property var modelData
                width: grid.cellWidth; height: grid.cellHeight
                ScenCard {
                    width: grid.cardW; height: parent.height - grid.gap
                    sc: cell.modelData
                    showTags: page.anyTags
                    selecting: page.selecting
                    selected: !!page.selectedNames[cell.modelData.name]
                    onActivated: function (mods) { page.activate(cell.modelData, mods) }
                    onPlayRequested: page.play(cell.modelData)
                    onMenuRequested: function (x, y) { page.menuFor(cell.modelData, x, y) }
                }
            }
        }
    }

    Component {
        id: listView
        ColumnLayout {
            spacing: 4
            RowLayout {
                Layout.fillWidth: true; Layout.leftMargin: 12; Layout.rightMargin: 12; spacing: 14
                Item { Layout.preferredWidth: 64 }
                Txt { text: "Scenario"; color: Theme.muted; font.pixelSize: 12; Layout.fillWidth: true; Layout.preferredWidth: 22 }
                Txt { text: "Tags"; color: Theme.muted; font.pixelSize: 12; Layout.fillWidth: true; Layout.preferredWidth: 16 }
                Txt { text: "PB"; color: Theme.muted; font.pixelSize: 12; Layout.preferredWidth: 90; horizontalAlignment: Text.AlignRight }
                Txt { text: "Plays"; color: Theme.muted; font.pixelSize: 12; Layout.preferredWidth: 60; horizontalAlignment: Text.AlignRight }
                Txt { text: "Last played"; color: Theme.muted; font.pixelSize: 12; Layout.preferredWidth: 90 }
                Item { Layout.preferredWidth: 70 }
            }
            ListView {
                id: lv
                Layout.fillWidth: true; Layout.fillHeight: true
                clip: true; boundsBehavior: Flickable.StopAtBounds
                ScrollBar.vertical: ThinScroll {}
                model: page.list
                spacing: 2
                delegate: ScenRow {
                    required property var modelData
                    width: lv.width - 10
                    sc: modelData
                    selected: !!page.selectedNames[modelData.name]
                    onActivated: function (mods) { page.activate(modelData, mods) }
                    onPlayRequested: page.play(modelData)
                    onMenuRequested: function (x, y) { page.menuFor(modelData, x, y) }
                }
            }
        }
    }

    // bulk actions
    Rectangle {
        visible: page.selecting
        anchors.horizontalCenter: parent.horizontalCenter; anchors.bottom: parent.bottom; anchors.bottomMargin: 18
        width: bulkRow.implicitWidth + 36; height: 52; radius: Theme.radius
        color: Theme.surface2; border.width: 1; border.color: Theme.border2
        RowLayout {
            id: bulkRow
            anchors.centerIn: parent; spacing: 10
            Txt { text: page.selectedCount + " selected"; w: 700 }
            Btn { small: true; kind: "ghost"; text: "Select all " + page.list.length; onClicked: { var n = {}; page.list.forEach(function (s) { n[s.name] = true }); page.selectedNames = n } }
            Rectangle { width: 1; height: 22; color: Theme.border2 }
            Btn { small: true; icon: "tag"; text: "Add tags"; enabled: page.selectedCount > 0; onClicked: Modals.pickTags("Add tags to " + page.selectedCount + " scenarios", [], function (ids) { page.bulk({ addTags: ids }, "Tags added") }) }
            Btn { small: true; text: "Remove tags"; enabled: page.selectedCount > 0; onClicked: Modals.pickTags("Remove tags from " + page.selectedCount + " scenarios", [], function (ids) { page.bulk({ removeTags: ids }, "Tags removed") }) }
            Btn { small: true; icon: "star"; text: "Favorite"; enabled: page.selectedCount > 0; onClicked: page.bulk({ favorite: true }, "Added to favorites") }
            Btn { small: true; icon: page.ui.quick === "hidden" ? "eye" : "eyeOff"; text: page.ui.quick === "hidden" ? "Unhide" : "Hide"; enabled: page.selectedCount > 0
                  onClicked: page.bulk({ hidden: page.ui.quick !== "hidden" }, page.ui.quick === "hidden" ? "Unhidden" : "Hidden") }
            Btn { small: true; icon: "download"; text: "Export pack"; enabled: page.selectedCount > 0; onClicked: Store.exportItems({ scenarios: Object.keys(page.selectedNames), name: page.selectedCount + " scenarios" }) }
            Btn { small: true; kind: "ghost"; icon: "x"; tip: "Done"; onClicked: page.clearSelection() }
        }
    }
}
