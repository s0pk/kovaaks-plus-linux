.pragma library
// Formatting helpers (the QML engine has no Intl, so these are written out by hand).

var MONTHS = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec']

function group(intPart) { return String(intPart).replace(/\B(?=(\d{3})+(?!\d))/g, ',') }

function fmtScore(v) {
  if (v === null || v === undefined || isNaN(v)) return '—'
  var abs = Math.abs(v)
  var digits = abs >= 1000 ? 0 : abs >= 100 ? 1 : 2
  var s = Number(v).toFixed(digits)
  if (s.indexOf('.') >= 0) s = s.replace(/0+$/, '').replace(/\.$/, '')
  var neg = s.charAt(0) === '-'
  if (neg) s = s.slice(1)
  var parts = s.split('.')
  return (neg ? '-' : '') + group(parts[0]) + (parts[1] ? '.' + parts[1] : '')
}
function fmtInt(v) { return v === null || v === undefined || isNaN(v) ? '—' : group(Math.round(v)) }
function fmtPct(v, d) { return v === null || v === undefined || isNaN(v) ? '—' : (v * 100).toFixed(d === undefined ? 1 : d) + '%' }
function fmtDuration(sec) {
  if (!sec) return '0m'
  var h = Math.floor(sec / 3600), m = Math.round((sec % 3600) / 60)
  return h ? h + 'h ' + m + 'm' : m + 'm'
}
function fmtDate(d) {
  if (!d) return '—'
  var dt = new Date(d)
  var s = dt.getDate() + ' ' + MONTHS[dt.getMonth()]
  return dt.getFullYear() === new Date().getFullYear() ? s : s + ' ' + dt.getFullYear()
}
function pad(n) { return n < 10 ? '0' + n : '' + n }
function fmtDateTime(d) {
  var dt = new Date(d)
  return dt.getDate() + ' ' + MONTHS[dt.getMonth()] + ' ' + pad(dt.getHours()) + ':' + pad(dt.getMinutes())
}
function timeAgo(d) {
  if (!d) return 'never'
  var s = (Date.now() - new Date(d).getTime()) / 1000
  if (s < 60) return 'just now'
  if (s < 3600) return Math.floor(s / 60) + 'm ago'
  if (s < 86400) return Math.floor(s / 3600) + 'h ago'
  if (s < 86400 * 30) return Math.floor(s / 86400) + 'd ago'
  if (s < 86400 * 365) return Math.floor(s / (86400 * 30)) + 'mo ago'
  return Math.floor(s / (86400 * 365)) + 'y ago'
}
function isToday(d) {
  if (!d) return false
  var a = new Date(d), b = new Date()
  return a.getFullYear() === b.getFullYear() && a.getMonth() === b.getMonth() && a.getDate() === b.getDate()
}
function fmtSens(r) { return r && r.sens ? (Math.round(r.sens * 100) / 100 + ' ' + (r.sensScale || '')).trim() : '—' }

// Benchmark prefixes and season/difficulty suffixes don't identify a scenario ("VT", "S5", "Novice"…).
var NOISE = /^(vt|vts|ra|cb|ww|kvks|s\d+|\d+%?|novice|intermediate|advanced|easy|medium|hard|elite|master|beginner|the|and|of|-)$/i

/** The most distinctive word of a scenario name, shown on generated thumbnails ("VT DotTS Novice S5" → "DotTS"). */
function keyWord(name) {
  var words = String(name).replace(/[()[\]{}]/g, ' ').split(/\s+/).filter(function (x) { return x })
  var w = words.filter(function (x) { return !NOISE.test(x) })[0] || words[0] || '?'
  return w.length > 10 ? w.slice(0, 9) + '…' : w
}

// KovaaK's often reports every rank colour as #ffffff, so fall back to well-known benchmark rank colours.
var RANK_COLORS = {
  iron: '#9ca3af', bronze: '#d08a4c', silver: '#cbd5e1', gold: '#fbbf24', platinum: '#5eead4', diamond: '#60a5fa',
  jade: '#34d399', master: '#f472b6', grandmaster: '#f43f5e', nova: '#a78bfa', astra: '#e879f9', celestial: '#fde68a'
}
var RANK_PALETTE = ['#6b7280', '#9ca3af', '#d08a4c', '#cbd5e1', '#fbbf24', '#5eead4', '#60a5fa', '#34d399', '#f472b6', '#f43f5e', '#a78bfa', '#e879f9', '#fde68a']
function rankColor(rank, index) {
  if (rank && rank.color && !/^#?f{6}$/i.test(rank.color)) return rank.color
  var key = ((rank && rank.name) || '').toLowerCase().replace(/[^a-z]/g, '')
  for (var k in RANK_COLORS) if (key.indexOf(k) === 0) return RANK_COLORS[k]
  return RANK_PALETTE[Math.min(index || 0, RANK_PALETTE.length - 1)]
}

function mediaPath(name) {
  if (!name) return ''
  return '/media/' + name.split('/').map(encodeURIComponent).join('/')
}
