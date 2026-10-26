import QtQuick

// Copies text to the clipboard (QML has no direct API: a hidden TextEdit does it).
Item {
    visible: false
    function copy(text) { helper.text = text; helper.selectAll(); helper.copy() }
    TextEdit { id: helper; visible: false }
}
