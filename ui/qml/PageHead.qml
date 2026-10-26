import QtQuick
import Kplus
import QtQuick.Layouts

// Page heading: big condensed title, optional subtitle, optional controls on the right.
RowLayout {
    id: root
    property string title: ""
    property string subtitle: ""
    default property alias actions: right.data
    width: parent ? parent.width : implicitWidth
    spacing: 16

    ColumnLayout {
        Layout.fillWidth: true
        spacing: 10
        Txt { text: root.title; display: true; w: 700; font.pixelSize: Math.max(36, Math.min(50, root.width * 0.034)); lineHeight: 0.92; Layout.fillWidth: true; elide: Text.ElideRight }
        Txt { visible: root.subtitle !== ""; text: root.subtitle; color: Theme.muted; wrapMode: Text.WordWrap; Layout.fillWidth: true; Layout.maximumWidth: 620 }
    }
    RowLayout { id: right; spacing: 8; Layout.alignment: Qt.AlignBottom }
}
