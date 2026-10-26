import QtQuick
import QtQuick.Layouts
import Kplus

// Export dialog: pack name, author and description, then a native "save as" via the backend.
Item {
    id: root
    property var dialog
    property string packName: "My pack"
    property var scenarios: []
    property var presets: []
    implicitHeight: col.implicitHeight
    readonly property string contents: {
        var parts = []
        if (scenarios.length) parts.push(scenarios.length + " scenario" + (scenarios.length === 1 ? "" : "s"))
        if (presets.length) parts.push(presets.length + " preset" + (presets.length === 1 ? "" : "s"))
        return parts.join(" and ")
    }
    Component.onCompleted: { nameIn.text = packName; authorIn.text = Store.config.steamName || "" }

    function save() {
        Backend.call("packs.export", { name: nameIn.text.trim() || "Pack", author: authorIn.text.trim() || null, description: descIn.text.trim() || null, scenarios: scenarios, presets: presets }, function (res) {
            if (!res) return
            Store.toast("Exported " + res.scenarios + " scenario(s) and " + res.presets + " preset(s)", "ok")
            Backend.send("app.revealFile", { path: res.path })
        }, function (e) { Store.toast(e, "error") })
        return true
    }
    ColumnLayout {
        id: col; width: parent.width; spacing: 14
        Txt { Layout.fillWidth: true; wrapMode: Text.WordWrap; color: Theme.text2
              text: "Includes " + root.contents + ", plus custom names, tags, notes, thumbnails and previews. Friends import it with Kovaak's Plus → Import / Export (or by dropping the file onto the window)." }
        ColumnLayout { Layout.fillWidth: true; spacing: 6; Txt { text: "Pack name"; w: 600; color: Theme.text2; font.pixelSize: 13 } Field { id: nameIn; Layout.fillWidth: true } }
        ColumnLayout { Layout.fillWidth: true; spacing: 6; Txt { text: "Author"; w: 600; color: Theme.text2; font.pixelSize: 13 } Field { id: authorIn; Layout.fillWidth: true } }
        ColumnLayout { Layout.fillWidth: true; spacing: 6; Txt { text: "Description"; w: 600; color: Theme.text2; font.pixelSize: 13 }
                       Field { id: descIn; Layout.fillWidth: true; placeholder: "What's in this pack? (shown to whoever imports it)" } }
    }
}
