.pragma library
// Shared chart helpers (ported from charts.js and runs.js).

function niceTicks(min, max, count) {
  count = count || 4
  if (min === max) { min -= 1; max += 1 }
  var span = max - min
  var step0 = span / count
  var mag = Math.pow(10, Math.floor(Math.log(step0) / Math.LN10))
  var norm = step0 / mag
  var step = (norm >= 5 ? 10 : norm >= 2 ? 5 : norm >= 1 ? 2 : 1) * mag
  var lo = Math.floor(min / step) * step, hi = Math.ceil(max / step) * step
  var ticks = []
  for (var v = lo; v <= hi + step / 2; v += step) ticks.push(+v.toFixed(10))
  return { lo: lo, hi: hi, ticks: ticks }
}

function shortNum(v) {
  var a = Math.abs(v)
  return a >= 10000 ? (v / 1000).toFixed(0) + 'k' : a >= 1000 ? (v / 1000).toFixed(1) + 'k' : String(+v.toFixed(2))
}

/** Simple moving average. */
function movingAverage(values, n) {
  var out = [], sum = 0
  for (var i = 0; i < values.length; i++) {
    sum += values[i]
    if (i >= n) sum -= values[i - n]
    out.push(sum / Math.min(i + 1, n))
  }
  return out
}

/**
 * Rebuilds a run's timeline from the per-kill rows. Score uses the scenario's own rules
 * (kills × score-per-kill + damage × score-per-damage, × accuracy when the scenario multiplies by it),
 * scaled so the last point equals the real final score.
 */
function runTimeline(d) {
  var kills = d.kills || []
  var s = d.summary || {}
  var sc = d.scoring || {}
  var end = Math.max(s.fightTime > 5 ? s.fightTime : 0, sc.timeLimit || 0, kills.length ? kills[kills.length - 1].t || 0 : 0) || kills.length
  var k = 0, hits = 0, shots = 0, dmg = 0
  var pts = [{ t: 0, kills: 0, hits: 0, shots: 0, dmg: 0, raw: 0, ttk: null }]
  kills.forEach(function (e, i) {
    k++; hits += e.hits; shots += e.shots; dmg += e.damage || 0
    var acc = shots ? hits / shots : 1
    var raw = (sc.scorePerKill || 0) * k + (sc.scorePerDamage || 0) * dmg
    if (!sc.scorePerKill && !sc.scorePerDamage) raw = k
    if (sc.multAccuracy) raw *= acc
    pts.push({ t: e.t || (i + 1) * (end / Math.max(1, kills.length)), kills: k, hits: hits, shots: shots, dmg: dmg, raw: raw, ttk: e.ttk })
  })
  var last = pts[pts.length - 1]
  var scale = last.raw > 0 && s.score ? s.score / last.raw : 1
  pts.forEach(function (p) { p.score = p.raw * scale; p.acc = p.shots ? p.hits / p.shots : null })
  if (end > last.t) { var cp = {}; for (var key in last) cp[key] = last[key]; cp.t = end; cp.ttk = null; pts.push(cp) }
  return { pts: pts, end: end }
}

/** Change in `key` over the trailing window, per second (or per minute). */
function rate(pts, key, windowSec, perSec) {
  return pts.map(function (p, i) {
    var j = i
    while (j > 0 && p.t - pts[j - 1].t <= windowSec) j--
    var a = pts[j === i && i > 0 ? i - 1 : j]
    var dt = Math.max(0.5, p.t - a.t)
    return { x: p.t, y: ((p[key] - a[key]) / dt) * perSec }
  })
}

/** Rank lines and bands for a score chart: only thresholds around the scores are shown (see thresholds.js). */
function thresholdOverlay(b, scores, rankEntry, rankColor) {
  if (!b || !scores.length) return { hLines: [], bands: [] }
  var all = b.rankMaxes.map(function (v, i) {
    var e = rankEntry(i + 1, b)
    return { y: v, label: e.name + ' ' + Math.round(v).toLocaleString(), color: rankColor(e, i + 1), icon: e.icon, align: 'start', solid: true }
  })
  var min = Math.min.apply(null, scores), max = Math.max.apply(null, scores)
  var below = all.filter(function (l) { return l.y < min }).slice(-1)
  var inside = all.filter(function (l) { return l.y >= min && l.y <= max })
  var above = all.filter(function (l) { return l.y > max }).slice(0, 1)
  var shown = below.concat(inside, above)
  var bands = shown.map(function (l, k) { return { from: l.y, to: shown[k + 1] ? shown[k + 1].y : null, color: l.color } })
  return { hLines: shown, bands: bands }
}
