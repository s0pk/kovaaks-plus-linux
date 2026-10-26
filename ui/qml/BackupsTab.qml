import QtQuick
import QtQuick.Layouts
import Kplus

Item {
    id: root
    implicitHeight: col.implicitHeight
    property var list: null
    function load() { Backend.call("settings.backups", {}, function (l) { root.list = l }, function () { root.list = [] }) }
    Component.onCompleted: load()

    Column {
        id: col; width: parent.width; spacing: 16
        RowLayout {
            width: parent.width; spacing: 12
            Txt { Layout.fillWidth: true; color: Theme.muted; wrapMode: Text.WordWrap; text: "A snapshot of PrimaryUserSettings.json, weaponsettings.ini and UI.json is saved before every change (last 40 kept)." }
            Btn { kind: "ghost"; icon: "folder"; text: "Open folder"; onClicked: Backend.call("app.reveal", { what: "backups" }, null, function (e) { Store.toast(e, "error") }) }
        }
        Txt { visible: root.list === null; text: "Loading…"; color: Theme.muted }
        Card {
            visible: root.list !== null && root.list.length === 0; width: parent.width; height: 90
            Txt { anchors.centerIn: parent; text: "No backups yet. One is made automatically the first time you change settings."; color: Theme.muted }
        }
        Card {
            visible: root.list !== null && root.list.length > 0
            width: parent.width; height: rows.implicitHeight + 8
            Column {
                id: rows; x: 0; y: 4; width: parent.width
                Repeater {
                    model: root.list || []
                    delegate: Item {
                        id: row
                        required property var modelData
                        required property int index
                        width: rows.width; height: 46
                        RowLayout {
                            anchors.fill: parent; anchors.leftMargin: 16; anchors.rightMargin: 12; spacing: 14
                            Txt { Layout.fillWidth: true; elide: Text.ElideRight; text: row.modelData.id.replace(/^\d{8}-\d{6}-?/, "").replace(/_/g, " ") || "snapshot" }
                            Txt { text: new Date(row.modelData.created).toLocaleString(Qt.locale(), Locale.ShortFormat); color: Theme.muted; font.pixelSize: 13 }
                            Btn { small: true; text: "Restore"
                                  onClicked: Modals.confirm("Restore this backup?", "Your current settings will be backed up first, then replaced with this snapshot.", "Restore", "primary", function (yes) {
                                      if (yes) Store.withRestart("settings.restore", { id: row.modelData.id }, "Backup restored", function () { root.load() }) }) }
                        }
                        Rectangle { anchors.bottom: parent.bottom; width: parent.width; height: 1; color: Theme.border; visible: index < (root.list || []).length - 1 }
                    }
                }
            }
        }
    }
}
