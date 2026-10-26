import QtQuick
import QtQuick.Controls
import Kplus

// GitHub-style training calendar. daily: [{day: "yyyy-mm-dd", runs, seconds, pbs}]
Flickable {
    id: root
    property var daily: []
    property int weeks: 53
    implicitHeight: 7 * 15 + 12
    height: implicitHeight
    contentWidth: grid.width; contentHeight: grid.height
    clip: true; boundsBehavior: Flickable.StopAtBounds
    flickableDirection: Flickable.HorizontalFlick
    ScrollBar.horizontal: ThinScroll {}
    Component.onCompleted: contentX = Math.max(0, contentWidth - width)
    onContentWidthChanged: contentX = Math.max(0, contentWidth - width)

    function key(d) { var p = function (n) { return n < 10 ? "0" + n : "" + n }; return d.getFullYear() + "-" + p(d.getMonth() + 1) + "-" + p(d.getDate()) }
    readonly property var cells: {
        var byDay = {}
        daily.forEach(function (d) { byDay[d.day] = d })
        var max = 1
        daily.forEach(function (d) { max = Math.max(max, d.runs) })
        var today = new Date(); today.setHours(0, 0, 0, 0)
        var start = new Date(today); start.setDate(start.getDate() - (weeks * 7 - 1) - start.getDay())
        var out = []
        for (var d = new Date(start); d <= today; d.setDate(d.getDate() + 1)) {
            var k = key(d), v = byDay[k], runs = v ? v.runs : 0
            out.push({ runs: runs, level: runs ? 0.25 + 0.75 * Math.sqrt(runs / max) : 0, pbs: v ? v.pbs : 0,
                       label: ["Sun", "Mon", "Tue", "Wed", "Thu", "Fri", "Sat"][d.getDay()] + " " + d.getDate() + " " + ["Jan", "Feb", "Mar", "Apr", "May", "Jun", "Jul", "Aug", "Sep", "Oct", "Nov", "Dec"][d.getMonth()] + " " + d.getFullYear() })
        }
        return out
    }
    property int hover: -1

    Grid {
        id: grid
        rows: 7; flow: Grid.TopToBottom; rowSpacing: 3; columnSpacing: 3
        Repeater {
            model: root.cells
            delegate: Rectangle {
                required property var modelData
                required property int index
                width: 12; height: 12; radius: 2
                color: modelData.runs ? Theme.mix(Theme.surface2, Theme.accent, Math.round(modelData.level * 100)) : Theme.surface2
                MouseArea { anchors.fill: parent; hoverEnabled: true; onEntered: { root.hover = index; tip.x = parent.x + 14; tip.y = parent.y - 6 } onExited: if (root.hover === index) root.hover = -1 }
            }
        }
    }
    Rectangle {
        id: tip
        parent: grid
        visible: root.hover >= 0; z: 5; color: Theme.surface3; border.width: 1; border.color: Theme.border2; radius: Theme.radiusSm
        width: tt.implicitWidth + 18; height: tt.implicitHeight + 12
        Txt { id: tt; x: 9; y: 6; font.pixelSize: 12; textFormat: Text.StyledText
              text: root.hover >= 0 ? "<b>" + root.cells[root.hover].runs + " run" + (root.cells[root.hover].runs === 1 ? "" : "s") + "</b> · " + root.cells[root.hover].label + (root.cells[root.hover].pbs ? " · " + root.cells[root.hover].pbs + " PB" : "") : "" }
    }
}
