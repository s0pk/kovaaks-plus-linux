import QtQuick
import QtQuick.Layouts
import Kplus

// One labelled setting: label and hint on the left, the control on the right.
Item {
    id: root
    property string label: ""
    property string hint: ""
    default property alias control: ctl.data
    implicitHeight: Math.max(50, Math.max(lab.implicitHeight, ctl.implicitHeight) + 14)
    Layout.fillWidth: true
    Rectangle { anchors.bottom: parent.bottom; width: parent.width; height: 1; color: Theme.border; opacity: 0.7 }
    RowLayout {
        anchors.fill: parent; anchors.topMargin: 7; anchors.bottomMargin: 7; spacing: 18
        ColumnLayout {
            id: lab
            Layout.fillWidth: true; Layout.preferredWidth: 1; Layout.alignment: Qt.AlignVCenter; spacing: 1
            Txt { text: root.label; Layout.fillWidth: true; wrapMode: Text.WordWrap }
            Txt { visible: root.hint !== ""; text: root.hint; font.pixelSize: 11; color: Theme.muted; Layout.fillWidth: true; wrapMode: Text.WordWrap }
        }
        RowLayout { id: ctl; Layout.alignment: Qt.AlignVCenter | Qt.AlignRight; spacing: 8 }
    }
}
