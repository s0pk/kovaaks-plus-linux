import QtQuick
import Kplus
import QtQuick.Layouts
import "js/Fmt.js" as Fmt

// One run in a recent-runs list. PBs carry a gold marker, earlier days recede.
ColumnLayout {
    id: root
    property var run: ({})
    property bool showHeader: false
    spacing: 0
    readonly property bool today: Fmt.isToday(run.date)

    Txt { visible: root.showHeader; text: root.today ? "Today" : "Earlier"; w: 600; font.pixelSize: 13; color: Theme.muted; Layout.topMargin: 6; Layout.bottomMargin: 4; Layout.leftMargin: 10 }
    Rectangle {
        Layout.fillWidth: true; Layout.preferredHeight: 36
        color: area.containsMouse ? Theme.surface2 : "transparent"
        opacity: !root.today && Theme.dimOld && !area.containsMouse ? 0.45 : 1
        Rectangle { visible: root.run.pb || root.today; width: 3; height: parent.height; color: root.run.pb ? Theme.gold : Theme.accent }
        Rectangle { visible: !!root.run.pb && Theme.pbGradient; width: parent.width * 0.5; height: parent.height
            gradient: Gradient { orientation: Gradient.Horizontal; GradientStop { position: 0; color: Theme.alpha(Theme.gold, 0.15) } GradientStop { position: 1; color: "transparent" } } }
        RowLayout {
            anchors.fill: parent; anchors.leftMargin: 10; anchors.rightMargin: 10; spacing: 10
            Txt { Layout.fillWidth: true; Layout.preferredWidth: 1; text: Store.displayName(Store.scenario(root.run.scenario)) || root.run.scenario; elide: Text.ElideRight }
            Txt { text: Fmt.fmtScore(root.run.score); w: 700; color: root.run.pb ? Theme.mix(Theme.gold, Theme.text, 30) : Theme.text }
            Rectangle { visible: !!root.run.pb; width: 26; height: 18; radius: 3; color: Theme.alpha(Theme.gold, 0.18); Txt { anchors.centerIn: parent; text: "PB"; font.pixelSize: 11; w: 700; color: Theme.gold } }
            Txt { text: Fmt.fmtPct(root.run.accuracy); color: Theme.muted; Layout.preferredWidth: 52; horizontalAlignment: Text.AlignRight; font.pixelSize: 13 }
            Txt { text: Fmt.timeAgo(root.run.date); color: Theme.muted; Layout.preferredWidth: 64; horizontalAlignment: Text.AlignRight; font.pixelSize: 13 }
        }
        HoverPreview { name: root.run.scenario || "" }
        MouseArea {
            id: area; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; acceptedButtons: Qt.LeftButton | Qt.RightButton
            onClicked: function (m) { if (m.button === Qt.RightButton) { var p = mapToItem(Modals.menuHost, m.x, m.y); Store.scenarioMenu(root.run.scenario, p.x, p.y) } else Store.openScenario(root.run.scenario) }
        }
    }
}
