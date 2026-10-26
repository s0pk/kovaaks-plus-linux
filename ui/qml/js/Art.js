.pragma library
// Generated scenario art. A tile says what kind of scenario it is: the name, KovaaK's own tags and the user's tags place it in
// an aim family, and each family has one fixed hue and its own motif. Details are seeded by the scenario name, so siblings in a
// family look related but never identical. The motifs come out as SVG path strings drawn on a 160 x 90 canvas.

var FAMILIES = {
  tracking: { label: 'Tracking', hue: 200 },
  clicking: { label: 'Clicking', hue: 35 },
  switching: { label: 'Switching', hue: 305 },
  movement: { label: 'Movement', hue: 150 },
  control: { label: 'Control', hue: 255 },
  other: { label: 'Scenario', hue: 90, chroma: 0.015 }
}

// Checked in order; the first match wins.
var RULES = [
  ['movement', /strafe|dodge|movement|bhop|jump|airstrafe|\bmover\b/],
  ['switching', /switch|\bts\b|micro ?ts|evasive|multi.?target|target ?switch/],
  ['tracking', /track|smooth|reactive|precise|laser|plasma|follow|pasu|beam|ground ?plaza|air ?angel|goose/],
  ['control', /control|stability|stabili|steady|micro ?adjust|mouse ?control/],
  ['clicking', /click|flick|1 ?wall|3 ?wall|wall|grid|tile|pokeball|popcorn|bounce|reflex|180|360|sixshot|six ?shot|single.?shot|aimerz|aether|shot/]
]

function classify(text) {
  var t = ' ' + String(text || '').toLowerCase() + ' '
  for (var i = 0; i < RULES.length; i++) if (RULES[i][1].test(t)) return RULES[i][0]
  return 'other'
}

function hash(str) {
  var h = 2166136261
  for (var i = 0; i < str.length; i++) { h ^= str.charCodeAt(i); h = Math.imul(h, 16777619) }
  return h >>> 0
}

function rng(seed) {
  var a = seed >>> 0
  return function () {
    a = (a + 0x6D2B79F5) | 0
    var t = Math.imul(a ^ (a >>> 15), 1 | a)
    t = (t + Math.imul(t ^ (t >>> 7), 61 | t)) ^ t
    return ((t ^ (t >>> 14)) >>> 0) / 4294967296
  }
}

// ---- path helpers ----
function n(v) { return Math.round(v * 10) / 10 }
function circle(cx, cy, r) { return 'M ' + n(cx - r) + ' ' + n(cy) + ' A ' + n(r) + ' ' + n(r) + ' 0 1 0 ' + n(cx + r) + ' ' + n(cy) + ' A ' + n(r) + ' ' + n(r) + ' 0 1 0 ' + n(cx - r) + ' ' + n(cy) + ' '}
function line(x1, y1, x2, y2) { return 'M ' + n(x1) + ' ' + n(y1) + ' L ' + n(x2) + ' ' + n(y2) + ' ' }

function newPaths() { return { a: '', b: '', bdash: '', adot: '', af: '' } }

function target(p, x, y, r, hot) {
  p.a += circle(x, y, r)
  p.af += circle(x, y, Math.max(1.4, r * 0.28))
  if (hot) {
    var o = r + 4, l = r + 10
    var dirs = [[1, 0], [-1, 0], [0, 1], [0, -1]]
    for (var i = 0; i < 4; i++) p.a += line(x + dirs[i][0] * o, y + dirs[i][1] * o, x + dirs[i][0] * l, y + dirs[i][1] * l)
  }
}

var MOTIFS = {
  clicking: function (p, r) {
    var spots = []
    for (var tries = 0; spots.length < 6 && tries < 60; tries++) {
      var x = 22 + r() * 118, y = 20 + r() * 40
      var ok = true
      for (var i = 0; i < spots.length; i++) if (Math.hypot(spots[i][0] - x, spots[i][1] - y) <= 24) ok = false
      if (ok) spots.push([x, y])
    }
    for (var k = 0; k < spots.length; k++) target(p, spots[k][0], spots[k][1], k === 0 ? 8 : 5 + r() * 3, k === 0)
  },
  tracking: function (p, r) {
    var y0 = 40 + r() * 18, y1 = 22 + r() * 22, amp = 14 + r() * 12
    var x0 = 16, x1 = 128 + r() * 10
    var d = 'M ' + x0 + ' ' + n(y0) + ' C ' + (x0 + 38) + ' ' + n(y0 - amp * 2) + ', ' + n(x1 - 44) + ' ' + n(y1 + amp * 2) + ', ' + n(x1) + ' ' + n(y1) + ' '
    p.bdash += d
    p.adot += d
    target(p, x1, y1, 7, true)
  },
  switching: function (p, r) {
    var pts = [[26 + r() * 10, 50 + r() * 6], [74 + r() * 12, 26 + r() * 8], [122 + r() * 12, 46 + r() * 10]]
    for (var i = 0; i < 3; i++) {
      if (i) p.bdash += line(pts[i - 1][0] + 9, pts[i - 1][1], pts[i][0] - 9, pts[i][1])
      target(p, pts[i][0], pts[i][1], i === 1 ? 7 : 5.5, i === 1)
    }
  },
  movement: function (p, r) {
    var y = 34 + r() * 10
    for (var i = 0; i < 5; i++) {
      var x = 30 + i * 18
      var d = 'M ' + x + ' ' + n(y - 7) + ' L ' + (x + 8) + ' ' + n(y) + ' L ' + x + ' ' + n(y + 7) + ' '
      if (i < 3) p.a += d; else p.b += d
    }
    p.b += line(14, y + 18, 146, y + 18)
    target(p, 126 + r() * 14, y, 6, false)
  },
  control: function (p, r) {
    var cx = 104 + r() * 10, cy = 36 + r() * 8
    p.bdash += circle(cx, cy, 24)
    var d = ''
    for (var i = 0; i <= 40; i++) {
      var t = i / 40, a = t * Math.PI * 5 + r() * 0.05, rad = 22 * (1 - t * 0.85)
      d += (i ? 'L ' : 'M ') + n(cx + Math.cos(a) * rad) + ' ' + n(cy + Math.sin(a) * rad) + ' '
    }
    p.a += d
    target(p, cx, cy, 4.5, true)
  },
  other: function (p) {
    var cx = 108, cy = 38
    p.b += circle(cx, cy, 20)
    p.af += circle(cx, cy, 3)
    var dirs = [[1, 0], [-1, 0], [0, 1], [0, -1]]
    for (var i = 0; i < 4; i++) p.a += line(cx + dirs[i][0] * 14, cy + dirs[i][1] * 14, cx + dirs[i][0] * 30, cy + dirs[i][1] * 30)
  }
}

// ---- OKLCH → sRGB hex ----
function oklch(L, C, Hdeg) {
  var h = Hdeg * Math.PI / 180
  var a = C * Math.cos(h), b = C * Math.sin(h)
  var l_ = L + 0.3963377774 * a + 0.2158037573 * b
  var m_ = L - 0.1055613458 * a - 0.0638541728 * b
  var s_ = L - 0.0894841775 * a - 1.2914855480 * b
  var l = l_ * l_ * l_, m = m_ * m_ * m_, s = s_ * s_ * s_
  var r = 4.0767416621 * l - 3.3077115913 * m + 0.2309699292 * s
  var g = -1.2684380046 * l + 2.6097574011 * m - 0.3413193965 * s
  var bl = -0.0041960863 * l - 0.7034186147 * m + 1.7076147010 * s
  function enc(v) {
    v = Math.max(0, Math.min(1, v))
    v = v <= 0.0031308 ? 12.92 * v : 1.055 * Math.pow(v, 1 / 2.4) - 0.055
    var x = Math.round(v * 255)
    return (x < 16 ? '0' : '') + x.toString(16)
  }
  return '#' + enc(r) + enc(g) + enc(bl)
}

/** Everything a tile needs: the family, its accent colour and the motif paths. tagColor (a user's tag colour) overrides the hue. */
function makeArt(name, info, tagColor) {
  var family = classify(name)
  if (family === 'other') family = classify(info || '')
  var f = FAMILIES[family]
  var accent = tagColor || oklch(0.80, f.chroma === undefined ? 0.105 : f.chroma, f.hue)
  var paths = newPaths()
  MOTIFS[family](paths, rng(hash(String(name))))
  return { family: family, accent: accent, paths: paths }
}
