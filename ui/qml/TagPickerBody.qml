import QtQuick
import QtQuick.Layouts
import Kplus
import "js/LibraryLogic.js" as LL
import "js/Consts.js" as C

// Grouped toggle chips to assign tags; new tags can be created inline. `selected` holds the chosen ids.
Item {
    id: root
    property var dialog
    property var selected: []
    property bool allowCreate: true
    implicitHeight: col.implicitHeight
    property string newName: ""
    property string newGroup: ""

    function toggle(id) {
        var s = selected.slice()
        var i = s.indexOf(id)
        if (i >= 0) s.splice(i, 1); else s.push(id)
        selected = s
    }
    function create() {
        var n = nameIn.text.trim()
        if (!n) return
        if (Store.tags.some(function (t) { return t.name.toLowerCase() === n.toLowerCase() })) { Store.toast("That tag already exists"); return }
        var g = groupSel.value === "__new" ? (newGroupIn.text.trim() || "Custom") : groupSel.value
        var tag = { id: C.newId(), name: n, group: g, color: C.SWATCHES[Store.tags.length % C.SWATCHES.length] }
        var groups = Store.groups.indexOf(g) >= 0 ? Store.groups : Store.groups.concat([g])
        Store.setTags(Store.tags.concat([tag]), groups, function () { var s = root.selected.slice(); s.push(tag.id); root.selected = s; nameIn.text = "" })
    }

    ColumnLayout {
        id: col; width: parent.width; spacing: 14
        Repeater {
            model: LL.groupsOf(Store.tags, Store.groups)
            delegate: ColumnLayout {
                required property string modelData
                readonly property var gt: Store.tags.filter(function (t) { return t.group === modelData })
                visible: gt.length > 0; Layout.fillWidth: true; spacing: 7
                Txt { text: modelData; w: 700; font.pixelSize: 12; color: Theme.muted }
                Flow {
                    Layout.fillWidth: true; spacing: 6
                    Repeater { model: gt; delegate: Chip { required property var modelData; text: modelData.name; chipColor: root.selected.indexOf(modelData.id) >= 0 ? modelData.color : Theme.muted
                                                            on: root.selected.indexOf(modelData.id) >= 0; clickable: true; opacity: on ? 1 : 0.75; onClicked: root.toggle(modelData.id) } }
                }
            }
        }
        RowLayout {
            visible: root.allowCreate; Layout.fillWidth: true; spacing: 8
            Field { id: nameIn; Layout.fillWidth: true; placeholder: "New tag name"; onAccepted: root.create() }
            Select { id: groupSel; implicitWidth: 150; value: Store.groups.length ? Store.groups[0] : "Custom"
                     options: LL.groupsOf(Store.tags, Store.groups).map(function (g) { return { value: g, label: g } }).concat([{ value: "__new", label: "New group…" }]) }
            Field { id: newGroupIn; visible: groupSel.value === "__new"; implicitWidth: 130; placeholder: "Group name" }
            Btn { icon: "plus"; text: "Create"; onClicked: root.create() }
        }
    }
}
