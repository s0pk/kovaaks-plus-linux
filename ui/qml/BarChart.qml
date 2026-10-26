import QtQuick
import Kplus
import "js/ChartMath.js" as CM

// Vertical bars with a y axis and a hover tooltip. bars: [{label, value, tip, color}]
Item {
    id: root
    property var bars: []
    property real chartHeight: 160
    property bool labels: false
    property color barColor: Theme.accent
    implicitHeight: chartHeight
    height: chartHeight

    readonly property real maxV: Math.max.apply(null, [1].concat(bars.map(function (b) { return b.value })))
    readonly property var nt: CM.niceTicks(0, maxV, 3)
    readonly property real padL: 36
    readonly property real padB: labels ? 22 : 6
    readonly property real padT: 8
    readonly property real plotH: height - padT - padB
    function yOf(v) { return padT + (1 - v / nt.hi) * plotH }
    readonly property real bw: bars.length ? (width - padL - 6) / bars.length : 0
    property int hover: -1

    Canvas {
        id: grid
        anchors.fill: parent
        onPaint: {
            var ctx = getContext("2d"); ctx.reset()
            ctx.font = "11px " + Theme.sans(400); ctx.textAlign = "right"; ctx.textBaseline = "middle"
            root.nt.ticks.forEach(function (t) {
                ctx.strokeStyle = Theme.border.toString(); ctx.lineWidth = 1; ctx.setLineDash([2, 4])
                ctx.beginPath(); ctx.moveTo(root.padL, root.yOf(t)); ctx.lineTo(width - 6, root.yOf(t)); ctx.stroke(); ctx.setLineDash([])
                ctx.fillStyle = Theme.muted.toString(); ctx.fillText(CM.shortNum(t), root.padL - 6, root.yOf(t))
            })
        }
        Connections { target: root; function onNtChanged() { grid.requestPaint() } function onWidthChanged() { grid.requestPaint() } function onHeightChanged() { grid.requestPaint() } }
        Connections { target: Theme; function onBorderChanged() { grid.requestPaint() } }
    }
    Repeater {
        model: root.bars
        delegate: Item {
            required property var modelData
            required property int index
            x: root.padL + index * root.bw; width: root.bw; height: root.height
            Rectangle {
                x: Math.max(1, root.bw * 0.18); width: Math.max(2, root.bw * 0.64)
                y: root.yOf(modelData.value); height: Math.max(0, root.yOf(0) - root.yOf(modelData.value))
                radius: Math.min(4, width / 2)
                color: modelData.color ? modelData.color : root.barColor
                opacity: modelData.value ? 0.9 : 0.25
            }
            Txt {
                visible: root.labels && (root.bars.length <= 14 || index % Math.ceil(root.bars.length / 10) === 0)
                x: 0; width: root.bw + 10; y: root.height - 18; horizontalAlignment: Text.AlignHCenter; text: modelData.label; font.pixelSize: 10; color: Theme.muted
            }
            MouseArea { anchors.fill: parent; hoverEnabled: true; onEntered: root.hover = index; onExited: if (root.hover === index) root.hover = -1 }
        }
    }
    Rectangle {
        visible: root.hover >= 0 && root.hover < root.bars.length
        z: 5; color: Theme.surface3; border.width: 1; border.color: Theme.border2; radius: Theme.radiusSm
        width: tt.implicitWidth + 18; height: tt.implicitHeight + 12
        x: Math.max(0, Math.min(root.width - width, root.padL + (root.hover + 0.5) * root.bw - width / 2))
        y: root.hover >= 0 && root.hover < root.bars.length ? Math.max(0, root.yOf(root.bars[root.hover].value) - height - 8) : 0
        Txt { id: tt; x: 9; y: 6; font.pixelSize: 12; textFormat: Text.StyledText
              text: root.hover >= 0 && root.hover < root.bars.length ? (root.bars[root.hover].tip || (root.bars[root.hover].label + ": <b>" + root.bars[root.hover].value + "</b>")) : "" }
    }
}
