import QtQuick
import Kplus
import QtQuick.Layouts

// Button. kind: "" (outlined), "primary", "ghost", "danger". Size flags: small, large. iconOnly makes it square.
Item {
    id: b
    property string text: ""
    property string icon: ""
    property string kind: ""
    property bool small: false
    property bool large: false
    property bool block: false
    property bool selected: false
    property bool iconFlip: false
    property bool iconFlipY: false
    property string tip: ""
    signal clicked(var mouse)

    readonly property bool hovered: area.containsMouse
    readonly property bool iconOnly: text === "" && icon !== ""
    implicitHeight: large ? 46 : small ? 30 : 34
    implicitWidth: iconOnly ? implicitHeight : row.implicitWidth + (small ? 20 : large ? 44 : 28)
    opacity: enabled ? 1 : 0.5
    activeFocusOnTab: true
    Keys.onReturnPressed: b.clicked(null)
    Keys.onSpacePressed: b.clicked(null)

    readonly property color fg: kind === "primary" ? Theme.onAccent : kind === "danger" ? Theme.bad : kind === "ghost" ? (hovered ? Theme.text : Theme.text2) : Theme.text

    Rectangle {
        anchors.fill: parent
        radius: Theme.radiusSm
        color: b.kind === "primary" ? (b.hovered ? Theme.mix(Theme.accent, "white", 14) : Theme.accent)
             : b.hovered || b.selected ? Theme.surface2 : "transparent"
        border.width: b.kind === "ghost" ? 0 : 1
        border.color: b.kind === "primary" ? Theme.accent
                    : b.kind === "danger" ? Theme.alpha(Theme.bad, 0.45)
                    : b.selected ? Theme.accent : (b.hovered ? Theme.mix(Theme.border2, Theme.text, 30) : Theme.border2)
        Behavior on color { ColorAnimation { duration: Theme.animMs } }
    }
    Rectangle {   // keyboard focus ring
        anchors.fill: parent; anchors.margins: -3
        radius: Theme.radiusSm + 2; color: "transparent"
        border.width: 2; border.color: Theme.accent
        visible: b.activeFocus && b.focusReason === Qt.TabFocusReason
    }

    RowLayout {
        id: row
        anchors.centerIn: parent
        spacing: 8
        Icon { visible: b.icon !== ""; name: b.icon; flipX: b.iconFlip; flipY: b.iconFlipY; size: b.small ? 14 : 16; color: b.fg; Layout.alignment: Qt.AlignVCenter }
        Txt { visible: b.text !== ""; text: b.text; w: 600; font.pixelSize: b.large ? 15 : b.small ? 12 : 13; color: b.fg; Layout.alignment: Qt.AlignVCenter }
    }
    MouseArea {
        id: area
        anchors.fill: parent
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor
        onClicked: function (m) { b.forceActiveFocus(Qt.MouseFocusReason); b.clicked(m) }
    }
    ToolTipArea { text: b.tip; target: area }
}
