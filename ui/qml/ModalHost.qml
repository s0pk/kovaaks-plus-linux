import QtQuick
import Kplus
import QtQuick.Layouts
import QtQuick.Controls
import "js/Fmt.js" as Fmt

// Dialog stack. Dialogs are opened through Modals.* (see Modals.qml); each is a card over a dimmed backdrop,
// or a side panel (opts.panel) that leaves the page visible and undimmed.
Item {
    id: host
    anchors.fill: parent
    z: 900
    visible: model.count > 0

    property var entries: ({})
    property int seq: 0
    ListModel { id: model }

    function push(entry) {
        var id = ++seq
        entries[id] = entry
        model.append({ entryId: id })
        return id
    }
    function finish(id, value) {
        var e = entries[id]
        if (!e) return
        delete entries[id]
        for (var i = 0; i < model.count; i++) if (model.get(i).entryId === id) { model.remove(i); break }
        if (e.onClose) e.onClose(value)
    }

    // ---- ready-made dialogs ----
    function openConfirm(title, text, okLabel, kind, cb) {
        var done = false
        return push({ title: title, component: confirmBody, props: { text: text }, actions: [
            { label: "Cancel", kind: "ghost", value: false },
            { label: okLabel, kind: kind, value: true } ], onClose: function (v) { if (cb) cb(!!v) } })
    }
    function openPrompt(title, label, value, okLabel, cb) {
        var result = null
        return push({ title: title, component: promptBody, props: { label: label, initial: value },
            actions: [ { label: "Cancel", kind: "ghost" }, { label: okLabel, kind: "primary", onClick: function (dlg) { result = dlg.body.result } } ],
            onSubmit: function (dlg) { result = dlg.body.result }, onClose: function () { if (cb) cb(result) } })
    }
    function openPresetPrompt(name, res, cb) {
        var result = null
        return push({ title: "Apply default preset?", component: presetPromptBody, props: { scenarioName: name, res: res }, actions: [
            { label: "Cancel", kind: "ghost" },
            { label: "Play without", onClick: function () { result = "skip" } },
            { label: res.running ? "Apply & restart" : "Apply preset", kind: "primary", onClick: function (dlg) {
                result = "apply"; if (dlg.body.remember) Store.saveConfig({ presetMode: "auto" }) } } ],
            onClose: function () { if (cb) cb(result) } })
    }
    // ---- tag and preset dialogs ----
    Component { id: tagPickerC; TagPickerBody {} }
    Component { id: tagEditorC; TagEditorBody {} }
    Component { id: tagManagerC; TagManagerBody {} }
    Component { id: presetPickerC; PresetPickerBody {} }

    function pickTags(title, selected, onSave) {
        openCustom(tagPickerC, { title: title, props: { selected: selected.slice() }, actions: [
            { label: "Cancel", kind: "ghost" },
            { label: "Save tags", kind: "primary", onClick: function (dlg) { onSave(dlg.body.selected) } } ] })
    }
    function editTag(tag) {
        openCustom(tagEditorC, { title: "Edit tag", props: { tag: tag }, actions: [
            { label: "Delete tag", kind: "danger", onClick: function (dlg) { return dlg.body.remove() } },
            { label: "Cancel", kind: "ghost" },
            { label: "Save", kind: "primary", onClick: function (dlg) { return dlg.body.save() } } ] })
    }
    function manageTags() {
        openCustom(tagManagerC, { title: "Manage tags", wide: true, actions: [
            { label: "Cancel", kind: "ghost" },
            { label: "Save", kind: "primary", onClick: function (dlg) { return dlg.body.save() } } ] })
    }
    function pickPreset(title, current, hint, cb) {
        var result = null
        openCustom(presetPickerC, { title: title, props: { choice: current || "", hint: hint || "" }, actions: [
            { label: "Cancel", kind: "ghost" },
            { label: "Save", kind: "primary", onClick: function (dlg) { result = dlg.body.choice } } ],
            onClose: function () { if (result !== null && cb) cb(result) } })
    }
    Component { id: runDetailC; RunDetail {} }
    Component { id: findPlayerC; FindPlayerBody {} }
    Component { id: tableSettingsC; TableSettingsBody {} }
    function tableSettings() { openCustom(tableSettingsC, { title: "Table settings", panel: true, props: {}, actions: [{ label: "Reset defaults", kind: "ghost", onClick: function (dlg) { return dlg.body.reset() } }, { label: "Done", kind: "primary" }] }) }
    function findPlayer() { openCustom(findPlayerC, { title: "View a player’s benchmarks", props: {}, actions: [{ label: "Close", kind: "ghost" }] }) }
    Component { id: lbDialogC; ScenarioLeaderboard {} }
    function runDetail(file, title) {
        Backend.call("stats.run", { file: file }, function (d) {
            var s = d.summary
            openCustom(runDetailC, { title: (title || s.scenario) + " · " + Fmt.fmtDateTime(s.date), wide: true, props: { detail: d }, actions: [{ label: "Close", kind: "primary" }] })
        }, function (e) { Store.toast(e, "error") })
    }
    function scenarioLeaderboard(name, display) {
        openCustom(lbDialogC, { title: "Leaderboard · " + (display || name), wide: true, props: { name: name }, actions: [{ label: "Close", kind: "primary" }] })
    }
    Component { id: presetCaptureC; PresetCaptureBody {} }
    Component { id: presetEditC; PresetEditBody {} }
    function capturePreset() {
        openCustom(presetCaptureC, { title: "New preset from current settings", actions: [{ label: "Cancel", kind: "ghost" },
            { label: "Create preset", kind: "primary", onClick: function (dlg) { return dlg.body.save() } }] })
    }
    function editPreset(p) {
        openCustom(presetEditC, { title: "Edit preset", props: { p: p }, actions: [{ label: "Cancel", kind: "ghost" },
            { label: "Save", kind: "primary", onClick: function (dlg) { return dlg.body.save() } }] })
    }
    Component { id: packExportC; PackExportBody {} }
    Component { id: packImportC; PackImportBody {} }
    function exportPack(o) {
        openCustom(packExportC, { title: "Export pack", props: { packName: o.name || "My pack", scenarios: o.scenarios || [], presets: o.presets || [] }, actions: [{ label: "Cancel", kind: "ghost" },
            { label: "Save .kpack…", kind: "primary", onClick: function (dlg) { return dlg.body.save() } }] })
    }
    function importPack(pv) {
        openCustom(packImportC, { title: "Import \u201c" + pv.name + "\u201d", wide: true, props: { preview: pv }, actions: [{ label: "Cancel", kind: "ghost" },
            { label: "Import", kind: "primary", onClick: function (dlg) { return dlg.body.run() } }] })
    }
    Component { id: autoTagC; AutoTagBody {} }
    function autoTag(scopes) { openCustom(autoTagC, { title: "Auto-tag scenarios", wide: true, props: { scopes: scopes || ({}) }, actions: [] }) }

    function openCustom(component, opts) {
        var id = push({ title: opts.title, component: component, props: opts.props || {}, wide: opts.wide, panel: opts.panel,
                        actions: opts.actions || [], onClose: opts.onClose, noScroll: opts.noScroll })
        return { close: function (v) { host.finish(id, v) } }
    }

    Component { id: confirmBody; Item { property var dialog; property string text; implicitHeight: t.implicitHeight; Txt { id: t; width: parent.width; text: parent.text; wrapMode: Text.WordWrap; color: Theme.text2 } } }
    Component {
        id: promptBody
        Item {
            property var dialog; property string label; property string initial; property alias result: f.text
            implicitHeight: col.implicitHeight
            Component.onCompleted: { f.text = initial; f.focusInput() }
            Column {
                id: col; width: parent.width; spacing: 6
                Txt { text: label; w: 600; font.pixelSize: 12; color: Theme.text2 }
                Field { id: f; width: parent.width; onAccepted: dialog.submit() }
            }
        }
    }
    Component {
        id: presetPromptBody
        Item {
            id: pb
            property var dialog; property string scenarioName; property var res; property bool remember: false
            implicitHeight: col.implicitHeight
            Column {
                id: col; width: parent.width; spacing: 12
                Txt { width: parent.width; wrapMode: Text.WordWrap; color: Theme.text2
                      text: pb.scenarioName + " uses the preset " + (pb.res && pb.res.preset ? pb.res.preset.name : "") + ", and your current KovaaK's settings are different." }
                Txt { visible: !!(pb.res && pb.res.running); width: parent.width; wrapMode: Text.WordWrap; font.pixelSize: 12; color: Theme.muted
                      text: "KovaaK's reads settings at startup, so applying will close it, write the preset, and relaunch straight into the scenario." }
                RowLayout {
                    width: parent.width; spacing: 10
                    Toggle { checked: pb.remember; onToggled: function (v) { pb.remember = v } }
                    Txt { text: "Don't ask again. Always apply default presets automatically"; color: Theme.text2; Layout.fillWidth: true; wrapMode: Text.WordWrap }
                }
            }
        }
    }

    // ---- frames ----
    Repeater {
        model: model
        delegate: Item {
            id: frame
            required property int entryId
            readonly property var entry: host.entries[entryId] || ({})
            readonly property bool panel: !!entry.panel
            anchors.fill: parent
            focus: true
            Component.onCompleted: forceActiveFocus()
            Keys.onEscapePressed: host.finish(entryId, null)

            QtObject {
                id: ctrl
                property var body: loader.item
                function close(v) { host.finish(frame.entryId, v) }
                function submit() { if (frame.entry.onSubmit) frame.entry.onSubmit(ctrl); host.finish(frame.entryId, undefined) }
            }

            Rectangle {   // backdrop
                anchors.fill: parent
                color: frame.panel ? "transparent" : Qt.rgba(0.03, 0.03, 0.028, 0.72)
                opacity: 0
                NumberAnimation on opacity { to: 1; duration: Theme.animMs; running: true }
                MouseArea { anchors.fill: parent; onPressed: host.finish(frame.entryId, null) }
            }

            Rectangle {
                id: card
                width: frame.panel ? Math.min(420, host.width - 24) : Math.min(frame.entry.wide ? 860 : 560, host.width - 40)
                height: frame.panel ? host.height - 24 : Math.min(col.implicitHeight, host.height * 0.88)
                x: frame.panel ? host.width - width - 12 : (host.width - width) / 2
                y: frame.panel ? 12 : (host.height - height) / 2
                radius: Theme.radius
                color: Theme.surface
                border.width: 1; border.color: Theme.border2
                clip: true
                opacity: 0
                NumberAnimation on opacity { to: 1; duration: Theme.animMs; running: true }
                MouseArea { anchors.fill: parent }   // swallow clicks

                ColumnLayout {
                    id: col
                    anchors.fill: parent
                    spacing: 0
                    Txt { visible: !!frame.entry.title; text: frame.entry.title || ""; display: true; w: 700; font.pixelSize: 26; Layout.margins: 22; Layout.bottomMargin: 6; Layout.fillWidth: true; elide: Text.ElideRight }
                    Flickable {
                        id: flick
                        Layout.fillWidth: true; Layout.fillHeight: true
                        Layout.leftMargin: 22; Layout.rightMargin: 22; Layout.topMargin: 10; Layout.bottomMargin: 18
                        Layout.preferredHeight: loader.item ? loader.item.implicitHeight : 0
                        Layout.minimumHeight: 80
                        contentHeight: loader.height; clip: true
                        boundsBehavior: Flickable.StopAtBounds
                        ScrollBar.vertical: ThinScroll {}
                        Loader {
                            id: loader
                            width: flick.width
                            sourceComponent: frame.entry.component
                            onLoaded: {
                                var p = frame.entry.props || {}
                                for (var k in p) item[k] = p[k]
                                item.dialog = ctrl
                                height = Qt.binding(function () { return item.implicitHeight })
                            }
                        }
                    }
                    RowLayout {
                        visible: (frame.entry.actions || []).length > 0
                        Layout.fillWidth: true; Layout.margins: 16; Layout.leftMargin: 22; Layout.rightMargin: 22
                        spacing: 10
                        Item { Layout.fillWidth: true }
                        Repeater {
                            model: frame.entry.actions || []
                            delegate: Btn {
                                required property var modelData
                                text: modelData.label; kind: modelData.kind || ""
                                onClicked: {
                                    var keep = modelData.onClick ? modelData.onClick(ctrl) : undefined
                                    if (keep === false) return
                                    host.finish(frame.entryId, modelData.value)
                                }
                            }
                        }
                    }
                }
            }
        }
    }
}
