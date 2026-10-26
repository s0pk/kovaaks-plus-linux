import QtQuick
import Kplus
import QtQuick.Layouts

// Left rail: brand, navigation, and the game status card.
Rectangle {
    id: root
    color: Theme.sidebar
    implicitWidth: 236

    Rectangle { anchors.right: parent.right; width: 1; height: parent.height; color: Theme.border }

    readonly property var routes: [
        { id: "home", label: "Home", icon: "home" },
        { id: "library", label: "Scenarios", icon: "library" },
        { id: "benchmarks", label: "Benchmarks", icon: "trophy" },
        { id: "stats", label: "Statistics", icon: "chart" },
        { sep: true },
        { id: "presets", label: "Settings & Presets", icon: "sliders" },
        { id: "packs", label: "Import / Export", icon: "box" },
        { id: "settings", label: "App Settings", icon: "settings" }
    ]

    ColumnLayout {
        anchors.fill: parent
        anchors.margins: 14
        anchors.topMargin: 22
        spacing: 0

        RowLayout {
            Layout.leftMargin: 8; Layout.bottomMargin: 26
            spacing: 11
            Image { source: Theme.assets + "logo.png"; sourceSize.width: 72; sourceSize.height: 72; Layout.preferredWidth: 36; Layout.preferredHeight: 36; smooth: true }
            Column {
                Txt { text: "Kovaak's"; display: true; w: 700; font.pixelSize: 26; lineHeight: 0.88; lineHeightMode: Text.ProportionalHeight }
                Txt { text: "Plus"; display: true; w: 700; font.pixelSize: 26; lineHeight: 0.88; lineHeightMode: Text.ProportionalHeight; color: Theme.muted }
            }
        }

        Repeater {
            model: root.routes
            delegate: Item {
                required property var modelData
                Layout.fillWidth: true
                Layout.preferredHeight: modelData.sep ? 25 : 38
                Rectangle { visible: !!modelData.sep; anchors.centerIn: parent; width: parent.width - 20; height: 1; color: Theme.border }
                Rectangle {
                    visible: !modelData.sep
                    anchors.fill: parent; radius: Theme.radiusSm
                    color: (Store.route === modelData.id) ? Theme.surface : (area.containsMouse ? Theme.surface : "transparent")
                }
                Brackets { visible: !modelData.sep; opacity: Store.route === modelData.id ? 1 : 0; len: 7; thick: 1.5 }
                Row {
                    visible: !modelData.sep
                    x: 12; anchors.verticalCenter: parent.verticalCenter; spacing: 11
                    Icon { name: modelData.icon || "dot"; size: 17; anchors.verticalCenter: parent.verticalCenter; color: Store.route === modelData.id ? Theme.text : Theme.text2; opacity: Store.route === modelData.id ? 1 : 0.7 }
                    Txt { text: modelData.label || ""; anchors.verticalCenter: parent.verticalCenter; w: Store.route === modelData.id ? 700 : 500; font.pixelSize: 15; color: Store.route === modelData.id || area.containsMouse ? Theme.text : Theme.text2 }
                }
                MouseArea { id: area; enabled: !modelData.sep; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onClicked: Store.go(modelData.id) }
            }
        }

        Item { Layout.fillHeight: true }

        // game status
        Rectangle { Layout.fillWidth: true; Layout.preferredHeight: 1; color: Theme.border }
        ColumnLayout {
            Layout.fillWidth: true; Layout.topMargin: 14; Layout.leftMargin: 8; Layout.rightMargin: 8
            spacing: 6
            RowLayout {
                spacing: 8
                Rectangle {
                    width: 8; height: 8; radius: 4
                    color: Store.game.running ? Theme.good : Theme.muted; opacity: Store.game.running ? 1 : 0.6
                }
                Txt { text: Store.game.running ? (Store.paused ? "KovaaK's · paused" : "KovaaK's running") : "KovaaK's not running"; color: Theme.muted; font.pixelSize: 13 }
            }
            Txt {
                Layout.fillWidth: true
                text: Store.game.currentScenario ? (Store.displayName(Store.scenario(Store.game.currentScenario)) || Store.game.currentScenario)
                      : (Store.game.running ? "In menus" : "Ready when you are")
                display: true; w: 600; font.pixelSize: 19; lineHeight: 1.05
                wrapMode: Text.WordWrap; maximumLineCount: 2; elide: Text.ElideRight
            }
            Btn {
                Layout.fillWidth: true; Layout.topMargin: 6
                kind: Store.game.running ? "primary" : ""
                icon: Store.game.running ? "target" : "play"
                text: Store.game.running ? "Back to game" : "Launch KovaaK's"
                onClicked: Store.game.running ? Store.resumeGame() : Store.launchGame()
            }
        }
    }
}
