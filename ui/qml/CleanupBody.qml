import QtQuick
import QtQuick.Layouts
import Kplus
import "js/Appearance.js" as AP

// "Clean up unused files": the media files nothing uses any more, with checkboxes, and broken links to clear.
Item {
    id: root
    property var dialog
    property var scan: ({ files: [], missing: [], emptyFolders: 0 })
    property var chosen: ({})
    property bool clearMissing: true
    readonly property var files: scan.files.slice().sort(function (a, b) { return a.path.localeCompare(b.path) })
    readonly property int nChosen: files.filter(function (f) { return chosen[f.path] }).length
    readonly property real bytes: files.filter(function (f) { return chosen[f.path] }).reduce(function (a, f) { return a + f.size }, 0)
    implicitHeight: col.implicitHeight
    Component.onCompleted: { var c = {}; files.forEach(function (f) { c[f.path] = true }); chosen = c; clearMissing = scan.missing.length > 0 }

    function toggle(path) { var c = {}; for (var k in chosen) c[k] = chosen[k]; c[path] = !c[path]; chosen = c }
    function all(on) { var c = {}; files.forEach(function (f) { c[f.path] = on }); chosen = c }
    function run() {
        var paths = files.filter(function (f) { return chosen[f.path] }).map(function (f) { return f.path })
        Backend.call("media.cleanUnused", { files: paths, clearMissing: clearMissing && scan.missing.length > 0 }, function (r) {
            var parts = []
            if (r.deleted) parts.push(r.deleted + " file" + (r.deleted === 1 ? "" : "s") + " (" + AP.fmtBytes(r.bytes) + ") moved to the Trash")
            if (r.folders) parts.push(r.folders + " empty folder" + (r.folders === 1 ? "" : "s") + " removed")
            if (r.cleared) parts.push(r.cleared + " broken link" + (r.cleared === 1 ? "" : "s") + " cleared")
            if (r.skipped) parts.push(r.skipped + " skipped (now in use or already gone)")
            Store.toast(parts.join(" · ") || "Nothing changed", "ok")
            if (r.cleared) Store.loadLibrary()
        }, function (e) { Store.toast(e, "error") })
        return true
    }
    component Check: Rectangle {
        property bool on: false
        width: 18; height: 18; radius: 3; color: on ? Theme.accent : "transparent"; border.width: 1; border.color: on ? Theme.accent : Theme.border2
        Icon { visible: parent.on; anchors.centerIn: parent; name: "check"; size: 12; color: Theme.onAccent }
    }
    ColumnLayout {
        id: col; width: parent.width; spacing: 12
        Txt { Layout.fillWidth: true; wrapMode: Text.WordWrap; color: Theme.text2
              text: (root.files.length ? "These media files aren't used by any scenario, tag or preset (usually thumbnails and previews you replaced or removed). They go to the Trash, so you can still restore them." : "No unused media files.")
                    + (root.scan.emptyFolders ? " Empty folders (" + root.scan.emptyFolders + ") are removed too." : "") }
        RowLayout { visible: root.files.length > 0; Layout.fillWidth: true
            Txt { text: root.nChosen + " of " + root.files.length + " file" + (root.files.length === 1 ? "" : "s") + " selected · " + AP.fmtBytes(root.bytes); font.pixelSize: 12; color: Theme.muted; Layout.fillWidth: true }
            Btn { small: true; kind: "ghost"; text: "Select all / none"; onClicked: root.all(root.nChosen !== root.files.length) } }
        Rectangle {
            visible: root.files.length > 0; Layout.fillWidth: true; Layout.preferredHeight: Math.min(280, root.files.length * 32 + 2)
            radius: Theme.radiusSm; color: Theme.bg2; border.width: 1; border.color: Theme.border; clip: true
            ListView {
                anchors.fill: parent; anchors.margins: 1; model: root.files; boundsBehavior: Flickable.StopAtBounds; clip: true
                delegate: Rectangle {
                    required property var modelData
                    width: ListView.view.width; height: 32; color: ma.containsMouse ? Theme.surface2 : "transparent"
                    RowLayout { anchors.fill: parent; anchors.leftMargin: 10; anchors.rightMargin: 10; spacing: 10
                        Check { on: !!root.chosen[modelData.path] }
                        Txt { Layout.fillWidth: true; elide: Text.ElideMiddle; text: modelData.path; font.pixelSize: 13 }
                        Txt { text: AP.fmtBytes(modelData.size); font.pixelSize: 12; color: Theme.muted } }
                    MouseArea { id: ma; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onClicked: root.toggle(modelData.path) }
                }
            }
        }
        RowLayout {
            visible: root.scan.missing.length > 0; Layout.fillWidth: true; spacing: 10
            Check { on: root.clearMissing; Layout.alignment: Qt.AlignTop; MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor; onClicked: root.clearMissing = !root.clearMissing } }
            ColumnLayout { Layout.fillWidth: true; spacing: 2
                Txt { Layout.fillWidth: true; wrapMode: Text.WordWrap; w: 600; text: "Also clear " + root.scan.missing.length + " link" + (root.scan.missing.length === 1 ? "" : "s") + " to files that no longer exist" }
                Txt { Layout.fillWidth: true; wrapMode: Text.WordWrap; font.pixelSize: 12; color: Theme.muted
                      text: root.scan.missing.slice(0, 4).join(" · ") + (root.scan.missing.length > 4 ? " · +" + (root.scan.missing.length - 4) + " more" : "") } }
        }
    }
}
