import QtQuick
import Kplus
import QtQuick.Layouts
import "js/Fmt.js" as Fmt

// A compact scenario row (picture, name, PB · last played, play button).
Rectangle {
    id: root
    property var sc: ({})
    implicitHeight: 52
    radius: Theme.radiusSm
    color: area.containsMouse ? Theme.surface3 : "transparent"
    RowLayout {
        anchors.fill: parent; anchors.leftMargin: 8; anchors.rightMargin: 8; spacing: 10
        Thumb { Layout.preferredWidth: 54; Layout.alignment: Qt.AlignVCenter; name: root.sc.name || ""; media: root.sc.thumbnail || ""; tagColor: Store.primaryTagColor(root.sc); info: Store.artInfo(root.sc); label: false; tagMedia: root.sc.thumbnail ? [] : Store.tagThumbs(root.sc) }
        ColumnLayout {
            Layout.fillWidth: true; spacing: 1
            Txt { text: Store.displayName(root.sc); w: 600; Layout.fillWidth: true; elide: Text.ElideRight }
            Txt { text: "PB " + Fmt.fmtScore(root.sc.pb) + " · " + Fmt.timeAgo(root.sc.lastPlayed); font.pixelSize: 12; color: Theme.muted }
        }
        Btn { small: true; icon: "play"; onClicked: Store.play(root.sc.name) }
    }
    HoverPreview { name: root.sc.name || "" }
    MouseArea {
        id: area; anchors.fill: parent; z: -1; hoverEnabled: true; cursorShape: Qt.PointingHandCursor
        acceptedButtons: Qt.LeftButton | Qt.RightButton
        onClicked: function (m) { if (m.button === Qt.RightButton) { var p = mapToItem(Modals.menuHost, m.x, m.y); Store.scenarioMenu(root.sc.name, p.x, p.y) } else Store.openScenario(root.sc.name) }
    }
}
