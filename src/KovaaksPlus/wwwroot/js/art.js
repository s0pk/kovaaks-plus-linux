// Generated scenario art. Instead of a random gradient, a tile says what kind of scenario it is:
// the name, KovaaK's own tags and the user's tags place it in an aim family, and each family has one fixed hue
// and its own drawn motif (scattered targets, a tracking trail, a switching path…). The details of the drawing are
// seeded by the scenario name, so siblings in a family look related but never identical.

const NS = 'http://www.w3.org/2000/svg';
const el = (tag, attrs = {}, cls) => {
  const e = document.createElementNS(NS, tag);
  for (const [k, v] of Object.entries(attrs)) e.setAttribute(k, v);
  if (cls) e.setAttribute('class', cls);
  return e;
};

/** Hues are OKLCH angles; lightness and chroma are shared so no family shouts louder than another. */
export const FAMILIES = {
  tracking: { label: 'Tracking', hue: 200 },
  clicking: { label: 'Clicking', hue: 35 },
  switching: { label: 'Switching', hue: 305 },
  movement: { label: 'Movement', hue: 150 },
  control: { label: 'Control', hue: 255 },
  other: { label: 'Scenario', hue: 90, chroma: 0.015 },
};

// Checked in order; the first match wins.
const RULES = [
  ['movement', /strafe|dodge|movement|bhop|jump|airstrafe|\bmover\b/],
  ['switching', /switch|\bts\b|micro ?ts|evasive|multi.?target|target ?switch/],
  ['tracking', /track|smooth|reactive|precise|laser|plasma|follow|pasu|beam|ground ?plaza|air ?angel|goose/],
  ['control', /control|stability|stabili|steady|micro ?adjust|mouse ?control/],
  ['clicking', /click|flick|1 ?wall|3 ?wall|wall|grid|tile|pokeball|popcorn|bounce|reflex|180|360|sixshot|six ?shot|single.?shot|aimerz|aether|shot/],
];

export function classify(text) {
  const t = ' ' + String(text || '').toLowerCase() + ' ';
  for (const [family, rx] of RULES) if (rx.test(t)) return family;
  return 'other';
}

function hash(str) {
  let h = 2166136261;
  for (let i = 0; i < str.length; i++) { h ^= str.charCodeAt(i); h = Math.imul(h, 16777619); }
  return h >>> 0;
}

function rng(seed) {
  let a = seed >>> 0;
  return () => {
    a = (a + 0x6D2B79F5) | 0;
    let t = Math.imul(a ^ (a >>> 15), 1 | a);
    t = (t + Math.imul(t ^ (t >>> 7), 61 | t)) ^ t;
    return ((t ^ (t >>> 14)) >>> 0) / 4294967296;
  };
}

// ---- motifs: drawn on a 160 × 90 canvas; the lower-left corner is kept clear for the scenario's name ----
const target = (g, x, y, r, hot = false) => {
  g.append(el('circle', { cx: x, cy: y, r }, 'a'));
  g.append(el('circle', { cx: x, cy: y, r: Math.max(1.4, r * 0.28) }, 'af'));
  if (hot) {
    const o = r + 4, l = r + 10;
    for (const [dx, dy] of [[1, 0], [-1, 0], [0, 1], [0, -1]])
      g.append(el('line', { x1: x + dx * o, y1: y + dy * o, x2: x + dx * l, y2: y + dy * l }, 'a'));
  }
};

const MOTIFS = {
  clicking(g, r) {
    const spots = [];
    for (let tries = 0; spots.length < 6 && tries < 60; tries++) {
      const x = 22 + r() * 118, y = 20 + r() * 40;
      if (spots.every(([sx, sy]) => Math.hypot(sx - x, sy - y) > 24)) spots.push([x, y]);
    }
    spots.forEach(([x, y], i) => target(g, x, y, i === 0 ? 8 : 5 + r() * 3, i === 0));
  },
  tracking(g, r) {
    const y0 = 40 + r() * 18, y1 = 22 + r() * 22, amp = 14 + r() * 12;
    const x0 = 16, x1 = 128 + r() * 10;
    const d = `M ${x0} ${y0} C ${x0 + 38} ${y0 - amp * 2}, ${x1 - 44} ${y1 + amp * 2}, ${x1} ${y1}`;
    g.append(el('path', { d }, 'b dash'));
    g.append(el('path', { d, 'stroke-dasharray': '0.1 5', 'stroke-linecap': 'round' }, 'a'));
    target(g, x1, y1, 7, true);
  },
  switching(g, r) {
    const pts = [[26 + r() * 10, 50 + r() * 6], [74 + r() * 12, 26 + r() * 8], [122 + r() * 12, 46 + r() * 10]];
    pts.forEach(([x, y], i) => {
      if (i) g.append(el('line', { x1: pts[i - 1][0] + 9, y1: pts[i - 1][1], x2: x - 9, y2: y }, 'b dash'));
      target(g, x, y, i === 1 ? 7 : 5.5, i === 1);
    });
  },
  movement(g, r) {
    const y = 34 + r() * 10;
    for (let i = 0; i < 5; i++) {
      const x = 30 + i * 18;
      g.append(el('path', { d: `M ${x} ${y - 7} L ${x + 8} ${y} L ${x} ${y + 7}` }, i < 3 ? 'a' : 'b'));
    }
    g.append(el('line', { x1: 14, y1: y + 18, x2: 146, y2: y + 18 }, 'b'));
    target(g, 126 + r() * 14, y, 6, false);
  },
  control(g, r) {
    const cx = 104 + r() * 10, cy = 36 + r() * 8;
    g.append(el('circle', { cx, cy, r: 24 }, 'b dash'));
    let d = '';
    for (let i = 0; i <= 40; i++) {
      const t = i / 40, a = t * Math.PI * 5 + r() * 0.05, rad = 22 * (1 - t * 0.85);
      d += `${i ? 'L' : 'M'} ${(cx + Math.cos(a) * rad).toFixed(1)} ${(cy + Math.sin(a) * rad).toFixed(1)} `;
    }
    g.append(el('path', { d }, 'a'));
    target(g, cx, cy, 4.5, true);
  },
  other(g) {
    const cx = 108, cy = 38;
    g.append(el('circle', { cx, cy, r: 20 }, 'b'));
    g.append(el('circle', { cx, cy, r: 3 }, 'af'));
    for (const [dx, dy] of [[1, 0], [-1, 0], [0, 1], [0, -1]]) g.append(el('line', { x1: cx + dx * 14, y1: cy + dy * 14, x2: cx + dx * 30, y2: cy + dy * 30 }, 'a'));
  },
};

/**
 * Builds the art for a scenario. `info` is any extra text that describes it (KovaaK's tags, the user's tag names);
 * `tagColor` is a user-chosen colour that overrides the family hue.
 */
export function makeArt(name, info = '', tagColor = null) {
  // The name is the strongest signal ("1wall 6targets" is clicking even if its tags mention mouse control); tags fill the gaps.
  let family = classify(name);
  if (family === 'other') family = classify(info);
  const f = FAMILIES[family];
  const accent = tagColor || `oklch(0.80 ${f.chroma ?? 0.105} ${f.hue})`;
  const svg = el('svg', { viewBox: '0 0 160 90', preserveAspectRatio: 'xMidYMid slice' }, 'art');
  svg.append(el('rect', { x: 0, y: 0, width: 160, height: 90, fill: 'url(#none)', opacity: 0 }));
  const g = el('g');
  MOTIFS[family](g, rng(hash(name)));
  svg.append(g);
  const base = '#131412';
  return {
    family,
    svg,
    accent,
    bg: `linear-gradient(160deg, color-mix(in oklab, ${accent} 22%, ${base}), color-mix(in oklab, ${accent} 8%, ${base}))`,
  };
}
