import QtQuick
import Kplus
import QtQuick.Layouts

// Context menus. Open with Modals.menu(items, x, y); items: {label, icon, onClick, danger, disabled, hint} | {sep:true} | {header:"…"}.
Item {
    id: root
    anchors.fill: parent
    visible: open
    z: 1000
    property bool open: false
    property var items: []

    function show(list, x, y) {
        items = list.filter(function (i) { return i })
        open = true
        panel.x = Math.max(8, Math.min(x, root.width - 240 - 8))
        panel.y = Math.max(8, Math.min(y, root.height - col.implicitHeight - 18))
        panel.forceActiveFocus()
    }
    function close() { open = false }

    MouseArea { anchors.fill: parent; acceptedButtons: Qt.AllButtons; onPressed: root.close() }

    Rectangle {
        id: panel
        width: 240
        height: col.implicitHeight + 10
        radius: Theme.radius
        color: Theme.surface2
        border.width: 1; border.color: Theme.border2
        focus: true
        Keys.onEscapePressed: root.close()
        // soft shadow
        Rectangle { z: -1; anchors.fill: parent; anchors.margins: -1; anchors.topMargin: 4; radius: Theme.radius + 1; color: "#80000000" }

        Column {
            id: col
            x: 5; y: 5; width: parent.width - 10
            Repeater {
                model: root.items
                delegate: Item {
                    id: item
                    required property var modelData
                    width: col.width
                    height: modelData.sep ? 9 : modelData.header ? 26 : 32
                    Rectangle { visible: !!modelData.sep; anchors.centerIn: parent; width: parent.width - 12; height: 1; color: Theme.border2 }
                    Txt { visible: !!modelData.header; x: 10; y: 5; width: parent.width - 20; text: modelData.header || ""; font.pixelSize: 12; color: Theme.muted; w: 600; elide: Text.ElideRight }
                    Rectangle {
                        visible: !modelData.sep && !modelData.header
                        anchors.fill: parent; radius: Theme.radiusSm
                        color: hover.containsMouse && !modelData.disabled ? Theme.surface3 : "transparent"
                        RowLayout {
                            anchors.fill: parent; anchors.leftMargin: 10; anchors.rightMargin: 10; spacing: 10
                            opacity: modelData.disabled ? 0.45 : 1
                            Icon { name: modelData.icon || "dot"; size: 16; color: modelData.danger ? Theme.bad : Theme.muted; opacity: modelData.icon ? 1 : 0 }
                            Txt { text: modelData.label || ""; color: modelData.danger ? Theme.bad : Theme.text; Layout.fillWidth: true; elide: Text.ElideRight }
                            Txt { visible: !!modelData.hint; text: modelData.hint || ""; font.pixelSize: 11; color: Theme.muted }
                        }
                        MouseArea {
                            id: hover; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor
                            onClicked: { if (modelData.disabled) return; root.close(); if (modelData.onClick) modelData.onClick() }
                        }
                    }
                }
            }
        }
    }
}
