import QtQuick
import QtQuick.Layouts
import Kplus
import "js/Fmt.js" as Fmt

// Benchmark boards (global / friends / country / country averages) and per-scenario boards, laid out like evxl.app.
ColumnLayout {
    id: root
    property var b: ({})
    property string mode: "overall"
    property string scope: "global"
    property int page: 0
    property string country: ""
    property string search: ""
    property string scenario: ""
    property var res: null
    property bool loading: false
    property string error: ""
    readonly property int maxRows: 50
    spacing: 10

    readonly property var allScenarios: { var l = []; ((b && b.categories) || []).forEach(function (c) { c.scenarios.forEach(function (s) { l.push(s) }) }); return l }
    Component.onCompleted: { scenario = allScenarios.length ? allScenarios[0].name : ""; load() }

    function ctxFor(name) {
        var s = allScenarios.filter(function (x) { return x.name === name })[0]
        return s ? { rankMaxes: s.rankMaxes, rankNames: b ? b.rankNames : [], ranks: b ? b.ranks : [] } : ({})
    }
    function load() {
        if (!b || !b.id) return
        if (mode === "scenario") { res = null; return }
        if (scope === "countries") {
            loading = true; error = ""
            Backend.call("lb.countries", { id: b.id }, function (r) { loading = false; res = r }, function (e) { loading = false; error = e })
            return
        }
        if (scope === "country" && !country) { res = null; error = ""; return }
        loading = true; error = ""
        Backend.call("lb.benchmark", { id: b.id, scope: scope === "country" ? "global" : scope, page: page, max: maxRows, search: search || null, country: scope === "country" ? country : null },
            function (r) { loading = false; res = r }, function (e) { loading = false; error = e })
    }
    readonly property var rows: res && res.data ? res.data : []

    function pillColor(name) {
        var base = (name || "").replace(/\s+complete$/i, "").trim()
        var all = ((b && b.rankNames) || []).concat((b && b.ranks) || [])
        var rk = all.filter(function (x) { return x.name && x.name.trim().toLowerCase() === base.toLowerCase() })[0] || { name: base }
        return Fmt.rankColor(rk, 3)
    }

    RowLayout {
        Layout.fillWidth: true; spacing: 8
        Seg { options: [{ value: "overall", label: "Overall" }, { value: "scenario", label: "Scenario" }]; value: root.mode; onPicked: function (v) { root.mode = v; root.page = 0; root.load() } }
        Select { visible: root.mode === "scenario"; implicitWidth: 280; options: root.allScenarios.map(function (s) { return { value: s.name, label: s.customName || s.name } }); value: root.scenario; onPicked: function (v) { root.scenario = v } }
        Seg { visible: root.mode === "overall"; options: [{ value: "global", label: "Global" }, { value: "friends", label: "Friends" }, { value: "country", label: "Country" }, { value: "countries", label: "Countries" }]
              value: root.scope === "me" ? "global" : root.scope; onPicked: function (v) { root.scope = v; root.page = 0; root.load() } }
        Field { visible: root.mode === "overall" && root.scope === "country"; implicitWidth: 60; placeholder: "AU"; text: root.country; onAccepted: { root.country = text.trim().toUpperCase(); root.page = 0; root.load() } }
        Btn { visible: root.mode === "overall" && root.scope !== "countries"; small: true; icon: "medal"; text: "My position"; onClicked: { root.scope = "me"; root.load() } }
        Field { visible: root.mode === "overall" && (root.scope === "global" || root.scope === "country"); implicitWidth: 200; placeholder: "Search by username…"; onEdited: function (t) { sdebounce.restart() }
                Timer { id: sdebounce; interval: 350; onTriggered: { root.search = parent.text.trim(); root.page = 0; root.load() } } }
        Item { Layout.fillWidth: true }
        RowLayout {
            visible: root.mode === "overall" && !!root.res && !!root.res.total && root.scope !== "countries" && root.scope !== "friends" && root.scope !== "me"; spacing: 8
            Btn { small: true; icon: "arrowLeft"; enabled: root.page > 0; onClicked: { root.page--; root.load() } }
            Txt { text: "Page " + (root.page + 1) + " of " + Math.max(1, Math.ceil(((root.res && root.res.total) || 0) / root.maxRows)).toLocaleString(); color: Theme.muted; font.pixelSize: 12 }
            Btn { small: true; icon: "arrowLeft"; iconFlip: true; enabled: !!root.res && root.page + 1 < Math.ceil((root.res.total || 0) / root.maxRows); onClicked: { root.page++; root.load() } }
        }
    }

    Loader {
        Layout.fillWidth: true; active: root.mode === "scenario"; visible: active
        sourceComponent: ScenarioLeaderboard { name: root.scenario; rankMaxes: root.ctxFor(root.scenario).rankMaxes || null; rankNames: (root.b && root.b.rankNames) || []; ranks: (root.b && root.b.ranks) || []; scope: "global" }
        onLoaded: item.load()
    }

    ColumnLayout {
        visible: root.mode === "overall"; Layout.fillWidth: true; spacing: 2
        RowLayout { visible: root.loading; spacing: 10; Spinner {} Txt { text: "Loading leaderboard…"; color: Theme.muted; font.pixelSize: 12 } }
        Txt { visible: !root.loading && root.error !== ""; text: root.error; color: Theme.muted; font.pixelSize: 12 }
        Txt { visible: !root.loading && root.error === "" && root.scope === "country" && !root.country; text: "Enter a two-letter country code (e.g. AU, US, GB)."; color: Theme.muted; font.pixelSize: 12 }
        Txt { visible: !root.loading && root.error === "" && !!root.res && root.rows.length === 0 && !(root.scope === "country" && !root.country)
              text: root.scope === "friends" ? "None of your friends are ranked on this benchmark yet." : root.scope === "me" ? "You're not on this leaderboard yet." : root.scope === "countries" ? "No country data for this benchmark yet." : "No results."; color: Theme.muted; font.pixelSize: 12 }

        // header
        RowLayout {
            visible: !root.loading && root.rows.length > 0; Layout.fillWidth: true; Layout.leftMargin: 10; Layout.rightMargin: 10; spacing: 10
            Txt { text: root.scope === "countries" ? "Pos" : "Pos"; color: Theme.muted; font.pixelSize: 12; Layout.preferredWidth: 56 }
            Txt { text: root.scope === "countries" ? "Country" : "Player"; color: Theme.muted; font.pixelSize: 12; Layout.fillWidth: true }
            Txt { text: root.scope === "countries" ? "Players" : "Rank"; color: Theme.muted; font.pixelSize: 12; Layout.preferredWidth: root.scope === "countries" ? 70 : 150; horizontalAlignment: root.scope === "countries" ? Text.AlignRight : Text.AlignLeft }
            Txt { text: root.scope === "countries" ? "Avg rank" : "Energy"; color: Theme.muted; font.pixelSize: 12; Layout.preferredWidth: root.scope === "countries" ? 150 : 70; horizontalAlignment: root.scope === "countries" ? Text.AlignLeft : Text.AlignRight }
            Txt { text: root.scope === "countries" ? "Avg energy" : "Progress"; color: Theme.muted; font.pixelSize: 12; Layout.preferredWidth: 80; horizontalAlignment: Text.AlignRight }
            Txt { text: root.scope === "countries" ? "Avg cm/360" : "cm/360"; color: Theme.muted; font.pixelSize: 12; Layout.preferredWidth: 80; horizontalAlignment: Text.AlignRight }
            Txt { visible: root.scope !== "countries"; text: "Last"; color: Theme.muted; font.pixelSize: 12; Layout.preferredWidth: 70; horizontalAlignment: Text.AlignRight }
        }
        Repeater {
            model: root.loading ? [] : root.rows
            delegate: Rectangle {
                id: lr
                required property var modelData
                required property int index
                readonly property bool countries: root.scope === "countries"
                readonly property bool self: !countries && modelData.steamId === Store.config.steamId
                Layout.fillWidth: true; Layout.preferredHeight: 34; radius: Theme.radiusSm
                color: self ? Theme.alpha(Theme.accent, 0.14) : (area.containsMouse ? Theme.surface2 : "transparent")
                Rectangle { visible: lr.self; width: 3; height: parent.height; color: Theme.accent }
                RowLayout {
                    anchors.fill: parent; anchors.leftMargin: 10; anchors.rightMargin: 10; spacing: 10
                    Txt { text: lr.countries ? "#" + (lr.index + 1) : (lr.modelData.position !== undefined && lr.modelData.position !== null ? "#" + Number(lr.modelData.position).toLocaleString() : "—"); w: 700
                          color: (lr.countries ? lr.index + 1 : lr.modelData.position) === 1 ? Theme.gold : (lr.countries ? lr.index + 1 : lr.modelData.position) === 2 ? "#cbd5e1" : (lr.countries ? lr.index + 1 : lr.modelData.position) === 3 ? "#d08a4c" : Theme.text2; Layout.preferredWidth: 56 }
                    RowLayout { Layout.fillWidth: true; spacing: 9
                        Flag { cc: lr.modelData.country || "" }
                        Txt { text: lr.countries ? lr.modelData.country : (lr.modelData.webappUsername || lr.modelData.steamAccountName || "?"); w: lr.self ? 700 : 400; elide: Text.ElideRight; Layout.fillWidth: true }
                        Rectangle { visible: lr.self; width: yt.implicitWidth + 12; height: 18; radius: 3; color: Theme.accentSoft; Txt { id: yt; anchors.centerIn: parent; text: "You"; font.pixelSize: 11; w: 700 } } }
                    Txt { visible: lr.countries; text: String(lr.modelData.totalPlayers); Layout.preferredWidth: 70; horizontalAlignment: Text.AlignRight }
                    Item { Layout.preferredWidth: lr.countries ? 150 : 150; Layout.preferredHeight: 22
                        RankPill { visible: !!(lr.countries ? lr.modelData.avgRankName : lr.modelData.rankName); compact: true; text: lr.countries ? (lr.modelData.avgRankName || "") : (lr.modelData.rankName || ""); rc: root.pillColor(lr.countries ? lr.modelData.avgRankName : lr.modelData.rankName) }
                        Txt { visible: !(lr.countries ? lr.modelData.avgRankName : lr.modelData.rankName); text: "—"; color: Theme.muted } }
                    Txt { text: lr.countries ? (lr.modelData.avgEnergy !== null && lr.modelData.avgEnergy !== undefined ? String(Math.round(lr.modelData.avgEnergy)) : "—") : (lr.modelData.energy !== null && lr.modelData.energy !== undefined ? String(Math.round(lr.modelData.energy)) : "—"); w: 700
                          Layout.preferredWidth: lr.countries ? 80 : 70; horizontalAlignment: Text.AlignRight; Layout.leftMargin: lr.countries ? 0 : 0 }
                    Txt { visible: !lr.countries; text: lr.modelData.progress !== null && lr.modelData.progress !== undefined ? Math.round(lr.modelData.progress * 100) + "%" : "—"; color: Theme.muted; Layout.preferredWidth: 80; horizontalAlignment: Text.AlignRight }
                    Txt { text: lr.countries ? (lr.modelData.avgCm360 ? lr.modelData.avgCm360.toFixed(1) : "—") : (lr.modelData.avgCm360 ? lr.modelData.avgCm360.toFixed(1) : "—"); color: Theme.muted; Layout.preferredWidth: 80; horizontalAlignment: Text.AlignRight }
                    Txt { visible: !lr.countries; text: lr.modelData.lastEpoch ? Fmt.timeAgo(lr.modelData.lastEpoch) : ""; color: Theme.muted; Layout.preferredWidth: 70; horizontalAlignment: Text.AlignRight }
                }
                MouseArea {
                    id: area; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; acceptedButtons: Qt.LeftButton | Qt.RightButton
                    onClicked: function (m) {
                        if (lr.countries) { root.country = lr.modelData.country; root.scope = "country"; root.page = 0; root.load(); return }
                        if (!lr.modelData.steamId) return
                        var p = { steamId: lr.modelData.steamId, name: lr.modelData.webappUsername || lr.modelData.steamAccountName, country: lr.modelData.country }
                        if (m.button === Qt.RightButton) { var pt = mapToItem(Modals.menuHost, m.x, m.y); Store.playerMenu(p, root.b.id, pt.x, pt.y) }
                        else Store.viewPlayer(p, root.b.id)
                    }
                }
            }
        }
    }
}
