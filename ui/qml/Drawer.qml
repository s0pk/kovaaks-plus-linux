import QtQuick
import QtQuick.Layouts
import QtQuick.Controls
import Kplus
import "js/Fmt.js" as Fmt
import "js/ChartMath.js" as CM
import "js/BenchCalc.js" as BC

// Scenario detail drawer: rename, tag, thumbnail/preview, notes, history, leaderboard, calculator, play.
Item {
    id: root
    anchors.fill: parent
    visible: opened || slide.running
    z: 800
    property bool opened: false
    property string name: ""
    property var detail: null
    property var thr: []              // benchmark rank thresholds for this scenario
    property var chosenBench: null
    readonly property var meta: detail ? detail.meta : ({})
    readonly property var runs: detail ? (detail.runs || []) : []
    readonly property var sc: Store.scenario(name) || ({ name: name, tags: [] })

    function openFor(n) {
        name = n; detail = null; thr = []; chosenBench = null; opened = true
        flick.contentY = 0
        reload()
        Store.loadPresets()
    }
    function close() { opened = false }
    function reload() {
        var nm = name
        Backend.call("library.detail", { name: nm }, function (d) { if (nm === root.name) { root.detail = d; root.loadThresholds() } }, function (e) { Store.toast(e, "error"); root.close() })
    }
    function save(patch) {
        var params = { name: name }
        for (var k in patch) params[k] = patch[k]
        Backend.call("library.setMeta", params, function (res) { Store.patchScenario(name, res.meta); root.detail = res }, function (e) { Store.toast(e, "error") })
    }
    function loadThresholds() {
        thr = []
        if (!detail || !(detail.benchmarks || []).length) return
        var nm = name
        Backend.call("bench.thresholds", { name: nm }, function (list) {
            if (nm !== root.name) return
            root.thr = list
            root.chosenBench = root.pickBench(list)
        }, function () {})
    }
    function pickBench(list) {
        var p = (Store.config.ui && Store.config.ui.chartThresholds) || "auto"
        if (p === "off" || !list.length) return null
        for (var i = 0; i < list.length; i++) if (list[i].id === p) return list[i]
        return list[0]
    }
    function setBenchPref(v) {
        var ui = JSON.parse(JSON.stringify(Store.config.ui || {}))
        ui.chartThresholds = v
        Store.saveConfig({ ui: ui })
        chosenBench = v === "off" ? null : thr.filter(function (b) { return b.id === v })[0] || null
    }
    function importDropped(urls) {
        if (!urls.length) return
        var path = String(urls[0])
        var kind = /\.(gif|mp4|webm)$/i.test(path) ? "preview" : "thumbnail"
        Backend.call("media.importPath", { path: path, owner: "scenario:" + name, target: kind }, function (f) { root.save((function () { var o = {}; o[kind] = f; return o })()) }, function (e) { Store.toast(e, "error") })
    }
    function setMedia(kind) {
        Backend.call("media.pick", { kind: kind === "preview" ? "video" : "image", owner: "scenario:" + name, target: kind }, function (f) {
            if (f) { var o = {}; o[kind] = f; root.save(o) }
        }, function (e) { Store.toast(e, "error") })
    }
    function showRun(file, title) { Modals.runDetail(file, title) }

    readonly property real pb: runs.length ? Math.max.apply(null, runs.map(function (r) { return r.score })) : NaN
    readonly property real avg5: {
        var l = runs.slice(-5)
        return l.length ? l.reduce(function (a, r) { return a + r.score }, 0) / l.length : NaN
    }
    readonly property var shown: runs.slice(-150)
    readonly property var historySeries: {
        if (shown.length < 2) return []
        var n = Math.min(10, Math.max(3, Math.floor(shown.length / 8)))
        var ma = CM.movingAverage(shown.map(function (r) { return r.score }), n)
        var dn = meta.customName || name
        return [
            { points: shown.map(function (r, i) {
                  return { x: i, y: r.score, pb: !!r.pb && i > 0, onClick: function () { root.showRun(r.file, dn) },
                           tip: "<b>" + Fmt.fmtScore(r.score) + "</b> · " + Fmt.fmtPct(r.accuracy) + "<br><font color='" + Theme.muted + "'>" + Fmt.fmtDateTime(r.date) + (r.pb ? " · PB" : "") + "</font>" } }),
              color: Theme.text2.toString(), width: 1.4, dots: true },
            { points: shown.map(function (r, i) { return { x: i, y: ma[i] } }), color: Theme.accent.toString(), width: 2.6, dots: false }
        ]
    }
    readonly property var overlay: CM.thresholdOverlay(chosenBench, shown.map(function (r) { return r.score }), BC.rankEntry, Fmt.rankColor)
    readonly property var historyLines: overlay.hLines.concat(isNaN(pb) ? [] : [{ y: pb, label: "PB " + Fmt.fmtScore(pb) }])

    Keys.onEscapePressed: root.close()
    focus: opened

    Rectangle {
        anchors.fill: parent
        color: Qt.rgba(0.03, 0.03, 0.028, 0.78)
        opacity: root.opened ? 1 : 0
        Behavior on opacity { NumberAnimation { duration: Theme.animMs } }
        MouseArea { anchors.fill: parent; onClicked: root.close() }
    }

    Rectangle {
        id: panel
        width: Math.min(760, root.width * 0.92)
        height: parent.height
        x: root.opened ? root.width - width : root.width
        color: Theme.bg2
        Behavior on x { NumberAnimation { id: slide; duration: Theme.animMs * 1.6; easing.type: Easing.OutCubic } }
        Rectangle { anchors.left: parent.left; width: 1; height: parent.height; color: Theme.border2 }
        MouseArea { anchors.fill: parent }   // swallow clicks

        Item {
            visible: !root.detail
            anchors.fill: parent
            Spinner { anchors.centerIn: parent }
        }

        Flickable {
            id: flick
            visible: !!root.detail
            anchors.top: parent.top; anchors.left: parent.left; anchors.right: parent.right; anchors.bottom: foot.top
            contentWidth: width; contentHeight: body.implicitHeight
            clip: true; boundsBehavior: Flickable.StopAtBounds
            ScrollBar.vertical: ThinScroll {}

            ColumnLayout {
                id: body
                width: flick.width
                spacing: 0

                // ---- hero ----
                Item {
                    Layout.fillWidth: true; Layout.preferredHeight: width * 8 / 21
                    Thumb {
                        anchors.fill: parent; fill: true; label: false
                        name: root.name; media: root.meta.thumbnail || (/\.(mp4|webm)$/i.test(root.meta.preview || "") ? "" : (root.meta.preview || ""))
                        tagColor: Store.primaryTagColor(root.sc); info: Store.artInfo(root.sc)
                        tagMedia: (root.meta.thumbnail || root.meta.preview) ? [] : Store.tagThumbs({ tags: root.meta.tags || [] })
                    }
                    Rectangle { anchors.fill: parent; gradient: Gradient { GradientStop { position: 0.35; color: "transparent" } GradientStop { position: 1; color: Theme.bg2 } } }
                    Row {
                        anchors.right: parent.right; anchors.top: parent.top; anchors.margins: 14; spacing: 8
                        Btn { small: true; icon: "image"; text: "Thumbnail"; tip: "Card thumbnail: click, or drop a file on the picture"; onClicked: root.setMedia("thumbnail") }
                        Btn { small: true; icon: "film"; text: "Preview"; tip: "Large preview: image, GIF or MP4/WebM clip"; onClicked: root.setMedia("preview") }
                        Btn { visible: !!(root.meta.thumbnail || root.meta.preview); small: true; icon: "trash"; tip: "Remove thumbnail & preview"; onClicked: root.save({ thumbnail: null, preview: null }) }
                        Btn { small: true; icon: "x"; tip: "Close"; onClicked: root.close() }
                    }
                    DropArea { anchors.fill: parent; onDropped: function (d) { root.importDropped(d.urls) } }
                }

                // ---- head ----
                ColumnLayout {
                    Layout.fillWidth: true; Layout.leftMargin: 26; Layout.rightMargin: 26; Layout.topMargin: -44
                    spacing: 0
                    TextInput {
                        id: titleIn
                        Layout.fillWidth: true
                        text: root.meta.customName || root.name
                        color: Theme.text; selectionColor: Theme.accentLine; selectedTextColor: Theme.text
                        font.family: Theme.display(700); font.pixelSize: 44
                        clip: true
                        onEditingFinished: {
                            var v = text.trim(), next = !v || v === root.name ? null : v
                            if (next !== (root.meta.customName || null)) root.save({ customName: next })
                        }
                        Keys.onEscapePressed: { text = root.meta.customName || root.name; focus = false }
                        Rectangle { z: -1; anchors.fill: parent; anchors.margins: -4; radius: Theme.radiusSm; color: parent.activeFocus ? Theme.surface : "transparent" }
                    }
                    RowLayout {
                        visible: !!root.meta.customName; Layout.topMargin: 4; spacing: 6
                        Txt { text: "In KovaaK's:"; font.pixelSize: 12; color: Theme.muted }
                        Txt { text: root.name; font.pixelSize: 12; w: 600; color: Theme.text2 }
                        Btn { small: true; kind: "ghost"; text: "Reset name"; onClicked: root.save({ customName: null }) }
                    }
                    Flow {
                        Layout.fillWidth: true; Layout.topMargin: 12; spacing: 8
                        Repeater {
                            model: (root.meta.tags || []).map(function (id) { return Store.tagById(id) }).filter(function (t) { return t })
                            delegate: Chip { required property var modelData; text: modelData.name; chipColor: modelData.color; removable: true
                                             onRemoved: root.save({ tags: (root.meta.tags || []).filter(function (x) { return x !== modelData.id }) }) }
                        }
                        Btn { small: true; icon: "tag"; text: "Edit tags"; onClicked: Modals.pickTags("Tags · " + (root.meta.customName || root.name), root.meta.tags || [], function (ids) { root.save({ tags: ids }) }) }
                    }
                    RowLayout {
                        Layout.fillWidth: true; Layout.topMargin: 10; spacing: 8
                        Icon { name: "sliders"; size: 15; color: Theme.muted }
                        Txt { text: "Default preset:"; font.pixelSize: 12; color: Theme.muted }
                        readonly property var tagPreset: Store.tags.filter(function (t) { return t.preset && (root.meta.tags || []).indexOf(t.id) >= 0 })[0]
                        function presetLabel(id) { var p = (Store.presets || []).filter(function (x) { return x.id === id })[0]; return p ? p.name : "?" }
                        Btn { small: true
                              text: root.meta.preset ? parent.presetLabel(root.meta.preset) : (parent.tagPreset ? parent.presetLabel(parent.tagPreset.preset) + " (from " + parent.tagPreset.name + ")" : "None")
                              onClicked: Modals.pickPreset("Default preset · " + (root.meta.customName || root.name), root.meta.preset || "", parent.tagPreset ? "Uses the \"" + parent.tagPreset.name + "\" tag's preset" : "", function (id) { root.save({ preset: id || null }) }) }
                        Btn { visible: !!root.meta.preset; small: true; kind: "ghost"; text: "Clear"; onClicked: root.save({ preset: null }) }
                        Item { Layout.fillWidth: true }
                        Btn { small: true; kind: "ghost"; icon: "star"; text: root.meta.favorite ? "Favorited" : "Favorite"; onClicked: root.save({ favorite: !root.meta.favorite }) }
                        Btn { small: true; kind: "ghost"; icon: root.meta.hidden ? "eye" : "eyeOff"; text: root.meta.hidden ? "Unhide" : "Hide"; onClicked: root.save({ hidden: !root.meta.hidden }) }
                    }
                }

                // ---- stats ----
                ColumnLayout {
                    Layout.fillWidth: true; Layout.margins: 26; Layout.topMargin: 22; spacing: 14
                    RowLayout {
                        Layout.fillWidth: true; spacing: 12
                        Repeater {
                            model: [["Personal best", Fmt.fmtScore(root.pb)], ["Plays", String(root.runs.length)], ["Avg (last 5)", Fmt.fmtScore(root.avg5)], ["Last played", root.runs.length ? Fmt.timeAgo(root.runs[root.runs.length - 1].date) : "never"]]
                            delegate: Column { required property var modelData; Layout.fillWidth: true; Layout.preferredWidth: 1
                                Txt { text: modelData[0]; font.pixelSize: 12; color: Theme.muted }
                                Txt { text: modelData[1]; display: true; w: 700; font.pixelSize: 32 } }
                        }
                    }
                    Flow {
                        Layout.fillWidth: true; spacing: 16
                        readonly property var f: root.detail ? root.detail.file : null
                        Txt { text: parent.f ? (parent.f.source === "workshop" ? "Steam Workshop" : "Local scenario") : "Not installed locally — KovaaK's will download it when played"; font.pixelSize: 12; color: parent.f ? Theme.muted : Theme.bad }
                        Txt { visible: !!(parent.f && parent.f.author); text: "by " + (parent.f ? parent.f.author : ""); font.pixelSize: 12; color: Theme.muted }
                        Txt { visible: !!(parent.f && parent.f.timeLimit); text: (parent.f ? parent.f.timeLimit : 0) + "s"; font.pixelSize: 12; color: Theme.muted }
                        Txt { visible: !!(parent.f && parent.f.gameTag); text: "Category: " + (parent.f ? parent.f.gameTag : ""); font.pixelSize: 12; color: Theme.muted }
                        Txt { visible: !!(parent.f && parent.f.difficulty); text: "Difficulty: " + (parent.f ? parent.f.difficulty : ""); font.pixelSize: 12; color: Theme.muted }
                    }
                }

                // ---- score history ----
                ColumnLayout {
                    Layout.fillWidth: true; Layout.leftMargin: 26; Layout.rightMargin: 26; Layout.topMargin: 6; Layout.bottomMargin: 18; spacing: 12
                    Rectangle { Layout.fillWidth: true; height: 1; color: Theme.border; Layout.bottomMargin: 6 }
                    RowLayout {
                        Layout.fillWidth: true
                        Txt { text: "Score history"; w: 700; Layout.fillWidth: true }
                        Select {
                            visible: root.thr.length > 0; implicitWidth: 220; implicitHeight: 26
                            options: [{ value: "off", label: "No rank lines" }].concat(root.thr.map(function (b) { return { value: b.id, label: b.name + (b.difficulty ? " · " + b.difficulty : "") } }))
                            value: root.chosenBench ? root.chosenBench.id : "off"
                            onPicked: function (v) { root.setBenchPref(v) }
                        }
                        Txt { visible: root.runs.length > 1; text: root.runs.length + " runs since " + (root.runs.length ? Fmt.fmtDate(root.runs[0].date) : ""); font.pixelSize: 12; color: Theme.muted }
                    }
                    LineChart { visible: root.runs.length > 1; Layout.fillWidth: true; chartHeight: 210; series: root.historySeries; hLines: root.historyLines; bands: root.overlay.bands }
                    Txt { visible: root.runs.length <= 1; text: root.runs.length ? "Play a few more runs to see a trend." : "No runs recorded yet."; font.pixelSize: 12; color: Theme.muted }
                }

                // ---- leaderboard ----
                ColumnLayout {
                    Layout.fillWidth: true; Layout.leftMargin: 26; Layout.rightMargin: 26; Layout.bottomMargin: 18; spacing: 12
                    Rectangle { Layout.fillWidth: true; height: 1; color: Theme.border; Layout.bottomMargin: 6 }
                    RowLayout { Layout.fillWidth: true
                        Txt { text: "Leaderboard"; w: 700; Layout.fillWidth: true }
                        Btn { small: true; kind: "ghost"; text: "Full leaderboard"; onClicked: Modals.scenarioLeaderboard(root.name, root.meta.customName || root.name) } }
                    Loader { Layout.fillWidth: true; active: !!root.detail; sourceComponent: ScenarioLeaderboard { name: root.name; compact: true } }
                }

                // ---- calculator ----
                ColumnLayout {
                    Layout.fillWidth: true; Layout.leftMargin: 26; Layout.rightMargin: 26; Layout.bottomMargin: 18; spacing: 12
                    Rectangle { Layout.fillWidth: true; height: 1; color: Theme.border; Layout.bottomMargin: 6 }
                    RowLayout { Layout.fillWidth: true
                        Txt { text: "Calculator"; w: 700 }
                        Txt { text: "score needed for a rank or leaderboard spot"; font.pixelSize: 12; color: Theme.muted; Layout.fillWidth: true } }
                    Loader { Layout.fillWidth: true; active: !!root.detail; sourceComponent: ScenarioCalculator { name: root.name; pb: isNaN(root.pb) ? 0 : root.pb; benchmarks: root.detail ? (root.detail.benchmarks || []) : [] } }
                }

                // ---- benchmarks ----
                ColumnLayout {
                    visible: !!(root.detail && (root.detail.benchmarks || []).length)
                    Layout.fillWidth: true; Layout.leftMargin: 26; Layout.rightMargin: 26; Layout.bottomMargin: 18; spacing: 12
                    Rectangle { Layout.fillWidth: true; height: 1; color: Theme.border; Layout.bottomMargin: 6 }
                    Txt { text: "Part of benchmarks"; w: 700 }
                    Flow {
                        Layout.fillWidth: true; spacing: 6
                        Repeater { model: root.detail ? (root.detail.benchmarks || []) : []
                                   delegate: Chip { required property var modelData; text: (modelData.name || "Benchmark " + modelData.id) + (modelData.difficulty ? " · " + modelData.difficulty : ""); chipColor: "#eab308"; clickable: true
                                                    onClicked: { root.close(); Store.go("benchmarks/" + modelData.id) } } }
                    }
                }

                // ---- description + notes ----
                ColumnLayout {
                    Layout.fillWidth: true; Layout.leftMargin: 26; Layout.rightMargin: 26; Layout.bottomMargin: 18; spacing: 12
                    Rectangle { Layout.fillWidth: true; height: 1; color: Theme.border; Layout.bottomMargin: 6 }
                    ColumnLayout {
                        visible: !!(root.detail && root.detail.file && root.detail.file.description); Layout.fillWidth: true; spacing: 6
                        Txt { text: "Description"; w: 700 }
                        Txt { text: root.detail && root.detail.file ? root.detail.file.description || "" : ""; color: Theme.muted; wrapMode: Text.WordWrap; Layout.fillWidth: true; Layout.bottomMargin: 10 }
                    }
                    Txt { text: "Notes"; w: 700 }
                    Rectangle {
                        Layout.fillWidth: true; Layout.preferredHeight: Math.max(90, notes.contentHeight + 20)
                        radius: Theme.radiusSm; color: Theme.bg2; border.width: 1; border.color: notes.activeFocus ? Theme.accent : Theme.border2
                        TextEdit {
                            id: notes
                            anchors.fill: parent; anchors.margins: 10
                            text: root.meta.notes || ""
                            color: Theme.text; selectionColor: Theme.accentLine; wrapMode: TextEdit.Wrap
                            font.family: Theme.sans(400); font.pixelSize: 14
                            onActiveFocusChanged: if (!activeFocus && (text.trim() || null) !== (root.meta.notes || null)) root.save({ notes: text })
                            Txt { visible: !parent.text && !parent.activeFocus; text: "Personal notes: focus points, sens tips, routine reminders…"; color: Theme.muted }
                        }
                    }
                }

                // ---- recent runs ----
                ColumnLayout {
                    visible: root.runs.length > 0
                    Layout.fillWidth: true; Layout.leftMargin: 26; Layout.rightMargin: 26; Layout.bottomMargin: 30; spacing: 4
                    Rectangle { Layout.fillWidth: true; height: 1; color: Theme.border; Layout.bottomMargin: 10 }
                    Txt { text: "Recent runs"; w: 700; Layout.bottomMargin: 6 }
                    RowLayout { Layout.fillWidth: true; Layout.leftMargin: 10; Layout.rightMargin: 10; spacing: 10
                        Txt { text: "When"; font.pixelSize: 12; color: Theme.muted; Layout.fillWidth: true }
                        Txt { text: "Score"; font.pixelSize: 12; color: Theme.muted; Layout.preferredWidth: 70; horizontalAlignment: Text.AlignRight }
                        Txt { text: "Accuracy"; font.pixelSize: 12; color: Theme.muted; Layout.preferredWidth: 64; horizontalAlignment: Text.AlignRight }
                        Txt { text: "Sens"; font.pixelSize: 12; color: Theme.muted; Layout.preferredWidth: 90; horizontalAlignment: Text.AlignRight }
                        Txt { text: "FOV"; font.pixelSize: 12; color: Theme.muted; Layout.preferredWidth: 40; horizontalAlignment: Text.AlignRight } }
                    Repeater {
                        model: root.runs.slice(-12).reverse()
                        delegate: Rectangle {
                            id: rr
                            required property var modelData
                            readonly property bool today: Fmt.isToday(modelData.date)
                            Layout.fillWidth: true; Layout.preferredHeight: 34
                            color: ra.containsMouse ? Theme.surface2 : "transparent"
                            opacity: !today && Theme.dimOld && !ra.containsMouse ? 0.5 : 1
                            Rectangle { visible: !!rr.modelData.pb || rr.today; width: 3; height: parent.height; color: rr.modelData.pb ? Theme.gold : Theme.accent }
                            RowLayout {
                                anchors.fill: parent; anchors.leftMargin: 10; anchors.rightMargin: 10; spacing: 10
                                RowLayout { Layout.fillWidth: true; spacing: 8
                                    Txt { text: Fmt.fmtDateTime(rr.modelData.date) }
                                    Rectangle { visible: !!rr.modelData.pb; width: 26; height: 18; radius: 3; color: Theme.alpha(Theme.gold, 0.18); Txt { anchors.centerIn: parent; text: "PB"; font.pixelSize: 11; w: 700; color: Theme.gold } } }
                                Txt { text: Fmt.fmtScore(rr.modelData.score); w: 700; Layout.preferredWidth: 70; horizontalAlignment: Text.AlignRight }
                                Txt { text: Fmt.fmtPct(rr.modelData.accuracy); Layout.preferredWidth: 64; horizontalAlignment: Text.AlignRight }
                                Txt { text: Fmt.fmtSens(rr.modelData); color: Theme.muted; Layout.preferredWidth: 90; horizontalAlignment: Text.AlignRight; elide: Text.ElideRight }
                                Txt { text: rr.modelData.fov ? String(rr.modelData.fov) : "—"; color: Theme.muted; Layout.preferredWidth: 40; horizontalAlignment: Text.AlignRight }
                            }
                            MouseArea { id: ra; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onClicked: root.showRun(rr.modelData.file, root.meta.customName || root.name) }
                        }
                    }
                }
            }
        }

        // footer
        Rectangle {
            id: foot
            anchors.bottom: parent.bottom; width: parent.width; height: 70
            color: Theme.bg2
            Rectangle { width: parent.width; height: 1; color: Theme.border }
            RowLayout {
                anchors.fill: parent; anchors.leftMargin: 26; anchors.rightMargin: 26; spacing: 10
                Btn { large: true; kind: "primary"; icon: "play"; text: "Play challenge"; onClicked: Store.play(root.name, "challenge") }
                Btn { large: true; text: "Freeplay"; onClicked: Store.play(root.name, "freeplay") }
                Item { Layout.fillWidth: true }
                Btn { kind: "ghost"; icon: "download"; text: "Export"; onClicked: Store.exportItems({ scenarios: [root.name], name: root.meta.customName || root.name }) }
                Btn { visible: !!(root.detail && root.detail.file); kind: "ghost"; icon: "folder"; tip: "Show file in file manager"; onClicked: Backend.send("library.revealScenario", { name: root.name }) }
            }
        }
    }

    Connections { target: Store; function onScenarioRequested(n) { root.openFor(n) } function onCloseOverlaysRequested() { root.close() } }
}
