import QtQuick

// Country flag (from flagcdn); blank when unknown.
Item {
    property string cc: ""
    implicitWidth: 18; implicitHeight: 13
    Image { anchors.fill: parent; visible: cc.length === 2; source: cc.length === 2 ? "https://flagcdn.com/w20/" + cc.toLowerCase() + ".png" : ""; asynchronous: true; fillMode: Image.PreserveAspectFit }
}
