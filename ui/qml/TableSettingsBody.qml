import QtQuick
import QtQuick.Layouts
import Kplus
import "js/BenchTable.js" as BT

// "Table settings" for the benchmark table (a side panel, so the table stays visible and updates live).
Item {
    id: root
    property var dialog
    implicitHeight: col.implicitHeight
    readonly property var ts: BT.settings((Store.config.ui || {}).benchTable)
    function set(key, value) {
        var n = {}
        for (var k in ts) n[k] = ts[k]
        n[key] = value
        n.v = BT.TABLE_VERSION
        Store.setUi("benchTable", n)
    }
    function reset() { var n = {}; for (var k in BT.DEFAULTS) n[k] = BT.DEFAULTS[k]; Store.setUi("benchTable", n); return false }

    component Group: Txt { property string label; text: label; w: 700; font.pixelSize: 12; color: Theme.muted; Layout.topMargin: 12; Layout.bottomMargin: 2 }
    component SegRow: RowLayout {
        property string label; property string key; property var opts: []
        Layout.fillWidth: true; spacing: 10
        Txt { text: parent.label; Layout.fillWidth: true }
        Seg { options: parent.opts.map(function (o) { return { value: o[0], label: o[1] } }); value: root.ts[parent.key]; onPicked: function (v) { root.set(parent.key, v) } }
    }
    component SliderRow: RowLayout {
        property string label; property string key; property real lo: 0; property real hi: 100; property real stp: 1; property string unit: ""
        Layout.fillWidth: true; spacing: 10
        Txt { text: parent.label; Layout.fillWidth: true }
        Sld { implicitWidth: 120; from: parent.lo; to: parent.hi; step: parent.stp; value: root.ts[parent.key]; onMoved: function (v) { root.set(parent.key, v) } }
        Txt { text: root.ts[parent.key] + parent.unit; font.pixelSize: 12; color: Theme.muted; Layout.preferredWidth: 44; horizontalAlignment: Text.AlignRight }
    }
    component ToggleRow: RowLayout {
        property string label; property string key; property string hint: ""
        Layout.fillWidth: true; spacing: 10
        ColumnLayout { Layout.fillWidth: true; spacing: 0
            Txt { text: parent.parent.label }
            Txt { visible: parent.parent.hint !== ""; text: parent.parent.hint; font.pixelSize: 11; color: Theme.muted; wrapMode: Text.WordWrap; Layout.fillWidth: true } }
        Toggle { checked: !!root.ts[parent.key]; onToggled: function (v) { root.set(parent.key, v) } }
    }

    ColumnLayout {
        id: col; width: parent.width; spacing: 8
        Group { label: "Layout" }
        SegRow { label: "Density"; key: "density"; opts: [["ultra", "Ultra"], ["compact", "Compact"], ["normal", "Normal"], ["wide", "Wide"]] }
        SegRow { label: "Progress bar"; key: "progress"; opts: [["normal", "Normal"], ["simple", "Simple"]] }
        SliderRow { label: "Skew"; key: "skew"; lo: 0; hi: 45; unit: "°" }
        SliderRow { label: "Outer radius"; key: "outerRadius"; lo: 0; hi: 16; unit: "px" }
        SliderRow { label: "Inner radius"; key: "innerRadius"; lo: 0; hi: 12; unit: "px" }
        ToggleRow { label: "Shade category cells"; key: "shadeCategory"; hint: "Tint category and subcategory labels with their own colour" }
        ToggleRow { label: "Shade rank cells"; key: "shadeRank"; hint: "Dark track behind each threshold" }
        ToggleRow { label: "Use rank column colors"; key: "rankColumnColors"; hint: "Fill each cell with its own rank colour instead of your current rank colour" }
        ToggleRow { label: "Subcategory gradient"; key: "subGradient"; hint: "Right-to-left glow from the energy back to the scores, coloured by each subcategory's rank" }
        SliderRow { visible: root.ts.subGradient; label: "Gradient strength"; key: "gradientStrength"; lo: 5; hi: 60; unit: "%" }
        Group { label: "Text & display" }
        SegRow { label: "Font"; key: "font"; opts: [["default", "Default"], ["condensed", "Condensed"], ["mono", "Mono"]] }
        SliderRow { label: "Text size"; key: "textSize"; lo: 80; hi: 130; stp: 5; unit: "%" }
        Txt { text: "Text contrast (how far text is pushed towards white)"; font.pixelSize: 12; color: Theme.muted; Layout.topMargin: 6 }
        SliderRow { label: "Rank names"; key: "rankTextContrast"; stp: 5; unit: "%" }
        SliderRow { label: "Rank thresholds"; key: "thresholdTextContrast"; stp: 5; unit: "%" }
        SliderRow { label: "Your scores"; key: "scoreTextContrast"; stp: 5; unit: "%" }
        SliderRow { label: "Energy"; key: "energyTextContrast"; stp: 5; unit: "%" }
        SliderRow { label: "Category labels"; key: "categoryTextContrast"; stp: 5; unit: "%" }
        ToggleRow { label: "Bold text"; key: "bold" }
        ToggleRow { label: "Text shadow"; key: "textShadow" }
        ToggleRow { label: "Show leaderboard position"; key: "showPosition"; hint: "Your global position on each scenario" }
        ToggleRow { label: "Show progress %"; key: "showProgress" }
        ToggleRow { label: "Uncapped progress %"; key: "uncappedProgress"; hint: "Show how far past the top rank you are" }
        ToggleRow { label: "Simplify scenario names"; key: "simplifyNames"; hint: "Hide the benchmark prefix and difficulty suffix" }
    }
}
