import QtQuick
import QtQuick.Layouts
import Kplus

Rectangle {
    id: root
    property var p: ({})
    signal chosen()
    implicitHeight: 38
    radius: Theme.radiusSm
    color: a.containsMouse ? Theme.surface2 : "transparent"
    border.width: a.containsMouse ? 1 : 0; border.color: Theme.border
    RowLayout {
        anchors.fill: parent; anchors.leftMargin: 10; anchors.rightMargin: 8; spacing: 10
        Flag { cc: root.p.country || "" }
        Txt { text: root.p.name || ""; w: 700 }
        Txt { visible: !!root.p.steamAccountName && root.p.steamAccountName !== root.p.name; text: "Steam: " + root.p.steamAccountName; font.pixelSize: 12; color: Theme.muted }
        Item { Layout.fillWidth: true }
        Rectangle { visible: root.p.steamId === Store.config.steamId; width: yt.implicitWidth + 12; height: 18; radius: 3; color: Theme.accentSoft; Txt { id: yt; anchors.centerIn: parent; text: "You"; font.pixelSize: 11; w: 700 } }
        Btn { visible: root.p.steamId !== Store.config.steamId; small: true; kind: "ghost"; icon: "star"; tip: "Favorite"; onClicked: Store.toggleFavoritePlayer(root.p) }
    }
    MouseArea { id: a; anchors.fill: parent; z: -1; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onClicked: root.chosen() }
}
