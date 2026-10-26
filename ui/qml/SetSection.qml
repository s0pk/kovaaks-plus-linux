import QtQuick
import QtQuick.Layouts
import Kplus

// A titled card of settings rows.
Card {
    id: root
    property string title: ""
    default property alias rows: col.data
    Layout.fillWidth: true
    pad: 18
    implicitHeight: col.implicitHeight + 36
    ColumnLayout {
        id: col
        width: parent.width; spacing: 0
        Txt { visible: root.title !== ""; text: root.title; display: true; w: 600; font.pixelSize: 20; Layout.bottomMargin: 6 }
    }
}
