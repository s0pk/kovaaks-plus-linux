import QtQuick
import QtQuick.Layouts
import Kplus
import "js/Appearance.js" as AP

PageScroll {
    id: page
    readonly property var c: Store.config
    readonly property var a: AP.appearance(Store.config)
    readonly property var colors: AP.effectiveColors(a, Theme.themes)
    property string restartDetected: ""

    function set(patch, msg) { Store.saveConfig(patch, function () { if (msg) Store.toast(msg, "ok") }) }
    function saveA(patch, extra) {
        var ui = AP.copy(Store.config.ui || {})
        var na = AP.copy(AP.appearance(Store.config))
        for (var k in patch) na[k] = patch[k]
        ui.appearance = na
        var p = { ui: ui }
        for (var e in (extra || {})) p[e] = extra[e]
        Store.saveConfig(p)
    }
    function opts(pairs) { return pairs.map(function (p) { return { value: p[0], label: p[1] } }) }
    readonly property var pauseKeys: opts(["Escape", "Tab", "Oemtilde", "P", "F1", "F2", "F3", "F4", "F5", "F6", "F7", "F8", "F9", "F10", "F11", "F12"].map(function (k) { return [k, { Escape: "Esc", Oemtilde: "` (backtick)" }[k] || k] }))
    readonly property var restartKeys: opts([["auto", "Auto (from KovaaK's binds)"]].concat(["R", "T", "F", "E", "Q", "G", "X", "Z", "Space", "Return", "Back", "F1", "F2", "F3", "F4", "F5", "F6", "F7", "F8", "F9", "F10", "F11", "F12"].map(function (k) { return [k, { Return: "Enter", Back: "Backspace" }[k] || k] })))
    function refreshRestartKey() {
        Backend.call("game.restartKey", {}, function (r) { page.restartDetected = r.detected ? "KovaaK's bind: " + ({ Return: "Enter", Back: "Backspace" }[r.detected] || r.detected) : "No bind found" }, function () {})
    }
    Component.onCompleted: refreshRestartKey()

    function pickGameFolder() {
        Backend.call("app.pickFolder", { title: "Select the FPSAimTrainer folder" }, function (p) {
            if (!p) return
            Backend.call("app.validateGamePath", { path: p }, function (v) {
                if (!v.valid) { Store.toast("That doesn't look like a KovaaK's install (expected an FPSAimTrainer subfolder).", "error"); return }
                page.set({ gamePath: p }, "Folder updated. Reindexing…")
                Store.loadLibrary()
            }, function (e) { Store.toast(e, "error") })
        }, function (e) { Store.toast(e, "error") })
    }
    function detect(then) { Backend.call("app.detect", {}, then, function (e) { Store.toast(e, "error") }) }
    function scanCleanup() {
        Backend.call("media.scanUnused", {}, function (scan) {
            if (!scan.files.length && !scan.missing.length && !scan.emptyFolders) { Store.toast("Nothing to clean up: all " + scan.referenced + " media files are in use.", "ok"); return }
            Modals.open(cleanupC, { title: "Clean up unused files", wide: true, props: { scan: scan }, actions: [{ label: "Cancel", kind: "ghost" }, { label: "Clean up", kind: "danger", onClick: function (dlg) { return dlg.body.run() } }] })
        }, function (e) { Store.toast(e, "error") })
    }
    Component { id: cleanupC; CleanupBody {} }
    Component { id: themeEditorC; ThemeEditorBody {} }

    /** Create (id = null, from the current colours) or edit a user theme. */
    function editTheme(id) {
        var existing = null
        if (id) a.userThemes.forEach(function (t) { if (t.id === id) existing = t })
        var work = existing ? AP.copy(existing) : { id: AP.newThemeId(), name: "My theme", colors: AP.copy(colors), accent: c.accent || "#ece8de", accent2: a.accent2 }
        Modals.open(themeEditorC, { title: existing ? "Edit theme" : "Save as theme", wide: true, props: { work: work, existing: !!existing, onSave: function (w) {
            var list = existing ? a.userThemes.map(function (t) { return t.id === id ? w : t }) : a.userThemes.concat([w])
            saveA({ userThemes: list, theme: w.id, custom: {}, accent2: w.accent2 }, { accent: w.accent })
            Store.toast("Theme saved", "ok")
        } }, actions: [{ label: "Cancel", kind: "ghost" }, { label: existing ? "Save theme" : "Create theme", kind: "primary", onClick: function (dlg) { return dlg.body.save() } }] })
    }
    function deleteTheme(t) {
        Modals.confirm("Delete theme?", "\"" + t.name + "\" will be removed.", "Delete", "danger", function (yes) {
            if (yes) saveA({ userThemes: a.userThemes.filter(function (x) { return x.id !== t.id }), theme: a.theme === t.id ? "midnight" : a.theme })
        })
    }
    function resetAppearance() {
        var ui = AP.copy(Store.config.ui || {})
        var keep = (ui.appearance || {}).userThemes
        ui.appearance = keep ? { userThemes: keep } : undefined
        set({ ui: ui, accent: "#8b5cf6" }, "Appearance reset")
    }

    PageHead { title: "App Settings"; subtitle: "Kovaak's Plus v" + Store.version }

    RowLayout {
        width: parent.width; spacing: 18
        // ================= left column =================
        ColumnLayout {
            Layout.fillWidth: true; Layout.preferredWidth: 1; Layout.alignment: Qt.AlignTop; spacing: 16
            SetSection {
                title: "Game & account"
                SetRow { label: "KovaaK's folder"; hint: page.c.gamePath || "Not set"
                    Btn { small: true; icon: "folder"; text: "Change"; onClicked: page.pickGameFolder() }
                    Btn { small: true; kind: "ghost"; icon: "external"; tip: "Open in file manager"; onClicked: Backend.send("app.reveal", { what: "game" }) } }
                SetRow { label: "Workshop folders"; hint: ((page.c.workshopPaths || []).length) + " found"
                    Btn { small: true; icon: "refresh"; text: "Re-detect"; onClicked: page.detect(function (d) { page.set({ workshopPaths: d.workshopPaths, gamePath: page.c.gamePath || d.gamePath }, "Found " + d.workshopPaths.length + " workshop folder(s)") }) } }
                SetRow { label: "Steam ID"; hint: page.c.steamName ? "Signed in as " + page.c.steamName + ". Used for evxl.app ranks and leaderboard scores" : "Used for evxl.app ranks and leaderboard scores"
                    Field { id: steamIn; implicitWidth: 190; placeholder: "17-digit SteamID64"; text: page.c.steamId || ""; onAccepted: page.set({ steamId: text.trim() || null }, "Steam ID saved") }
                    Btn { small: true; kind: "ghost"; text: "Save"; onClicked: page.set({ steamId: steamIn.text.trim() || null }, "Steam ID saved") }
                    Btn { small: true; kind: "ghost"; text: "Detect"; tip: "Detect from Steam"
                          onClicked: page.detect(function (d) { steamIn.text = d.steamId || ""; page.set({ steamId: d.steamId, steamName: d.steamName }, d.steamId ? "Detected " + (d.steamName || d.steamId) : "No Steam login found") }) } }
            }
            SetSection {
                title: "Window switching"
                SetRow { label: "Pausing brings Kovaak's Plus forward"; hint: "When KovaaK's is focused and you press the pause key"
                    Select { implicitWidth: 150; options: page.pauseKeys; value: page.c.pauseKey; onPicked: function (v) { page.set({ pauseKey: v }, "Pause key updated") } }
                    Toggle { checked: !!page.c.pauseBringsApp; onToggled: function (v) { page.set({ pauseBringsApp: v }) } } }
                SetRow { label: "Show results when a run ends"; hint: "Brings this app forward with your stats and PB comparison"
                    Toggle { checked: !!page.c.runEndBringsApp; onToggled: function (v) { page.set({ runEndBringsApp: v }) } } }
                SetRow { label: "Focus KovaaK's when launching a scenario"; hint: "Switch straight to the game after picking a scenario"
                    Toggle { checked: !!page.c.focusGameOnPlay; onToggled: function (v) { page.set({ focusGameOnPlay: v }) } } }
                SetRow { label: "Default play mode"; hint: "Used by the Play buttons"
                    Select { implicitWidth: 160; options: page.opts([["challenge", "Challenge"], ["freeplay", "Freeplay"]]); value: page.c.defaultMode; onPicked: function (v) { page.set({ defaultMode: v }) } } }
                SetRow { label: "Default presets"; hint: "When a scenario (or its tag) has a preset that differs from your current settings"
                    Select { implicitWidth: 200; options: page.opts([["ask", "Ask each time"], ["auto", "Apply automatically"], ["off", "Never apply"]]); value: page.c.presetMode || "ask"; onPicked: function (v) { page.set({ presetMode: v }) } } }
            }
            SetSection {
                title: "Returning to KovaaK's"
                SetRow { label: "Resuming from the pause bar"; hint: "Space / Resume / Back to game while paused"
                    Select { implicitWidth: 230; options: page.opts([["restart", "Restart the scenario"], ["continue", "Continue where I paused"]]); value: page.c.pauseResume || "restart"; onPicked: function (v) { page.set({ pauseResume: v }) } } }
                SetRow { label: "After a run ends"; hint: "Space on the results screen"
                    Select { implicitWidth: 230; options: page.opts([["restart", "Restart the same scenario"], ["next", "Play the next scenario in the queue"], ["focus", "Just switch to KovaaK's"]]); value: page.c.afterRun || "restart"; onPicked: function (v) { page.set({ afterRun: v }) } } }
                SetRow { label: "KovaaK's restart key"; hint: "Pressed for you after switching back" + (page.restartDetected ? ". " + page.restartDetected : "")
                    Select { implicitWidth: 230; options: page.restartKeys; value: page.c.restartKey || "auto"; onPicked: function (v) { page.set({ restartKey: v }, "Restart key updated"); page.refreshRestartKey() } } }
                Txt { Layout.fillWidth: true; Layout.topMargin: 10; wrapMode: Text.WordWrap; font.pixelSize: 12; color: Theme.muted
                      text: "The queue is the list you launched from: a benchmark difficulty, or the scenarios currently shown in the library. The key is only sent once KovaaK's is confirmed to be in front." }
            }
        }
        // ================= right column =================
        ColumnLayout {
            Layout.fillWidth: true; Layout.preferredWidth: 1; Layout.alignment: Qt.AlignTop; spacing: 16
            SetSection {
                title: "Rewards & library"
                SetRow { label: "Celebrate new personal bests"; hint: "Confetti and a gold results screen"
                    Toggle { checked: !!page.c.celebratePB; onToggled: function (v) { page.set({ celebratePB: v }) } } }
                SetRow { label: "Sounds"; hint: "Short chime on a new PB"
                    Toggle { checked: !!page.c.sounds; onToggled: function (v) { page.set({ sounds: v }) } } }
                SetRow { label: "Show scenarios that aren't installed"; hint: "Scenarios you have stats for but no local file"
                    Toggle { checked: !!page.c.showUninstalled; onToggled: function (v) { page.set({ showUninstalled: v }) } } }
                SetRow { label: "Name on tag thumbnails"; hint: "Overlay the scenario name when a card uses its tag's thumbnail"
                    Toggle { checked: page.c.tagThumbNames !== false; onToggled: function (v) { page.set({ tagThumbNames: v }) } } }
            }
            SetSection {
                id: appearance
                title: "Appearance"
                RowLayout { Layout.fillWidth: true; Layout.bottomMargin: 8
                    Txt { text: "Theme"; font.pixelSize: 12; color: Theme.muted; Layout.fillWidth: true }
                    Btn { small: true; kind: "ghost"; text: "Reset"; onClicked: page.resetAppearance() } }
                Flow {
                    Layout.fillWidth: true; spacing: 8; Layout.bottomMargin: 8
                    Repeater {
                        model: ["range", "midnight", "oled", "graphite", "slate", "nord", "plum", "forest"].map(function (id) { return { id: id, t: AP.themeById(id, page.a, Theme.themes) } }).concat(page.a.userThemes.map(function (u) { return { id: u.id, t: AP.themeById(u.id, page.a, Theme.themes) } }))
                        delegate: Rectangle {
                            id: tile
                            required property var modelData
                            readonly property bool on: page.a.theme === modelData.id
                            width: 112; height: 66; radius: Theme.radiusSm; color: modelData.t.colors.bg
                            border.width: on ? 2 : 1; border.color: on ? Theme.accent : modelData.t.colors.border
                            Rectangle { x: 8; y: 8; width: parent.width - 16; height: 24; radius: 2; color: tile.modelData.t.colors.surface; border.width: 1; border.color: tile.modelData.t.colors.border
                                Rectangle { x: 6; y: 8; width: 8; height: 8; radius: 1; color: tile.modelData.t.accent || Theme.accent }
                                Rectangle { x: 20; y: 10; width: 40; height: 4; radius: 1; color: tile.modelData.t.colors.muted } }
                            Txt { x: 8; y: 40; width: parent.width - 16; text: tile.modelData.t.label; font.pixelSize: 12; w: 600; color: tile.modelData.t.colors.text; elide: Text.ElideRight }
                            Row { visible: tile.modelData.t.user === true && tma.containsMouse; anchors.right: parent.right; anchors.bottom: parent.bottom; anchors.margins: 3; spacing: 2
                                Btn { kind: "ghost"; icon: "edit"; implicitWidth: 22; implicitHeight: 22; onClicked: page.editTheme(tile.modelData.id) }
                                Btn { kind: "ghost"; icon: "trash"; implicitWidth: 22; implicitHeight: 22; onClicked: page.deleteTheme({ id: tile.modelData.id, name: tile.modelData.t.label }) } }
                            MouseArea { id: tma; anchors.fill: parent; z: -1; hoverEnabled: true; cursorShape: Qt.PointingHandCursor
                                onClicked: { var t = tile.modelData.t; page.saveA({ theme: tile.modelData.id, custom: {}, accent2: t.accent2 || page.a.accent2 }, t.accent ? { accent: t.accent } : {}) } }
                        }
                    }
                    Rectangle {
                        width: 112; height: 66; radius: Theme.radiusSm; color: "transparent"; border.width: 1; border.color: Theme.border2
                        Column { anchors.centerIn: parent; spacing: 4
                            Icon { name: "plus"; size: 16; color: Theme.text2; anchors.horizontalCenter: parent.horizontalCenter }
                            Txt { text: "Save as theme"; font.pixelSize: 12; color: Theme.text2 } }
                        MouseArea { anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onClicked: page.editTheme(null) }
                    }
                }
                SetRow { label: "Accent color"; hint: "Buttons, highlights, charts"
                    SwatchRow { swatches: AP.ACCENTS; value: page.c.accent || "#ece8de"; onPicked: function (v) { page.set({ accent: String(v) }) } } }
                SetRow { label: "Secondary color"; hint: "Links, gradients, secondary charts"
                    SwatchRow { swatches: AP.ACCENTS2; value: page.a.accent2; onPicked: function (v) { page.saveA({ accent2: String(v) }) } } }
                Repeater {
                    model: AP.BASE_KEYS
                    delegate: SetRow {
                        required property var modelData
                        label: modelData[1]; hint: page.a.custom[modelData[0]] ? "Custom (differs from the theme)" : ""
                        Btn { visible: !!page.a.custom[modelData[0]]; small: true; kind: "ghost"; text: "Reset"; onClicked: { var cu = AP.copy(page.a.custom); delete cu[modelData[0]]; page.saveA({ custom: cu }) } }
                        ColorBox { value: page.colors[modelData[0]]; onPicked: function (v) { var cu = AP.copy(page.a.custom); cu[modelData[0]] = String(v); page.saveA({ custom: cu }) } }
                    }
                }
                RowLayout { visible: Object.keys(page.a.custom).length > 0; Layout.fillWidth: true; Layout.topMargin: 6
                    Txt { text: "You've customised some colours."; font.pixelSize: 12; color: Theme.muted; Layout.fillWidth: true }
                    Btn { small: true; icon: "plus"; text: "Save as theme"; onClicked: page.editTheme(null) }
                    Btn { small: true; kind: "ghost"; text: "Reset colours"; onClicked: page.saveA({ custom: ({}) }) } }
                SetRow { label: "Font"
                    Select { implicitWidth: 200; options: AP.FONTS; value: page.a.font; onPicked: function (v) { page.saveA({ font: v }) } } }
                SetRow { label: "Interface scale"; hint: "Zoom the whole app"
                    Sld { implicitWidth: 160; from: 80; to: 130; step: 5; value: page.a.scale; onMoved: function (v) { page.saveA({ scale: Math.round(v) }) } }
                    Txt { text: page.a.scale + "%"; font.pixelSize: 12; color: Theme.muted; Layout.preferredWidth: 40; horizontalAlignment: Text.AlignRight } }
                SetRow { label: "Corners"; hint: page.a.radius === "rounded" ? "Corner radius" : ""
                    Seg { options: [{ value: "sharp", label: "Sharp" }, { value: "rounded", label: "Rounded" }]; value: page.a.radius; onPicked: function (v) { page.saveA({ radius: v }) } }
                    Sld { visible: page.a.radius === "rounded"; implicitWidth: 110; from: 2; to: 24; step: 1; value: page.a.radiusPx; onMoved: function (v) { page.saveA({ radiusPx: Math.round(v) }) } }
                    Txt { visible: page.a.radius === "rounded"; text: page.a.radiusPx + "px"; font.pixelSize: 12; color: Theme.muted; Layout.preferredWidth: 36; horizontalAlignment: Text.AlignRight } }
                SetRow { label: "Density"; hint: "Spacing of cards, tables and pages"
                    Select { implicitWidth: 170; options: page.opts([["compact", "Compact"], ["comfortable", "Comfortable"], ["spacious", "Spacious"]]); value: page.a.density; onPicked: function (v) { page.saveA({ density: v }) } } }
                SetRow { label: "Scenario card size"
                    Select { implicitWidth: 170; options: page.opts([["small", "Small"], ["medium", "Medium"], ["large", "Large"]]); value: page.a.cardSize; onPicked: function (v) { page.saveA({ cardSize: v }) } } }
                SetRow { label: "Animations"; hint: "Turn off for a calmer, snappier interface"
                    Toggle { checked: !!page.a.motion; onToggled: function (v) { page.saveA({ motion: v }) } } }
                SetRow { label: "Highlight PB runs"; hint: "Gold gradient on personal-best runs in run lists"
                    Toggle { checked: !!page.a.pbGradient; onToggled: function (v) { page.saveA({ pbGradient: v }) } } }
                SetRow { label: "Dim runs from earlier days"; hint: "Keep today's runs bright in run lists"
                    Toggle { checked: !!page.a.dimOld; onToggled: function (v) { page.saveA({ dimOld: v }) } } }
                SetRow { label: "Preview on hover"; hint: "Hovering a scenario plays its preview: over the card in grid view, in a pop-up in lists and tables"
                    Toggle { checked: !!page.a.hoverPreview; onToggled: function (v) { page.saveA({ hoverPreview: v }) } } }
            }
            SetSection {
                title: "Data"
                SetRow { label: "Kovaak's Plus data"; hint: "Tags, names, presets, thumbnails, backups"
                    Btn { small: true; icon: "folder"; text: "Open"; onClicked: Backend.send("app.openDataFolder", {}) } }
                SetRow { label: "Thumbnails & icons"; hint: "media/scenarios, media/tags and media/presets, one folder per item"
                    Btn { small: true; icon: "folder"; text: "Open"; onClicked: Backend.send("media.openFolder", {}) } }
                SetRow { label: "Clean up unused files"; hint: "Find thumbnails, previews and icons nothing uses any more, and links to files that are gone"
                    Btn { small: true; icon: "trash"; text: "Scan"; onClicked: page.scanCleanup() } }
                SetRow { label: "Clean up automatically on launch"; hint: "Each time the app starts, unused files go to the Trash and broken links are cleared"
                    Toggle { checked: !!page.c.autoCleanMedia; onToggled: function (v) { page.set({ autoCleanMedia: v }) } } }
                SetRow { label: "KovaaK's stats folder"; hint: "Where run CSVs are saved"
                    Btn { small: true; icon: "folder"; text: "Open"; onClicked: Backend.send("app.reveal", { what: "stats" }) } }
                SetRow { label: "Re-run setup"; hint: "Walk through first-time setup again"
                    Btn { small: true; text: "Run setup"; onClicked: Store.saveConfig({ setupComplete: false }, function () { Store.firstRun = true }) } }
            }
            Card {
                Layout.fillWidth: true; pad: 18; implicitHeight: about.implicitHeight + 36
                ColumnLayout { id: about; width: parent.width; spacing: 10
                    Txt { Layout.fillWidth: true; wrapMode: Text.WordWrap; font.pixelSize: 13; color: Theme.muted; textFormat: Text.StyledText
                          text: "<b>Sharing with friends:</b> the app finds KovaaK's, their workshop scenarios and their Steam account by itself. Your tags and presets travel separately as .kpack files." }
                    Txt { Layout.fillWidth: true; wrapMode: Text.WordWrap; font.pixelSize: 13; color: Theme.muted; textFormat: Text.StyledText; linkColor: Theme.accent2
                          text: "Benchmark data from <a href='https://evxl.app'>evxl.app</a> and KovaaK's. Kovaak's Plus never modifies the game, reads its memory, or touches your scenario files (except when you import a pack)."
                          onLinkActivated: function (u) { Backend.send("app.openUrl", { url: u }) } } }
            }
        }
    }
}
