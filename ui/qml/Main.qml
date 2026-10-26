import QtQuick
import Kplus
import QtQuick.Controls
import QtQuick.Layouts
import QtQuick.Window

ApplicationWindow {
    id: win
    visible: true
    width: 1440
    height: 900
    minimumWidth: 1100
    minimumHeight: 700
    title: "Kovaak's Plus"
    color: Theme.bg

    // remember the window size between launches
    Connections {
        target: Store
        function onBootedChanged() {
            var w = (Store.config.ui || {}).window
            if (!w) return
            if (w.max) win.visibility = Window.Maximized
            else { win.width = Math.max(win.minimumWidth, w.w); win.height = Math.max(win.minimumHeight, w.h) }
            windowSave.armed = true
        }
    }
    Timer {
        id: windowSave
        property bool armed: false
        interval: 700
        onTriggered: Store.setUi("window", { w: Math.round(win.width), h: Math.round(win.height), max: win.visibility === Window.Maximized })
    }
    onWidthChanged: if (windowSave.armed || Store.booted) windowSave.restart()
    onHeightChanged: if (windowSave.armed || Store.booted) windowSave.restart()

    // dev only: frames presented per second, logged once a second
    property int frames: 0
    onFrameSwapped: frames++
    Timer { running: Launch.dev; interval: 1000; repeat: true; onTriggered: { if (win.frames > 0) console.info("fps=" + win.frames); win.frames = 0 } }

    // The whole interface lives in a scaled root so the "interface scale" setting works like the web UI's zoom.
    Item {
        id: root
        width: win.width / Theme.uiScale
        height: win.height / Theme.uiScale
        scale: Theme.uiScale
        transformOrigin: Item.TopLeft
        focus: true
        DropArea {
            anchors.fill: parent; z: -1
            onDropped: function (e) {
                var u = e.urls.length ? String(e.urls[0]) : ""
                if (!/\.(kpack|zip)$/i.test(u)) { Store.toast("Drop a .kpack file to import it"); return }
                Backend.call("packs.pickImport", { path: decodeURIComponent(u.replace(/^file:\/\//, "")) }, function (pv) { if (pv) Modals.importPack(pv) }, function (e2) { Store.toast(e2, "error") })
            }
        }
        Keys.onSpacePressed: function (e) { if (Store.paused && !Store.results && !modals.visible && !drawer.opened) { Store.resumeGame(); e.accepted = true } }

        RowLayout {
            anchors.fill: parent
            spacing: 0
            Sidebar { Layout.fillHeight: true; Layout.preferredWidth: 236 }
            ColumnLayout {
                Layout.fillWidth: true; Layout.fillHeight: true
                spacing: 0
                PauseBanner { Layout.fillWidth: true }
                Loader {
                    id: pages
                    Layout.fillWidth: true; Layout.fillHeight: true
                    sourceComponent: {
                        if (!Backend.connected) return connecting
                        if (!Store.booted) return connecting
                        switch (Store.route) {
                        case "home": return homePage
                        case "library": return libraryPage
                        case "benchmarks": return benchmarksPage
                        case "stats": return statsPage
                        case "presets": return presetsPage
                        case "packs": return packsPage
                        case "settings": return settingsPage
                        }
                        return homePage
                    }
                }
            }
        }

        Drawer { id: drawer }
        ModalHost { id: modals }
        HoverPop {}
        MenuHost { id: menus }
        Loader {
            id: resultsLoader
            property var snap: null       // the payload the open results screen shows (kept while it closes)
            anchors.fill: parent
            active: Store.results !== null && snap !== null
            sourceComponent: Component { Results { d: resultsLoader.snap } }
            Connections { target: Store; function onResultsChanged() { if (Store.results) resultsLoader.snap = Store.results } }
        }
        Loader { anchors.fill: parent; active: Store.booted && (Store.firstRun || !Store.valid); sourceComponent: Setup {} }
        ToastHost {}
        NativeDialogs { id: dialogs }
    }

    Connections {
        target: Store
        function onDevScroll() {
            function find(it) {
                if (it.contentY !== undefined && it.contentHeight > it.height + 50) return it
                for (var i = 0; i < it.children.length; i++) { var r = find(it.children[i]); if (r) return r }
                return null
            }
            probe.target = pages.item ? find(pages.item) : null
            if (probe.target) probe.restart()
        }
    }
    SequentialAnimation {
        id: probe
        property var target: null
        loops: 3
        NumberAnimation { target: probe.target; property: "contentY"; from: 0; to: probe.target ? Math.min(2400, probe.target.contentHeight - probe.target.height) : 0; duration: 1800; easing.type: Easing.InOutQuad }
        NumberAnimation { target: probe.target; property: "contentY"; to: 0; duration: 1800; easing.type: Easing.InOutQuad }
    }
    Connections {
        target: Store
        function onPausedChanged() { if (Store.paused) root.forceActiveFocus() }   // so Space resumes instead of typing into a search box
    }
    Connections {
        target: Backend
        function onEventReceived(name, d) { if (name === "dialog") dialogs.show(d) }
        function onClosedChanged() { if (Backend.closed) Qt.quit() }
    }
    Component.onCompleted: { Modals.host = modals; Modals.menuHost = menus; console.info("launch ws=" + Launch.ws + " http=" + Launch.http + " dev=" + Launch.dev) }

    Component { id: connecting; Item { Txt { anchors.centerIn: parent; text: Store.bootError !== "" ? "Could not start: " + Store.bootError : (Launch.ws === "" ? "Start this program from Kovaak's Plus (kovaaks-plus)." : "Connecting…"); color: Theme.muted } } }
    Component { id: homePage; Home {} }
    Component { id: libraryPage; Library {} }
    Component { id: benchmarksPage; Benchmarks {} }
    Component { id: statsPage; Stats {} }
    Component { id: presetsPage; Presets {} }
    Component { id: packsPage; Packs {} }
    Component { id: settingsPage; AppSettings {} }
}
