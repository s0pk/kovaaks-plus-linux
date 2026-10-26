import QtQuick
import QtQuick.Layouts
import QtQuick.Controls
import Kplus

PageScroll {
    id: page
    property var chosen: ({})          // scenario name -> true
    property var chosenPresets: ({})
    property string query: ""
    readonly property var lib: Store.scenarios
    readonly property var presets: Store.presets || []
    readonly property int nChosen: Object.keys(chosen).length
    readonly property int nPresets: Object.keys(chosenPresets).length
    readonly property var usedTags: Store.tags.filter(function (t) { return lib.some(function (s) { return s.tags.indexOf(t.id) >= 0 }) })
    readonly property var results: {
        var q = query.trim().toLowerCase()
        var l = q ? lib.filter(function (s) { return (s.name + " " + (s.customName || "")).toLowerCase().indexOf(q) >= 0 })
                  : lib.filter(function (s) { return s.plays }).sort(function (a, b) { return b.plays - a.plays })
        return l.slice(0, 80)
    }
    Component.onCompleted: { Store.loadLibrary(); Store.loadPresets() }

    function flip(map, key) { var m = {}; for (var k in map) m[k] = map[k]; if (m[key]) delete m[key]; else m[key] = true; return m }
    function addAll(names) { var m = {}; for (var k in chosen) m[k] = chosen[k]; names.forEach(function (n) { m[n] = true }); chosen = m }
    function pickImport() { Backend.call("packs.pickImport", {}, function (pv) { if (pv) Modals.importPack(pv) }, function (e) { Store.toast(e, "error") }) }

    PageHead { title: "Import / Export"; subtitle: "Share scenarios (with your names, tags and thumbnails) and settings presets as a single .kpack file." }

    RowLayout {
        width: parent.width; spacing: 18
        Card { Layout.fillWidth: true; Layout.preferredWidth: 1; Layout.alignment: Qt.AlignTop; pad: 18; implicitHeight: ic.implicitHeight + 36
            ColumnLayout { id: ic; width: parent.width; spacing: 12
                RowLayout { spacing: 8; Icon { name: "upload"; size: 16; color: Theme.muted } Txt { text: "Import a pack"; display: true; w: 600; font.pixelSize: 20 } }
                Txt { Layout.fillWidth: true; wrapMode: Text.WordWrap; color: Theme.muted; text: "Got a .kpack from a friend? Pick it here or just drop it anywhere on this window. You'll see exactly what's inside before anything is installed." }
                Btn { large: true; kind: "primary"; icon: "folder"; text: "Choose .kpack file…"; onClicked: page.pickImport() } } }
        Card { Layout.fillWidth: true; Layout.preferredWidth: 1; Layout.alignment: Qt.AlignTop; pad: 18; implicitHeight: qc.implicitHeight + 36
            ColumnLayout { id: qc; width: parent.width; spacing: 4
                RowLayout { Layout.bottomMargin: 6; spacing: 8; Icon { name: "layers"; size: 16; color: Theme.muted } Txt { text: "Quick exports"; display: true; w: 600; font.pixelSize: 20 } }
                Repeater {
                    model: [
                        { t: "Everything I've customized", d: "All scenarios with a custom name, tag, note or image, plus every preset. Good for backups or moving to a new PC.", id: "all" },
                        { t: "All presets", d: "Every settings preset you've saved.", id: "presets" },
                        { t: "Favorites", d: "Your starred scenarios.", id: "favs" } ]
                    delegate: Rectangle {
                        required property var modelData
                        Layout.fillWidth: true; implicitHeight: qr.implicitHeight + 20; radius: Theme.radiusSm; color: qa.containsMouse ? Theme.surface2 : "transparent"
                        RowLayout { id: qr; anchors.fill: parent; anchors.margins: 10; anchors.topMargin: 10; spacing: 10
                            ColumnLayout { Layout.fillWidth: true; spacing: 1
                                Txt { text: modelData.t; w: 600; Layout.fillWidth: true }
                                Txt { text: modelData.d; font.pixelSize: 12; color: Theme.muted; Layout.fillWidth: true; wrapMode: Text.WordWrap } }
                            Icon { name: "download"; size: 16; color: Theme.muted } }
                        MouseArea { id: qa; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor
                            onClicked: {
                                if (modelData.id === "all") Store.exportItems({ scenarios: page.lib.filter(function (s) { return s.customName || s.tags.length || s.hasNotes || s.thumbnail || s.favorite }).map(function (s) { return s.name }), presets: page.presets.map(function (p) { return p.id }), name: "My Kovaak's Plus setup" })
                                else if (modelData.id === "presets") { if (!page.presets.length) Store.toast("No presets yet"); else Store.exportItems({ presets: page.presets.map(function (p) { return p.id }), name: "My presets" }) }
                                else { var f = page.lib.filter(function (s) { return s.favorite }); if (!f.length) Store.toast("No favorites yet"); else Store.exportItems({ scenarios: f.map(function (s) { return s.name }), name: "Favorites" }) } } }
                    }
                } } }
    }

    Card {
        width: parent.width; pad: 18; implicitHeight: bc.implicitHeight + 36
        ColumnLayout { id: bc; width: parent.width; spacing: 12
            RowLayout { spacing: 8; Icon { name: "box"; size: 16; color: Theme.muted } Txt { text: "Build a custom pack"; display: true; w: 600; font.pixelSize: 20 } }
            Txt { Layout.fillWidth: true; font.pixelSize: 13; color: Theme.muted; wrapMode: Text.WordWrap
                  text: page.usedTags.length ? "Add whole tags at once:" : "Tip: once you tag scenarios, you can add a whole tag to a pack in one click here." }
            Flow { Layout.fillWidth: true; spacing: 6; visible: page.usedTags.length > 0
                Repeater { model: page.usedTags
                    delegate: Chip { required property var modelData; clickable: true; text: modelData.name; chipColor: modelData.color
                        onClicked: page.addAll(page.lib.filter(function (s) { return s.tags.indexOf(modelData.id) >= 0 }).map(function (s) { return s.name })) } } }
            RowLayout {
                Layout.fillWidth: true; spacing: 18
                ColumnLayout { Layout.fillWidth: true; Layout.preferredWidth: 1; Layout.alignment: Qt.AlignTop; spacing: 8
                    Field { Layout.fillWidth: true; icon: "search"; placeholder: "Search scenarios to add…"; onEdited: function (t) { page.query = t } }
                    Rectangle { Layout.fillWidth: true; Layout.preferredHeight: 340; radius: Theme.radiusSm; color: Theme.bg2; border.width: 1; border.color: Theme.border; clip: true
                        ListView {
                            anchors.fill: parent; anchors.margins: 1; model: page.results; boundsBehavior: Flickable.StopAtBounds; clip: true; ScrollBar.vertical: ThinScroll {}
                            delegate: Rectangle {
                                required property var modelData
                                width: ListView.view.width; height: 34; color: ra.containsMouse ? Theme.surface2 : "transparent"
                                RowLayout { anchors.fill: parent; anchors.leftMargin: 10; anchors.rightMargin: 10; spacing: 10
                                    Rectangle { width: 18; height: 18; radius: 3; color: page.chosen[modelData.name] ? Theme.accent : "transparent"; border.width: 1; border.color: page.chosen[modelData.name] ? Theme.accent : Theme.border2
                                                Icon { visible: !!page.chosen[modelData.name]; anchors.centerIn: parent; name: "check"; size: 12; color: Theme.onAccent } }
                                    Txt { Layout.fillWidth: true; elide: Text.ElideRight; text: Store.displayName(modelData) }
                                    Txt { visible: !modelData.installed; text: "not installed"; font.pixelSize: 11; color: Theme.muted } }
                                MouseArea { id: ra; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onClicked: page.chosen = page.flip(page.chosen, modelData.name) }
                            } } } }
                ColumnLayout { Layout.fillWidth: true; Layout.preferredWidth: 1; Layout.alignment: Qt.AlignTop; spacing: 8
                    Txt { text: "In this pack"; w: 700; color: Theme.muted; font.pixelSize: 12; Layout.preferredHeight: 34; verticalAlignment: Text.AlignVCenter }
                    Rectangle { Layout.fillWidth: true; Layout.preferredHeight: 340; radius: Theme.radiusSm; color: Theme.bg2; border.width: 1; border.color: Theme.border; clip: true
                        Txt { visible: page.nChosen === 0; anchors.centerIn: parent; text: "Nothing added yet."; color: Theme.muted; font.pixelSize: 13 }
                        ListView {
                            anchors.fill: parent; anchors.margins: 1; model: Object.keys(page.chosen); boundsBehavior: Flickable.StopAtBounds; clip: true; ScrollBar.vertical: ThinScroll {}
                            delegate: Rectangle {
                                required property string modelData
                                width: ListView.view.width; height: 34; color: "transparent"
                                RowLayout { anchors.fill: parent; anchors.leftMargin: 10; anchors.rightMargin: 4; spacing: 8
                                    Txt { Layout.fillWidth: true; elide: Text.ElideRight; text: Store.displayName(Store.scenario(modelData)) || modelData }
                                    Btn { small: true; kind: "ghost"; icon: "x"; implicitWidth: 24; implicitHeight: 24; onClicked: page.chosen = page.flip(page.chosen, modelData) } }
                            } } } }
            }
            ColumnLayout { Layout.fillWidth: true; spacing: 8
                Txt { text: "Presets:"; font.pixelSize: 13; color: Theme.muted }
                Txt { visible: page.presets.length === 0; text: "No presets saved yet."; font.pixelSize: 13; color: Theme.muted }
                Flow { Layout.fillWidth: true; spacing: 6
                    Repeater { model: page.presets
                        delegate: Chip { required property var modelData; clickable: true; text: modelData.name; on: !!page.chosenPresets[modelData.id]
                            onClicked: page.chosenPresets = page.flip(page.chosenPresets, modelData.id) } } } }
            Rectangle { Layout.fillWidth: true; Layout.topMargin: 4; height: 1; color: Theme.border }
            RowLayout { Layout.fillWidth: true; spacing: 8
                Txt { text: page.nChosen + " scenarios · " + page.nPresets + " presets"; color: Theme.muted; Layout.fillWidth: true }
                Btn { kind: "ghost"; text: "Clear"; onClicked: { page.chosen = ({}); page.chosenPresets = ({}) } }
                Btn { kind: "primary"; icon: "download"; text: "Export pack…"; enabled: page.nChosen > 0 || page.nPresets > 0
                      onClicked: Store.exportItems({ scenarios: Object.keys(page.chosen), presets: Object.keys(page.chosenPresets), name: "Custom pack" }) } }
        }
    }
}
