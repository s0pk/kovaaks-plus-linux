import QtQuick
import QtQuick.Layouts
import Kplus

// Quick chips for your favourite players on the Benchmarks pages.
Flow {
    id: root
    visible: Store.favoritePlayers().length > 0
    spacing: 8
    signal findRequested()
    Row {
        spacing: 5; height: 24
        Icon { name: "star"; size: 14; color: Theme.gold; anchors.verticalCenter: parent.verticalCenter }
        Txt { text: "Favorites"; font.pixelSize: 12; color: Theme.muted; anchors.verticalCenter: parent.verticalCenter }
    }
    Repeater {
        model: Store.favoritePlayers()
        delegate: Rectangle {
            required property var modelData
            readonly property bool on: !!Store.viewing && Store.viewing.steamId === modelData.steamId
            width: r.implicitWidth + 18; height: 24; radius: Theme.radiusSm
            color: on ? Theme.accentSoft : Theme.alpha(Theme.muted, a.containsMouse ? 0.26 : 0.16)
            border.width: 1; border.color: on ? Theme.accent : Theme.alpha(Theme.muted, 0.32)
            Row { id: r; anchors.centerIn: parent; spacing: 6
                Flag { cc: modelData.country || ""; anchors.verticalCenter: parent.verticalCenter }
                Txt { text: modelData.name; w: 600; font.pixelSize: 12; anchors.verticalCenter: parent.verticalCenter } }
            MouseArea { id: a; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onClicked: Store.viewPlayer(modelData) }
        }
    }
    Btn { small: true; kind: "ghost"; icon: "user"; text: "Friends & search"; onClicked: root.findRequested() }
}
