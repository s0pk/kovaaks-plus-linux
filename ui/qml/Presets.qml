import QtQuick
import Kplus

// Settings & Presets: saved setups, the live KovaaK's settings editor, and backups.
PageScroll {
    id: page
    PageHead {
        title: "Settings & Presets"
        subtitle: "Edit KovaaK's settings directly and save them as presets you can swap or share. Your current settings are backed up before every change."
    }
    Seg {
        options: [{ value: "presets", label: "Presets" }, { value: "live", label: "Current settings" }, { value: "backups", label: "Backups" }]
        value: Store.settingsTab
        onPicked: function (v) { Store.settingsTab = v }
    }
    Loader {
        width: parent.width
        height: item ? item.implicitHeight : 0
        sourceComponent: Store.settingsTab === "live" ? live : Store.settingsTab === "backups" ? backups : presets
    }
    Component { id: presets; PresetsTab {} }
    Component { id: live; LiveSettings {} }
    Component { id: backups; BackupsTab {} }
}
