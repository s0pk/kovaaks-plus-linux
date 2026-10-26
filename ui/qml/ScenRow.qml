import QtQuick
import QtQuick.Layouts
import Kplus
import "js/Fmt.js" as Fmt

// A scenario as a table row (list view).
Rectangle {
    id: root
    property var sc: ({})
    property bool selected: false
    readonly property var tagList: (sc.tags || []).map(function (id) { return Store.tagById(id) }).filter(function (t) { return t })
    signal activated(int modifiers)
    signal playRequested()
    signal menuRequested(real x, real y)
    implicitHeight: 50
    radius: Theme.radiusSm
    color: selected ? Theme.surface2 : (area.containsMouse ? Theme.surface : "transparent")
    border.width: selected ? 1 : 0
    border.color: Theme.text

    RowLayout {
        anchors.fill: parent; anchors.leftMargin: 12; anchors.rightMargin: 12; spacing: 14
        Thumb { Layout.preferredWidth: 64; Layout.alignment: Qt.AlignVCenter; label: false; name: root.sc.name || ""; media: root.sc.thumbnail || ""; tagColor: Store.primaryTagColor(root.sc); info: Store.artInfo(root.sc); tagMedia: root.sc.thumbnail ? [] : Store.tagThumbs(root.sc) }
        ColumnLayout {
            Layout.fillWidth: true; Layout.preferredWidth: 22; spacing: 0
            RowLayout { spacing: 6
                Icon { visible: !!root.sc.favorite; name: "star"; size: 13; color: Theme.gold }
                Txt { text: Store.displayName(root.sc); w: 600; elide: Text.ElideRight; Layout.fillWidth: true } }
            Txt { visible: !!root.sc.customName || !!root.sc.author; text: root.sc.customName ? root.sc.name : (root.sc.author || ""); font.pixelSize: 11; color: Theme.muted; elide: Text.ElideRight; Layout.fillWidth: true }
        }
        Row {
            Layout.fillWidth: true; Layout.preferredWidth: 16; spacing: 6; clip: true
            Repeater { model: root.tagList; delegate: Chip { required property var modelData; small: true; text: modelData.name; chipColor: modelData.color } }
        }
        Txt { text: Fmt.fmtScore(root.sc.pb); w: 600; Layout.preferredWidth: 90; horizontalAlignment: Text.AlignRight }
        Txt { text: String(root.sc.plays || 0); color: Theme.muted; Layout.preferredWidth: 60; horizontalAlignment: Text.AlignRight }
        Txt { text: root.sc.lastPlayed ? Fmt.timeAgo(root.sc.lastPlayed) : "never"; color: Theme.muted; font.pixelSize: 12; Layout.preferredWidth: 90 }
        Btn { small: true; icon: "play"; text: "Play"; onClicked: root.playRequested() }
    }
    HoverPreview { name: root.sc.name || "" }
    MouseArea {
        id: area; anchors.fill: parent; z: -1; hoverEnabled: true; cursorShape: Qt.PointingHandCursor
        acceptedButtons: Qt.LeftButton | Qt.RightButton
        onClicked: function (m) { if (m.button === Qt.RightButton) { var p = mapToItem(Modals.menuHost, m.x, m.y); root.menuRequested(p.x, p.y) } else root.activated(m.modifiers) }
    }
}
