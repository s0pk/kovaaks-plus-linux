import QtQuick
import Kplus
import QtQuick.Layouts

// Shown while KovaaK's is paused: pick another scenario, tweak settings, or jump back in.
Rectangle {
    id: root
    visible: Store.paused
    height: visible ? 52 : 0
    color: Theme.surface2
    Rectangle { anchors.bottom: parent.bottom; width: parent.width; height: 1; color: Theme.text }

    RowLayout {
        anchors.fill: parent; anchors.leftMargin: 22; anchors.rightMargin: 18; spacing: 14
        Rectangle { width: 10; height: 10; radius: 5; color: Theme.gold }
        RowLayout {
            Layout.fillWidth: true; spacing: 8
            Txt { text: "KovaaK's is paused"; w: 700 }
            Txt {
                visible: !!Store.game.currentScenario
                text: "· " + (Store.displayName(Store.scenario(Store.game.currentScenario)) || Store.game.currentScenario)
                color: Theme.muted; Layout.fillWidth: true; elide: Text.ElideRight
            }
            Txt { text: "Pick another scenario, tweak settings, or jump back in."; font.pixelSize: 12; color: Theme.muted; Layout.leftMargin: 10; visible: root.width > 900 }
        }
        Btn {
            kind: "primary"
            icon: Store.config.pauseResume === "continue" ? "play" : "refresh"
            text: Store.config.pauseResume === "continue" ? "Resume" : "Restart run"
            onClicked: Store.resumeGame()
            Kbd { text: "Space"; anchors.left: parent.right; anchors.leftMargin: 8; anchors.verticalCenter: parent.verticalCenter }
        }
        Item { width: 52 }
        Btn { kind: "ghost"; icon: "x"; tip: "Dismiss"; onClicked: Store.paused = false }
    }
}
