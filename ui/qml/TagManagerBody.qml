import QtQuick
import QtQuick.Layouts
import Kplus
import "js/LibraryLogic.js" as LL
import "js/Consts.js" as C

// Manage all tags: create, rename, recolour, regroup, reorder, thumbnails, presets, delete. Order here is the order everywhere.
Item {
    id: root
    property var dialog
    property var tags: []
    property var groups: []
    implicitHeight: col.implicitHeight

    Component.onCompleted: {
        tags = Store.tags.map(function (t) { var c = {}; for (var k in t) c[k] = t[k]; return c })
        groups = Store.groups.slice()
    }
    readonly property var groupList: LL.groupsOf(tags, groups)
    function bump() { tags = tags.slice(); groups = groups.slice() }

    /** Moves a tag into `group`, before `beforeTag` (or to the end of the group when null). */
    function moveTag(tag, beforeTag, group) {
        var list = tags.filter(function (x) { return x !== tag })
        tag.group = group
        var at
        if (beforeTag && beforeTag !== tag) at = list.indexOf(beforeTag)
        else {
            var last = -1
            list.forEach(function (x, i) { if (x.group === group) last = i })
            at = last >= 0 ? last + 1 : list.length
        }
        list.splice(at < 0 ? list.length : at, 0, tag)
        tags = list
    }
    function moveGroup(g, delta) {
        var gl = groupList.slice()
        var i = gl.indexOf(g), j = i + delta
        if (j < 0 || j >= gl.length) return
        gl.splice(j, 0, gl.splice(i, 1)[0])
        groups = gl
    }
    function addTag(g) { tags = tags.concat([{ id: C.newId(), name: "New tag", group: g, color: C.SWATCHES[tags.length % C.SWATCHES.length] }]) }
    function removeTag(t) {
        Modals.confirm("Delete tag?", "\"" + t.name + "\" will be removed from every scenario.", "Delete", "danger", function (ok) { if (ok) tags = tags.filter(function (x) { return x !== t }) })
    }
    function renameGroup(g, nv) {
        nv = nv.trim() || g
        if (nv === g) return
        tags.forEach(function (t) { if (t.group === g) t.group = nv })
        groups = groupList.map(function (x) { return x === g ? nv : x })
    }
    function save() {
        Store.setTags(tags.filter(function (t) { return t.name.trim() }), groupList, function () { Store.toast("Tags saved", "ok") })
        return true
    }

    ColumnLayout {
        id: col; width: parent.width; spacing: 18
        Repeater {
            model: root.groupList
            delegate: ColumnLayout {
                id: grp
                required property string modelData
                readonly property var list: root.tags.filter(function (t) { return t.group === modelData })
                Layout.fillWidth: true; spacing: 6
                RowLayout {
                    Layout.fillWidth: true; spacing: 8
                    Field { implicitWidth: 220; text: grp.modelData; onAccepted: root.renameGroup(grp.modelData, text) }
                    Txt { text: grp.list.length + " tag" + (grp.list.length === 1 ? "" : "s"); font.pixelSize: 12; color: Theme.muted }
                    Btn { small: true; kind: "ghost"; icon: "arrowUp"; tip: "Move group up"; onClicked: root.moveGroup(grp.modelData, -1) }
                    Btn { small: true; kind: "ghost"; icon: "arrowUp"; iconFlipY: true; tip: "Move group down"; onClicked: root.moveGroup(grp.modelData, 1) }
                    Item { Layout.fillWidth: true }
                    Btn { small: true; icon: "plus"; text: "Add tag"; onClicked: root.addTag(grp.modelData) }
                    Btn { visible: grp.list.length === 0; small: true; kind: "ghost"; text: "Remove group"; onClicked: root.groups = root.groupList.filter(function (x) { return x !== grp.modelData }) }
                }
                Repeater {
                    model: grp.list
                    delegate: Rectangle {
                        id: row
                        required property var modelData
                        required property int index
                        Layout.fillWidth: true; Layout.preferredHeight: 46; radius: Theme.radiusSm; color: Theme.bg2
                        RowLayout {
                            anchors.fill: parent; anchors.leftMargin: 8; anchors.rightMargin: 8; spacing: 8
                            Btn { small: true; kind: "ghost"; icon: "arrowUp"; enabled: row.index > 0; onClicked: root.moveTag(row.modelData, grp.list[row.index - 1], grp.modelData) }
                            Btn { small: true; kind: "ghost"; icon: "arrowUp"; iconFlipY: true; enabled: row.index < grp.list.length - 1; onClicked: root.moveTag(row.modelData, grp.list[row.index + 2] || null, grp.modelData) }
                            Rectangle { width: 22; height: 22; radius: 4; color: row.modelData.color; border.width: 1; border.color: Theme.border2
                                        MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor; onClicked: root.dialog && colorDlg.openFor(row.modelData) } }
                            Field { Layout.fillWidth: true; text: row.modelData.name; onEdited: function (t) { row.modelData.name = t } }
                            Select { implicitWidth: 150; value: row.modelData.group; options: root.groupList.map(function (g) { return { value: g, label: g } }); onPicked: function (g) { root.moveTag(row.modelData, null, g) } }
                            Btn { small: true; icon: "image"; kind: row.modelData.thumbnail ? "primary" : ""; tip: row.modelData.thumbnail ? "Default thumbnail set (click to change)" : "Set default thumbnail"
                                  onClicked: Backend.call("media.pick", { kind: "video", owner: "tag:" + row.modelData.name, target: "thumbnail" }, function (f) { if (f) { row.modelData.thumbnail = f; root.bump() } }) }
                            Btn { small: true; icon: "sliders"; kind: row.modelData.preset ? "primary" : ""; tip: "Set default preset"
                                  onClicked: Modals.pickPreset("Default preset for \"" + row.modelData.name + "\"", row.modelData.preset || "", "", function (id) { row.modelData.preset = id || null; root.bump() }) }
                            Chip { text: row.modelData.name; chipColor: row.modelData.color; Layout.preferredWidth: 120 }
                            Btn { small: true; kind: "ghost"; icon: "trash"; tip: "Delete tag"; onClicked: root.removeTag(row.modelData) }
                        }
                    }
                }
                Txt { visible: grp.list.length === 0; text: "No tags in this group."; color: Theme.muted; font.pixelSize: 12 }
            }
        }
        Btn { icon: "plus"; text: "Add group"; onClicked: root.groups = root.groupList.concat(["New group " + (root.groupList.length + 1)]) }
    }

    QtObject { id: colorDlg
        property var target: null
        function openFor(t) { target = t; picker.selectedColor = t.color; picker.open() } }
    ColorPickerDialog { id: picker; onPicked: function (c) { if (colorDlg.target) { colorDlg.target.color = c.toString(); root.bump() } } }
}
