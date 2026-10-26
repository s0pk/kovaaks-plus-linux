pragma Singleton
import QtQuick
import Kplus

// Entry points for dialogs and menus. The visible hosts live in Main.qml and register themselves here, so any page can
// open a confirmation, a prompt, a custom dialog or a context menu with a single call.
QtObject {
    property var host: null       // ModalHost
    property var menuHost: null   // MenuHost

    /** Asks a yes/no question. cb(true|false). */
    function confirm(title, text, okLabel, kind, cb) {
        if (host) host.openConfirm(title, text, okLabel || "Confirm", kind || "primary", cb)
    }
    /** Asks for a line of text. cb(textOrNull). */
    function prompt(title, label, value, okLabel, cb) {
        if (host) host.openPrompt(title, label, value || "", okLabel || "Save", cb)
    }
    /**
     * Opens a dialog whose body is the given Component. The component gets `dialog` (with close(value)) injected,
     * and may declare its own buttons through the options (actions: [{label, kind, value, onClick}]).
     * opts: { title, wide, panel, actions, props, onClose }
     */
    function open(component, opts) { if (host) return host.openCustom(component, opts || {}); return null }

    /** Tag dialogs and other bigger dialogs (implemented in ModalHost). */
    function editTag(tag) { if (host) host.editTag(tag) }
    function manageTags() { if (host) host.manageTags() }
    function pickTags(title, selected, onSave) { if (host) host.pickTags(title, selected, onSave) }
    function pickPreset(title, current, hint, cb) { if (host) host.pickPreset(title, current, hint, cb) }
    function autoTag(scopes) { if (host) host.autoTag(scopes) }

    function runDetail(file, title) { if (host) host.runDetail(file, title) }
    function scenarioLeaderboard(name, display) { if (host) host.scenarioLeaderboard(name, display) }

    function findPlayer() { if (host) host.findPlayer() }
    function tableSettings() { if (host) host.tableSettings() }

    function exportPack(o) { if (host) host.exportPack(o) }
    function importPack(pv) { if (host) host.importPack(pv) }
    function capturePreset() { if (host) host.capturePreset() }
    function editPreset(p) { if (host) host.editPreset(p) }
    function presetPrompt(name, res, cb) { if (host) host.openPresetPrompt(name, res, cb) }

    /** items: [{label, icon, onClick, danger, disabled, hint}] | {sep:true} | {header:"text"}; x,y in window coordinates. */
    function menu(items, x, y) { if (menuHost) menuHost.show(items, x, y) }
}
