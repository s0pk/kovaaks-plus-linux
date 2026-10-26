.pragma library
// Filtering, searching and sorting of the scenario library (ported from views/library.js).

var QUICK = [
  { id: 'all', label: 'All scenarios', icon: 'layers' },
  { id: 'fav', label: 'Favorites', icon: 'star' },
  { id: 'recent', label: 'Played this week', icon: 'clock' },
  { id: 'never', label: 'Never played', icon: 'target' },
  { id: 'untagged', label: 'Untagged', icon: 'tag' },
  { id: 'bench', label: 'In a benchmark', icon: 'trophy' },
  { id: 'hidden', label: 'Hidden', icon: 'eyeOff' }
]

var SORTS = [
  { value: 'recent', label: 'Recently played' }, { value: 'name', label: 'Name (A–Z)' }, { value: 'plays', label: 'Most played' },
  { value: 'pb', label: 'Recent PBs' }, { value: 'added', label: 'First played' }, { value: 'tag', label: 'Tag (A–Z)' },
  { value: 'tagorder', label: 'Tag (panel order)' }
]

var SOURCES = [
  { value: 'any', label: 'Everything' }, { value: 'local', label: 'Local files' }, { value: 'workshop', label: 'Steam Workshop' },
  { value: 'missing', label: 'Played, not installed' }
]

function defaultUi() { return { tags: [], quick: 'all', tagMode: 'any', search: '', source: 'any', bench: null } }

/** Natural, case-insensitive comparison ("Scenario 2" < "Scenario 10"). */
function natCompare(a, b) {
  a = String(a || '').toLowerCase(); b = String(b || '').toLowerCase()
  var ra = a.match(/(\d+|\D+)/g) || [], rb = b.match(/(\d+|\D+)/g) || []
  for (var i = 0; i < Math.min(ra.length, rb.length); i++) {
    var x = ra[i], y = rb[i]
    if (x === y) continue
    var nx = /^\d/.test(x), ny = /^\d/.test(y)
    if (nx && ny) { var d = parseInt(x, 10) - parseInt(y, 10); if (d) return d } else return x < y ? -1 : 1
  }
  return ra.length - rb.length
}

function dn(s) { return s.customName || s.name || '' }
function time(d) { return d ? new Date(d).getTime() : 0 }

function groupsOf(tags, groups) {
  var g = groups.slice()
  tags.forEach(function (t) { if (g.indexOf(t.group) < 0) g.push(t.group) })
  return g
}
/** Panel order of all tags (groups in panel order, tags in list order). */
function panelOrder(tags, groups) {
  var out = []
  groupsOf(tags, groups).forEach(function (g) { tags.forEach(function (t) { if (t.group === g) out.push(t) }) })
  return out
}

function baseFilter(s, quick) {
  if (quick !== 'hidden' && s.hidden) return false
  switch (quick) {
    case 'fav': return !!s.favorite
    case 'recent': return !!s.lastPlayed && Date.now() - new Date(s.lastPlayed) < 7 * 86400000
    case 'never': return !s.plays
    case 'untagged': return !s.tags.length
    case 'bench': return !!(s.benchmarks && s.benchmarks.length)
    case 'hidden': return !!s.hidden
  }
  return true
}

function sourceFilter(s, source, showUninstalled) {
  if (source === 'local') return s.installed && s.source === 'local'
  if (source === 'workshop') return s.source === 'workshop'
  if (source === 'missing') return !s.installed
  return showUninstalled !== false || s.installed
}

function tagName(tags, id) { for (var i = 0; i < tags.length; i++) if (tags[i].id === id) return tags[i].name; return null }

function tagKeyAZ(s, tags) {
  var names = s.tags.map(function (id) { return tagName(tags, id) }).filter(function (x) { return x }).sort(natCompare)
  return names.length ? names[0] : null
}
function tagRank(s, rank) {
  var r = s.tags.map(function (id) { return rank[id] }).filter(function (x) { return x !== undefined })
  return r.length ? Math.min.apply(null, r) : 1e9
}

/** The visible, sorted list for the current filters. */
function compute(scenarios, tags, groups, config, ui, sortBy) {
  var q = (ui.search || '').trim().toLowerCase()
  var terms = q ? q.split(/\s+/) : []
  var list = scenarios.filter(function (s) { return sourceFilter(s, ui.source, config.showUninstalled) && baseFilter(s, ui.quick) })
  if (ui.bench) list = list.filter(function (s) { return s.benchmarks && s.benchmarks.indexOf(ui.bench) >= 0 })
  if (ui.tags.length) {
    list = list.filter(function (s) {
      return ui.tagMode === 'all'
        ? ui.tags.every(function (t) { return s.tags.indexOf(t) >= 0 })
        : ui.tags.some(function (t) { return s.tags.indexOf(t) >= 0 })
    })
  }
  if (terms.length) {
    list = list.filter(function (s) {
      var hay = [s.name, s.customName, s.author].concat(s.tags.map(function (id) { return tagName(tags, id) })).filter(function (x) { return x }).join(' ').toLowerCase()
      return terms.every(function (t) { return hay.indexOf(t) >= 0 })
    })
  }
  var rank = {}
  panelOrder(tags, groups).forEach(function (t, i) { rank[t.id] = i })
  var byName = function (a, b) { return natCompare(dn(a), dn(b)) }
  var cmp = {
    recent: function (a, b) { return time(b.lastPlayed) - time(a.lastPlayed) || byName(a, b) },
    name: byName,
    plays: function (a, b) { return (b.plays || 0) - (a.plays || 0) },
    pb: function (a, b) { return time(b.pbDate) - time(a.pbDate) },
    added: function (a, b) { return time(b.firstPlayed) - time(a.firstPlayed) },
    tag: function (a, b) {
      var x = tagKeyAZ(a, tags), y = tagKeyAZ(b, tags)
      var c = x === y ? 0 : x === null ? 1 : y === null ? -1 : natCompare(x, y)
      return c || byName(a, b)
    },
    tagorder: function (a, b) { return (tagRank(a, rank) - tagRank(b, rank)) || byName(a, b) }
  }[sortBy] || byName
  return list.sort(cmp)
}

/** Section heading for tag sorts: the scenario's primary tag (or null = untagged); undefined when not sorting by tag. */
function sectionOf(s, tags, groups, sortBy) {
  if (sortBy === 'tag') { var n = tagKeyAZ(s, tags); if (!n) return null; for (var i = 0; i < tags.length; i++) if (tags[i].name === n) return tags[i]; return null }
  if (sortBy === 'tagorder') {
    var order = panelOrder(tags, groups), rank = {}
    order.forEach(function (t, i) { rank[t.id] = i })
    var r = tagRank(s, rank)
    return r < 1e9 ? order[r] : null
  }
  return undefined
}

function quickCount(scenarios, config, ui, id) {
  var n = 0
  for (var i = 0; i < scenarios.length; i++) if (sourceFilter(scenarios[i], ui.source, config.showUninstalled) && baseFilter(scenarios[i], id)) n++
  return n
}

function tagCounts(scenarios, config, ui) {
  var counts = {}
  scenarios.forEach(function (s) {
    if (!sourceFilter(s, ui.source, config.showUninstalled) || !baseFilter(s, ui.quick)) return
    s.tags.forEach(function (t) { counts[t] = (counts[t] || 0) + 1 })
  })
  return counts
}

/** Tag click: only this tag (click again to clear), Ctrl = add/remove, Shift = range in panel order. */
function selectTag(ui, lastClicked, t, ctrl, shift, tags, groups) {
  var sel = ui.tags.slice()
  if (ctrl) sel = sel.indexOf(t.id) >= 0 ? sel.filter(function (x) { return x !== t.id }) : sel.concat([t.id])
  else if (shift && lastClicked) {
    var order = panelOrder(tags, groups).map(function (x) { return x.id })
    var a = order.indexOf(lastClicked), b = order.indexOf(t.id)
    sel = a >= 0 && b >= 0 ? order.slice(Math.min(a, b), Math.max(a, b) + 1) : [t.id]
  } else sel = sel.length === 1 && sel[0] === t.id ? [] : [t.id]
  return sel
}

/** Every filter currently narrowing the list, as chips ({label, color, clear: key}). */
function activeFilters(ui, tags, benchNames) {
  var list = []
  var q = QUICK.filter(function (x) { return x.id === ui.quick })[0]
  if (ui.quick !== 'all' && q) list.push({ label: q.label, kind: 'quick' })
  ui.tags.forEach(function (id) {
    var t = null
    for (var i = 0; i < tags.length; i++) if (tags[i].id === id) t = tags[i]
    list.push({ label: t ? 'Tag: ' + t.name : 'Missing tag', color: t ? t.color : '', kind: 'tag', id: id })
  })
  if (ui.tags.length > 1) list.push({ label: ui.tagMode === 'all' ? 'Match all tags' : 'Match any tag', kind: 'mode' })
  if (ui.source !== 'any') list.push({ label: { local: 'Local files', workshop: 'Steam Workshop', missing: 'Played, not installed' }[ui.source], kind: 'source' })
  if ((ui.search || '').trim()) list.push({ label: 'Search: "' + ui.search.trim() + '"', kind: 'search' })
  if (ui.bench) {
    var b = (benchNames || {})[ui.bench]
    list.push({ label: 'Benchmark: ' + (b ? b.name + (b.difficulty ? ' ' + b.difficulty : '') : ui.bench), color: '#eab308', kind: 'bench' })
  }
  return list
}
