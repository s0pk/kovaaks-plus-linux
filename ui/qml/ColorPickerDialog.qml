import QtQuick
import QtQuick.Dialogs

// The system colour dialog as a tiny reusable object.
ColorDialog {
    id: dlg
    signal picked(color c)
    onAccepted: picked(selectedColor)
}
