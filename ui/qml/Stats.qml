import QtQuick
import QtQuick.Layouts
import Kplus
import "js/Fmt.js" as Fmt

PageScroll {
    id: page
    property var overview: null
    property int range: 30
    property string posMode: "percentile"
    property var positions: null
    property string posError: ""

    function load() {
        Backend.call("stats.overview", {}, function (o) { page.overview = o }, function (e) { Store.toast(e, "error") })
        Store.loadLibrary()
    }
    function loadPositions() {
        if (!Store.config.steamId || positions) return
        Backend.call("stats.positions", {}, function (p) { page.positions = p }, function (e) { page.posError = e })
    }
    Component.onCompleted: { load(); loadPositions() }
    Connections { target: Store; function onStatsReadyChanged() { page.load() } }

    readonly property var days: {
        var out = [], d = new Date()
        d.setDate(d.getDate() - (range - 1))
        var p = function (n) { return n < 10 ? "0" + n : "" + n }
        var M = ["Jan", "Feb", "Mar", "Apr", "May", "Jun", "Jul", "Aug", "Sep", "Oct", "Nov", "Dec"], W = ["Sun", "Mon", "Tue", "Wed", "Thu", "Fri", "Sat"]
        for (var i = 0; i < range; i++) {
            out.push({ key: d.getFullYear() + "-" + p(d.getMonth() + 1) + "-" + p(d.getDate()), label: d.getDate() + (range > 30 ? " " + M[d.getMonth()] : ""), long: W[d.getDay()] + " " + d.getDate() + " " + M[d.getMonth()] })
            d.setDate(d.getDate() + 1)
        }
        return out
    }
    readonly property var byDay: { var m = {}; if (overview) overview.daily.forEach(function (d) { m[d.day] = d }); return m }
    readonly property var activityBars: days.map(function (d) { var v = byDay[d.key]; var m = v ? Math.round(v.seconds / 60) : 0; return { label: d.label, value: m, tip: d.long + ": <b>" + m + " min</b> · " + (v ? v.runs : 0) + " runs" } })
    readonly property var pbBars: days.map(function (d) { var v = byDay[d.key]; return { label: d.label, value: v ? v.pbs : 0, tip: d.long + ": <b>" + (v ? v.pbs : 0) + " PBs</b>", color: Theme.gold } })
    readonly property var tagRows: {
        var totals = {}
        Store.scenarios.forEach(function (s) { s.tags.forEach(function (t) { totals[t] = (totals[t] || 0) + (s.plays || 0) }) })
        return Store.tags.map(function (t) { return { t: t, plays: totals[t.id] || 0 } }).filter(function (x) { return x.plays }).sort(function (a, b) { return b.plays - a.plays })
    }
    readonly property real maxTag: Math.max.apply(null, [1].concat(tagRows.map(function (x) { return x.plays })))
    readonly property var recentPbs: overview ? overview.recent.filter(function (r) { return r.pb }).slice(0, 10) : []
    readonly property var posList: {
        if (!positions) return []
        return positions.slice().sort(function (a, b) { return posMode === "raw" ? a.position - b.position : a.percentile - b.percentile }).slice(0, 30)
    }

    PageHead { title: "Statistics"; subtitle: "Every run KovaaK's has saved to its stats folder." }

    Txt { visible: !page.overview; text: "Crunching your run history…"; color: Theme.muted; width: parent.width; horizontalAlignment: Text.AlignHCenter; topPadding: 40 }

    RowLayout {
        visible: !!page.overview; width: parent.width; spacing: 30
        StatTile { Layout.fillWidth: true; Layout.preferredWidth: 1; label: "Total runs"; value: page.overview ? page.overview.totalRuns.toLocaleString() : "" }
        StatTile { Layout.fillWidth: true; Layout.preferredWidth: 1; label: "Scenarios played"; value: page.overview ? page.overview.totalScenarios.toLocaleString() : "" }
        StatTile { Layout.fillWidth: true; Layout.preferredWidth: 1; label: "Time aiming"; value: page.overview ? Fmt.fmtDuration(page.overview.totalSeconds) : "" }
        StatTile { Layout.fillWidth: true; Layout.preferredWidth: 1; label: "Training since"; value: page.overview ? Fmt.fmtDate(page.overview.first) : "" }
    }

    Card {
        visible: !!page.overview; width: parent.width; pad: 18; height: heatCol.implicitHeight + 36
        ColumnLayout { id: heatCol; width: parent.width; spacing: 12
            RowLayout { Layout.fillWidth: true
                Txt { text: "Training calendar"; display: true; w: 600; font.pixelSize: 20; Layout.fillWidth: true }
                Txt { text: "runs per day, last 12 months"; font.pixelSize: 12; color: Theme.muted } }
            Heatmap { Layout.fillWidth: true; daily: page.overview ? page.overview.daily : [] } }
    }

    RowLayout {
        visible: !!page.overview; width: parent.width; spacing: 16
        Card { Layout.fillWidth: true; Layout.preferredWidth: 1; Layout.alignment: Qt.AlignTop; pad: 18; implicitHeight: a1.implicitHeight + 36
            ColumnLayout { id: a1; width: parent.width; spacing: 12
                RowLayout { Layout.fillWidth: true
                    Txt { text: "Time aiming per day"; display: true; w: 600; font.pixelSize: 20; Layout.fillWidth: true }
                    Seg { options: [{ value: 14, label: "14d" }, { value: 30, label: "30d" }, { value: 90, label: "90d" }]; value: page.range; onPicked: function (v) { page.range = v } } }
                BarChart { Layout.fillWidth: true; chartHeight: 170; labels: true; bars: page.activityBars } } }
        Card { Layout.fillWidth: true; Layout.preferredWidth: 1; Layout.alignment: Qt.AlignTop; pad: 18; implicitHeight: a2.implicitHeight + 36
            ColumnLayout { id: a2; width: parent.width; spacing: 12
                Txt { text: "Personal bests per day"; display: true; w: 600; font.pixelSize: 20 }
                BarChart { Layout.fillWidth: true; chartHeight: 170; labels: true; bars: page.pbBars; barColor: Theme.gold } } }
    }

    RowLayout {
        visible: !!page.overview; width: parent.width; spacing: 16
        Card { Layout.fillWidth: true; Layout.preferredWidth: 1; Layout.alignment: Qt.AlignTop; pad: 18; implicitHeight: tc.implicitHeight + 36
            ColumnLayout { id: tc; width: parent.width; spacing: 10
                RowLayout { spacing: 8; Icon { name: "tag"; size: 16; color: Theme.muted } Txt { text: "Runs by tag"; display: true; w: 600; font.pixelSize: 20 } }
                Txt { visible: page.tagRows.length === 0; text: "Tag your scenarios to see where your training time goes."; color: Theme.muted; font.pixelSize: 13 }
                Repeater {
                    model: page.tagRows.slice(0, 14)
                    delegate: RowLayout {
                        required property var modelData
                        Layout.fillWidth: true; spacing: 10
                        Txt { text: modelData.t.name; Layout.preferredWidth: 140; elide: Text.ElideRight }
                        Progress { Layout.fillWidth: true; implicitHeight: 10; value: modelData.plays / page.maxTag; fill: modelData.t.color }
                        Txt { text: modelData.plays.toLocaleString(); color: Theme.muted; font.pixelSize: 12; Layout.preferredWidth: 60; horizontalAlignment: Text.AlignRight }
                        MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor; onClicked: Store.go("library?tag=" + modelData.t.id) }
                    }
                } } }
        Card { Layout.fillWidth: true; Layout.preferredWidth: 1; Layout.alignment: Qt.AlignTop; pad: 18; implicitHeight: pc.implicitHeight + 36
            ColumnLayout { id: pc; width: parent.width; spacing: 6
                RowLayout { spacing: 8; Icon { name: "trophy"; size: 16; color: Theme.muted } Txt { text: "Latest personal bests"; display: true; w: 600; font.pixelSize: 20 } }
                Txt { visible: page.recentPbs.length === 0; text: "No PBs in your last 60 runs. Time for a new one?"; color: Theme.muted; font.pixelSize: 13 }
                Repeater {
                    model: page.recentPbs
                    delegate: Rectangle {
                        required property var modelData
                        Layout.fillWidth: true; Layout.preferredHeight: 34; color: ra.containsMouse ? Theme.surface2 : "transparent"
                        Rectangle { width: 3; height: parent.height; color: Theme.gold }
                        RowLayout { anchors.fill: parent; anchors.leftMargin: 10; anchors.rightMargin: 10; spacing: 10
                            Txt { text: Store.displayName(Store.scenario(modelData.scenario)) || modelData.scenario; elide: Text.ElideRight; Layout.fillWidth: true }
                            Txt { text: Fmt.fmtScore(modelData.score); w: 700; color: Theme.mix(Theme.gold, Theme.text, 30) }
                            Txt { text: Fmt.timeAgo(modelData.date); color: Theme.muted; Layout.preferredWidth: 70; horizontalAlignment: Text.AlignRight; font.pixelSize: 13 } }
                        HoverPreview { name: modelData.scenario }
                        MouseArea { id: ra; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; acceptedButtons: Qt.LeftButton | Qt.RightButton
                                    onClicked: function (m) { if (m.button === Qt.RightButton) { var p = mapToItem(Modals.menuHost, m.x, m.y); Store.scenarioMenu(modelData.scenario, p.x, p.y) } else Store.openScenario(modelData.scenario) } }
                    }
                } } }
    }

    Card {
        visible: !!page.overview; width: parent.width; pad: 18; implicitHeight: mp.implicitHeight + 36
        ColumnLayout { id: mp; width: parent.width; spacing: 4
            Txt { text: "Most played scenarios"; display: true; w: 600; font.pixelSize: 20; Layout.bottomMargin: 8 }
            RowLayout { Layout.fillWidth: true; Layout.leftMargin: 10; Layout.rightMargin: 10; spacing: 10
                Txt { text: "#"; color: Theme.muted; font.pixelSize: 12; Layout.preferredWidth: 30 }
                Txt { text: "Scenario"; color: Theme.muted; font.pixelSize: 12; Layout.fillWidth: true }
                Txt { text: "Plays"; color: Theme.muted; font.pixelSize: 12; Layout.preferredWidth: 70; horizontalAlignment: Text.AlignRight }
                Txt { text: "Time"; color: Theme.muted; font.pixelSize: 12; Layout.preferredWidth: 80; horizontalAlignment: Text.AlignRight }
                Txt { text: "PB"; color: Theme.muted; font.pixelSize: 12; Layout.preferredWidth: 90; horizontalAlignment: Text.AlignRight }
                Txt { text: "Last played"; color: Theme.muted; font.pixelSize: 12; Layout.preferredWidth: 90; horizontalAlignment: Text.AlignRight } }
            Repeater {
                model: page.overview ? page.overview.top : []
                delegate: Rectangle {
                    required property var modelData
                    required property int index
                    Layout.fillWidth: true; Layout.preferredHeight: 34; color: tr.containsMouse ? Theme.surface2 : "transparent"
                    RowLayout { anchors.fill: parent; anchors.leftMargin: 10; anchors.rightMargin: 10; spacing: 10
                        Txt { text: String(index + 1); color: Theme.muted; Layout.preferredWidth: 30 }
                        Txt { text: Store.displayName(Store.scenario(modelData.scenario)) || modelData.scenario; elide: Text.ElideRight; Layout.fillWidth: true }
                        Txt { text: String(modelData.plays); Layout.preferredWidth: 70; horizontalAlignment: Text.AlignRight }
                        Txt { text: Fmt.fmtDuration(modelData.seconds); color: Theme.muted; Layout.preferredWidth: 80; horizontalAlignment: Text.AlignRight }
                        Txt { text: Fmt.fmtScore(modelData.pb); w: 700; Layout.preferredWidth: 90; horizontalAlignment: Text.AlignRight }
                        Txt { text: Fmt.timeAgo(modelData.last); color: Theme.muted; Layout.preferredWidth: 90; horizontalAlignment: Text.AlignRight } }
                    HoverPreview { name: modelData.scenario }
                    MouseArea { id: tr; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; acceptedButtons: Qt.LeftButton | Qt.RightButton
                                onClicked: function (m) { if (m.button === Qt.RightButton) { var p = mapToItem(Modals.menuHost, m.x, m.y); Store.scenarioMenu(modelData.scenario, p.x, p.y) } else Store.openScenario(modelData.scenario) } }
                }
            } } }

    Card {
        visible: !!page.overview; width: parent.width; pad: 18; implicitHeight: pcol.implicitHeight + 36
        ColumnLayout { id: pcol; width: parent.width; spacing: 4
            RowLayout { Layout.fillWidth: true; Layout.bottomMargin: 8; spacing: 8
                Icon { name: "medal"; size: 16; color: Theme.muted }
                Txt { text: "Best leaderboard positions"; display: true; w: 600; font.pixelSize: 20; Layout.fillWidth: true }
                Seg { options: [{ value: "percentile", label: "By percentile" }, { value: "raw", label: "By position" }]; value: page.posMode; onPicked: function (v) { page.posMode = v } } }
            Txt { visible: !Store.config.steamId; text: "Add your Steam ID in App Settings to see your leaderboard positions."; color: Theme.muted; font.pixelSize: 13 }
            RowLayout { visible: !!Store.config.steamId && !page.positions && page.posError === ""; spacing: 10; Spinner {} Txt { text: "Loading positions from evxl.app…"; color: Theme.muted; font.pixelSize: 12 } }
            Txt { visible: page.posError !== ""; text: page.posError; color: Theme.muted; font.pixelSize: 13 }
            Txt { visible: !!page.positions && page.posList.length === 0; text: "No ranked results yet."; color: Theme.muted; font.pixelSize: 13 }
            Repeater {
                model: page.posList
                delegate: Rectangle {
                    required property var modelData
                    required property int index
                    Layout.fillWidth: true; Layout.preferredHeight: 34; color: pr.containsMouse ? Theme.surface2 : "transparent"
                    RowLayout { anchors.fill: parent; anchors.leftMargin: 10; anchors.rightMargin: 10; spacing: 10
                        Txt { text: String(index + 1); color: Theme.muted; Layout.preferredWidth: 30 }
                        Txt { text: Store.displayName(Store.scenario(modelData.name)) || modelData.name; elide: Text.ElideRight; Layout.fillWidth: true }
                        Txt { text: "#" + modelData.position.toLocaleString(); w: 700; Layout.preferredWidth: 90; horizontalAlignment: Text.AlignRight }
                        Txt { text: modelData.players.toLocaleString(); color: Theme.muted; Layout.preferredWidth: 90; horizontalAlignment: Text.AlignRight }
                        Rectangle { Layout.preferredWidth: 70; Layout.preferredHeight: 20; radius: 3; color: modelData.percentile <= 1 ? Theme.alpha(Theme.gold, 0.18) : Theme.surface3
                                    Txt { anchors.centerIn: parent; font.pixelSize: 11; w: 700; color: modelData.percentile <= 1 ? Theme.gold : Theme.text2
                                          text: (modelData.percentile < 0.1 ? modelData.percentile.toFixed(3) : modelData.percentile < 1 ? modelData.percentile.toFixed(2) : modelData.percentile.toFixed(1)) + "%" } } }
                    HoverPreview { name: modelData.name }
                    MouseArea { id: pr; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; acceptedButtons: Qt.LeftButton | Qt.RightButton
                                onClicked: function (m) { if (m.button === Qt.RightButton) { var p = mapToItem(Modals.menuHost, m.x, m.y); Store.scenarioMenu(modelData.name, p.x, p.y) } else Store.openScenario(modelData.name) } }
                }
            }
            Txt { visible: !!page.positions; text: (page.positions ? page.positions.length : 0) + " rated scenarios · updated daily by evxl.app from KovaaK's leaderboards"; font.pixelSize: 12; color: Theme.muted; Layout.topMargin: 6 } } }
}
