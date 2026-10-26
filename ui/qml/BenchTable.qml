import QtQuick
import QtQuick.Layouts
import QtQuick.Controls
import Kplus
import "js/BenchTable.js" as BT

// The evxl-style benchmark table: category / subcategory labels, scores with a progress %, a skewed bar per rank threshold,
// and the energy of each subcategory. Everything is drawn from the precomputed model (see BenchTable.js).
Flickable {
    id: root
    property var model: null
    signal editScore(string name, var value)      // value null = reset
    signal playRequested(string name)
    signal openRequested(string name)
    signal leaderboardRequested(string name, string display)
    signal menuRequested(string name, real x, real y)

    readonly property var ts: model ? model.ts : BT.settings({})
    readonly property real rowH: model ? model.rowH : 31
    readonly property int n: model ? model.nThresh : 0
    readonly property real fontPx: 14 * ts.textSize / 100
    readonly property string bodyFont: ts.font === "condensed" ? Theme.display(ts.bold ? 700 : 600) : ts.font === "mono" ? "monospace" : Theme.sans(ts.bold ? 700 : 500)

    // column widths
    readonly property real catW: 30
    readonly property real subW: 30
    readonly property real nameW: 300
    readonly property real posW: ts.showPosition ? 64 : 0
    readonly property real scoreW: 84
    readonly property real pctW: ts.showProgress ? 40 : 0
    readonly property real energyW: model && model.energyMode ? 64 : 0
    readonly property real fixedW: catW + subW + nameW + posW + scoreW + pctW + energyW
    readonly property real cellW: Math.max(76, n ? (width - fixedW - 16) / n : 0)
    readonly property real totalW: fixedW + n * cellW

    clip: true
    contentWidth: Math.max(width, totalW)
    contentHeight: tableCol.implicitHeight
    implicitHeight: tableCol.implicitHeight
    boundsBehavior: Flickable.StopAtBounds
    flickableDirection: Flickable.HorizontalFlick
    interactive: contentWidth > width
    ScrollBar.horizontal: ThinScroll {}

    function skewMatrix(h) {
        var k = Math.tan(ts.skew * Math.PI / 180)
        return Qt.matrix4x4(1, -k, 0, k * h / 2, 0, 1, 0, 0, 0, 0, 1, 0, 0, 0, 0, 1)
    }

    Column {
        id: tableCol
        width: root.contentWidth

        // ---- header ----
        Item {
            width: parent.width; height: 34
            Txt { x: root.catW + root.subW + 4; anchors.verticalCenter: parent.verticalCenter; text: "Scenario"; color: Theme.muted; font.pixelSize: 12; w: 600 }
            Txt { visible: root.ts.showPosition; x: root.catW + root.subW + root.nameW; width: root.posW - 8; anchors.verticalCenter: parent.verticalCenter; text: "Pos"; color: Theme.muted; font.pixelSize: 12; w: 600; horizontalAlignment: Text.AlignRight }
            Txt { x: root.catW + root.subW + root.nameW + root.posW; width: root.scoreW - 8; anchors.verticalCenter: parent.verticalCenter; text: "Score"; color: Theme.muted; font.pixelSize: 12; w: 600; horizontalAlignment: Text.AlignRight }
            Repeater {
                model: root.model ? root.model.heads : []
                delegate: Item {
                    required property var modelData
                    required property int index
                    x: root.catW + root.subW + root.nameW + root.posW + root.scoreW + root.pctW + index * root.cellW; width: root.cellW; height: 34
                    Row {
                        anchors.centerIn: parent; spacing: 6
                        Image { visible: status === Image.Ready; source: modelData.icon || ""; width: visible ? 20 : 0; height: 20; anchors.verticalCenter: parent.verticalCenter; fillMode: Image.PreserveAspectFit; asynchronous: true }
                        Txt { text: modelData.name; w: 700; font.pixelSize: 12; color: modelData.color; anchors.verticalCenter: parent.verticalCenter }
                    }
                }
            }
            Txt { visible: !!root.model && root.model.energyMode; x: root.totalW - root.energyW; width: root.energyW; anchors.verticalCenter: parent.verticalCenter; text: "Energy"; color: Theme.muted; font.pixelSize: 12; w: 600; horizontalAlignment: Text.AlignHCenter }
        }

        // ---- body ----
        Item {
            id: body
            width: parent.width
            height: root.model ? root.model.rows.length * root.rowH : 0

            // subcategory glows (optional)
            Repeater {
                model: root.model && root.ts.subGradient ? root.model.subs : []
                delegate: Rectangle {
                    required property var modelData
                    visible: !!modelData.groupColor
                    x: root.catW + root.subW + root.nameW + root.posW; y: modelData.start * root.rowH
                    width: root.totalW - x; height: modelData.count * root.rowH
                    gradient: Gradient {
                        orientation: Gradient.Horizontal
                        GradientStop { position: 0; color: "transparent" }
                        GradientStop { position: 0.55; color: modelData.groupColor ? Theme.alpha(Qt.color(modelData.groupColor), root.ts.gradientStrength * 0.0035) : "transparent" }
                        GradientStop { position: 1; color: modelData.groupColor ? Theme.alpha(Qt.color(modelData.groupColor), root.ts.gradientStrength / 100) : "transparent" }
                    }
                }
            }

            // rows
            Repeater {
                model: root.model ? root.model.rows : []
                delegate: Item {
                    id: row
                    required property var modelData
                    required property int index
                    y: index * root.rowH; width: body.width; height: root.rowH
                    readonly property var r: modelData
                    Rectangle { visible: row.r.lastSub && row.index < (root.model.rows.length - 1); x: root.catW + root.subW; y: parent.height - 1; width: parent.width - root.catW - root.subW; height: 1; color: Theme.border }
                    Rectangle { visible: nameArea.containsMouse; x: root.catW + root.subW; width: root.nameW + root.posW + root.scoreW; height: parent.height; color: Theme.alpha(Theme.text, 0.04) }

                    // name + actions
                    Item {
                        x: root.catW + root.subW; width: root.nameW; height: parent.height
                        Txt { id: nm; x: 4; anchors.verticalCenter: parent.verticalCenter; width: parent.width - 64
                              text: row.r.display; elide: Text.ElideRight; font.pixelSize: root.fontPx; color: row.r.unplayed ? Theme.muted : Theme.text2; font.family: root.bodyFont }
                        Row {
                            anchors.right: parent.right; anchors.verticalCenter: parent.verticalCenter; spacing: 2
                            Repeater { model: [{ i: "chart", tip: "Leaderboard" }, { i: "play", tip: "Play" }]
                                       delegate: Rectangle { required property var modelData; width: 24; height: 24; radius: 6; color: ib.containsMouse ? Theme.surface3 : "transparent"
                                           Icon { anchors.centerIn: parent; name: modelData.i; size: 13; color: ib.containsMouse ? Theme.text : Theme.muted }
                                           MouseArea { id: ib; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor
                                                       onClicked: modelData.i === "play" ? root.playRequested(row.r.name) : root.leaderboardRequested(row.r.name, row.r.display) } } }
                        }
                        HoverPreview { name: row.r.name }
                        MouseArea {
                            id: nameArea; anchors.fill: parent; anchors.rightMargin: 60; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; acceptedButtons: Qt.LeftButton | Qt.RightButton
                            onClicked: function (m) { if (m.button === Qt.RightButton) { var p = mapToItem(Modals.menuHost, m.x, m.y); root.menuRequested(row.r.name, p.x, p.y) } else root.openRequested(row.r.name) }
                        }
                    }
                    Txt { visible: root.ts.showPosition; x: root.catW + root.subW + root.nameW; width: root.posW - 8; anchors.verticalCenter: parent.verticalCenter; text: row.r.pos; horizontalAlignment: Text.AlignRight; font.pixelSize: root.fontPx * 0.9; color: Theme.muted }

                    // score (click to try a what-if value)
                    Item {
                        id: scoreCell
                        x: root.catW + root.subW + root.nameW + root.posW; width: root.scoreW; height: parent.height
                        property bool editing: false
                        Row {
                            visible: !scoreCell.editing
                            anchors.right: parent.right; anchors.rightMargin: 8; anchors.verticalCenter: parent.verticalCenter; spacing: 6
                            Txt { visible: row.r.custom; text: "custom"; font.pixelSize: 9; w: 700; color: Theme.accent2; anchors.verticalCenter: parent.verticalCenter }
                            Txt { text: row.r.scoreText; font.pixelSize: root.fontPx * 0.92; font.family: root.bodyFont; color: row.r.scoreColor ? row.r.scoreColor : Theme.muted; font.italic: row.r.custom; anchors.verticalCenter: parent.verticalCenter }
                            Rectangle { visible: row.r.custom; width: 16; height: 16; radius: 4; color: Theme.surface3; anchors.verticalCenter: parent.verticalCenter
                                        Txt { anchors.centerIn: parent; text: "×"; font.pixelSize: 12; color: Theme.text2 }
                                        MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor; onClicked: root.editScore(row.r.name, null) } }
                        }
                        MouseArea { anchors.fill: parent; visible: !scoreCell.editing; cursorShape: Qt.IBeamCursor; onClicked: { scoreCell.editing = true; si.text = row.r.score ? String(row.r.score) : ""; si.forceActiveFocus(); si.selectAll() } }
                        Rectangle {
                            visible: scoreCell.editing; anchors.fill: parent; anchors.margins: 3; radius: 5; color: Theme.bg2; border.width: 1; border.color: Theme.accent
                            TextInput {
                                id: si; anchors.fill: parent; anchors.leftMargin: 6; anchors.rightMargin: 6; verticalAlignment: TextInput.AlignVCenter; horizontalAlignment: TextInput.AlignRight
                                color: Theme.text; font.family: Theme.sans(600); font.pixelSize: 13; selectByMouse: true; inputMethodHints: Qt.ImhFormattedNumbersOnly
                                function commit(save) {
                                    if (!scoreCell.editing) return
                                    scoreCell.editing = false
                                    if (!save) return
                                    var t = text.trim()
                                    root.editScore(row.r.name, t === "" ? null : parseFloat(t))
                                }
                                onAccepted: commit(true)
                                Keys.onEscapePressed: commit(false)
                                onActiveFocusChanged: if (!activeFocus) commit(true)
                            }
                        }
                    }
                    Txt { visible: root.ts.showProgress; x: root.catW + root.subW + root.nameW + root.posW + root.scoreW; width: root.pctW; anchors.verticalCenter: parent.verticalCenter; text: row.r.pct; font.pixelSize: root.fontPx * 0.85; color: Theme.muted; horizontalAlignment: Text.AlignHCenter }

                    // thresholds
                    Repeater {
                        model: row.r.thr
                        delegate: Item {
                            id: cell
                            required property var modelData
                            required property int index
                            x: root.catW + root.subW + root.nameW + root.posW + root.scoreW + root.pctW + index * root.cellW
                            width: root.cellW; height: root.rowH
                            readonly property bool first: index === 0
                            readonly property bool last: index === root.n - 1
                            readonly property real barL: first ? 12 : 2
                            readonly property real barW: root.cellW - barL - (last ? 12 : 2)
                            Item {
                                visible: !!cell.modelData
                                x: cell.barL; y: root.n > 0 ? (root.ts.density === "ultra" ? 3 : 5) : 5
                                width: cell.barW; height: root.rowH - 2 * y
                                transform: Matrix4x4 { matrix: root.skewMatrix(parent.height) }
                                Rectangle {
                                    anchors.fill: parent
                                    color: root.ts.shadeRank ? Qt.rgba(0, 0, 0, 0.2) : "transparent"
                                    topLeftRadius: cell.first ? root.ts.outerRadius : root.ts.innerRadius; bottomLeftRadius: cell.first ? root.ts.outerRadius : root.ts.innerRadius
                                    topRightRadius: cell.last ? root.ts.outerRadius : root.ts.innerRadius; bottomRightRadius: cell.last ? root.ts.outerRadius : root.ts.innerRadius
                                }
                                Rectangle {
                                    visible: !!cell.modelData && cell.modelData.f > 0
                                    height: parent.height; width: cell.modelData ? parent.width * cell.modelData.f : 0
                                    color: cell.modelData ? cell.modelData.fill : "transparent"
                                    topLeftRadius: cell.first ? root.ts.outerRadius : root.ts.innerRadius; bottomLeftRadius: cell.first ? root.ts.outerRadius : root.ts.innerRadius
                                    topRightRadius: root.ts.innerRadius; bottomRightRadius: root.ts.innerRadius
                                }
                            }
                            Txt {
                                visible: !!cell.modelData; anchors.centerIn: parent
                                text: cell.modelData ? cell.modelData.text : ""; font.pixelSize: root.fontPx * 0.88; font.family: root.bodyFont
                                color: cell.modelData ? cell.modelData.color : Theme.text
                                style: root.ts.textShadow ? Text.Outline : Text.Normal; styleColor: "#99000000"
                            }
                        }
                    }
                }
            }

            // category and subcategory labels (vertical)
            Repeater {
                model: root.model ? root.model.cats : []
                delegate: Rectangle {
                    required property var modelData
                    x: 0; y: modelData.start * root.rowH; width: root.catW; height: modelData.count * root.rowH
                    color: root.ts.shadeCategory ? Theme.mix(Theme.surface, Qt.color(modelData.color), 84) : "transparent"
                    border.width: 0
                    Rectangle { anchors.right: parent.right; width: 1; height: parent.height; color: Theme.border }
                    Rectangle { anchors.top: parent.top; width: parent.width; height: 1; color: Theme.border }
                    Item { anchors.fill: parent; clip: true
                        Txt { anchors.centerIn: parent; rotation: -90; width: parent.height - 8; horizontalAlignment: Text.AlignHCenter; text: modelData.label; elide: Text.ElideRight; color: modelData.color; font.pixelSize: root.fontPx * 0.72; w: 700 } }
                }
            }
            Repeater {
                model: root.model ? root.model.subs : []
                delegate: Rectangle {
                    required property var modelData
                    x: root.catW; y: modelData.start * root.rowH; width: root.subW; height: modelData.count * root.rowH
                    color: root.ts.shadeCategory ? Theme.mix(Theme.surface, Qt.color(modelData.color), 84) : "transparent"
                    Rectangle { anchors.right: parent.right; width: 1; height: parent.height; color: Theme.border }
                    Rectangle { anchors.top: parent.top; width: parent.width; height: 1; color: Theme.border }
                    Item { anchors.fill: parent; clip: true
                        Txt { anchors.centerIn: parent; rotation: -90; width: parent.height - 8; horizontalAlignment: Text.AlignHCenter; text: modelData.label; elide: Text.ElideRight; color: modelData.color; font.pixelSize: root.fontPx * 0.72; w: 700 } }
                }
            }
            // energy per subcategory
            Repeater {
                model: root.model && root.model.energyMode ? root.model.subs : []
                delegate: Item {
                    required property var modelData
                    x: root.totalW - root.energyW; y: modelData.start * root.rowH; width: root.energyW; height: modelData.count * root.rowH
                    Txt { anchors.centerIn: parent; text: modelData.energy ? modelData.energy.text : ""; display: true; w: 700; font.pixelSize: root.fontPx * 1.0; color: modelData.energy && modelData.energy.color ? modelData.energy.color : Theme.muted }
                }
            }
        }
    }
}
