.pragma library
.import "BenchCalc.js" as BC
.import "Fmt.js" as Fmt
// Data model for the benchmark table (ported from benchTable() in views/benchmarks.js): everything the QML table draws,
// precomputed per row, plus the category / subcategory / energy blocks that the web version builds with HTML row-spans.

var TABLE_VERSION = 2
var DEFAULTS = {
  v: TABLE_VERSION, density: 'normal', progress: 'normal', skew: 45, outerRadius: 8, innerRadius: 4, shadeCategory: true, shadeRank: true,
  rankColumnColors: false, font: 'default', textSize: 100, rankTextContrast: 45, thresholdTextContrast: 45, scoreTextContrast: 45,
  energyTextContrast: 45, categoryTextContrast: 45, bold: true, textShadow: true,
  subGradient: false, gradientStrength: 22,
  showPosition: false, showProgress: true, uncappedProgress: false, simplifyNames: false
}

function settings(saved) {
  saved = saved || {}
  var ts = {}
  for (var k in DEFAULTS) ts[k] = DEFAULTS[k]
  if (saved.v !== TABLE_VERSION) return ts
  for (var k2 in saved) ts[k2] = saved[k2]
  if (saved.textContrast !== undefined && saved.textContrast !== null) {
    if (saved.rankTextContrast === undefined) ts.rankTextContrast = saved.textContrast
    if (saved.scoreTextContrast === undefined) ts.scoreTextContrast = saved.textContrast
  }
  if (saved.thresholdTextContrast === undefined) ts.thresholdTextContrast = ts.rankTextContrast
  if (saved.energyTextContrast === undefined) ts.energyTextContrast = ts.scoreTextContrast
  return ts
}

// ---- colour helpers on #rrggbb strings ----
function parse(c) {
  c = String(c || '#888888').trim()
  if (c.charAt(0) === '#') {
    if (c.length === 4) c = '#' + c[1] + c[1] + c[2] + c[2] + c[3] + c[3]
    return [parseInt(c.slice(1, 3), 16), parseInt(c.slice(3, 5), 16), parseInt(c.slice(5, 7), 16)]
  }
  var m = /rgba?\((\d+),\s*(\d+),\s*(\d+)/.exec(c)
  return m ? [+m[1], +m[2], +m[3]] : [136, 136, 136]
}
function hex(rgb) {
  return '#' + rgb.map(function (v) { v = Math.max(0, Math.min(255, Math.round(v))); return (v < 16 ? '0' : '') + v.toString(16) }).join('')
}
/** CSS color-mix(in srgb, color pct%, other). */
function mix(color, pct, other) {
  var a = parse(color), b = parse(other)
  var p = pct / 100
  return hex([a[0] * p + b[0] * (1 - p), a[1] * p + b[1] * (1 - p), a[2] * p + b[2] * (1 - p)])
}
function mixWhite(color, pct) { return mix(color, pct, '#ffffff') }
function shade(color) { return mix(color, 85, '#000000') }

/** "VT Pasu Intermediate S5" → "Pasu" (drops the benchmark prefix, difficulty and season). */
function simplifyName(name, b) {
  var words = name.split(/\s+/)
  var diffWords = (b.difficulty || '').toLowerCase().split(/\s+/).filter(function (x) { return x })
  var abbr = (b.abbreviation || '').toLowerCase()
  while (words.length > 1 && (words[0].toLowerCase() === abbr || /^(vt|ra|cb|vts)$/i.test(words[0]))) words.shift()
  while (words.length > 1) {
    var w = words[words.length - 1].toLowerCase().replace(/[()]/g, '')
    if (/^s\d+(\.\d+)?$/.test(w) || diffWords.indexOf(w) >= 0 || ['novice', 'intermediate', 'advanced', 'elite', 'easy', 'medium', 'hard'].indexOf(w) >= 0) words.pop()
    else break
  }
  return words.join(' ')
}

function keysOf(subs) {
  var seen = {}
  return subs.map(function (s, k) {
    var key = (s.subcategoryName || '').trim() || ('#' + (k + 1))
    if (seen[key]) { seen[key]++; key += ' (' + seen[key] + ')' } else seen[key] = 1
    return key
  })
}

var DENSITY = { ultra: 22, compact: 26, normal: 31, wide: 40 }

/** Builds everything the table needs. b = benchmark (with what-if scores applied), res = BC.computeBenchmark(b). */
function build(b, res, ts) {
  var layout = res.layout, list = res.list
  var nThresh = 0
  list.forEach(function (s) { nThresh = Math.max(nThresh, (s.rankMaxes || []).length) })
  var energyMode = !!(res.supported && res.subEnergies)
  var ranks = [], rankCol = []
  for (var i = 0; i < nThresh; i++) {
    var e = BC.rankEntry(i + 1, b)
    ranks.push(e)
    rankCol.push(Fmt.rankColor(e, i + 1))
  }
  var rankPct = 100 - ts.rankTextContrast, thrPct = 100 - ts.thresholdTextContrast, scorePct = 100 - ts.scoreTextContrast
  var energyPct = 100 - ts.energyTextContrast, catPct = 100 - ts.categoryTextContrast

  var heads = ranks.map(function (r, i) { return { name: r.name, icon: r.icon, color: mixWhite(rankCol[i], rankPct) } })
  var rows = [], cats = [], subs = [], groups = []
  var idx = 0

  layout.forEach(function (cat) {
    var catRows = cat.subcategories.reduce(function (a, s) { return a + s.scenarioCount }, 0)
    var subKeys = keysOf(cat.subcategories)
    var catColor = cat.color || b.color || '#64748b'
    cats.push({ label: cat.categoryName, color: mixWhite(catColor, catPct), start: rows.length, count: catRows })
    cat.subcategories.forEach(function (sub, si) {
      var subColor = sub.color || catColor
      var subEn = energyMode ? ((res.subEnergies[cat.categoryName] || {})[subKeys[si]]) : null
      var subList = list.slice(idx, idx + sub.scenarioCount).filter(function (x) { return x })
      var subRank = energyMode
        ? (subEn !== null && subEn !== undefined ? res.thresholds.filter(function (x) { return subEn >= x }).length : 0)
        : Math.round(subList.reduce(function (a, s) { return a + BC.rankOf(s.score, s.rankMaxes).baseRank }, 0) / Math.max(1, subList.length))
      var groupColor = subRank > 0 ? Fmt.rankColor(BC.rankEntry(subRank, b), subRank) : null
      var blockStart = rows.length
      for (var k = 0; k < sub.scenarioCount; k++, idx++) {
        var s = list[idx]
        if (!s) continue
        var r = BC.rankOf(s.score, s.rankMaxes)
        var cur = Fmt.rankColor(BC.rankEntry(r.baseRank, b), r.baseRank)
        var fill = r.baseRank > 0 ? shade(cur) : '#71717a'
        var top = (s.rankMaxes || [])[(s.rankMaxes || []).length - 1]
        var pct = !s.score ? '' : r.isMaxed ? (ts.uncappedProgress && top ? '+' + Math.round((s.score / top - 1) * 100) + '%' : '100%') : Math.round(r.progressToNext * 100) + '%'
        var thr = []
        for (var t = 0; t < nThresh; t++) {
          var tv = (s.rankMaxes || [])[t]
          if (tv === undefined || tv === null) { thr.push(null); continue }
          var prev = t > 0 ? s.rankMaxes[t - 1] : 0
          var f = s.score >= tv ? 1 : s.score > prev ? (s.score - prev) / (tv - prev) : 0
          if (ts.progress === 'simple' && f < 1) f = 0
          thr.push({ text: Fmt.fmtScore(tv), color: mixWhite(rankCol[t], thrPct), f: f, fill: ts.rankColumnColors ? shade(rankCol[t]) : fill })
        }
        rows.push({
          name: s.name, display: s.customName || (ts.simplifyNames ? simplifyName(s.name, b) : s.name),
          score: s.score, scoreText: s.score ? Fmt.fmtScore(s.score) : '—', scoreColor: s.score ? mixWhite(cur, scorePct) : null,
          custom: s.customScore !== undefined && s.customScore !== null, pct: pct,
          pos: s.leaderboardRank ? '#' + Number(s.leaderboardRank).toLocaleString() : '—', thr: thr, unplayed: !s.score, lastSub: k === sub.scenarioCount - 1
        })
      }
      subs.push({ label: sub.subcategoryName || '', color: mixWhite(subColor, catPct), start: blockStart, count: rows.length - blockStart,
                  groupColor: groupColor,
                  energy: energyMode ? { text: subEn !== null && subEn !== undefined ? Fmt.fmtScore(subEn) : '–',
                                         color: subEn ? mixWhite(Fmt.rankColor(BC.rankEntry(res.thresholds.filter(function (x) { return subEn >= x }).length, b), res.thresholds.filter(function (x) { return subEn >= x }).length), energyPct) : null } : null })
    })
  })
  return { heads: heads, rows: rows, cats: cats, subs: subs, nThresh: nThresh, energyMode: energyMode, rowH: DENSITY[ts.density] || 31, ts: ts }
}

/** Applies what-if scores typed into the table. `customs` maps scenario name → value. */
function withCustoms(b, customs) {
  return Object.assign({}, b, { categories: b.categories.map(function (c) {
    return Object.assign({}, c, { scenarios: c.scenarios.map(function (s) {
      return customs.hasOwnProperty(s.name) ? Object.assign({}, s, { customScore: customs[s.name] }) : s
    }) })
  }) })
}
