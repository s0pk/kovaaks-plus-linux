import QtQuick
import QtQuick.Layouts
import Kplus
import "js/Fmt.js" as Fmt
import "js/PresetLogic.js" as PL

Item {
    id: root
    implicitHeight: col.implicitHeight
    Component.onCompleted: Store.loadPresets()

    Column {
        id: col
        width: parent.width; spacing: 16
        RowLayout {
            width: parent.width
            Btn { kind: "primary"; icon: "plus"; text: "New preset from current settings"; onClicked: Modals.capturePreset() }
            Item { Layout.fillWidth: true }
            Txt { visible: Store.presets !== null; text: (Store.presets ? Store.presets.length : 0) + " preset" + (Store.presets && Store.presets.length === 1 ? "" : "s"); color: Theme.muted; font.pixelSize: 13 }
        }
        Txt { visible: Store.presets === null; text: "Loading presets…"; color: Theme.muted; width: parent.width; horizontalAlignment: Text.AlignHCenter; topPadding: 30 }
        Card {
            visible: Store.presets !== null && Store.presets.length === 0
            width: parent.width; height: 150
            Column {
                anchors.centerIn: parent; spacing: 8; width: parent.width - 60
                Icon { name: "sliders"; size: 26; color: Theme.muted; anchors.horizontalCenter: parent.horizontalCenter }
                Txt { text: "No presets yet"; w: 700; anchors.horizontalCenter: parent.horizontalCenter }
                Txt { text: "Capture your current sensitivity, crosshair, colors and more as a preset, then switch setups in one click or share them with friends."
                      color: Theme.muted; width: parent.width; horizontalAlignment: Text.AlignHCenter; wrapMode: Text.WordWrap }
            }
        }
        CardGrid {
            visible: Store.presets !== null && Store.presets.length > 0
            width: parent.width; minWidth: 330; gap: 16
            model: Store.presets || []
            delegate: PresetCard { required property var modelData; p: modelData; width: parent.cellWidth }
        }
    }

    component PresetCard: Rectangle {
        id: pc
        property var p: ({})
        readonly property var sp: PL.specs(p)
        readonly property string chUrl: p.crosshairData ? "data:image/png;base64," + p.crosshairData : (sp.crosshair ? Launch.http + "/crosshair/" + encodeURIComponent(sp.crosshair) : "")
        height: inner.implicitHeight
        radius: Theme.radius; color: Theme.surface; border.width: 1; border.color: hov.hovered ? Theme.border2 : Theme.border
        clip: true
        HoverHandler { id: hov }
        Column {
            id: inner
            width: parent.width
            Item {
                width: parent.width; height: width * 9 / 16
                Thumb { visible: !!pc.p.thumbnail; anchors.fill: parent; fill: true; name: pc.p.name; media: pc.p.thumbnail || ""; label: false }
                Rectangle {
                    visible: !pc.p.thumbnail; anchors.fill: parent; color: Theme.bg2
                    Image { anchors.centerIn: parent; width: 90; height: 90; fillMode: Image.PreserveAspectFit; source: pc.chUrl; visible: pc.chUrl !== "" }
                    Icon { visible: pc.chUrl === ""; anchors.centerIn: parent; name: "target"; size: 34; color: Theme.border2 }
                }
            }
            Item {
                width: parent.width; implicitHeight: body.implicitHeight + 28
                height: implicitHeight
                Column {
                    id: body
                    x: 16; y: 14; width: parent.width - 32; spacing: 10
                    RowLayout {
                        width: parent.width; spacing: 8
                        Txt { text: pc.p.name; w: 700; font.pixelSize: 16; elide: Text.ElideRight; Layout.fillWidth: true }
                        Txt { text: Fmt.fmtDate(pc.p.updated); font.pixelSize: 12; color: Theme.muted }
                    }
                    Txt { visible: !!pc.p.description; text: pc.p.description || ""; color: Theme.muted; font.pixelSize: 13; width: parent.width; wrapMode: Text.WordWrap }
                    Flow {
                        width: parent.width; spacing: 5
                        Repeater { model: pc.p.categories || []; delegate: Chip { required property string modelData; small: true; text: PL.CAT_LABELS[modelData] || modelData; chipColor: "#64748b" } }
                    }
                    Grid {
                        width: parent.width; columns: 2; columnSpacing: 12; rowSpacing: 3
                        Txt { visible: !!pc.sp.sens; width: parent.width / 2 - 6; elide: Text.ElideRight; font.pixelSize: 12; color: Theme.muted; textFormat: Text.StyledText
                              text: "Sens <b><font color='" + Theme.text + "'>" + pc.sp.sens + "</font></b>" }
                        Txt { visible: !!pc.sp.dpi; width: parent.width / 2 - 6; elide: Text.ElideRight; font.pixelSize: 12; color: Theme.muted; textFormat: Text.StyledText
                              text: "DPI <b><font color='" + Theme.text + "'>" + pc.sp.dpi + "</font></b>" }
                        Txt { visible: !!pc.sp.fov; width: parent.width / 2 - 6; elide: Text.ElideRight; font.pixelSize: 12; color: Theme.muted; textFormat: Text.StyledText
                              text: "FOV <b><font color='" + Theme.text + "'>" + pc.sp.fov + "</font></b>" }
                        Txt { visible: !!pc.sp.crosshair; width: parent.width / 2 - 6; elide: Text.ElideRight; font.pixelSize: 12; color: Theme.muted; textFormat: Text.StyledText
                              text: "Crosshair <b><font color='" + Theme.text + "'>" + (pc.sp.crosshair || "").replace(/\.png$/i, "") + "</font></b>" }
                        Txt { visible: !!pc.sp.theme; width: parent.width; elide: Text.ElideRight; font.pixelSize: 12; color: Theme.muted; textFormat: Text.StyledText
                              text: "Theme <b><font color='" + Theme.text + "'>" + pc.sp.theme + "</font></b>" }
                    }
                    RowLayout {
                        width: parent.width; spacing: 6
                        Btn { Layout.fillWidth: true; small: true; kind: "primary"; icon: "check"; text: "Apply"
                              onClicked: Store.withRestart("presets.apply", { id: pc.p.id }, "Applied \"" + pc.p.name + "\"") }
                        Btn { small: true; icon: "edit"; tip: "Edit name, description & images"; onClicked: Modals.editPreset(pc.p) }
                        Btn { small: true; icon: "refresh"; tip: "Update from current settings"
                              onClicked: Modals.confirm("Update preset?", "Replace the values in \"" + pc.p.name + "\" with your current KovaaK's settings (same categories)?", "Update", "primary", function (yes) {
                                  if (yes) Backend.call("presets.recapture", { id: pc.p.id }, function () { Store.toast("Preset updated", "ok"); Store.loadPresets() }, function (e) { Store.toast(e, "error") }) }) }
                        Btn { small: true; icon: "download"; tip: "Export preset"; onClicked: Store.exportItems({ presets: [pc.p.id], name: pc.p.name }) }
                        Btn { small: true; icon: "trash"; tip: "Delete"
                              onClicked: Modals.confirm("Delete preset?", "\"" + pc.p.name + "\" will be deleted. Your KovaaK's settings are not affected.", "Delete", "danger", function (yes) {
                                  if (yes) Backend.call("presets.delete", { id: pc.p.id }, function () { Store.loadPresets() }, function (e) { Store.toast(e, "error") }) }) }
                    }
                }
            }
        }
    }
}
