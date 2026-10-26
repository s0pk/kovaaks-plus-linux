import QtQuick
import QtQuick.Layouts
import Kplus
import "js/LibraryLogic.js" as LL
import "js/Consts.js" as C

// Edit one tag: name, colour, category, sidebar icon, default thumbnail, default preset.
Item {
    id: root
    property var dialog
    property var tag: ({})
    property var t: ({})
    property string presetName: ""
    implicitHeight: col.implicitHeight
    readonly property int usedBy: Store.scenarios.filter(function (s) { return s.tags.indexOf(root.t.id) >= 0 }).length

    Component.onCompleted: {
        var c = {}
        for (var k in tag) c[k] = tag[k]
        t = c
        nameIn.text = t.name
        Store.loadPresets(function () { updatePresetName() })
    }
    function set(patch) { var c = {}; for (var k in t) c[k] = t[k]; for (var p in patch) c[p] = patch[p]; t = c }
    function updatePresetName() {
        var p = (Store.presets || []).filter(function (x) { return x.id === t.preset })[0]
        presetName = t.preset ? (p ? p.name : "Missing preset") : "None"
    }
    onTChanged: updatePresetName()
    function owner() { return "tag:" + (nameIn.text.trim() || t.name) }
    function pick(kind, target, then) {
        Backend.call("media.pick", { kind: kind, owner: owner(), target: target }, function (f) { if (f) then(f) }, function (e) { Store.toast(e, "error") })
    }

    /** Validates and saves; returns false to keep the dialog open. */
    function save() {
        var name = nameIn.text.trim()
        if (!name) { Store.toast("Give the tag a name"); return false }
        if (Store.tags.some(function (x) { return x.id !== t.id && x.name.toLowerCase() === name.toLowerCase() })) { Store.toast("Another tag already has that name"); return false }
        var g = groupSel.value === "__new" ? (newGroupIn.text.trim() || "Custom") : groupSel.value
        var nt = {}
        for (var k in t) nt[k] = t[k]
        nt.name = name; nt.group = g
        var groups = Store.groups.indexOf(g) >= 0 ? Store.groups : Store.groups.concat([g])
        Store.setTags(Store.tags.map(function (x) { return x.id === nt.id ? nt : x }), groups, function () { Store.toast("Tag saved", "ok") })
        return true
    }
    function remove() {
        Modals.confirm("Delete tag?", "\"" + t.name + "\" will be removed from " + usedBy + " scenario" + (usedBy === 1 ? "" : "s") + ".", "Delete", "danger", function (ok) {
            if (!ok) return
            Store.setTags(Store.tags.filter(function (x) { return x.id !== t.id }), Store.groups, function () { Store.toast("Tag deleted", "ok") })
            root.dialog.close(null)
        })
        return false
    }

    ColumnLayout {
        id: col; width: parent.width; spacing: 14
        RowLayout {
            Layout.fillWidth: true; spacing: 12
            ColumnLayout { Layout.fillWidth: true; spacing: 6
                Txt { text: "Name"; w: 600; font.pixelSize: 12; color: Theme.text2 }
                Field { id: nameIn; Layout.fillWidth: true } }
            Chip { Layout.alignment: Qt.AlignBottom; Layout.bottomMargin: 6; text: nameIn.text || "Tag"; chipColor: root.t.color || Theme.accent }
        }
        ColumnLayout { Layout.fillWidth: true; spacing: 6
            Txt { text: "Category"; w: 600; font.pixelSize: 12; color: Theme.text2 }
            RowLayout { spacing: 8
                Select { id: groupSel; implicitWidth: 220; value: root.t.group || (Store.groups[0] || "Custom")
                         options: LL.groupsOf(Store.tags, Store.groups).map(function (g) { return { value: g, label: g } }).concat([{ value: "__new", label: "New category…" }]) }
                Field { id: newGroupIn; visible: groupSel.value === "__new"; implicitWidth: 180; placeholder: "New category name" } } }
        ColumnLayout { Layout.fillWidth: true; spacing: 6
            Txt { text: "Colour"; w: 600; font.pixelSize: 12; color: Theme.text2 }
            SwatchRow { Layout.fillWidth: true; value: root.t.color || "#8b5cf6"; onPicked: function (c) { root.set({ color: c.toString() }) } } }
        ColumnLayout { Layout.fillWidth: true; spacing: 6
            Txt { text: "Sidebar icon"; w: 600; font.pixelSize: 12; color: Theme.text2 }
            Flow { Layout.fillWidth: true; spacing: 5
                Rectangle { width: 32; height: 32; radius: Theme.radiusSm; color: Theme.bg2; border.width: !root.t.icon ? 2 : 1; border.color: !root.t.icon ? Theme.accent : Theme.border2
                            Rectangle { anchors.centerIn: parent; width: 12; height: 12; radius: 3; color: root.t.color || Theme.accent }
                            MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor; onClicked: root.set({ icon: null }) } }
                Repeater { model: C.TAG_ICONS
                    delegate: Rectangle { required property string modelData; width: 32; height: 32; radius: Theme.radiusSm; color: Theme.bg2
                        border.width: root.t.icon === "ic:" + modelData ? 2 : 1; border.color: root.t.icon === "ic:" + modelData ? Theme.accent : Theme.border2
                        Icon { anchors.centerIn: parent; name: modelData; size: 16; color: root.t.color || Theme.text }
                        MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor; onClicked: root.set({ icon: "ic:" + modelData }) } } }
                Rectangle { width: 32; height: 32; radius: Theme.radiusSm; color: Theme.bg2; border.width: root.t.icon && String(root.t.icon).indexOf("ic:") !== 0 ? 2 : 1; border.color: root.t.icon && String(root.t.icon).indexOf("ic:") !== 0 ? Theme.accent : Theme.border2
                            Icon { anchors.centerIn: parent; visible: !(root.t.icon && String(root.t.icon).indexOf("ic:") !== 0); name: "upload"; size: 16; color: Theme.text2 }
                            Image { anchors.centerIn: parent; width: 20; height: 20; visible: !!(root.t.icon && String(root.t.icon).indexOf("ic:") !== 0); source: visible ? Launch.http + "/media/" + String(root.t.icon).split("/").map(encodeURIComponent).join("/") : ""; fillMode: Image.PreserveAspectFit }
                            ToolTipArea { text: "Upload an image"; target: upl }
                            MouseArea { id: upl; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onClicked: root.pick("image", "icon", function (f) { root.set({ icon: f }) }) } }
            } }
        ColumnLayout { Layout.fillWidth: true; spacing: 6
            Txt { text: "Default thumbnail"; w: 600; font.pixelSize: 12; color: Theme.text2 }
            RowLayout { spacing: 12
                Thumb { Layout.preferredWidth: 180; name: root.t.name || "Tag"; media: root.t.thumbnail || ""; tagColor: root.t.color || ""; info: root.t.name || "" }
                ColumnLayout { spacing: 6
                    Btn { small: true; icon: "image"; text: root.t.thumbnail ? "Change" : "Choose…"; onClicked: root.pick("video", "thumbnail", function (f) { root.set({ thumbnail: f }) }) }
                    Btn { visible: !!root.t.thumbnail; small: true; kind: "ghost"; text: "Remove"; onClicked: root.set({ thumbnail: null }) }
                    Txt { Layout.maximumWidth: 240; wrapMode: Text.WordWrap; font.pixelSize: 12; color: Theme.muted; text: "Scenarios with this tag and no thumbnail of their own use it; with several tagged thumbnails the card is split between them." } } } }
        ColumnLayout { Layout.fillWidth: true; spacing: 6
            Txt { text: "Default settings preset"; w: 600; font.pixelSize: 12; color: Theme.text2 }
            RowLayout { spacing: 10
                Btn { small: true; icon: "sliders"; text: root.presetName; onClicked: Modals.pickPreset("Default preset for \"" + root.t.name + "\"", root.t.preset || "", "Scenarios with this tag play with your current settings", function (id) { root.set({ preset: id || null }) }) }
                Txt { text: "Used when a tagged scenario has no preset of its own."; font.pixelSize: 12; color: Theme.muted } } }
        Txt { text: "Used by " + root.usedBy + " scenario" + (root.usedBy === 1 ? "" : "s") + "."; font.pixelSize: 12; color: Theme.muted }
    }
}
