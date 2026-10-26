import QtQuick
import Kplus
import QtQuick.Layouts

// Small tinted label (a tag). `chipColor` tints it; `on` fills it; `removable` shows a close mark.
Item {
    id: root
    property string text: ""
    property color chipColor: Theme.accent
    property bool small: false
    property bool on: false
    property bool removable: false
    property bool clickable: false
    signal clicked()
    signal removed()
    implicitHeight: small ? 20 : 24
    implicitWidth: row.implicitWidth + (small ? 14 : 18)

    Rectangle {
        anchors.fill: parent
        radius: Theme.radiusSm
        color: Theme.alpha(root.chipColor, root.on ? 0.32 : (area.containsMouse && root.clickable ? 0.26 : 0.16))
        border.width: 1
        border.color: Theme.alpha(root.chipColor, root.on ? 0.7 : 0.32)
    }
    RowLayout {
        id: row
        anchors.centerIn: parent
        spacing: 6
        Txt { text: root.text; w: 600; font.pixelSize: root.small ? 11 : 12; color: root.on ? Theme.text : Theme.mix(root.chipColor, "white", 55) }
        Txt {
            visible: root.removable; text: "×"; font.pixelSize: 14; color: Theme.text2
            MouseArea { anchors.fill: parent; anchors.margins: -4; cursorShape: Qt.PointingHandCursor; onClicked: root.removed() }
        }
    }
    MouseArea { id: area; anchors.fill: parent; enabled: root.clickable; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onClicked: root.clicked(); z: -1 }
}
