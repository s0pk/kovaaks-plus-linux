import QtQuick
import QtQuick.Layouts
import Kplus
import "js/Fmt.js" as Fmt

// A scenario in the grid: picture, name, tags, PB / plays / last played. Hover shows the reticle and a play button.
Rectangle {
    id: root
    property var sc: ({})
    property bool selected: false
    property bool selecting: false
    property bool showTags: true
    readonly property var tagList: (sc.tags || []).map(function (id) { return Store.tagById(id) }).filter(function (t) { return t })
    readonly property real bodyHeight: 92 + (showTags ? 26 : 0)
    signal activated(int modifiers)
    signal playRequested()
    signal menuRequested(real x, real y)

    implicitHeight: thumb.height + bodyHeight
    color: Theme.surface
    radius: Theme.radius
    border.width: 1
    border.color: selected ? Theme.text : (area.containsMouse ? Theme.border2 : Theme.border)
    clip: true

    Thumb {
        id: thumb
        width: parent.width
        name: root.sc.name || ""
        media: root.sc.thumbnail || ""
        tagColor: Store.primaryTagColor(root.sc)
        info: Store.artInfo(root.sc)
        tagMedia: root.sc.thumbnail ? [] : Store.tagThumbs(root.sc)
        // hover: play the preview (image, GIF or clip) over the thumbnail
        Loader {
            id: hoverMedia
            anchors.fill: parent
            active: false
            opacity: active ? 1 : 0
            sourceComponent: MediaView { file: root.sc.preview || "" }
        }
        Timer { id: hoverDelay; interval: 260; onTriggered: if (hh.hovered && Theme.hoverPreview && root.sc.preview) hoverMedia.active = true }
        HoverHandler { id: hh; onHoveredChanged: { if (hovered) hoverDelay.restart(); else { hoverDelay.stop(); hoverMedia.active = false } } }
        Row {
            x: 8; y: 8; spacing: 5
            Rectangle { visible: !!root.sc.favorite; width: 22; height: 22; radius: 3; color: "#a6141513"; Icon { anchors.centerIn: parent; name: "star"; size: 13; color: Theme.gold } }
            Rectangle { visible: !!(root.sc.benchmarks && root.sc.benchmarks.length); width: 22; height: 22; radius: 3; color: "#a6141513"; Icon { anchors.centerIn: parent; name: "trophy"; size: 13; color: Theme.gold } }
            Rectangle { visible: root.sc.installed === false; width: onl.implicitWidth + 12; height: 22; radius: 3; color: "#a6141513"; Txt { id: onl; anchors.centerIn: parent; text: "Online"; font.pixelSize: 11; w: 600 } }
        }
        Rectangle {   // selection box
            visible: root.selecting; anchors.right: parent.right; anchors.top: parent.top; anchors.margins: 8
            width: 22; height: 22; radius: 2; color: root.selected ? Theme.accent : "#59000000"
            border.width: 2; border.color: root.selected ? Theme.accent : "#b3ffffff"
            Icon { visible: root.selected; anchors.centerIn: parent; name: "check"; size: 14; color: Theme.onAccent }
        }
        Rectangle {   // play button
            visible: area.containsMouse && !root.selecting
            anchors.right: parent.right; anchors.bottom: parent.bottom; anchors.margins: 10
            width: 38; height: 38; radius: Theme.radiusSm; color: Theme.accent
            Icon { anchors.centerIn: parent; name: "play"; size: 18; color: Theme.onAccent }
            MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor; onClicked: root.playRequested() }
        }
    }

    Item {
        anchors.top: thumb.bottom; anchors.bottom: parent.bottom; anchors.left: parent.left; anchors.right: parent.right
        anchors.leftMargin: 13; anchors.rightMargin: 13; anchors.topMargin: 10; anchors.bottomMargin: 11
        Column {
            width: parent.width; spacing: 4
            Txt { width: parent.width; text: Store.displayName(root.sc); display: true; w: 600; font.pixelSize: 19; lineHeight: 1.05; wrapMode: Text.WordWrap; maximumLineCount: 2; elide: Text.ElideRight }
            Txt { visible: !!root.sc.customName; width: parent.width; text: root.sc.name || ""; font.pixelSize: 11; color: Theme.muted; elide: Text.ElideRight }
        }
        Row {
            visible: root.showTags && root.tagList.length > 0
            anchors.bottom: meta.top; anchors.bottomMargin: 8; spacing: 6
            Repeater { model: root.tagList.slice(0, 3); delegate: Chip { required property var modelData; small: true; text: modelData.name; chipColor: modelData.color } }
            Chip { visible: root.tagList.length > 3; small: true; text: "+" + (root.tagList.length - 3); chipColor: Theme.muted }
        }
        RowLayout {
            id: meta
            anchors.bottom: parent.bottom; width: parent.width; spacing: 12
            Txt { text: "PB"; font.pixelSize: 13; color: Theme.muted; Layout.rightMargin: -8 }
            Txt { text: Fmt.fmtScore(root.sc.pb); font.pixelSize: 13; w: 600 }
            Txt { text: (root.sc.plays || 0) + " plays"; font.pixelSize: 13; color: Theme.muted }
            Item { Layout.fillWidth: true }
            Txt { visible: !!root.sc.lastPlayed; text: Fmt.timeAgo(root.sc.lastPlayed); font.pixelSize: 13; color: Theme.muted }
        }
    }

    Brackets { opacity: (area.containsMouse || root.selected) ? 1 : 0 }

    MouseArea {
        id: area
        anchors.fill: parent
        z: -1
        hoverEnabled: true
        acceptedButtons: Qt.LeftButton | Qt.RightButton
        cursorShape: Qt.PointingHandCursor
        onClicked: function (m) {
            if (m.button === Qt.RightButton) { var p = mapToItem(Modals.menuHost, m.x, m.y); root.menuRequested(p.x, p.y) }
            else root.activated(m.modifiers)
        }
    }
}
