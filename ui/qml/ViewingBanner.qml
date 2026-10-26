import QtQuick
import QtQuick.Layouts
import Kplus

// Shown while someone else's benchmarks are displayed.
Card {
    id: root
    property string extraUrl: ""
    visible: !!Store.viewing
    height: visible ? 64 : 0
    border.color: Theme.mix(Theme.border, Theme.accent, 45)
    color: Theme.mix(Theme.surface, Theme.accent, 90)
    RowLayout {
        anchors.fill: parent; anchors.leftMargin: 16; anchors.rightMargin: 12; spacing: 12
        Icon { name: "user"; size: 20; color: Theme.accent }
        ColumnLayout { Layout.fillWidth: true; spacing: 2
            RowLayout { spacing: 6
                Txt { text: "Viewing" }
                Flag { cc: Store.viewing ? (Store.viewing.country || "") : "" }
                Txt { text: Store.viewing ? Store.viewing.name : ""; w: 700 }
                Txt { text: "’s benchmarks" }
                Btn { small: true; kind: "ghost"; icon: "star"; tip: "Favorite"; onClicked: Store.toggleFavoritePlayer(Store.viewing) } }
            Txt { text: "Their KovaaK's leaderboard scores. Goes back to yours when you leave Benchmarks."; font.pixelSize: 12; color: Theme.muted } }
        Btn { small: true; kind: "ghost"; icon: "external"; text: "evxl.app"; onClicked: Backend.send("app.openUrl", { url: root.extraUrl || (Store.viewing ? "https://evxl.app/u/" + Store.viewing.steamId : "") }) }
        Btn { small: true; icon: "search"; text: "Another player"; onClicked: Modals.findPlayer() }
        Btn { small: true; kind: "primary"; icon: "arrowLeft"; text: "Back to mine"; onClicked: Store.viewPlayer(null) }
    }
}
