pragma Singleton
import QtQuick
import Kplus

// Design tokens: the same palette, type and shapes as the web UI's "Range" identity (charcoal and bone, squared frames,
// condensed numerals). Every colour derives from six base colours so custom themes stay consistent.
QtObject {
    id: t

    readonly property url assets: Qt.resolvedUrl("../assets/")

    // ---- base colours (theme + overrides) ----
    property color bg: "#141513"
    property color surface: "#1b1c1a"
    property color border: "#2d2f2b"
    property color text: "#ece8de"
    property color muted: "#8d9085"
    property color sidebar: "#10110f"
    property color accent: "#ece8de"
    property color accent2: "#8fb8b0"

    // Colours may be given as colour values or strings ("white", "#8b5cf6").
    function mix(a, b, pct) { var cb = Qt.color(b); return Qt.tint(Qt.color(a), Qt.rgba(cb.r, cb.g, cb.b, pct / 100)) }
    function alpha(c, a) { var cc = Qt.color(c); return Qt.rgba(cc.r, cc.g, cc.b, a) }
    function lum(c0) {
        var c = Qt.color(c0)
        function f(v) { return v <= 0.03928 ? v / 12.92 : Math.pow((v + 0.055) / 1.055, 2.4) }
        return 0.2126 * f(c.r) + 0.7152 * f(c.g) + 0.0722 * f(c.b)
    }

    readonly property color bg2: mix(bg, surface, 40)
    readonly property color surface2: mix(surface, text, 4)
    readonly property color surface3: mix(surface, text, 9)
    readonly property color border2: mix(border, text, 10)
    readonly property color text2: mix(text, muted, 40)
    readonly property color onAccent: lum(accent) > 0.4 ? "#141513" : "#ffffff"
    readonly property color accentSoft: alpha(accent, 0.12)
    readonly property color accentLine: alpha(accent, 0.38)
    readonly property color good: "#5fbf8a"
    readonly property color bad: "#e5604d"
    readonly property color gold: "#f0b93a"

    // ---- shape ----
    property real radius: 4
    property real radiusSm: 3
    property real uiScale: 1.0
    property bool motion: true
    property string density: "comfortable"
    property string cardSize: "medium"
    property bool dimOld: true
    property bool pbGradient: true
    property bool hoverPreview: true
    readonly property real cardMin: ({ small: 190, medium: 232, large: 300 })[cardSize] || 232
    readonly property int animMs: motion ? 140 : 0

    // ---- type ----
    property string fontKey: "system"
    function nearest(list, w) {
        var best = list[0]
        for (var i = 0; i < list.length; i++) if (Math.abs(list[i] - w) < Math.abs(best - w)) best = list[i]
        return best
    }
    // Body face (weights 400-700) and the condensed display face (600-800) used for headings and numerals.
    function sans(w) { return fontKey === "system" ? "KPSans" + nearest([400, 500, 600, 700], w || 400) : (fontKey === "consolas" ? "monospace" : "sans-serif") }
    function display(w) { return fontKey === "system" ? "KPDisplay" + nearest([600, 700, 800], w || 700) : (fontKey === "consolas" ? "monospace" : "sans-serif") }

    property list<FontLoader> _fonts: [
        FontLoader { source: t.assets + "BigShoulders-600.ttf" },
        FontLoader { source: t.assets + "BigShoulders-700.ttf" },
        FontLoader { source: t.assets + "BigShoulders-800.ttf" },
        FontLoader { source: t.assets + "InstrumentSans-400.ttf" },
        FontLoader { source: t.assets + "InstrumentSans-500.ttf" },
        FontLoader { source: t.assets + "InstrumentSans-600.ttf" },
        FontLoader { source: t.assets + "InstrumentSans-700.ttf" }
    ]

    // ---- themes (same six base colours as the web UI) ----
    readonly property var themes: ({
        range: { label: "Range", bg: "#141513", surface: "#1b1c1a", border: "#2d2f2b", text: "#ece8de", muted: "#8d9085", sidebar: "#10110f" },
        midnight: { label: "Midnight", bg: "#0b0d12", surface: "#141821", border: "#252b3a", text: "#e8eaf0", muted: "#7d859a", sidebar: "#0d1016" },
        oled: { label: "OLED black", bg: "#000000", surface: "#0c0d10", border: "#1c1e25", text: "#ececf1", muted: "#7a8193", sidebar: "#000000" },
        graphite: { label: "Graphite", bg: "#121212", surface: "#1c1c1c", border: "#2e2e2e", text: "#ededed", muted: "#8a8a8a", sidebar: "#141414" },
        slate: { label: "Slate blue", bg: "#0f172a", surface: "#16213a", border: "#26324f", text: "#e8edf7", muted: "#7d8aa8", sidebar: "#0c1424" },
        nord: { label: "Nord", bg: "#1f2430", surface: "#2a3140", border: "#3b4252", text: "#eceff4", muted: "#8f9bb3", sidebar: "#1b202b" },
        plum: { label: "Plum", bg: "#140d1a", surface: "#1f1428", border: "#33243f", text: "#f1eaf7", muted: "#937fa8", sidebar: "#110b16" },
        forest: { label: "Forest", bg: "#0b120e", surface: "#131d17", border: "#223328", text: "#e6f0e9", muted: "#7c9585", sidebar: "#09100c" }
    })

    /** Applies the saved configuration (config.accent and config.ui.appearance), the way theme.js did. */
    function apply(config) {
        var ui = (config && config.ui) || {}
        var a = ui.appearance || {}
        var id = a.theme || "range"
        var th = themes[id]
        if (!th) {
            var users = a.userThemes || []
            for (var i = 0; i < users.length; i++) if (users[i].id === id) { th = users[i].colors; break }
        }
        th = th || themes.range
        var c = {}
        var keys = ["bg", "surface", "border", "text", "muted", "sidebar"]
        for (var k = 0; k < keys.length; k++) c[keys[k]] = (a.custom && a.custom[keys[k]]) || th[keys[k]]
        bg = c.bg; surface = c.surface; border = c.border; text = c.text; muted = c.muted; sidebar = c.sidebar || c.bg
        accent = (config && config.accent) || "#ece8de"
        accent2 = a.accent2 || "#8fb8b0"
        fontKey = a.font || "system"
        var r = a.radius === "sharp" ? 3 : Math.max(2, Math.min(24, a.radiusPx || 4))
        radius = r
        radiusSm = Math.round(r * 0.67)
        uiScale = Math.max(0.6, Math.min(1.6, (a.scale || 100) / 100))
        motion = a.motion !== false
        density = a.density || "comfortable"
        cardSize = a.cardSize || "medium"
        dimOld = a.dimOld !== false
        pbGradient = a.pbGradient !== false
        hoverPreview = a.hoverPreview !== false
    }
}
