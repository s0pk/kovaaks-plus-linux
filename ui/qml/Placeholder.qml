import QtQuick
import Kplus
import QtQuick.Layouts

// Pages not yet ported to the native UI.
Item {
    property string title: ""
    ColumnLayout {
        anchors.centerIn: parent; spacing: 10; width: Math.min(460, parent.width - 60)
        Icon { name: "settings"; size: 40; color: Theme.muted; Layout.alignment: Qt.AlignHCenter; opacity: 0.6 }
        Txt { text: title; display: true; w: 700; font.pixelSize: 30; Layout.alignment: Qt.AlignHCenter }
        Txt { text: "This page hasn't been ported to the native interface yet. Launch with KPLUS_HOST=chromium to use it in the browser window meanwhile."; color: Theme.muted; wrapMode: Text.WordWrap; horizontalAlignment: Text.AlignHCenter; Layout.fillWidth: true }
    }
}
