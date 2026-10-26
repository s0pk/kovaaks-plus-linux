import QtQuick
import Kplus
import QtQuick.Layouts
import "js/Fmt.js" as Fmt

// A scenario of the pinned benchmark with a progress bar toward its next rank.
Rectangle {
    id: root
    property var row: ({})
    property var bench: ({})
    implicitHeight: 32
    radius: Theme.radiusSm
    color: area.containsMouse ? Theme.surface3 : "transparent"
    readonly property var rank: (bench.ranks && (bench.ranks[row.r] || bench.ranks[0])) || ({})
    readonly property color rc: Fmt.rankColor(rank, row.r)
    readonly property var maxes: row.s.rankMaxes || []
    readonly property real nextT: maxes[row.r] || 0
    readonly property real lowerT: row.r > 0 ? maxes[row.r - 1] : 0
    readonly property real prog: nextT ? Math.max(0, Math.min(1, (row.best - lowerT) / (nextT - lowerT))) : 1
    RowLayout {
        anchors.fill: parent; anchors.leftMargin: 6; anchors.rightMargin: 6; spacing: 10
        Txt { Layout.fillWidth: true; text: row.s.customName || row.s.name; elide: Text.ElideRight }
        Progress { Layout.preferredWidth: 90; value: root.prog; fill: root.rc }
        Rectangle {
            Layout.preferredWidth: 104; Layout.preferredHeight: 24; radius: Theme.radiusSm
            color: Theme.alpha(root.rc, 0.18); border.width: 1; border.color: Theme.alpha(root.rc, 0.4)
            Txt { anchors.centerIn: parent; text: root.rank.name || "—"; w: 700; font.pixelSize: 12; color: Theme.mix(root.rc, "white", 55) }
        }
    }
    MouseArea { id: area; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onClicked: Store.play(row.s.name) }
}
