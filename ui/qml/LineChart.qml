import QtQuick
import Kplus
import "js/ChartMath.js" as CM

// Line / area chart with hover tooltip, rank bands and reference lines (the web UI's lineChart).
//   series: [{points: [{x, y, tip, pb, onClick}], color, width, dashed, area, dots, opacity}]
//   hLines: [{y, label, color, align: "start"|"end", solid}]   bands: [{from, to, color, opacity}]
Item {
    id: root
    property var series: []
    property var hLines: []
    property var bands: []
    property real chartHeight: 220
    property var yTick: null           // function(value) -> string
    property var xLabels: null         // function(value) -> string
    property var yFormat: null
    property real yMin: NaN
    property string emptyText: "No data yet"
    signal pointClicked(var point)

    implicitHeight: chartHeight
    height: chartHeight

    property var _lay: null
    readonly property var pad: ({ l: 46, r: 14, t: 12, b: xLabels ? 24 : 10 })

    function computeLayout() {
        var w = Math.max(200, width), h = height
        var all = []
        series.forEach(function (sr) { sr.points.forEach(function (p) { all.push(p) }) })
        if (!all.length) return null
        var ys = all.map(function (p) { return p.y })
        hLines.forEach(function (l) { ys.push(l.y) })
        var ymin = Math.min.apply(null, ys), ymax = Math.max.apply(null, ys)
        if (!isNaN(yMin)) ymin = Math.min(ymin, yMin)
        var nt = CM.niceTicks(ymin, ymax, 4)
        var xs = all.map(function (p) { return p.x })
        var xmin = Math.min.apply(null, xs), xmax = Math.max.apply(null, xs)
        var pd = pad
        return {
            w: w, h: h, lo: nt.lo, hi: nt.hi, ticks: nt.ticks, xmin: xmin, xmax: xmax,
            X: function (x) { return pd.l + (xmax === xmin ? (w - pd.l - pd.r) / 2 : (x - xmin) / (xmax - xmin) * (w - pd.l - pd.r)) },
            Y: function (y) { return pd.t + (1 - (y - nt.lo) / ((nt.hi - nt.lo) || 1)) * (h - pd.t - pd.b) }
        }
    }

    Canvas {
        id: cv
        anchors.fill: parent
        antialiasing: true
        renderTarget: Canvas.FramebufferObject
        onPaint: {
            var ctx = getContext("2d")
            ctx.reset()
            var L = root._lay = root.computeLayout()
            if (!L) return
            var pd = root.pad
            var muted = Theme.muted.toString(), grid = Theme.border.toString()
            ctx.font = "11px " + Theme.sans(400)
            // grid + y labels
            ctx.lineWidth = 1
            L.ticks.forEach(function (t) {
                ctx.strokeStyle = grid; ctx.setLineDash([2, 4])
                ctx.beginPath(); ctx.moveTo(pd.l, L.Y(t)); ctx.lineTo(L.w - pd.r, L.Y(t)); ctx.stroke()
                ctx.setLineDash([])
                ctx.fillStyle = muted; ctx.textAlign = "right"; ctx.textBaseline = "middle"
                ctx.fillText((root.yTick || CM.shortNum)(t), pd.l - 8, L.Y(t))
            })
            if (root.xLabels) {
                var n = Math.min(6, Math.floor((L.w - pd.l) / 90))
                for (var i = 0; i <= n; i++) {
                    var xv = L.xmin + (L.xmax - L.xmin) * (i / (n || 1))
                    ctx.fillStyle = muted; ctx.textAlign = i === 0 ? "left" : i === n ? "right" : "center"; ctx.textBaseline = "alphabetic"
                    ctx.fillText(root.xLabels(xv), L.X(xv), L.h - 6)
                }
            }
            // bands
            root.bands.forEach(function (bd) {
                var y1 = L.Y(Math.min(L.hi, bd.to === null || bd.to === undefined ? L.hi : bd.to)), y2 = L.Y(Math.max(L.lo, bd.from === null || bd.from === undefined ? L.lo : bd.from))
                if (y2 - y1 <= 0) return
                var c = Qt.color(bd.color)
                ctx.fillStyle = Qt.rgba(c.r, c.g, c.b, bd.opacity || 0.07).toString()
                ctx.fillRect(pd.l, y1, L.w - pd.l - pd.r, y2 - y1)
            })
            // series
            root.series.forEach(function (sr) {
                if (!sr.points.length) return
                var col = Qt.color(sr.color)
                var pts = sr.points.map(function (p) { return [L.X(p.x), L.Y(p.y)] })
                if (sr.area) {
                    var g = ctx.createLinearGradient(0, pd.t, 0, L.h - pd.b)
                    g.addColorStop(0, Qt.rgba(col.r, col.g, col.b, 0.32).toString()); g.addColorStop(1, Qt.rgba(col.r, col.g, col.b, 0).toString())
                    ctx.fillStyle = g
                    ctx.beginPath(); ctx.moveTo(pts[0][0], L.Y(L.lo))
                    pts.forEach(function (p) { ctx.lineTo(p[0], p[1]) })
                    ctx.lineTo(pts[pts.length - 1][0], L.Y(L.lo)); ctx.closePath(); ctx.fill()
                }
                ctx.strokeStyle = Qt.rgba(col.r, col.g, col.b, sr.opacity || 1).toString()
                ctx.lineWidth = sr.width || 2; ctx.lineJoin = "round"; ctx.lineCap = "round"
                ctx.setLineDash(sr.dashed ? [5, 5] : [])
                ctx.beginPath()
                pts.forEach(function (p, i) { if (i) ctx.lineTo(p[0], p[1]); else ctx.moveTo(p[0], p[1]) })
                ctx.stroke(); ctx.setLineDash([])
                if (sr.dots !== false && sr.points.length <= 120) {
                    sr.points.forEach(function (p, i) {
                        if (p.pb) { ctx.fillStyle = Theme.gold.toString(); ctx.strokeStyle = Theme.bg.toString(); ctx.lineWidth = 1.5; ctx.beginPath(); ctx.arc(pts[i][0], pts[i][1], 4, 0, Math.PI * 2); ctx.fill(); ctx.stroke() }
                        else if (sr.dots) { ctx.fillStyle = col.toString(); ctx.beginPath(); ctx.arc(pts[i][0], pts[i][1], 2.5, 0, Math.PI * 2); ctx.fill() }
                    })
                }
            })
            // reference lines
            root.hLines.forEach(function (l) {
                var c = Qt.color(l.color || Theme.gold.toString())
                ctx.strokeStyle = Qt.rgba(c.r, c.g, c.b, l.solid ? 0.55 : 0.8).toString()
                ctx.lineWidth = l.solid ? 1 : 1.2; ctx.setLineDash(l.solid ? [] : [6, 5])
                ctx.beginPath(); ctx.moveTo(pd.l, L.Y(l.y)); ctx.lineTo(L.w - pd.r, L.Y(l.y)); ctx.stroke(); ctx.setLineDash([])
                if (l.label) {
                    var start = l.align === "start"
                    ctx.font = "bold 11px " + Theme.sans(700)
                    ctx.textAlign = start ? "left" : "right"; ctx.textBaseline = "alphabetic"
                    var x = start ? pd.l + 6 : L.w - pd.r - 4
                    ctx.lineWidth = 3; ctx.strokeStyle = "rgba(0,0,0,0.55)"; ctx.strokeText(l.label, x, L.Y(l.y) - 6)
                    ctx.fillStyle = c.toString(); ctx.fillText(l.label, x, L.Y(l.y) - 6)
                }
            })
        }
    }

    Txt { visible: !root.series.length || !root.series.some(function (s) { return s.points.length }); anchors.centerIn: parent; text: root.emptyText; color: Theme.muted }

    // hover cursor + tooltip
    property var hoverPoint: null
    Rectangle { id: cursorLine; visible: root.hoverPoint !== null; width: 1; color: Theme.alpha(Theme.text, 0.18); y: root.pad.t; height: root.height - root.pad.t - root.pad.b; x: 0 }
    Rectangle { id: cursorDot; visible: root.hoverPoint !== null; width: 9; height: 9; radius: 5; color: Theme.text; border.width: 2; border.color: Theme.bg }
    Rectangle {
        id: tip
        visible: root.hoverPoint !== null && tipText.text !== ""
        color: Theme.surface3; border.width: 1; border.color: Theme.border2; radius: Theme.radiusSm
        width: tipText.implicitWidth + 18; height: tipText.implicitHeight + 12
        z: 5
        Txt { id: tipText; x: 9; y: 6; font.pixelSize: 12; textFormat: Text.StyledText }
    }
    MouseArea {
        anchors.fill: parent
        hoverEnabled: true
        cursorShape: root.hoverPoint && root.hoverPoint.onClick ? Qt.PointingHandCursor : Qt.ArrowCursor
        onPositionChanged: function (m) {
            var L = root._lay
            if (!L || !root.series.length) return
            var main = root.series[0], best = null, bd = 1e12
            main.points.forEach(function (p) { var dx = Math.abs(L.X(p.x) - m.x); if (dx < bd) { bd = dx; best = p } })
            if (!best) return
            root.hoverPoint = best
            var px = L.X(best.x), py = L.Y(best.y)
            cursorLine.x = px; cursorDot.x = px - 4.5; cursorDot.y = py - 4.5
            tipText.text = best.tip || ("<b>" + (root.yFormat || CM.shortNum)(best.y) + "</b>")
            tip.x = Math.max(0, Math.min(root.width - tip.width, px - tip.width / 2)); tip.y = Math.max(0, py - tip.height - 12)
        }
        onExited: root.hoverPoint = null
        onClicked: if (root.hoverPoint && root.hoverPoint.onClick) root.hoverPoint.onClick()
    }

    onWidthChanged: cv.requestPaint()
    onHeightChanged: cv.requestPaint()
    onSeriesChanged: cv.requestPaint()
    onHLinesChanged: cv.requestPaint()
    onBandsChanged: cv.requestPaint()
    Connections { target: Theme; function onAccentChanged() { cv.requestPaint() } function onBgChanged() { cv.requestPaint() } }
}
