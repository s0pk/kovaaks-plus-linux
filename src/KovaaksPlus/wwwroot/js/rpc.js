// Bridge to the native host (JSON-RPC style): Photino's message channel, or a WebSocket when the UI runs in a Chromium window.
const pending = new Map();
const listeners = new Map();
let nextId = 1;
const photino = window.external && typeof window.external.sendMessage === 'function';
// Chromium host: JSON-RPC over a WebSocket to the app. The per-run token comes in the URL the app opened.
const token = photino ? null : (new URLSearchParams(location.search).get('t') || sessionStorage.getItem('kplus-t'));
if (token) { try { sessionStorage.setItem('kplus-t', token); } catch { } }
const host = photino || token ? true : null;

function dispatch(raw) {
  let msg = raw;
  if (typeof raw === 'string') { try { msg = JSON.parse(raw); } catch { return; } }
  if (msg && msg.event) {
    (listeners.get(msg.event) || []).forEach((fn) => { try { fn(msg.data); } catch (err) { console.error(err); } });
    (listeners.get('*') || []).forEach((fn) => fn(msg.event, msg.data));
    return;
  }
  const p = pending.get(msg.id);
  if (!p) return;
  pending.delete(msg.id);
  if (msg.error) p.reject(new Error(msg.error)); else p.resolve(msg.result);
}

let sendRaw;
if (photino) {
  window.external.receiveMessage(dispatch);
  sendRaw = (text) => window.external.sendMessage(text);
} else if (token) {
  const queue = [];
  const ws = new WebSocket(`ws://${location.host}/ws?t=${encodeURIComponent(token)}`);
  ws.onopen = () => queue.splice(0).forEach((m) => ws.send(m));
  ws.onmessage = (e) => dispatch(e.data);
  sendRaw = (text) => (ws.readyState === 1 ? ws.send(text) : queue.push(text));
}

export function call(method, params = {}) {
  if (!host) return Promise.reject(new Error('Not running inside Kovaak\'s Plus'));
  const id = nextId++;
  return new Promise((resolve, reject) => {
    pending.set(id, { resolve, reject });
    sendRaw(JSON.stringify({ id, method, params }));
  });
}

export function on(event, fn) {
  if (!listeners.has(event)) listeners.set(event, []);
  listeners.get(event).push(fn);
  return () => listeners.set(event, listeners.get(event).filter((f) => f !== fn));
}

// Links to other sites open in the desktop browser; the app window itself never navigates away from the UI.
document.addEventListener('click', (e) => {
  const a = e.target instanceof Element ? e.target.closest('a[href]') : null;
  if (!a) return;
  const href = a.getAttribute('href') || '';
  if (/^https?:\/\//i.test(href) && !href.startsWith(location.origin + '/')) {
    e.preventDefault();
    call('app.openUrl', { url: href }).catch(() => { });
  }
}, true);
