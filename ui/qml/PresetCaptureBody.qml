import QtQuick
import QtQuick.Layouts
import Kplus
import "js/PresetLogic.js" as PL

// "New preset from current settings": a name, an optional description and which categories to include.
Item {
    id: root
    property var dialog
    property var chosen: ({ sens: true, fov: true, crosshair: true, visuals: true, audio: true, theme: true })
    implicitHeight: col.implicitHeight

    function save() {
        var name = nameIn.text.trim()
        if (!name) { Store.toast("Give it a name"); return false }
        var cats = PL.CAT_ORDER.filter(function (c) { return chosen[c] })
        if (!cats.length) { Store.toast("Pick at least one category"); return false }
        Backend.call("presets.capture", { name: name, description: descIn.text.trim() || null, categories: cats },
                     function () { Store.toast("Preset created", "ok"); Store.loadPresets() }, function (e) { Store.toast(e, "error") })
        return true
    }
    ColumnLayout {
        id: col; width: parent.width; spacing: 14
        ColumnLayout { Layout.fillWidth: true; spacing: 6
            Txt { text: "Name"; w: 600; color: Theme.text2; font.pixelSize: 13 }
            Field { id: nameIn; Layout.fillWidth: true; placeholder: "e.g. Tracking 40cm, Valorant clicking…" } }
        ColumnLayout { Layout.fillWidth: true; spacing: 6
            Txt { text: "Description"; w: 600; color: Theme.text2; font.pixelSize: 13 }
            Field { id: descIn; Layout.fillWidth: true; placeholder: "Optional description" } }
        ColumnLayout { Layout.fillWidth: true; spacing: 8
            Txt { text: "Include"; w: 600; color: Theme.text2; font.pixelSize: 13 }
            Flow { Layout.fillWidth: true; spacing: 6
                Repeater { model: PL.CAT_ORDER
                    delegate: Chip { required property string modelData; clickable: true; text: PL.CAT_LABELS[modelData]; on: !!root.chosen[modelData]
                        onClicked: { var c = {}; for (var k in root.chosen) c[k] = root.chosen[k]; c[modelData] = !c[modelData]; root.chosen = c } } } }
            Txt { Layout.fillWidth: true; wrapMode: Text.WordWrap; font.pixelSize: 12; color: Theme.muted
                  text: "Only the selected categories are saved and applied, so a \"Crosshair\" preset won't touch your sensitivity." } }
    }
}
