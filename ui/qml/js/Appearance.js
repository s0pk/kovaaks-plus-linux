.pragma library
// Appearance settings (config.ui.appearance): defaults, user themes and the colours a theme resolves to.

var BASE_KEYS = [["bg", "Background"], ["surface", "Panels"], ["border", "Borders"], ["text", "Text"], ["muted", "Muted text"], ["sidebar", "Sidebar"]]
var DEFAULTS = {
  theme: "range", accent2: "#8fb8b0", custom: {}, userThemes: [], font: "system", scale: 100, radius: "rounded", radiusPx: 4,
  density: "comfortable", cardSize: "medium", glow: false, motion: true, dimOld: true, pbGradient: true, hoverPreview: true
}
var ACCENTS = ["#ece8de", "#8b5cf6", "#6366f1", "#3b82f6", "#06b6d4", "#10b981", "#84cc16", "#f59e0b", "#f97316", "#ef4444", "#ec4899"]
var ACCENTS2 = ["#22d3ee", "#38bdf8", "#34d399", "#facc15", "#f472b6", "#a78bfa"]
var FONTS = [{ value: "system", label: "Range (default)" }, { value: "segoe", label: "System sans-serif" }, { value: "consolas", label: "Monospace" }]

function appearance(config) {
  var src = ((config && config.ui) || {}).appearance || {}
  var a = {}
  for (var k in DEFAULTS) a[k] = DEFAULTS[k]
  for (var s in src) a[s] = src[s]
  if (a.radius === "default" || a.radius === "round") { a.radiusPx = a.radius === "round" ? 18 : 12; a.radius = "rounded" }
  a.custom = a.custom || {}
  a.userThemes = a.userThemes || []
  return a
}

/** {label, colors, user, accent, accent2} for a built-in (from Theme.themes) or user theme. */
function themeById(id, a, builtin) {
  if (builtin[id]) { var b = builtin[id]; return { label: b.label, colors: { bg: b.bg, surface: b.surface, border: b.border, text: b.text, muted: b.muted, sidebar: b.sidebar } } }
  for (var i = 0; i < a.userThemes.length; i++) {
    var u = a.userThemes[i]
    if (u.id === id) return { label: u.name, colors: u.colors, user: true, accent: u.accent, accent2: u.accent2 }
  }
  return themeById("range", a, builtin)
}

function effectiveColors(a, builtin) {
  var c = {}, base = themeById(a.theme, a, builtin).colors
  BASE_KEYS.forEach(function (k) { c[k[0]] = a.custom[k[0]] || base[k[0]] })
  return c
}

function copy(o) { return JSON.parse(JSON.stringify(o)) }
function newThemeId() { return "u" + Math.random().toString(36).slice(2, 9) }
function fmtBytes(n) { return n >= 1048576 ? (n / 1048576).toFixed(1) + " MB" : n >= 1024 ? Math.round(n / 1024) + " KB" : n + " B" }
