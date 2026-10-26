import QtQuick
import Kplus

// On/off switch (squared, like the rest of the UI).
Item {
    id: root
    property bool checked: false
    signal toggled(bool value)
    implicitWidth: 40; implicitHeight: 22
    activeFocusOnTab: true
    Keys.onSpacePressed: { root.checked = !root.checked; root.toggled(root.checked) }
    Rectangle {
        anchors.fill: parent; radius: 3
        color: root.checked ? Theme.accent : Theme.surface3
        border.width: 1; border.color: root.checked ? Theme.accent : Theme.border2
        Behavior on color { ColorAnimation { duration: Theme.animMs } }
    }
    Rectangle {
        width: 14; height: 14; radius: 2; y: 4
        x: root.checked ? parent.width - width - 4 : 4
        color: root.checked ? Theme.onAccent : Theme.muted
        Behavior on x { NumberAnimation { duration: Theme.animMs; easing.type: Easing.OutCubic } }
    }
    MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor; onClicked: { root.checked = !root.checked; root.toggled(root.checked) } }
}
