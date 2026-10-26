pragma Singleton
import QtQuick
import Kplus
import "js/Fmt.js" as Fmt
import "js/LibraryLogic.js" as LL

// Global client-side state shared by all pages (the equivalent of state.js, play.js and main.js's bookkeeping).
QtObject {
    id: s

    // ---- app ----
    property var config: ({})
    property string version: ""
    property bool valid: false
    property bool firstRun: false
    property bool booted: false
    property string dataFolder: ""
    property string bootError: ""

    // ---- library ----
    property var scenarios: []
    property var byName: ({})
    property var tags: []
    property var groups: []
    property bool libraryLoaded: false
    signal libraryChanged()

    // ---- library page state (kept while navigating) ----
    property var libUi: LL.defaultUi()
    property var benchNames: null      // benchmark id -> {name, difficulty, color}
    function setLib(patch) {
        var n = {}
        for (var k in libUi) n[k] = libUi[k]
        for (var p in patch) n[p] = patch[p]
        libUi = n
    }
    function loadBenchNames() {
        if (benchNames) return
        Backend.call("evxl.catalog", {}, function (cat) {
            var map = {}
            ;(cat.groups || []).forEach(function (g) { g.difficulties.forEach(function (d) { map[d.id] = { name: g.name, difficulty: d.name, color: g.color } }) })
            benchNames = map
        }, function () { benchNames = {} })
    }

    // ---- game ----
    property var game: ({ running: false, currentScenario: null })
    property bool paused: false
    property bool statsReady: false
    property var statsProgress: null
    property var catalogProgress: null
    property var queue: null           // { names: [...], index } : the list the current scenario was launched from
    property var presets: null
    property string settingsTab: "presets"
    property string liveCat: "sens"

    // ---- routing ("home", "library", "benchmarks/2789", …) ----
    property string route: "home"
    property string routeArg: ""
    property var routeParams: ({})
    signal routeChanged2()
    function go(path) {
        var q = ""
        var qi = path.indexOf("?")
        if (qi >= 0) { q = path.slice(qi + 1); path = path.slice(0, qi) }
        var parts = path.replace(/^\/+/, "").split("/")
        var params = {}
        if (q) q.split("&").forEach(function (kv) { var p = kv.split("="); params[decodeURIComponent(p[0])] = decodeURIComponent(p[1] || "") })
        routeParams = params
        routeArg = parts.length > 1 ? decodeURIComponent(parts.slice(1).join("/")) : ""
        route = parts[0] || "home"
        if (route !== "benchmarks") viewing = null
        routeChanged2()
    }

    // ---- benchmark page session state ----
    property var benchCustoms: ({})      // "player|benchId" -> {scenario: what-if score}
    property bool benchCalcOpen: false

    // ---- another player's benchmarks (cleared when you leave the Benchmarks tab) ----
    property var viewing: null
    signal closeOverlaysRequested()
    function viewPlayer(p, benchId) {
        viewing = (p && p.steamId && p.steamId !== config.steamId) ? { steamId: String(p.steamId), name: p.name || String(p.steamId), country: p.country || null } : null
        closeOverlaysRequested()
        go(benchId ? "benchmarks/" + benchId : "benchmarks")
    }
    function favoritePlayers() { return (config.ui && config.ui.favoritePlayers) || [] }
    function isFavoritePlayer(steamId) { return favoritePlayers().some(function (x) { return x.steamId === steamId }) }
    function toggleFavoritePlayer(p) {
        var ui = JSON.parse(JSON.stringify(config.ui || {}))
        var list = ui.favoritePlayers || []
        var i = -1
        for (var k = 0; k < list.length; k++) if (list[k].steamId === p.steamId) i = k
        if (i >= 0) list.splice(i, 1); else list.push({ steamId: String(p.steamId), name: p.name || String(p.steamId), country: p.country || null })
        ui.favoritePlayers = list
        saveConfig({ ui: ui }, function () { toast(i >= 0 ? "Removed " + p.name + " from favorites" : "Added " + p.name + " to favorites", "ok") })
    }
    /** Click / right-click behaviour for a leaderboard row. */
    function playerMenu(p, benchId, x, y) {
        var self = p.steamId === config.steamId
        Modals.menu([
            { header: p.name || p.steamId },
            { label: self ? "View my benchmarks" : "View their benchmarks", icon: "trophy", onClick: function () { viewPlayer(p, benchId) } },
            self ? null : { label: isFavoritePlayer(p.steamId) ? "Remove from favorites" : "Add to favorites", icon: "star", onClick: function () { toggleFavoritePlayer(p) } },
            { sep: true },
            { label: "Open profile on evxl.app", icon: "external", onClick: function () { Backend.send("app.openUrl", { url: "https://evxl.app/u/" + p.steamId }) } },
            { label: "Open Steam profile", icon: "external", onClick: function () { Backend.send("app.openUrl", { url: "https://steamcommunity.com/profiles/" + p.steamId }) } }
        ], x, y)
    }

    // ---- toasts ----
    signal toastRequested(string text, string kind)
    function toast(text, kind) { toastRequested(text, kind || "") }

    // ---- run results / events other parts of the UI react to ----
    signal runCompleted(var data)
    property var hover: null             // {name, x, y}: the scenario whose pop-up preview is showing
    function showHover(name, x, y) {
        var sc = scenario(name)
        if (!sc || !Theme.hoverPreview) return
        if (!(sc.preview || sc.thumbnail) && !tagThumbs(sc).length) { hover = null; return }   // only a generated tile: not worth a pop-up
        hover = { name: name, x: x, y: y }
    }
    function hideHover() { if (hover) hover = null }
    signal devScroll()                   // dev only: scroll the current page up and down (frame-rate probe)
    property var results: null           // the run.completed payload while the results screen is open
    signal scenarioRequested(string name)
    function openScenario(name) { scenarioRequested(name) }
    signal scenarioMetaChanged(string name)
    signal configSaved()

    // ================= library =================

    function scenario(name) { return byName[String(name || "").toLowerCase()] }
    function tagById(id) { for (var i = 0; i < tags.length; i++) if (tags[i].id === id) return tags[i]; return null }
    function displayName(sc) { return sc ? (sc.customName || sc.name || "") : "" }
    function primaryTagColor(sc) {
        if (!sc || !sc.tags || !sc.tags.length) return ""
        var t = tagById(sc.tags[0])
        return t ? t.color : ""
    }
    /** KovaaK's own tags plus the names of the user's tags: what the generated art classifies from. */
    function artInfo(sc) {
        var own = []
        for (var i = 0; i < tags.length; i++) if (sc && sc.tags && sc.tags.indexOf(tags[i].id) >= 0) own.push(tags[i].name)
        return [sc && sc.gameTag].concat(own).filter(function (x) { return x }).join(" ")
    }
    function tagThumbs(sc) {
        if (!sc || !sc.tags || !sc.tags.length) return []
        return tags.filter(function (t) { return t.thumbnail && sc.tags.indexOf(t.id) >= 0 }).map(function (t) { return t.thumbnail })
    }

    function applyLibrary(res) {
        var map = {}
        for (var i = 0; i < res.scenarios.length; i++) map[res.scenarios[i].name.toLowerCase()] = res.scenarios[i]
        byName = map
        scenarios = res.scenarios
        tags = res.tags
        groups = res.groups
        libraryLoaded = true
        libraryChanged()
    }

    function loadLibrary(ok) {
        Backend.call("library.list", {}, function (res) { applyLibrary(res); if (ok) ok(res) },
                     function (e) { toast(e, "error") })
    }

    /** Merge a fresh scenario meta back into the cached list without a full reload. */
    function patchScenario(name, meta) {
        var sc = scenario(name)
        if (!sc) return
        sc.customName = meta.customName === undefined ? null : meta.customName
        sc.tags = meta.tags || []
        sc.favorite = !!meta.favorite
        sc.hidden = !!meta.hidden
        sc.thumbnail = meta.thumbnail === undefined ? null : meta.thumbnail
        sc.preview = meta.preview === undefined ? null : meta.preview
        sc.hasNotes = !!meta.notes
        sc.preset = meta.preset === undefined ? null : meta.preset
        scenarios = scenarios.slice()
        libraryChanged()
        scenarioMetaChanged(name)
    }

    function saveConfig(patch, ok) {
        Backend.call("app.saveConfig", patch, function (res) {
            config = res.config
            valid = res.valid
            Theme.apply(config)
            configSaved()
            if (ok) ok(res)
        }, function (e) { toast(e, "error") })
    }

    /** Changes one key of config.ui: applied to the UI immediately, saved to disk shortly after (for sliders and the like). */
    property var _pendingUi: null
    property Timer _uiTimer: Timer { interval: 400; onTriggered: { if (s._pendingUi) { var ui = s._pendingUi; s._pendingUi = null; s.saveConfig({ ui: ui }) } } }
    function setUi(key, value) {
        var ui = JSON.parse(JSON.stringify(config.ui || {}))
        ui[key] = value
        var c = {}
        for (var k in config) c[k] = config[k]
        c.ui = ui
        config = c
        _pendingUi = ui
        _uiTimer.restart()
    }

    function setTags(newTags, newGroups, ok) {
        Backend.call("library.saveTags", { tags: newTags, groups: newGroups }, function (res) {
            tags = res.tags
            groups = res.groups
            libraryChanged()
            if (ok) ok()
        }, function (e) { toast(e, "error") })
    }

    // ================= playing =================

    function setQueue(names, current) {
        queue = names && names.length ? { names: names.slice(), index: Math.max(0, names.indexOf(current)) } : null
    }
    function nextInQueue(current) {
        var q = queue
        if (!q) return null
        var i = -1
        for (var k = 0; k < q.names.length; k++) if (current && q.names[k].toLowerCase() === current.toLowerCase()) i = k
        if (!current) i = q.index
        return i >= 0 && i + 1 < q.names.length ? q.names[i + 1] : null
    }

    /** opts: { queue: [names] } sets the queue; otherwise it is kept only if it contains this scenario. */
    function play(name, mode, opts) {
        opts = opts || {}
        if (opts.queue) setQueue(opts.queue, name)
        else if (queue) {
            var idx = -1
            for (var k = 0; k < queue.names.length; k++) if (queue.names[k].toLowerCase() === name.toLowerCase()) idx = k
            if (idx >= 0) queue.index = idx; else queue = null
        }
        mode = mode || config.defaultMode || "challenge"
        Backend.call("game.play", { name: name, mode: mode }, function (res) {
            if (res && res.needsPreset) {
                Modals.presetPrompt(name, res, function (choice) {
                    if (!choice) return
                    Backend.call("game.play", { name: name, mode: mode, preset: choice }, function (r2) {
                        if (r2 && r2.presetApplied) toast("Applied preset \"" + r2.presetApplied + "\"", "ok")
                    }, function (e) { toast(e, "error") })
                })
                return
            }
            if (res && res.presetApplied) toast("Applied preset \"" + res.presetApplied + "\"", "ok")
        }, function (e) { toast(e, "error") })
    }

    function launchGame() { Backend.call("game.launch", {}, function () { toast("Launching KovaaK's…") }) }

    /** From the pause bar / sidebar. While paused this restarts the run (pressing KovaaK's restart key) unless set to continue. */
    function resumeGame() {
        var wasPaused = paused
        paused = false
        var restart = wasPaused && (config.pauseResume || "restart") === "restart"
        Backend.send("game.focus", { resuming: !restart, action: restart ? "restart" : "focus" })
    }

    /** Updates a scenario's overlay data (tags, favorite, name…) and merges the answer into the cached list. */
    function setMeta(name, patch, ok) {
        var params = { name: name }
        for (var k in patch) params[k] = patch[k]
        Backend.call("library.setMeta", params, function (res) {
            if (scenario(name)) patchScenario(name, res.meta); else loadLibrary()
            if (ok) ok(res)
        }, function (e) { toast(e, "error") })
    }

    /** The right-click menu for a scenario (same items as the web UI). */
    function scenarioMenu(name, x, y) {
        var sc = scenario(name) || { name: name, tags: [], favorite: false, hidden: false }
        var dn = displayName(sc) || name
        Modals.menu([
            { header: dn },
            { label: "Play challenge", icon: "play", onClick: function () { play(name, "challenge") } },
            { label: "Play freeplay", icon: "target", onClick: function () { play(name, "freeplay") } },
            { sep: true },
            { label: sc.favorite ? "Remove from favorites" : "Add to favorites", icon: "star", onClick: function () { setMeta(name, { favorite: !sc.favorite }) } },
            { label: sc.hidden ? "Unhide" : "Hide from library", icon: sc.hidden ? "eye" : "eyeOff", onClick: function () { setMeta(name, { hidden: !sc.hidden }) } },
            { label: "Rename…", icon: "edit", onClick: function () {
                Modals.prompt("Rename scenario", "Display name (only inside Kovaak's Plus; the game file keeps its name)", sc.customName || name, "Save", function (v) {
                    if (v !== null && v !== undefined) setMeta(name, { customName: v.trim() && v.trim() !== name ? v.trim() : null })
                }) } },
            { sep: true },
            { label: "Details", icon: "library", onClick: function () { openScenario(name) } },
            sc.installed ? { label: "Show file in file manager", icon: "folder", onClick: function () { Backend.send("library.revealScenario", { name: name }) } } : null
        ], x, y)
    }

    /** Pack export dialog (implemented with the Import / Export page). */
    function exportItems(opts) { Modals.exportPack(opts) }

    /**
     * Calls a settings-changing RPC. If the game is running the backend says so and we ask before it is closed and relaunched.
     * ok(true|false) tells whether the change went through.
     */
    function withRestart(method, params, label, ok) {
        function done(res) { toast(res && res.relaunched ? label + ": relaunching KovaaK's…" : label, "ok"); if (ok) ok(true) }
        Backend.call(method, params, function (res) {
            if (res && res.needsRestart) {
                Modals.confirm("KovaaK's is running", "KovaaK's only reads settings at startup and overwrites them when it closes. Kovaak's Plus will close the game, apply your changes and relaunch it.", "Close, apply & relaunch", "primary", function (yes) {
                    if (!yes) { if (ok) ok(false); return }
                    var p2 = {}
                    for (var k in params) p2[k] = params[k]
                    p2.restart = true
                    Backend.call(method, p2, done, function (e) { toast(e, "error"); if (ok) ok(false) })
                })
            } else done(res)
        }, function (e) { toast(e, "error"); if (ok) ok(false) })
    }

    function loadPresets(ok) {
        Backend.call("presets.list", {}, function (r) { presets = r; if (ok) ok(r) }, function () { presets = presets || [] })
    }

    // ================= events from the backend =================

    property Connections _events: Connections {
        target: Backend
        function onEventReceived(name, d) {
            switch (name) {
            case "game.status":
                s.game = { running: d.running, currentScenario: d.currentScenario !== undefined ? d.currentScenario : s.game.currentScenario }
                if (!d.running) s.paused = false
                break
            case "game.scenario": s.game = { running: s.game.running, currentScenario: d.name }; break
            case "game.pause":
                if (d && d.scenario) s.game = { running: s.game.running, currentScenario: d.scenario }
                s.paused = true
                break
            case "run.completed":
                s.paused = false
                s.game = { running: s.game.running, currentScenario: d.run.scenario }
                var sc = s.scenario(d.run.scenario)
                if (sc) {
                    sc.plays = (sc.plays || 0) + 1
                    sc.lastPlayed = d.run.date
                    if (sc.pb === null || sc.pb === undefined || d.run.score > sc.pb) { sc.pb = d.run.score; sc.pbDate = d.run.date }
                    s.scenarios = s.scenarios.slice()
                    s.libraryChanged()
                } else s.loadLibrary()
                s.runCompleted(d)
                s.results = d
                break
            case "stats.progress": s.statsProgress = d; break
            case "stats.ready": s.statsReady = true; s.statsProgress = null; s.loadLibrary(); break
            case "evxl.catalogProgress": s.catalogProgress = d; break
            case "toast": s.toast(d.text, d.kind || ""); break
            case "zoom": break
            case "dev.eval":
                console.info("dev.eval dev=" + Launch.dev + " code=" + d.code)
                if (Launch.dev) { try { eval(d.code) } catch (err) { console.warn("dev.eval failed: " + err) } }
                break
            }
        }
        function onConnectedChanged() { if (Backend.connected) s.boot() }
    }

    /** App Settings → Data → "Clean up automatically on launch": recycle unused media and clear broken links without asking. */
    property Timer _cleanTimer: Timer {
        interval: 4000
        onTriggered: Backend.call("media.scanUnused", {}, function (scan) {
            if (!scan.files.length && !scan.missing.length && !scan.emptyFolders) return
            Backend.call("media.cleanUnused", { files: scan.files.map(function (f) { return f.path }), clearMissing: true }, function (r) {
                var parts = []
                if (r.deleted) parts.push(r.deleted + " unused file" + (r.deleted === 1 ? "" : "s") + " moved to the Trash")
                if (r.cleared) parts.push(r.cleared + " broken link" + (r.cleared === 1 ? "" : "s") + " cleared")
                if (parts.length) s.toast("Cleanup: " + parts.join(" · "), "ok")
                if (r.cleared) s.loadLibrary()
            }, function () {})
        }, function () {})
    }

    function boot() {
        Backend.call("app.init", {}, function (init) {
            config = init.config
            version = init.version
            valid = init.valid
            firstRun = !!init.firstRun
            statsReady = init.statsReady
            dataFolder = init.dataFolder
            game = { running: init.running, currentScenario: init.currentScenario }
            Theme.apply(config)
            booted = true
            if (!init.firstRun && init.valid) loadLibrary()
            if (config.autoCleanMedia) _cleanTimer.start()
        }, function (e) { bootError = e })
    }
}
