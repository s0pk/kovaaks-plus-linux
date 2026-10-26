import QtQuick
import Kplus
import QtQuick.Shapes
import "js/Art.js" as Art
import "js/Fmt.js" as Fmt

// A scenario's picture: the user's own image if set, else generated art that says what kind of scenario it is.
// Size it by width; it keeps 16:9 unless `fill` is set.
Item {
    id: root
    property string name: ""
    property string media: ""          // path relative to the media folder
    property string tagColor: ""
    property string info: ""
    property bool label: true
    property bool fill: false
    property var tagMedia: []          // tag default thumbnails (sliced diagonally when several)
    property string labelText: ""
    implicitHeight: fill ? 100 : width * 9 / 16
    clip: true

    readonly property bool isVideo: /\.(mp4|webm)$/i.test(media)
    readonly property var art: Art.makeArt(name, info, tagColor !== "" ? tagColor : null)
    readonly property real k: Math.max(width / 160, height / 90)

    // generated tile
    Rectangle {
        anchors.fill: parent
        visible: media === "" && tagMedia.length === 0
        gradient: Gradient {
            GradientStop { position: 0; color: Theme.mix("#131412", root.art.accent, 22) }
            GradientStop { position: 1; color: Theme.mix("#131412", root.art.accent, 8) }
        }
    }
    Shape {
        visible: media === "" && tagMedia.length === 0
        x: (root.width - 160 * root.k) / 2
        y: (root.height - 90 * root.k) / 2
        width: 160; height: 90
        transform: Scale { xScale: root.k; yScale: root.k }
        preferredRendererType: Shape.CurveRenderer
        ShapePath {   // faint solid
            strokeColor: Theme.alpha(Qt.color(root.art.accent), 0.38); strokeWidth: 1.7 / root.k; fillColor: "transparent"
            capStyle: ShapePath.RoundCap; joinStyle: ShapePath.RoundJoin
            PathSvg { path: root.art.paths.b }
        }
        ShapePath {   // faint dashed
            strokeColor: Theme.alpha(Qt.color(root.art.accent), 0.38); strokeWidth: 1.7 / root.k; fillColor: "transparent"
            strokeStyle: ShapePath.DashLine; dashPattern: [1.8, 2.4]; capStyle: ShapePath.RoundCap
            PathSvg { path: root.art.paths.bdash }
        }
        ShapePath {   // solid
            strokeColor: root.art.accent; strokeWidth: 1.7 / root.k; fillColor: "transparent"
            capStyle: ShapePath.RoundCap; joinStyle: ShapePath.RoundJoin
            PathSvg { path: root.art.paths.a }
        }
        ShapePath {   // dotted trail
            strokeColor: root.art.accent; strokeWidth: 1.7 / root.k; fillColor: "transparent"
            strokeStyle: ShapePath.DashLine; dashPattern: [0.06, 2.9]; capStyle: ShapePath.RoundCap
            PathSvg { path: root.art.paths.adot }
        }
        ShapePath {   // filled centres
            strokeColor: "transparent"; fillColor: root.art.accent
            PathSvg { path: root.art.paths.af }
        }
    }
    Txt {
        visible: root.label && media === "" && tagMedia.length === 0
        text: root.labelText !== "" ? root.labelText : Fmt.keyWord(root.name)
        display: true; w: 700
        x: 12; y: parent.height - height - 9
        width: parent.width - 20
        elide: Text.ElideRight
        font.pixelSize: Math.max(14, Math.min(parent.width * 0.17 * (text.length <= 4 ? 1 : text.length <= 6 ? 0.85 : text.length <= 8 ? 0.72 : 0.6), 44))
    }

    // the user's own image
    Image {
        anchors.fill: parent
        visible: media !== "" && !isVideo
        source: media !== "" && !isVideo ? Launch.http + Fmt.mediaPath(media) : ""
        fillMode: Image.PreserveAspectCrop
        asynchronous: true
        cache: true
        sourceSize.width: Math.max(64, Math.ceil(width * 2))
    }
    // a clip as thumbnail: first frame only
    MediaView { anchors.fill: parent; visible: media !== "" && isVideo; file: isVideo ? media : ""; playing: false }
    // tag thumbnails: one fills the tile, several are cut into diagonal slices
    Repeater {
        model: media === "" ? tagMedia.slice(0, 4) : []
        delegate: Image {
            required property int index
            required property string modelData
            readonly property int n: Math.min(4, root.tagMedia.length)
            x: index * root.width / n - (index > 0 ? root.width * 0.04 : 0)
            width: root.width / n + (index > 0 ? root.width * 0.04 : 0) + (index < n - 1 ? root.width * 0.04 : 0)
            height: root.height
            source: Launch.http + Fmt.mediaPath(modelData)
            fillMode: Image.PreserveAspectCrop
            asynchronous: true
        }
    }
}
