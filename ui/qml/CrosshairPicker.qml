import QtQuick
import QtQuick.Layouts
import Kplus

// A crosshair image setting: preview, name and a Choose button that opens a grid of the game's crosshairs.
RowLayout {
    id: root
    property var files: []
    property string value: ""
    signal picked(string file)
    spacing: 10
    Rectangle {
        implicitWidth: 38; implicitHeight: 38; radius: Theme.radiusSm; color: Theme.bg2; border.width: 1; border.color: Theme.border
        Image { anchors.centerIn: parent; width: 30; height: 30; fillMode: Image.PreserveAspectFit; source: root.value ? Launch.http + "/crosshair/" + encodeURIComponent(root.value) : "" }
    }
    Txt { text: root.value || "None"; font.pixelSize: 13; elide: Text.ElideRight; Layout.maximumWidth: 140 }
    Btn {
        small: true; text: "Choose"
        onClicked: Modals.open(grid, { title: "Choose a crosshair", wide: true, props: { files: root.files, value: root.value, onChosen: function (f) { root.value = f; root.picked(f) } }, actions: [{ label: "Close", kind: "ghost" }] })
    }
    Component {
        id: grid
        Item {
            id: g
            property var dialog
            property var files: []
            property string value: ""
            property var onChosen
            implicitHeight: Math.min(420, flow.implicitHeight)
            Flickable {
                anchors.fill: parent; contentHeight: flow.implicitHeight; clip: true; boundsBehavior: Flickable.StopAtBounds
                Flow {
                    id: flow; width: parent.width; spacing: 8
                    Repeater {
                        model: g.files
                        delegate: Rectangle {
                            required property string modelData
                            width: 92; height: 98; radius: Theme.radiusSm; color: ca.containsMouse ? Theme.surface2 : "transparent"
                            border.width: 1; border.color: modelData === g.value ? Theme.accent : "transparent"
                            Rectangle { x: 14; y: 8; width: 64; height: 64; radius: Theme.radiusSm; color: Theme.bg2
                                        Image { anchors.fill: parent; anchors.margins: 4; fillMode: Image.PreserveAspectFit; asynchronous: true; source: Launch.http + "/crosshair/" + encodeURIComponent(modelData) } }
                            Txt { x: 4; y: 76; width: 84; text: modelData.replace(/\.png$/i, ""); font.pixelSize: 11; color: Theme.muted; elide: Text.ElideRight; horizontalAlignment: Text.AlignHCenter }
                            MouseArea { id: ca; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onClicked: { g.onChosen(modelData); g.dialog.close(null) } }
                        }
                    }
                }
            }
        }
    }
}
