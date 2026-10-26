import QtQuick
import QtQuick.Layouts
import Kplus

// Player picker: favourites and Steam friends (filtered as you type), plus evxl search on Enter.
Item {
    id: root
    property var dialog
    property var friends: null
    property string friendsError: ""
    property var hits: null
    property bool searching: false
    property int token: 0
    implicitHeight: 460

    Component.onCompleted: {
        input.focusInput()
        if (Store.config.steamId) Backend.call("lb.friends", {}, function (l) { root.friends = l || [] }, function (e) { root.friendsError = "Couldn't load friends: " + e })
    }
    function q() { return input.text.trim().toLowerCase() }
    function match(p) { var s = q(); return !s || (p.name || "").toLowerCase().indexOf(s) >= 0 || (p.steamAccountName || "").toLowerCase().indexOf(s) >= 0 || p.steamId === s }
    readonly property var favs: { var _ = input.text; return Store.favoritePlayers().filter(match) }
    readonly property var friendList: {
        var _ = input.text
        var ids = {}
        Store.favoritePlayers().forEach(function (p) { ids[p.steamId] = true })
        return (friends || []).filter(function (p) { return !ids[p.steamId] }).filter(match).sort(function (a, b) { return a.name.localeCompare(b.name) })
    }
    function open(p) { dialog.close(null); Store.viewPlayer(p) }
    function search() {
        var s = input.text.trim()
        if (!s) return
        var t = ++token
        searching = true
        Backend.call("player.search", { query: s }, function (list) {
            if (t !== token) return
            searching = false
            if (list.length === 1 && /^\d{17}$|steamcommunity|evxl\.app/i.test(s)) { open(list[0]); return }
            hits = list
        }, function (e) { if (t === token) { searching = false; hits = []; Store.toast(e, "error") } })
    }

    ColumnLayout {
        anchors.fill: parent; spacing: 10
        RowLayout { Layout.fillWidth: true; spacing: 8
            Field { id: input; Layout.fillWidth: true; placeholder: "Filter, or search a Steam name, SteamID64 or profile link"; onAccepted: root.search(); onEdited: root.hits = null }
            Btn { kind: "primary"; icon: "search"; text: "Search"; onClicked: root.search() } }
        Txt { text: "Typing filters your favorites and friends. Press Enter to search everyone on evxl.app (names, SteamID64, Steam or evxl.app links)."; font.pixelSize: 12; color: Theme.muted; wrapMode: Text.WordWrap; Layout.fillWidth: true }
        Flickable {
            Layout.fillWidth: true; Layout.fillHeight: true; clip: true; contentHeight: list.implicitHeight; boundsBehavior: Flickable.StopAtBounds
            ColumnLayout {
                id: list; width: parent.width; spacing: 2
                RowLayout { visible: root.searching; spacing: 10; Spinner {} Txt { text: "Searching evxl.app…"; color: Theme.muted; font.pixelSize: 12 } }
                Txt { visible: !!root.hits; text: "Search results · " + (root.hits ? root.hits.length : 0); w: 700; font.pixelSize: 12; color: Theme.muted; Layout.topMargin: 6 }
                Repeater { model: root.hits || []; delegate: PlayerHit { required property var modelData; p: modelData; Layout.fillWidth: true; onChosen: root.open(modelData) } }
                Txt { visible: !!root.hits && root.hits.length === 0; text: "No players found. Try their Steam profile link or SteamID64."; color: Theme.muted; font.pixelSize: 12 }
                Txt { text: "Favorites · " + root.favs.length; w: 700; font.pixelSize: 12; color: Theme.muted; Layout.topMargin: 10 }
                Repeater { model: root.favs; delegate: PlayerHit { required property var modelData; p: modelData; Layout.fillWidth: true; onChosen: root.open(modelData) } }
                Txt { visible: root.favs.length === 0; text: input.text ? "No favorites match." : "Star a player to keep them here."; color: Theme.muted; font.pixelSize: 12 }
                Txt { text: "Friends" + (root.friends ? " · " + root.friendList.length : ""); w: 700; font.pixelSize: 12; color: Theme.muted; Layout.topMargin: 10 }
                Txt { visible: !Store.config.steamId; text: "Add your Steam ID in App Settings to see your Steam friends."; color: Theme.muted; font.pixelSize: 12 }
                Txt { visible: root.friendsError !== ""; text: root.friendsError; color: Theme.muted; font.pixelSize: 12 }
                RowLayout { visible: !!Store.config.steamId && !root.friends && root.friendsError === ""; spacing: 10; Spinner {} Txt { text: "Loading your Steam friends…"; color: Theme.muted; font.pixelSize: 12 } }
                Repeater { model: root.friendList; delegate: PlayerHit { required property var modelData; p: modelData; Layout.fillWidth: true; onChosen: root.open(modelData) } }
                Txt { visible: !!root.friends && root.friendList.length === 0; text: input.text ? "No friends match." : "None of your Steam friends are on evxl.app yet."; color: Theme.muted; font.pixelSize: 12 }
            }
        }
    }
}
