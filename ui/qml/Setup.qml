import QtQuick
import QtQuick.Layouts
import Kplus

// First-run setup: everything is auto-detected, the user just confirms.
Rectangle {
    id: root
    color: Theme.bg
    z: 90
    property var cfg: ({})
    property bool gameOk: false

    Component.onCompleted: {
        var c = {}
        for (var k in Store.config) c[k] = Store.config[k]
        ;["pauseBringsApp", "runEndBringsApp", "celebratePB"].forEach(function (key) { if (c[key] === undefined) c[key] = true })
        cfg = c
        validate()
    }
    function patch(p) { var c = {}; for (var k in cfg) c[k] = cfg[k]; for (var q in p) c[q] = p[q]; cfg = c }
    function validate() {
        if (!cfg.gamePath) { gameOk = false; return }
        var gp = cfg.gamePath
        Backend.call("app.validateGamePath", { path: gp }, function (v) { if (gp === cfg.gamePath) gameOk = !!v.valid }, function () { gameOk = false })
    }
    function browse() {
        Backend.call("app.pickFolder", { title: "Select the FPSAimTrainer folder (…/steamapps/common/FPSAimTrainer)" }, function (p) { if (p) { patch({ gamePath: p }); validate() } }, function (e) { Store.toast(e, "error") })
    }
    function finish() {
        var p = {}
        for (var k in cfg) p[k] = cfg[k]
        p.setupComplete = true
        Store.saveConfig(p, function (res) {
            if (!res.valid) { Store.toast("That folder doesn't look like a KovaaK's install", "error"); return }
            Store.firstRun = false
            Store.toast("All set! Indexing your stats…", "ok")
            Store.loadLibrary()
        })
    }
    MouseArea { anchors.fill: parent; hoverEnabled: true; onWheel: function (w) { w.accepted = true } }   // swallow input behind

    Flickable {
        anchors.fill: parent; contentHeight: Math.max(height, card.height + 80); clip: true; boundsBehavior: Flickable.StopAtBounds
        Card {
            id: card
            anchors.horizontalCenter: parent.horizontalCenter; y: Math.max(40, (parent.height - height) / 2 - 10)
            width: Math.min(680, parent.width - 48); pad: 36
            height: col.implicitHeight + 72
            ColumnLayout {
                id: col; width: parent.width; spacing: 14
                Image { source: Theme.assets + "logo.png"; Layout.preferredWidth: 56; Layout.preferredHeight: 56; sourceSize.width: 112; sourceSize.height: 112; smooth: true }
                Txt { text: "Welcome to Kovaak's Plus"; display: true; w: 700; font.pixelSize: 44; lineHeight: 0.92 }
                Txt { Layout.fillWidth: true; wrapMode: Text.WordWrap; font.pixelSize: 15; color: Theme.muted; Layout.bottomMargin: 8
                      text: "Your control center for KovaaK's. Browse and launch scenarios here; the game only comes forward when you're aiming. Pause or finish a run and you're back here with your stats." }

                component CheckRow: Item {
                    id: cr
                    property bool ok: false
                    property bool optional: false
                    property string title: ""
                    property string sub: ""
                    default property alias control: ctl.data
                    Layout.fillWidth: true; implicitHeight: 54
                    Rectangle { anchors.bottom: parent.bottom; width: parent.width; height: 1; color: Theme.border }
                    RowLayout { anchors.fill: parent; spacing: 14
                        Txt { text: cr.ok ? "✓" : (cr.optional ? "–" : "✕"); w: 700; font.pixelSize: 18; color: cr.ok ? Theme.good : (cr.optional ? Theme.muted : Theme.bad); Layout.preferredWidth: 20; horizontalAlignment: Text.AlignHCenter }
                        ColumnLayout { Layout.fillWidth: true; spacing: 1
                            Txt { text: cr.title; w: 700 }
                            Txt { text: cr.sub; font.pixelSize: 12; color: Theme.muted; Layout.fillWidth: true; elide: Text.ElideMiddle } }
                        RowLayout { id: ctl } }
                }
                CheckRow { ok: root.gameOk; title: "KovaaK's installation"; sub: root.cfg.gamePath || "Not found automatically"
                           Btn { small: true; icon: "folder"; text: "Browse"; onClicked: root.browse() } }
                CheckRow { ok: !!(root.cfg.workshopPaths && root.cfg.workshopPaths.length); optional: true; title: "Steam Workshop scenarios"
                           sub: root.cfg.workshopPaths && root.cfg.workshopPaths.length ? root.cfg.workshopPaths.length + " workshop folder(s) found" : "None found (that's fine)" }
                CheckRow { ok: !!root.cfg.steamId; optional: true; title: "Steam account"
                           sub: root.cfg.steamName ? "Signed in as " + root.cfg.steamName + ". Used for benchmark ranks on evxl.app" : "Used for benchmark ranks (optional)"
                           Field { implicitWidth: 190; placeholder: "7656119…"; text: root.cfg.steamId || ""; onEdited: function (t) { root.patch({ steamId: t.trim() || null }) } } }

                Txt { text: "Behavior"; w: 700; font.pixelSize: 13; color: Theme.muted; Layout.topMargin: 14 }
                Repeater {
                    model: [["pauseBringsApp", "Pausing in KovaaK's brings this app forward", "Press " + (root.cfg.pauseKey || "Escape") + " in game to come back here"],
                            ["runEndBringsApp", "Show results when a run ends", "Score, PB comparison and benchmark rank"],
                            ["celebratePB", "Celebrate new personal bests", "Confetti and a short chime"]]
                    delegate: RowLayout {
                        required property var modelData
                        Layout.fillWidth: true; spacing: 14
                        ColumnLayout { Layout.fillWidth: true; spacing: 1
                            Txt { text: modelData[1]; w: 600 }
                            Txt { text: modelData[2]; font.pixelSize: 12; color: Theme.muted } }
                        Toggle { checked: root.cfg[modelData[0]] !== false; onToggled: function (v) { var p = {}; p[modelData[0]] = v; root.patch(p) } }
                    }
                }
                Rectangle { Layout.fillWidth: true; Layout.topMargin: 10; implicitHeight: tip.implicitHeight + 24; radius: Theme.radiusSm; color: Theme.bg2; border.width: 1; border.color: Theme.border
                            Txt { id: tip; x: 14; y: 12; width: parent.width - 28; wrapMode: Text.WordWrap; font.pixelSize: 13; color: Theme.muted; textFormat: Text.StyledText
                                  text: "<b>Tip:</b> Set KovaaK's display mode to <b>Windowed Fullscreen</b> so switching between the game and this app is instant." } }
                RowLayout { Layout.fillWidth: true; Layout.topMargin: 12
                    Item { Layout.fillWidth: true }
                    Btn { large: true; kind: "primary"; text: "Let's go"; enabled: root.gameOk; onClicked: root.finish() } }
            }
        }
    }
}
