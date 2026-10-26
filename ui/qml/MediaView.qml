import QtQuick
import QtMultimedia
import Kplus
import "js/Fmt.js" as Fmt

// A user's image, GIF or short video clip (from the media folder), cropped to fill. Clips play muted and loop.
// `playing: false` keeps a clip on its first frame (used for thumbnails).
Item {
    id: root
    property string file: ""
    property bool playing: true
    readonly property bool isVideo: /\.(mp4|webm)$/i.test(file)
    readonly property url src: file !== "" ? Launch.http + Fmt.mediaPath(file) : ""
    clip: true

    AnimatedImage {
        anchors.fill: parent
        visible: !root.isVideo
        source: root.isVideo ? "" : root.src
        fillMode: Image.PreserveAspectCrop
        playing: root.playing
        asynchronous: true
        cache: true
    }
    Loader {
        anchors.fill: parent
        active: root.isVideo
        sourceComponent: Item {
            MediaPlayer {
                id: mp
                source: root.src
                videoOutput: vo
                loops: MediaPlayer.Infinite
                Component.onCompleted: play()
                onMediaStatusChanged: if (mediaStatus === MediaPlayer.BufferedMedia && !root.playing) pause()
            }
            VideoOutput { id: vo; anchors.fill: parent; fillMode: VideoOutput.PreserveAspectCrop }
        }
    }
}
