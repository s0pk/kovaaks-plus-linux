import QtQuick
import Kplus
import QtQuick.Controls

// Single-line text input.
Rectangle {
    id: root
    property alias text: input.text
    property alias placeholder: hint.text
    property alias echoMode: input.echoMode
    property alias readOnly: input.readOnly
    property alias inputMethodHints: input.inputMethodHints
    property alias validator: input.validator
    property string icon: ""
    signal accepted()
    signal edited(string text)
    implicitHeight: 34
    implicitWidth: 220
    radius: Theme.radiusSm
    color: Theme.bg2
    border.width: 1
    border.color: input.activeFocus ? Theme.accent : Theme.border2
    Rectangle { visible: input.activeFocus; anchors.fill: parent; anchors.margins: -3; radius: Theme.radiusSm + 2; color: "transparent"; border.width: 3; border.color: Theme.accentSoft }

    Icon { visible: root.icon !== ""; name: root.icon; size: 16; color: Theme.muted; x: 11; anchors.verticalCenter: parent.verticalCenter }
    TextInput {
        id: input
        anchors.fill: parent
        anchors.leftMargin: root.icon !== "" ? 34 : 12
        anchors.rightMargin: 12
        verticalAlignment: TextInput.AlignVCenter
        color: Theme.text
        selectionColor: Theme.accentLine
        selectedTextColor: Theme.text
        font.family: Theme.sans(400)
        font.pixelSize: 14
        clip: true
        onAccepted: root.accepted()
        onTextEdited: root.edited(text)
    }
    Txt { id: hint; anchors.fill: input; verticalAlignment: Text.AlignVCenter; visible: input.text === ""; color: Theme.muted; elide: Text.ElideRight }
    function focusInput() { input.forceActiveFocus() }
}
