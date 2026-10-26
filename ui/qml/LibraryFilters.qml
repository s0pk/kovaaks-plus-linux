import QtQuick
import QtQuick.Layouts
import QtQuick.Controls
import Kplus
import "js/LibraryLogic.js" as LL

// The left panel of the Scenarios page: quick lists, tag groups, benchmark filters, source.
Flickable {
    id: root
    property var scenarios: []
    property var lastTag: null
    contentHeight: col.implicitHeight + 24
    clip: true
    boundsBehavior: Flickable.StopAtBounds
    ScrollBar.vertical: ThinScroll {}

    readonly property var ui: Store.libUi
    readonly property var counts: LL.tagCounts(Store.scenarios, Store.config, ui)
    readonly property var groups: LL.groupsOf(Store.tags, Store.groups)

    component FilterItem: Rectangle {
        id: fi
        property string label: ""
        property string icon: ""
        property color swatch: "transparent"
        property bool on: false
        property int count: -1
        property bool editable: false
        signal clicked(var mouse)
        signal menu(real x, real y)
        signal edit()
        height: 32
        radius: Theme.radiusSm
        color: on ? Theme.surface3 : (area.containsMouse ? Theme.surface : "transparent")
        RowLayout {
            anchors.fill: parent; anchors.leftMargin: 9; anchors.rightMargin: 9; spacing: 9
            Icon { visible: fi.icon !== ""; name: fi.icon || "dot"; size: 15; color: Theme.text2; opacity: 0.75 }
            Rectangle { visible: fi.icon === "" && fi.swatch !== "transparent"; width: 10; height: 10; radius: 2; color: fi.swatch }
            Txt { text: fi.label; w: fi.on ? 600 : 400; color: fi.on || area.containsMouse ? Theme.text : Theme.text2; Layout.fillWidth: true; elide: Text.ElideRight }
            Btn { visible: fi.editable && area.containsMouse; kind: "ghost"; small: true; icon: "edit"; implicitWidth: 22; implicitHeight: 22; onClicked: fi.edit() }
            Txt { visible: fi.count >= 0; text: String(fi.count); font.pixelSize: 11; color: Theme.muted }
        }
        MouseArea {
            id: area; anchors.fill: parent; z: -1; hoverEnabled: true; cursorShape: Qt.PointingHandCursor
            acceptedButtons: Qt.LeftButton | Qt.RightButton
            onClicked: function (m) {
                if (m.button === Qt.RightButton) { var p = mapToItem(Modals.menuHost, m.x, m.y); fi.menu(p.x, p.y) }
                else fi.clicked(m)
            }
        }
    }

    ColumnLayout {
        id: col
        width: parent.width - 8
        spacing: 18

        // quick lists
        Column {
            Layout.fillWidth: true; spacing: 1
            Repeater {
                model: LL.QUICK
                delegate: FilterItem {
                    required property var modelData
                    width: col.width
                    label: modelData.label; icon: modelData.icon
                    on: root.ui.quick === modelData.id
                    count: LL.quickCount(Store.scenarios, Store.config, root.ui, modelData.id)
                    onClicked: Store.setLib({ quick: modelData.id })
                }
            }
        }

        // tag groups
        Repeater {
            model: root.groups
            delegate: ColumnLayout {
                id: grp
                required property string modelData
                required property int index
                readonly property var gtags: Store.tags.filter(function (t) { return t.group === modelData })
                visible: gtags.length > 0
                Layout.fillWidth: true; spacing: 6
                RowLayout {
                    Layout.fillWidth: true
                    Txt { text: grp.modelData; w: 600; font.pixelSize: 13; color: Theme.muted; Layout.fillWidth: true }
                    Btn { visible: grp.index === root.groups.findIndex(function (x) { return Store.tags.some(function (t) { return t.group === x }) }) && root.ui.tags.length > 1
                          kind: "ghost"; small: true; implicitHeight: 22; text: "Match " + root.ui.tagMode
                          tip: "Match any / all selected tags"; onClicked: Store.setLib({ tagMode: root.ui.tagMode === "any" ? "all" : "any" }) }
                }
                Column {
                    Layout.fillWidth: true; spacing: 1
                    Repeater {
                        model: grp.gtags
                        delegate: FilterItem {
                            required property var modelData
                            width: col.width
                            label: modelData.name
                            swatch: modelData.color
                            icon: modelData.icon && String(modelData.icon).indexOf("ic:") === 0 ? String(modelData.icon).slice(3) : ""
                            on: root.ui.tags.indexOf(modelData.id) >= 0
                            count: root.counts[modelData.id] || 0
                            editable: true
                            onClicked: function (m) {
                                var sel = LL.selectTag(root.ui, root.lastTag, modelData, !!(m.modifiers & Qt.ControlModifier), !!(m.modifiers & Qt.ShiftModifier), Store.tags, Store.groups)
                                if (!(m.modifiers & Qt.ShiftModifier)) root.lastTag = modelData.id
                                Store.setLib({ tags: sel })
                            }
                            onEdit: Modals.editTag(modelData)
                            onMenu: function (x, y) {
                                Modals.menu([
                                    { header: modelData.name },
                                    { label: "Show only this tag", icon: "search", onClick: function () { Store.setLib({ tags: [modelData.id], quick: "all" }) } },
                                    { label: "Edit tag…", icon: "edit", onClick: function () { Modals.editTag(modelData) } }
                                ], x, y)
                            }
                        }
                    }
                }
            }
        }

        // benchmarks chosen as filters
        ColumnLayout {
            visible: (Store.config.benchmarkFilters || []).length > 0
            Layout.fillWidth: true; spacing: 6
            Txt { text: "Benchmarks"; w: 600; font.pixelSize: 13; color: Theme.muted }
            Column {
                Layout.fillWidth: true; spacing: 1
                Repeater {
                    model: Store.config.benchmarkFilters || []
                    delegate: FilterItem {
                        required property var modelData
                        readonly property var info: (Store.benchNames || ({}))[modelData] || ({ name: "Benchmark " + modelData })
                        width: col.width
                        label: info.name + (info.difficulty ? " · " + info.difficulty : "")
                        icon: "trophy"
                        on: root.ui.bench === modelData
                        count: Store.scenarios.filter(function (s) { return s.benchmarks && s.benchmarks.indexOf(modelData) >= 0 }).length
                        onClicked: Store.setLib({ bench: root.ui.bench === modelData ? null : modelData })
                        onMenu: function (x, y) {
                            Modals.menu([
                                { header: info.name },
                                { label: "Open benchmark page", icon: "trophy", onClick: function () { Store.go("benchmarks/" + modelData) } },
                                { label: "Remove from filters", icon: "x", onClick: function () { Store.saveConfig({ benchmarkFilters: (Store.config.benchmarkFilters || []).filter(function (x) { return x !== modelData }) }) } }
                            ], x, y)
                        }
                    }
                }
            }
        }

        // source
        ColumnLayout {
            Layout.fillWidth: true; spacing: 6
            Txt { text: "Source"; w: 600; font.pixelSize: 13; color: Theme.muted }
            Column {
                Layout.fillWidth: true; spacing: 1
                Repeater {
                    model: LL.SOURCES
                    delegate: FilterItem {
                        required property var modelData
                        width: col.width
                        label: modelData.label
                        on: root.ui.source === modelData.value
                        onClicked: Store.setLib({ source: modelData.value })
                    }
                }
            }
        }

        RowLayout {
            Layout.fillWidth: true; spacing: 6
            Btn { small: true; icon: "tag"; text: "Manage tags"; onClicked: Modals.manageTags() }
            Btn { visible: root.ui.tags.length > 0; small: true; kind: "ghost"; text: "Clear tags"; onClicked: Store.setLib({ tags: [] }) }
        }
        Item { Layout.preferredHeight: 8 }
    }
}
