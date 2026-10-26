import QtQuick
import Kplus
import QtQuick.Controls

// The app's slim scrollbar.
ScrollBar {
    id: bar
    implicitWidth: 10
    padding: 2
    contentItem: Rectangle {
        implicitWidth: 6; implicitHeight: 40
        radius: 3
        color: bar.pressed ? Theme.mix(Theme.border2, Theme.text, 35) : bar.hovered ? Theme.mix(Theme.border2, Theme.text, 20) : Theme.border2
        opacity: bar.size < 1 ? 1 : 0
    }
    background: Item {}
}
