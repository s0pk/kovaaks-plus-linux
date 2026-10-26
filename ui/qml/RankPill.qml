import QtQuick
import QtQuick.Layouts

// A rank name on a tinted chip. `iconSource` is the evxl rank artwork (hidden if it fails to load).
Rectangle {
    id: root
    property string text: ""
    property color rc: Theme.muted
    property url iconSource: ""
    property bool compact: false
    implicitHeight: compact ? 22 : 26
    implicitWidth: row.implicitWidth + (compact ? 16 : 14)
    radius: Theme.radiusSm
    color: Theme.alpha(rc, 0.18)
    border.width: 1; border.color: Theme.alpha(rc, 0.4)
    Row {
        id: row; anchors.centerIn: parent; spacing: 6
        Image { id: img; visible: status === Image.Ready; source: root.iconSource; width: visible ? (root.compact ? 16 : 20) : 0; height: width; anchors.verticalCenter: parent.verticalCenter; asynchronous: true; fillMode: Image.PreserveAspectFit }
        Txt { text: root.text; w: 700; font.pixelSize: root.compact ? 11 : 12; color: Theme.mix(root.rc, "white", 55); anchors.verticalCenter: parent.verticalCenter }
    }
}
