import QtQuick
import Kplus
import QtQuick.Shapes
import "js/Icons.js" as Icons

// 24px stroke icon from the shared set, drawn as vector paths (no image files, always crisp).
Item {
    id: root
    property string name: "target"
    property real size: 16
    property color color: Theme.text
    property real strokeWidth: 2
    property bool flipX: false
    property bool flipY: false
    implicitWidth: size
    implicitHeight: size

    Shape {
        width: 24; height: 24
        transform: [
            Scale { xScale: (root.flipX ? -1 : 1) * root.size / 24; yScale: (root.flipY ? -1 : 1) * root.size / 24; origin.x: root.flipX ? 12 : 0; origin.y: root.flipY ? 12 : 0 }
        ]
        preferredRendererType: Shape.CurveRenderer
        ShapePath {
            strokeColor: root.color
            strokeWidth: root.strokeWidth
            capStyle: ShapePath.RoundCap
            joinStyle: ShapePath.RoundJoin
            fillColor: Icons.filled(root.name) ? root.color : "transparent"
            PathSvg { path: Icons.path(root.name) }
        }
    }
}
