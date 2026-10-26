import QtQuick
import Kplus
import "js/Fmt.js" as Fmt

// The floating preview next to the cursor (list rows and table names). One at a time, driven by Store.hover.
Rectangle {
    id: root
    readonly property var h: Store.hover
    readonly property var sc: h ? Store.scenario(h.name) : null
    readonly property string file: sc ? (sc.preview || sc.thumbnail || "") : ""
    visible: !!sc && Theme.hoverPreview
    z: 70
    width: 300; height: 169 + body.implicitHeight + 24
    radius: Theme.radius; color: Theme.surface3; border.width: 1; border.color: Theme.border2; clip: true
    x: h ? (h.x + 18 + width > parent.width - 10 ? Math.max(10, h.x - width - 18) : h.x + 18) : 0
    y: h ? (h.y + 18 + height > parent.height - 10 ? Math.max(10, h.y - height - 14) : h.y + 18) : 0
    opacity: visible ? 1 : 0
    Behavior on opacity { NumberAnimation { duration: Theme.animMs } }
    enabled: false

    Item {
        width: parent.width; height: 169
        MediaView { anchors.fill: parent; visible: root.file !== ""; file: root.visible ? root.file : "" }
        Thumb { anchors.fill: parent; fill: true; visible: root.file === "" && !!root.sc; name: root.sc ? root.sc.name : ""; label: false
                tagColor: root.sc ? Store.primaryTagColor(root.sc) : ""; info: root.sc ? Store.artInfo(root.sc) : ""; tagMedia: root.sc ? Store.tagThumbs(root.sc) : [] }
    }
    Column {
        id: body
        x: 14; y: 169 + 12; width: parent.width - 28; spacing: 2
        Txt { text: root.sc ? Store.displayName(root.sc) : ""; w: 700; width: parent.width; elide: Text.ElideRight }
        Txt { width: parent.width; font.pixelSize: 12; color: Theme.muted; elide: Text.ElideRight
              text: root.sc ? (root.sc.pb !== null && root.sc.pb !== undefined ? "PB " + Fmt.fmtScore(root.sc.pb) + " · " : "") + (root.sc.plays || 0) + " plays" + (root.sc.preview ? "" : " · no preview set") : "" }
    }
}
