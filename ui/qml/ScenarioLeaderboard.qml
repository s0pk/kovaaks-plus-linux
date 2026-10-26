import QtQuick
import QtQuick.Layouts
import Kplus
import "js/Fmt.js" as Fmt

// KovaaK's scenario leaderboard: global / friends / around me. `compact` is the short version for the drawer.
ColumnLayout {
    id: root
    property string name: ""
    property bool compact: false
    property int maxRows: compact ? 10 : 50
    property var rankMaxes: null
    property var rankNames: []
    property var ranks: []
    property string scope: Store.config.steamId ? "friends" : "global"
    property int page: 0
    property var res: null
    property string error: ""
    property bool loading: false
    spacing: 10

    function load() {
        loading = true; error = ""
        var sc = scope, pg = page
        Backend.call("lb.scenario", { name: name, scope: sc, page: pg, max: maxRows }, function (r) {
            loading = false
            if (r.error) { error = r.error; res = r; return }
            if (sc === "me" && r.page !== undefined && r.page !== null) page = r.page
            res = r
        }, function (e) { loading = false; error = e })
    }
    Component.onCompleted: load()

    readonly property var rows: {
        var list = (res && res.rows) || []
        if (compact && list.length > maxRows) {
            var self = list.filter(function (r) { return r.self })[0]
            var top = list.slice(0, maxRows)
            if (self && top.indexOf(self) < 0) top = top.slice(0, maxRows - 1).concat([self])
            return top
        }
        return list
    }

    function rankOf(score) {
        if (!rankMaxes || !rankMaxes.length || !score) return { r: 0, over: null }
        var r = rankMaxes.filter(function (t) { return score >= t }).length
        var base = r > 0 ? rankMaxes[r - 1] : rankMaxes[0]
        return { r: r, over: base ? (score / base - 1) : null }
    }

    RowLayout {
        Layout.fillWidth: true; spacing: 10
        Seg {
            options: [{ value: "global", label: "Global" }, { value: "friends", label: "Friends" }, { value: "me", label: "My position" }]
            value: root.scope
            onPicked: function (v) { root.scope = v; root.page = 0; root.load() }
        }
        Rectangle {
            visible: !!(root.res && root.res.me && root.res.me.position)
            implicitWidth: meRow.implicitWidth + 24; implicitHeight: 30; radius: Theme.radiusSm; color: Theme.accentSoft; border.width: 1; border.color: Theme.accentLine
            Row { id: meRow; anchors.centerIn: parent; spacing: 6
                Icon { name: "medal"; size: 15; color: Theme.text; anchors.verticalCenter: parent.verticalCenter }
                Txt { text: "You:"; anchors.verticalCenter: parent.verticalCenter }
                Txt { text: root.res && root.res.me ? "#" + Number(root.res.me.position).toLocaleString() : ""; w: 700; anchors.verticalCenter: parent.verticalCenter }
                Txt { text: root.res && root.res.me ? "of " + Number(root.res.me.players).toLocaleString() + " · top " + (root.res.me.position / root.res.me.players * 100).toFixed(root.res.me.position / root.res.me.players < 0.01 ? 2 : 1) + "%" : ""; color: Theme.muted; anchors.verticalCenter: parent.verticalCenter }
            }
        }
        Txt { visible: !!(root.res && root.res.localBest && root.scope !== "friends" && !(root.res.me && root.res.me.position)); text: "Your best: " + (root.res ? Fmt.fmtScore(root.res.localBest) : ""); color: Theme.muted; font.pixelSize: 12 }
        Item { Layout.fillWidth: true }
        RowLayout {
            visible: !!(root.res && root.res.total && root.scope !== "friends" && !root.compact); spacing: 8
            Btn { small: true; icon: "arrowLeft"; enabled: root.page > 0; onClicked: { root.page--; root.load() } }
            Txt { text: "Page " + (root.page + 1) + " of " + Math.max(1, Math.ceil(((root.res && root.res.total) || 0) / root.maxRows)).toLocaleString(); color: Theme.muted; font.pixelSize: 12 }
            Btn { small: true; icon: "arrowLeft"; iconFlip: true; enabled: !!root.res && root.page + 1 < Math.ceil((root.res.total || 0) / root.maxRows); onClicked: { root.page++; root.load() } }
        }
        Txt { visible: !!(root.res && root.res.scope !== "friends" && root.res.total && root.compact); text: root.res ? Number(root.res.total).toLocaleString() + " players" : ""; color: Theme.muted; font.pixelSize: 12 }
        Txt { visible: root.scope === "friends" && !!(root.res && root.res.friendCount !== undefined); text: root.res ? root.res.friendCount + " friends play KovaaK's" : ""; color: Theme.muted; font.pixelSize: 12 }
    }

    RowLayout { visible: root.loading; spacing: 10; Spinner {} Txt { text: root.scope === "friends" ? "Checking your friends' scores…" : "Loading leaderboard…"; color: Theme.muted; font.pixelSize: 12 } }
    Txt { visible: !root.loading && root.error !== ""; text: root.error; color: Theme.muted; font.pixelSize: 12 }
    Txt { visible: !root.loading && root.error === "" && root.res && root.rows.length === 0; text: root.scope === "friends" ? "None of your Steam friends have a score here yet." : "No scores yet."; color: Theme.muted; font.pixelSize: 12 }

    // header
    RowLayout {
        visible: root.rows.length > 0 && !root.loading
        Layout.fillWidth: true; Layout.leftMargin: 10; Layout.rightMargin: 10; spacing: 10
        Txt { text: "Pos"; color: Theme.muted; font.pixelSize: 12; Layout.preferredWidth: 56 }
        Txt { text: "Player"; color: Theme.muted; font.pixelSize: 12; Layout.fillWidth: true }
        Txt { text: "Score"; color: Theme.muted; font.pixelSize: 12; Layout.preferredWidth: 80; horizontalAlignment: Text.AlignRight }
        Txt { visible: !!root.rankMaxes; text: "Rank"; color: Theme.muted; font.pixelSize: 12; Layout.preferredWidth: 130 }
        Txt { visible: !root.compact; text: "Acc"; color: Theme.muted; font.pixelSize: 12; Layout.preferredWidth: 56; horizontalAlignment: Text.AlignRight }
        Txt { visible: !root.compact; text: "Sens"; color: Theme.muted; font.pixelSize: 12; Layout.preferredWidth: 80; horizontalAlignment: Text.AlignRight }
        Txt { visible: !root.compact; text: "Date"; color: Theme.muted; font.pixelSize: 12; Layout.preferredWidth: 70; horizontalAlignment: Text.AlignRight }
    }
    Repeater {
        model: root.loading ? [] : root.rows
        delegate: Rectangle {
            id: row
            required property var modelData
            Layout.fillWidth: true; Layout.preferredHeight: 34
            radius: Theme.radiusSm
            readonly property bool viewed: !!Store.viewing && modelData.steamId === Store.viewing.steamId
            color: modelData.self ? Theme.alpha(Theme.accent, 0.14) : viewed ? Theme.alpha(Theme.accent2, 0.14) : (area.containsMouse ? Theme.surface2 : "transparent")
            Rectangle { visible: !!modelData.self; width: 3; height: parent.height; color: Theme.accent }
            RowLayout {
                anchors.fill: parent; anchors.leftMargin: 10; anchors.rightMargin: 10; spacing: 10
                Txt { text: modelData.rank !== undefined && modelData.rank !== null ? "#" + Number(modelData.rank).toLocaleString() : "—"; w: 700
                      color: modelData.rank === 1 ? Theme.gold : modelData.rank === 2 ? "#cbd5e1" : modelData.rank === 3 ? "#d08a4c" : Theme.text2; Layout.preferredWidth: 56 }
                RowLayout { Layout.fillWidth: true; spacing: 9
                    Flag { cc: modelData.country || "" }
                    Txt { text: modelData.name || modelData.steamAccountName || modelData.webappUsername || "?"; w: modelData.self ? 700 : 400; elide: Text.ElideRight; Layout.fillWidth: true }
                    Rectangle { visible: !!modelData.self; width: youT.implicitWidth + 12; height: 18; radius: 3; color: Theme.accentSoft; Txt { id: youT; anchors.centerIn: parent; text: "You"; font.pixelSize: 11; w: 700 } }
                }
                Txt { text: Fmt.fmtScore(modelData.score); w: 700; Layout.preferredWidth: 80; horizontalAlignment: Text.AlignRight }
                Item {
                    visible: !!root.rankMaxes; Layout.preferredWidth: 130; Layout.preferredHeight: 22
                    readonly property var ro: root.rankOf(modelData.score)
                    readonly property var rk: ro.r > 0 ? ((root.rankNames || [])[ro.r - 1] || (root.ranks || [])[ro.r]) : null
                    RankPill { visible: !!parent.rk; compact: true; text: parent.rk ? (parent.rk.name.toUpperCase() + (parent.ro.over !== null && parent.ro.over > 0 ? "  +" + Math.round(parent.ro.over * 100) + "%" : "")) : ""; rc: parent.rk ? Fmt.rankColor(parent.rk, parent.ro.r) : Theme.muted }
                    Txt { visible: !parent.rk; text: "Unranked"; color: Theme.muted; font.pixelSize: 12 }
                }
                Txt { visible: !root.compact; text: modelData.accuracy !== undefined && modelData.accuracy !== null ? Fmt.fmtPct(modelData.accuracy) : "—"; color: Theme.muted; Layout.preferredWidth: 56; horizontalAlignment: Text.AlignRight }
                Txt { visible: !root.compact; text: modelData.cm360 ? (+modelData.cm360).toFixed(1) + " cm" : (modelData.sens ? (+modelData.sens).toFixed(2) + " " + (modelData.sensScale || "") : "—"); color: Theme.muted; Layout.preferredWidth: 80; horizontalAlignment: Text.AlignRight; elide: Text.ElideRight }
                Txt { visible: !root.compact; text: modelData.epoch ? Fmt.timeAgo(modelData.epoch) : ""; color: Theme.muted; Layout.preferredWidth: 70; horizontalAlignment: Text.AlignRight }
            }
            MouseArea {
                id: area; anchors.fill: parent; hoverEnabled: modelData.steamId; cursorShape: modelData.steamId ? Qt.PointingHandCursor : Qt.ArrowCursor
                acceptedButtons: Qt.LeftButton | Qt.RightButton
                onClicked: function (m) {
                    if (!modelData.steamId) return
                    var p = { steamId: modelData.steamId, name: modelData.name, country: modelData.country }
                    if (m.button === Qt.RightButton) { var pt = mapToItem(Modals.menuHost, m.x, m.y); Store.playerMenu(p, undefined, pt.x, pt.y) }
                    else Store.viewPlayer(p)
                }
            }
        }
    }
}
