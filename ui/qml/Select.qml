import QtQuick
import Kplus

// A dropdown that opens the app's own menu. options: [{value, label}]
Rectangle {
    id: root
    property var options: []
    property var value
    property int menuWidth: 0
    signal picked(var value)
    implicitHeight: 34
    implicitWidth: 180
    radius: Theme.radiusSm
    color: Theme.bg2
    border.width: 1
    border.color: area.containsMouse ? Theme.mix(Theme.border2, Theme.text, 30) : Theme.border2

    readonly property string label: {
        for (var i = 0; i < options.length; i++) if (options[i].value === value) return options[i].label
        return ""
    }
    Txt { x: 12; anchors.verticalCenter: parent.verticalCenter; text: root.label; width: parent.width - 40; elide: Text.ElideRight }
    Icon { name: "chevron"; size: 14; color: Theme.muted; anchors.right: parent.right; anchors.rightMargin: 10; anchors.verticalCenter: parent.verticalCenter }
    MouseArea {
        id: area; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor
        onClicked: {
            var p = root.mapToItem(Modals.menuHost, 0, root.height + 4)
            Modals.menu(root.options.map(function (o) {
                return { label: o.label, icon: o.value === root.value ? "check" : "", onClick: function () { root.value = o.value; root.picked(o.value) } }
            }), p.x, p.y)
        }
    }
}
