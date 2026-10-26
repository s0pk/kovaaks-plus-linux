import QtQuick
import Kplus

// Text with the app's fonts. `w` picks the weight (the faces are static instances), `display` switches to the condensed face.
Text {
    property int w: 400
    property bool display: false
    color: Theme.text
    font.family: display ? Theme.display(w) : Theme.sans(w)
    font.pixelSize: 14
    textFormat: Text.PlainText
    renderType: Text.NativeRendering
}
