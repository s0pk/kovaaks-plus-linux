// Appearance: themes, colours, fonts, scale, density… stored in config.ui.appearance and applied as CSS variables/classes.
// Every theme is defined by six base colours; the in-between shades are derived, so custom themes stay consistent.
import { call } from './rpc.js';
import { state } from './state.js';

export const BASE_KEYS = [
  ['bg', 'Background'], ['surface', 'Panels'], ['border', 'Borders'], ['text', 'Text'], ['muted', 'Muted text'], ['sidebar', 'Sidebar'],
];

export const THEMES = {
  range: { label: 'Range', colors: { bg: '#141513', surface: '#1b1c1a', border: '#2d2f2b', text: '#ece8de', muted: '#8d9085', sidebar: '#10110f' } },
  midnight: { label: 'Midnight', colors: { bg: '#0b0d12', surface: '#141821', border: '#252b3a', text: '#e8eaf0', muted: '#7d859a', sidebar: '#0d1016' } },
  oled: { label: 'OLED black', colors: { bg: '#000000', surface: '#0c0d10', border: '#1c1e25', text: '#ececf1', muted: '#7a8193', sidebar: '#000000' } },
  graphite: { label: 'Graphite', colors: { bg: '#121212', surface: '#1c1c1c', border: '#2e2e2e', text: '#ededed', muted: '#8a8a8a', sidebar: '#141414' } },
  slate: { label: 'Slate blue', colors: { bg: '#0f172a', surface: '#16213a', border: '#26324f', text: '#e8edf7', muted: '#7d8aa8', sidebar: '#0c1424' } },
  nord: { label: 'Nord', colors: { bg: '#1f2430', surface: '#2a3140', border: '#3b4252', text: '#eceff4', muted: '#8f9bb3', sidebar: '#1b202b' } },
  plum: { label: 'Plum', colors: { bg: '#140d1a', surface: '#1f1428', border: '#33243f', text: '#f1eaf7', muted: '#937fa8', sidebar: '#110b16' } },
  forest: { label: 'Forest', colors: { bg: '#0b120e', surface: '#131d17', border: '#223328', text: '#e6f0e9', muted: '#7c9585', sidebar: '#09100c' } },
};

export const FONTS = {
  system: { label: 'Range (default)', text: '"Instrument Sans", system-ui, "Segoe UI", sans-serif', display: '"Big Shoulders Display", "Instrument Sans", system-ui, sans-serif' },
  segoe: { label: 'Segoe UI', text: '"Segoe UI Variable Text", "Segoe UI", system-ui, sans-serif', display: '"Segoe UI Variable Display", "Segoe UI", system-ui, sans-serif' },
  bahnschrift: { label: 'Bahnschrift', text: 'Bahnschrift, "Segoe UI", sans-serif', display: 'Bahnschrift, "Segoe UI", sans-serif' },
  trebuchet: { label: 'Trebuchet MS', text: '"Trebuchet MS", "Segoe UI", sans-serif', display: '"Trebuchet MS", "Segoe UI", sans-serif' },
  verdana: { label: 'Verdana', text: 'Verdana, "Segoe UI", sans-serif', display: 'Verdana, "Segoe UI", sans-serif' },
  consolas: { label: 'Consolas (mono)', text: 'Consolas, "Cascadia Mono", monospace', display: 'Consolas, "Cascadia Mono", monospace' },
};

export const APPEARANCE_DEFAULTS = {
  theme: 'range', accent2: '#8fb8b0', custom: {}, userThemes: [], font: 'system', scale: 100, radius: 'rounded', radiusPx: 4,
  density: 'comfortable', cardSize: 'medium', glow: false, motion: true, dimOld: true, pbGradient: true, hoverPreview: true,
};

export const DEFAULT_ACCENT = '#ece8de';

/** Text colour that stays readable on top of a given background (dark ink on light accents, white on dark ones). */
export function onColor(hex) {
  const m = /^#?([0-9a-f]{2})([0-9a-f]{2})([0-9a-f]{2})$/i.exec(hex || '');
  if (!m) return '#141513';
  const [r, g, b] = [m[1], m[2], m[3]].map((x) => parseInt(x, 16) / 255).map((c) => (c <= 0.03928 ? c / 12.92 : ((c + 0.055) / 1.055) ** 2.4));
  return 0.2126 * r + 0.7152 * g + 0.0722 * b > 0.4 ? '#141513' : '#ffffff';
}

export function appearance() {
  const a = { ...APPEARANCE_DEFAULTS, ...((state.config.ui || {}).appearance || {}) };
  if (a.radius === 'default' || a.radius === 'round') { a.radiusPx = a.radius === 'round' ? 18 : 12; a.radius = 'rounded'; }   // older settings
  a.custom = a.custom || {};
  a.userThemes = a.userThemes || [];
  return a;
}

export function themeById(id, a = appearance()) {
  if (THEMES[id]) return THEMES[id];
  const u = a.userThemes.find((t) => t.id === id);
  return u ? { label: u.name, colors: u.colors, user: true, accent: u.accent, accent2: u.accent2 } : THEMES.range;
}

/** The six base colours in effect: theme colours with any per-colour overrides on top. */
export function effectiveColors(a = appearance()) {
  return { ...themeById(a.theme, a).colors, ...a.custom };
}

export function applyAppearance() {
  const a = appearance();
  const c = effectiveColors(a);
  const root = document.documentElement.style;
  const mix = (x, y, p) => `color-mix(in srgb, ${x}, ${y} ${p}%)`;
  root.setProperty('--bg', c.bg);
  root.setProperty('--bg-2', mix(c.bg, c.surface, 40));
  root.setProperty('--surface', c.surface);
  root.setProperty('--surface-2', mix(c.surface, c.text, 4));
  root.setProperty('--surface-3', mix(c.surface, c.text, 9));
  root.setProperty('--border', c.border);
  root.setProperty('--border-2', mix(c.border, c.text, 10));
  root.setProperty('--text', c.text);
  root.setProperty('--text-2', mix(c.text, c.muted, 40));
  root.setProperty('--muted', c.muted);
  root.setProperty('--sidebar', c.sidebar || c.bg);
  const accent = state.config.accent || DEFAULT_ACCENT;
  root.setProperty('--accent', accent);
  root.setProperty('--on-accent', onColor(accent));
  root.setProperty('--accent-2', a.accent2 || '#8fb8b0');
  const font = FONTS[a.font] || FONTS.system;
  root.setProperty('--font', font.text);
  root.setProperty('--font-display', font.display);
  const r = a.radius === 'sharp' ? 3 : Math.max(2, Math.min(24, a.radiusPx || 12));
  root.setProperty('--radius', r + 'px');
  root.setProperty('--radius-sm', Math.round(r * 0.67) + 'px');
  root.setProperty('--card-min', { small: '190px', medium: '232px', large: '300px' }[a.cardSize] || '232px');
  const b = document.body.classList;
  ['density-compact', 'density-comfortable', 'density-spacious'].forEach((x) => b.remove(x));
  b.add('density-' + a.density);
  b.toggle('no-glow', !a.glow);
  b.toggle('no-motion', !a.motion);
  b.toggle('radius-sharp', a.radius === 'sharp');
  b.toggle('no-dim-old', !a.dimOld);
  b.toggle('no-pb-gradient', !a.pbGradient);
  call('app.setZoom', { factor: (a.scale || 100) / 100 }).catch(() => { });
}
