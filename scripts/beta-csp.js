/**
 * Content-Security-Policy pentru shelfshare.ro / beta.shelfshare.ro.
 *
 * Token-urile de sesiune stau în localStorage, deci ORICE script străin rulat
 * pe pagină înseamnă preluarea contului. React escapează textul, iar paginile
 * pre-randate trec prin escapeHtml/jsonForScript, dar un CSP e plasa de sub
 * ele: chiar dacă mâine scapă un titlu neescapat, browserul refuză scriptul.
 *
 * Doar prin header, de la serverul ăsta: aplicația de Android (Capacitor)
 * își încarcă fișierele local și nu e atinsă.
 *
 * Ce trebuie să meargă:
 * - scriptul inline din index.html (tema, înainte de primul paint) - prin
 *   hash, calculat din fișierul servit, ca un build nou să nu-l rupă;
 * - API-ul (fetch + socket.io pe WebSocket), de la adresa din build-info.json;
 * - harta: stilurile și plăcile OpenFreeMap, workerul MapLibre din /assets;
 * - Google Analytics, încărcat abia după consimțământ (lib/analytics);
 * - coperțile, de pe o mulțime de gazde (Open Library, Google, anticariate,
 *   stocarea noastră) - imaginile nu rulează cod, deci `https:` e suficient.
 *
 * JSON-LD-ul (`application/ld+json`) nu e script executabil, deci nu intră
 * sub `script-src` și nu are nevoie de hash.
 */
const crypto = require('crypto');
const fs = require('fs');
const path = require('path');

const DEFAULT_API = 'https://api.shelfshare.ro';

const GOOGLE_ANALYTICS = [
  'https://*.googletagmanager.com',
  'https://*.google-analytics.com',
  'https://*.analytics.google.com',
  'https://*.g.doubleclick.net',
  'https://*.google.com',
];

const MAP_TILES = 'https://tiles.openfreemap.org';

/** Hash-urile scripturilor inline EXECUTABILE din HTML (fără src, tip JS). */
function inlineScriptHashes(html) {
  const hashes = [];
  const pattern = /<script(\s[^>]*)?>([\s\S]*?)<\/script\s*>/gi;
  let match;
  while ((match = pattern.exec(html)) !== null) {
    const attrs = match[1] ?? '';
    if (/\ssrc\s*=/i.test(attrs)) continue;
    const type = /\stype\s*=\s*["']?([^"'\s>]+)/i.exec(attrs)?.[1]?.toLowerCase();
    if (type && type !== 'module' && type !== 'text/javascript') continue;
    // Parserul HTML transformă CRLF în LF înainte ca browserul să calculeze
    // hash-ul, deci îl calculăm pe textul normalizat la fel.
    const text = match[2].replace(/\r\n?/g, '\n');
    const digest = crypto.createHash('sha256').update(text, 'utf8').digest('base64');
    hashes.push(`'sha256-${digest}'`);
  }
  return hashes;
}

function apiSources(apiBaseUrl) {
  let api;
  try {
    api = new URL(apiBaseUrl || DEFAULT_API);
  } catch {
    api = new URL(DEFAULT_API);
  }
  const ws = new URL(api.origin);
  ws.protocol = api.protocol === 'http:' ? 'ws:' : 'wss:';
  return [api.origin, ws.origin];
}

function buildCsp(indexHtml, apiBaseUrl) {
  const directives = {
    'default-src': ["'self'"],
    'script-src': ["'self'", ...inlineScriptHashes(indexHtml), 'https://*.googletagmanager.com'],
    // `unsafe-inline` doar pentru stiluri: Leaflet/MapLibre și câteva
    // componente scriu atribute `style`. Un stil nu poate rula cod.
    'style-src': ["'self'", "'unsafe-inline'"],
    'img-src': ["'self'", 'data:', 'blob:', 'https:'],
    'font-src': ["'self'", 'data:'],
    'connect-src': ["'self'", ...apiSources(apiBaseUrl), MAP_TILES, ...GOOGLE_ANALYTICS],
    'worker-src': ["'self'", 'blob:'],
    'manifest-src': ["'self'"],
    'frame-src': ["'none'"],
    'object-src': ["'none'"],
    'base-uri': ["'self'"],
    'form-action': ["'self'"],
    'frame-ancestors': ["'none'"],
  };
  return Object.entries(directives)
    .map(([name, values]) => `${name} ${values.join(' ')}`)
    .join('; ');
}

/**
 * CSP-ul pentru folderul servit, recalculat doar când se schimbă index.html
 * (un deploy nou). Dacă fișierele lipsesc sau nu se pot citi, rămâne ultima
 * valoare bună - iar înainte de prima, una fără hash-uri, care blochează doar
 * scriptul de temă, nu aplicația.
 */
function createCspProvider(root) {
  let cachedMtime = null;
  let cached = buildCsp('', DEFAULT_API);
  return function contentSecurityPolicy() {
    try {
      const indexPath = path.join(root, 'index.html');
      const { mtimeMs } = fs.statSync(indexPath);
      if (mtimeMs !== cachedMtime) {
        const html = fs.readFileSync(indexPath, 'utf8');
        let apiBaseUrl = DEFAULT_API;
        try {
          apiBaseUrl =
            JSON.parse(fs.readFileSync(path.join(root, 'build-info.json'), 'utf8')).apiBaseUrl ||
            DEFAULT_API;
        } catch {
          /* build vechi, fără build-info.json */
        }
        cached = buildCsp(html, apiBaseUrl);
        cachedMtime = mtimeMs;
      }
    } catch {
      /* păstrăm ultima valoare */
    }
    return cached;
  };
}

module.exports = { buildCsp, createCspProvider, inlineScriptHashes };
