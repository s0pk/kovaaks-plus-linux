import QtQuick
import QtQuick.Layouts
import Kplus
import "js/Fmt.js" as Fmt
import "js/BenchCalc.js" as BC

// What to improve to reach a target rank, an energy, or a leaderboard position on a benchmark.
ColumnLayout {
    id: root
    property var b: ({})
    property var res: ({})
    property string mode: "rank"
    property int rankPick: 1
    property var plan: null
    property var target: null
    property string note: ""
    property string message: ""
    property bool busy: false
    spacing: 12

    readonly property bool energy: !!(res.supported && res.params)
    readonly property int rankCount: res.rankCount || (b.rankNames || []).length
    readonly property var rankOptions: { var o = []; for (var i = 1; i <= rankCount; i++) o.push({ value: i, label: BC.rankEntry(i, b).name }); return o }
    Component.onCompleted: { rankPick = Math.min(rankCount, (res.rank || 0) + 1); energyIn.text = String(Math.round(((res.energy || 0) + 50) / 10) * 10); run() }

    function run() {
        note = ""; message = ""
        if (mode === "rank") { finish({ rank: rankPick }) }
        else if (mode === "energy") finish({ energy: parseFloat(energyIn.text) })
        else {
            var pos = Math.max(1, parseInt(posIn.text, 10) || 0)
            if (!pos) { Store.toast("Enter a leaderboard position"); return }
            busy = true
            Backend.call("lb.benchmark", { id: b.id, page: Math.floor((pos - 1) / 50), max: 50 }, function (lb) {
                busy = false
                var data = lb.data || []
                var row = data[(pos - 1) % 50] || data[data.length - 1]
                if (!row) { message = "That position doesn't exist on this leaderboard yet."; plan = null; return }
                note = "#" + pos.toLocaleString() + " is currently " + (row.webappUsername || row.steamAccountName) + " (" + row.rankName + (row.energy !== null && row.energy !== undefined ? ", " + Math.round(row.energy) + " energy" : "") + ")."
                var t
                if (root.energy && row.energy !== null && row.energy !== undefined) t = { energy: Math.ceil(row.energy) + 1 }
                else {
                    var base = (row.rankName || "").replace(/ complete$/i, "").toLowerCase()
                    var idx = (b.rankNames || []).findIndex(function (r) { return r.name.toLowerCase() === base })
                    t = { rank: Math.max(1, idx + 1) }
                }
                finish(t)
            }, function (e) { busy = false; message = e })
        }
    }
    function finish(t) { target = t; plan = BC.planBenchmark(b, res, t) }
    function pctText(p) { return p === Infinity ? "—" : p <= 0 ? "done" : "+" + (p * 100).toFixed(p < 0.1 ? 1 : 0) + "%" }
    readonly property string targetLabel: target ? (target.rank ? BC.rankEntry(target.rank, b).name : target.energy + " energy") : ""
    readonly property color targetColor: target && target.rank ? Fmt.rankColor(BC.rankEntry(target.rank, b), target.rank) : Theme.accent2

    RowLayout {
        Layout.fillWidth: true; spacing: 8
        Seg {
            options: root.energy ? [{ value: "rank", label: "Target rank" }, { value: "energy", label: "Target energy" }, { value: "lb", label: "Leaderboard position" }] : [{ value: "rank", label: "Target rank" }, { value: "lb", label: "Leaderboard position" }]
            value: root.mode; onPicked: function (v) { root.mode = v; root.plan = null; if (v === "rank") root.run() }
        }
        Select { visible: root.mode === "rank"; implicitWidth: 220; options: root.rankOptions; value: root.rankPick; onPicked: function (v) { root.rankPick = v; root.run() } }
        Field { id: energyIn; visible: root.mode === "energy"; implicitWidth: 120; inputMethodHints: Qt.ImhFormattedNumbersOnly; onAccepted: root.run() }
        RowLayout { visible: root.mode === "lb"; spacing: 6; Txt { text: "#"; color: Theme.muted }
                    Field { id: posIn; implicitWidth: 130; placeholder: "e.g. 1000"; inputMethodHints: Qt.ImhDigitsOnly; onAccepted: root.run() } }
        Btn { visible: root.mode !== "rank"; kind: "primary"; icon: "target"; text: "Calculate"; onClicked: root.run() }
        Item { Layout.fillWidth: true }
    }
    RowLayout { visible: root.busy; spacing: 10; Spinner {} Txt { text: "Looking up that position…"; color: Theme.muted; font.pixelSize: 12 } }
    Txt { visible: root.message !== ""; text: root.message; color: Theme.muted; font.pixelSize: 12 }
    Txt { visible: root.note !== ""; text: root.note; color: Theme.muted; font.pixelSize: 12; wrapMode: Text.WordWrap; Layout.fillWidth: true }

    // summary
    Txt {
        visible: !!root.plan; Layout.fillWidth: true; wrapMode: Text.WordWrap; color: Theme.text2
        text: !root.plan ? "" : root.plan.already ? (root.target.rank ? "You already have " + root.targetLabel + ". Nothing to improve." : "Your " + Math.round(root.res.energy || 0) + " energy already beats " + root.plan.targetEnergy + ". Nothing to improve.")
              : !root.plan.achievable ? (root.plan.note || "Not reachable with this benchmark's scoring.")
              : "To reach " + root.targetLabel + (root.plan.mode === "energy" ? " (" + root.plan.targetEnergy + " energy), raise " + root.plan.items.length + " subcategor" + (root.plan.items.length === 1 ? "y" : "ies") + " to at least " + root.plan.level + " energy:"
                : root.plan.mode === "subcategory" ? ", improve one scenario in each of " + root.plan.items.length + " subcategor" + (root.plan.items.length === 1 ? "y" : "ies") + ":"
                : ", improve " + root.plan.items.length + " scenario" + (root.plan.items.length === 1 ? "" : "s") + ":")
    }
    // plan table
    RowLayout {
        visible: !!root.plan && root.plan.items.length > 0
        Layout.fillWidth: true; Layout.leftMargin: 10; Layout.rightMargin: 10; spacing: 10
        Txt { text: "Scenario"; font.pixelSize: 12; color: Theme.muted; Layout.fillWidth: true; Layout.preferredWidth: 3 }
        Txt { text: root.plan && root.plan.mode === "scenario" ? "Category" : "Subcategory"; font.pixelSize: 12; color: Theme.muted; Layout.fillWidth: true; Layout.preferredWidth: 2 }
        Txt { text: "Current"; font.pixelSize: 12; color: Theme.muted; Layout.preferredWidth: 80; horizontalAlignment: Text.AlignRight }
        Txt { text: "Needed"; font.pixelSize: 12; color: Theme.muted; Layout.preferredWidth: 80; horizontalAlignment: Text.AlignRight }
        Txt { text: "Increase"; font.pixelSize: 12; color: Theme.muted; Layout.preferredWidth: 130; horizontalAlignment: Text.AlignRight }
        Txt { visible: !!root.plan && root.plan.mode === "energy"; text: "Energy"; font.pixelSize: 12; color: Theme.muted; Layout.preferredWidth: 80; horizontalAlignment: Text.AlignRight }
        Item { Layout.preferredWidth: 70 }
    }
    Repeater {
        model: root.plan ? root.plan.items : []
        delegate: Rectangle {
            required property var modelData
            Layout.fillWidth: true; Layout.preferredHeight: 38; radius: Theme.radiusSm; color: ra.containsMouse ? Theme.surface2 : "transparent"
            RowLayout {
                anchors.fill: parent; anchors.leftMargin: 10; anchors.rightMargin: 10; spacing: 10
                Txt { text: modelData.customName || modelData.name; w: 600; elide: Text.ElideRight; Layout.fillWidth: true; Layout.preferredWidth: 3 }
                Txt { text: modelData.group; color: Theme.muted; elide: Text.ElideRight; Layout.fillWidth: true; Layout.preferredWidth: 2 }
                Txt { text: modelData.current ? Fmt.fmtScore(modelData.current) : "—"; Layout.preferredWidth: 80; horizontalAlignment: Text.AlignRight }
                Txt { text: Fmt.fmtScore(modelData.need); w: 700; color: root.targetColor; Layout.preferredWidth: 80; horizontalAlignment: Text.AlignRight }
                Row { Layout.preferredWidth: 130; layoutDirection: Qt.RightToLeft; spacing: 6
                    Txt { text: root.pctText(modelData.pct); font.pixelSize: 12; color: Theme.muted; anchors.verticalCenter: parent.verticalCenter }
                    Txt { text: modelData.current ? "+" + Fmt.fmtScore(modelData.need - modelData.current) : "new"; w: 700; color: Theme.good; anchors.verticalCenter: parent.verticalCenter } }
                Txt { visible: !!root.plan && root.plan.mode === "energy"; text: modelData.from + " → " + modelData.to; color: Theme.muted; Layout.preferredWidth: 80; horizontalAlignment: Text.AlignRight; font.pixelSize: 12 }
                Btn { small: true; kind: "primary"; icon: "play"; text: "Play"; onClicked: Store.play(modelData.name, null, { queue: root.plan.items.map(function (x) { return x.name }) }) }
            }
            MouseArea { id: ra; anchors.fill: parent; z: -1; hoverEnabled: true }
        }
    }
    Txt {
        visible: !!root.plan && root.plan.items.length > 0; Layout.fillWidth: true; wrapMode: Text.WordWrap; font.pixelSize: 12; color: Theme.muted
        text: root.plan && root.plan.mode === "energy" ? "Sorted by smallest relative improvement. Energy uses a harmonic mean, so lifting your weakest subcategories is the fastest way up." : "Sorted by smallest relative improvement; for each group the easiest scenario to rank up is picked."
    }
}
