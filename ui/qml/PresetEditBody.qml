import QtQuick
import QtQuick.Layouts
import Kplus

// Edit a preset's name, description, thumbnail and preview.
Item {
    id: root
    property var dialog
    property var p: ({})
    property string thumb: ""
    property string preview: ""
    implicitHeight: col.implicitHeight
    Component.onCompleted: { nameIn.text = p.name; descIn.text = p.description || ""; thumb = p.thumbnail || ""; preview = p.preview || "" }

    function owner() { return "preset:" + p.name }
    function pick(kind, target, then) {
        Backend.call("media.pick", { kind: kind, owner: owner(), target: target }, function (f) { if (f) then(f) }, function (e) { Store.toast(e, "error") })
    }
    function importDropped(urls) {
        if (!urls.length) return
        var path = String(urls[0])
        var isVideo = /\.(gif|mp4|webm)$/i.test(path)
        Backend.call("media.importPath", { path: path, owner: owner(), target: isVideo ? "preview" : "thumbnail" }, function (f) { if (isVideo) preview = f; else thumb = f }, function (e) { Store.toast(e, "error") })
    }
    function save() {
        Backend.call("presets.save", { id: p.id, name: nameIn.text.trim() || p.name, description: descIn.text.trim() || null, thumbnail: thumb || null, preview: preview || null },
                     function () { Store.loadPresets() }, function (e) { Store.toast(e, "error") })
        return true
    }
    ColumnLayout {
        id: col; width: parent.width; spacing: 14
        ColumnLayout { Layout.fillWidth: true; spacing: 6
            Txt { text: "Name"; w: 600; color: Theme.text2; font.pixelSize: 13 }
            Field { id: nameIn; Layout.fillWidth: true } }
        ColumnLayout { Layout.fillWidth: true; spacing: 6
            Txt { text: "Description"; w: 600; color: Theme.text2; font.pixelSize: 13 }
            Field { id: descIn; Layout.fillWidth: true } }
        RowLayout { Layout.fillWidth: true; spacing: 14
            Thumb { Layout.preferredWidth: 160; name: root.p.name; media: root.thumb; label: false
                    DropArea { anchors.fill: parent; onDropped: function (d) { root.importDropped(d.urls) } } }
            ColumnLayout { Layout.alignment: Qt.AlignTop; spacing: 8
                Btn { small: true; icon: "image"; text: "Set thumbnail"; onClicked: root.pick("image", "thumbnail", function (f) { root.thumb = f }) }
                Btn { small: true; icon: "film"; text: root.preview ? "Change preview" : "Set preview"; onClicked: root.pick("video", "preview", function (f) { root.preview = f }) }
                Btn { visible: root.thumb !== "" || root.preview !== ""; small: true; kind: "ghost"; text: "Remove images"; onClicked: { root.thumb = ""; root.preview = "" } }
                Txt { visible: root.preview !== ""; text: "Preview: " + root.preview; font.pixelSize: 12; color: Theme.muted; elide: Text.ElideMiddle; Layout.maximumWidth: 260 } } }
    }
}
