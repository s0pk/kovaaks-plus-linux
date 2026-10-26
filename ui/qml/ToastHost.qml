import QtQuick
import Kplus

// Short messages at the bottom right. Errors stay longer.
Column {
    id: root
    spacing: 8
    anchors.right: parent.right; anchors.bottom: parent.bottom
    anchors.margins: 18

    Connections {
        target: Store
        function onToastRequested(text, kind) { model.append({ msg: text, kind: kind }) }
    }
    ListModel { id: model }

    Repeater {
        model: model
        delegate: Rectangle {
            id: toast
            required property string msg
            required property string kind
            required property int index
            width: Math.min(380, Math.max(200, label.implicitWidth + 36))
            height: label.implicitHeight + 22
            radius: Theme.radiusSm
            color: Theme.surface2
            border.width: 1; border.color: Theme.border2
            opacity: 0
            Rectangle {
                width: 3; height: parent.height; radius: 1
                color: kind === "error" ? Theme.bad : kind === "ok" ? Theme.good : Theme.accent
            }
            Txt { id: label; x: 16; y: 11; width: parent.width - 28; text: toast.msg; wrapMode: Text.WordWrap }
            NumberAnimation on opacity { from: 0; to: 1; duration: Theme.animMs; running: true }
            Timer { interval: toast.kind === "error" ? 6000 : 3200; running: true; onTriggered: fade.start() }
            NumberAnimation { id: fade; target: toast; property: "opacity"; to: 0; duration: 300; onFinished: if (toast.index >= 0) model.remove(toast.index) }
        }
    }
}
