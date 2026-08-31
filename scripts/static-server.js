const http = require('http');
const https = require('https');
const fs = require('fs');
const path = require('path');
const crypto = require('crypto');

const root = path.join(__dirname, '..', 'frontend', 'build', 'web');
const port = 5959;
const siteUrl = 'https://shelfshare.ro';
const apiUrl = 'https://api.shelfshare.ro';

const STATIC_SITEMAP_ROUTES = [
  { path: '/', priority: '1.0' },
  { path: '/login', priority: '0.3' },
  { path: '/register', priority: '0.3' },
  { path: '/leaderboard', priority: '0.5' },
  { path: '/global-stats', priority: '0.5' },
  { path: '/safety-center', priority: '0.4' },
  { path: '/help-center', priority: '0.4' },
  { path: '/about-dev', priority: '0.3' },
];

// Pagini plain-HTML, randate direct de acest server, fără Flutter - conținut
// pur static (safety tips, FAQ, about dev), care înainte trecea prin
// ShellRoute-ul autentificat din app_router.dart și era invizibil oricui nu
// era logat (inclusiv Googlebot, deși erau în sitemap - vezi
// STATIC_SITEMAP_ROUTES de mai sus). Servite ca fișiere reale, nu ca shell-ul
// Flutter cu conținut injectat, ca să nu mai aștepte bootul motorului Flutter.
const STATIC_HTML_PAGES = {
  '/safety-center': path.join(__dirname, 'static-pages', 'safety-center.html'),
  '/about-dev': path.join(__dirname, 'static-pages', 'about-dev.html'),
  '/help-center': path.join(__dirname, 'static-pages', 'help-center.html'),
};

function fetchJson(url) {
  return new Promise((resolve) => {
    https
      .get(url, (res) => {
        if (res.statusCode && res.statusCode >= 400) {
          res.resume();
          resolve(null);
          return;
        }
        let body = '';
        res.on('data', (chunk) => (body += chunk));
        res.on('end', () => {
          try {
            resolve(JSON.parse(body));
          } catch {
            resolve(null);
          }
        });
      })
      .on('error', () => resolve(null));
  });
}

function escapeHtml(value) {
  return String(value ?? '').replace(/[<>&'"]/g, (c) => ({ '<': '&lt;', '>': '&gt;', '&': '&amp;', "'": '&apos;', '"': '&quot;' }[c]));
}

// Anunțurile publice (userBookId + updatedAt) sunt cerute de la backend la
// fiecare request la /sitemap.xml - fără cache, ca lastmod să rămână corect;
// serverul de fișiere statice oricum primește foarte puține hit-uri pe ruta
// asta (doar crawlere), deci costul suplimentar per-request e neglijabil.
async function fetchPublicListings() {
  const data = await fetchJson(`${apiUrl}/books/browse?limit=100&sort=recent`);
  return Array.isArray(data?.items) ? data.items : [];
}

async function buildSitemap() {
  const listings = await fetchPublicListings();
  const urls = [
    ...STATIC_SITEMAP_ROUTES.map((r) => `  <url><loc>${siteUrl}${r.path}</loc><priority>${r.priority}</priority></url>`),
    ...listings.map((item) => {
      const lastmod = new Date(item.updatedAt ?? item.createdAt).toISOString();
      return `  <url><loc>${siteUrl}/books/${escapeHtml(item.id)}</loc><lastmod>${lastmod}</lastmod><priority>0.7</priority></url>`;
    }),
  ];
  return `<?xml version="1.0" encoding="UTF-8"?>\n<urlset xmlns="http://www.sitemaps.org/schemas/sitemap/0.9">\n${urls.join('\n')}\n</urlset>\n`;
}

const DEFAULT_DESCRIPTION = 'Schimbă, vinde sau cumpără cărți second-hand de la alți cititori din România.';
const DEFAULT_IMAGE = `${siteUrl}/icons/Icon-512.png`;

// Flutter web randează totul client-side, deci un crawler care nu execută JS
// (sau un unfurl de link WhatsApp/Discord) ar vedea mereu titlul/descrierea
// generice din index.html, indiferent de cartea/profilul distribuit -
// înlocuim aici, în HTML-ul servit, valorile specifice paginii înainte ca
// Flutter să apuce să se încarce.
function renderPageHtml(template, meta) {
  const title = escapeHtml(meta.title);
  const description = escapeHtml(meta.description || DEFAULT_DESCRIPTION);
  const image = escapeHtml(meta.image || DEFAULT_IMAGE);
  const url = escapeHtml(meta.url);

  let html = template
    .replace('<title>ShelfShare</title>', `<title>${title}</title>`)
    .replace(
      `content="${DEFAULT_DESCRIPTION}">`,
      `content="${description}">`,
    )
    .replace('href="https://shelfshare.ro/">', `href="${url}">`)
    .replace('<meta property="og:url" content="https://shelfshare.ro">', `<meta property="og:url" content="${url}">`)
    .replace('<meta property="og:title" content="ShelfShare">', `<meta property="og:title" content="${title}">`)
    .replace(`<meta property="og:description" content="${DEFAULT_DESCRIPTION}">`, `<meta property="og:description" content="${description}">`)
    .replace(`<meta property="og:image" content="${DEFAULT_IMAGE}">`, `<meta property="og:image" content="${image}">`)
    .replace('<meta name="twitter:title" content="ShelfShare">', `<meta name="twitter:title" content="${title}">`)
    .replace(`<meta name="twitter:description" content="${DEFAULT_DESCRIPTION}">`, `<meta name="twitter:description" content="${description}">`)
    .replace(`<meta name="twitter:image" content="${DEFAULT_IMAGE}">`, `<meta name="twitter:image" content="${image}">`);

  if (meta.jsonLd) {
    html = html.replace('</head>', `  <script type="application/ld+json">${JSON.stringify(meta.jsonLd)}</script>\n</head>`);
  }

  // Conținut real, vizibil, randat pe server pentru crawlere - Flutter randează
  // totul în canvas, deci fără asta pagina n-are niciun text indexabil în afara
  // <title>/<meta>. #seo-content e afișat efectiv (nu display:none - Google
  // dă mai puțină greutate textului ascuns) și eliminat la 'flutter-first-frame'
  // exact ca #splash, ca să nu rămână sub/peste UI-ul real după hidratare.
  if (meta.bodyHtml) {
    html = html.replace(
      '<div id="splash">',
      `<div id="seo-content">${meta.bodyHtml}</div>\n  <div id="splash">`,
    );
  }
  return html;
}

// /leaderboard și /global-stats sunt rute publice pe backend (fără
// @UseGuards pe profile/leaderboard/* și books/most-shared|trending|
// popular-authors), dar în Flutter stau în ShellRoute-ul autentificat - orice
// vizitator neautentificat (inclusiv Googlebot) e redirecționat la /login
// înainte să vadă conținutul, deși sunt și în sitemap.xml. Nu le scoatem din
// spatele autentificării (ar însemna să deschidem tot shell-ul MainScaffold
// userilor anonimi, risc mai mare decât beneficiul), doar le pre-randăm
// conținut real pentru crawlere, exact ca la /books/:id și /users/:id -
// userii reali tot ajung la /login, comportamentul lor nu se schimbă.
async function fetchLeaderboardMeta() {
  const data = await fetchJson(`${apiUrl}/profile/leaderboard/national`);
  if (!Array.isArray(data) || data.length === 0) return null;
  const top = data.slice(0, 10);
  const description = `Clasamentul cititorilor cu cele mai multe schimburi de cărți pe ShelfShare: ${top
    .slice(0, 3)
    .map((u) => u.name)
    .join(', ')} și alții.`;
  const bodyHtml = `
    <h1>Clasament cititori</h1>
    <p>${escapeHtml(description)}</p>
    <ol>
      ${top
        .map(
          (u) =>
            `<li>${escapeHtml(u.name)}${u.city ? ` (${escapeHtml(u.city)})` : ''} - ${escapeHtml(u.booksExchangedCount)} schimburi</li>`,
        )
        .join('\n      ')}
    </ol>
  `;
  return {
    title: 'Clasament cititori | ShelfShare',
    description,
    url: `${siteUrl}/leaderboard`,
    bodyHtml,
  };
}

async function fetchGlobalStatsMeta() {
  const [mostShared, trending, popularAuthors] = await Promise.all([
    fetchJson(`${apiUrl}/books/most-shared`),
    fetchJson(`${apiUrl}/books/trending`),
    fetchJson(`${apiUrl}/books/popular-authors`),
  ]);
  const shared = Array.isArray(mostShared) ? mostShared.slice(0, 5) : [];
  const trend = Array.isArray(trending) ? trending.slice(0, 5) : [];
  const authors = Array.isArray(popularAuthors) ? popularAuthors.slice(0, 5) : [];
  if (!shared.length && !trend.length && !authors.length) return null;

  const bookItem = (entry) =>
    `<li>${escapeHtml(entry.book?.title)}${entry.book?.author ? ` de ${escapeHtml(entry.book.author)}` : ''} - ${escapeHtml(entry.count)}</li>`;
  const authorItem = (entry) => `<li>${escapeHtml(entry.author)} - ${escapeHtml(entry.count)}</li>`;
  const description =
    'Statistici globale ShelfShare: cele mai schimbate cărți, cărți în tendințe și autori populari printre cititorii din România.';
  const bodyHtml = `
    <h1>Statistici globale</h1>
    <p>${description}</p>
    ${shared.length ? `<h2>Cele mai schimbate cărți</h2><ul>${shared.map(bookItem).join('')}</ul>` : ''}
    ${trend.length ? `<h2>În tendințe</h2><ul>${trend.map(bookItem).join('')}</ul>` : ''}
    ${authors.length ? `<h2>Autori populari</h2><ul>${authors.map(authorItem).join('')}</ul>` : ''}
  `;
  return {
    title: 'Statistici globale | ShelfShare',
    description,
    url: `${siteUrl}/global-stats`,
    bodyHtml,
  };
}

async function fetchBookMeta(id) {
  const data = await fetchJson(`${apiUrl}/books/${id}/preview`);
  if (!data) return null;
  const byline = data.author ? `${data.title} de ${data.author}` : data.title;
  // salePrice poate fi 0/setat chiar și pentru anunțuri doar-de-schimb (câmpul
  // nu e golit când userul dezactivează vânzarea) - isForSale e sursa de
  // adevăr pentru ce arătăm (preț vs. "disponibilă pentru schimb").
  const isForSale = data.isForSale && data.salePrice != null && Number(data.salePrice) > 0;
  const priceClause = isForSale ? ` - ${data.salePrice} lei` : ' - disponibilă pentru schimb';
  const description = data.description
    ? data.description.slice(0, 200)
    : `${byline}, disponibilă pe ShelfShare${data.city ? ` în ${data.city}` : ''}${priceClause}.`;
  const bodyHtml = `
    <h1>${escapeHtml(data.title)}</h1>
    ${data.author ? `<p>de ${escapeHtml(data.author)}</p>` : ''}
    ${data.coverUrl ? `<img src="${escapeHtml(data.coverUrl)}" alt="${escapeHtml(data.title)}">` : ''}
    <p>${escapeHtml(description)}</p>
    <ul>
      ${data.city ? `<li>Oraș: ${escapeHtml(data.city)}</li>` : ''}
      <li>${isForSale ? `Preț: ${escapeHtml(data.salePrice)} lei` : 'Disponibilă pentru schimb'}</li>
      ${data.condition ? `<li>Stare: ${escapeHtml(data.condition)}</li>` : ''}
    </ul>
  `;
  return {
    title: `${byline} | ShelfShare`,
    description,
    image: data.coverUrl,
    url: `${siteUrl}/books/${id}`,
    bodyHtml,
    jsonLd: {
      '@context': 'https://schema.org',
      '@type': 'Book',
      name: data.title,
      ...(data.author ? { author: { '@type': 'Person', name: data.author } } : {}),
      ...(data.coverUrl ? { image: data.coverUrl } : {}),
      url: `${siteUrl}/books/${id}`,
    },
  };
}

async function fetchProfileMeta(id) {
  const data = await fetchJson(`${apiUrl}/profile/${id}`);
  if (!data) return null;
  const description = data.bio || `Profilul lui ${data.name} pe ShelfShare${data.city ? ` (${data.city})` : ''} - ${data.listingsCount ?? 0} cărți listate.`;
  const bodyHtml = `
    <h1>${escapeHtml(data.name)}</h1>
    ${data.profileImage ? `<img src="${escapeHtml(data.profileImage)}" alt="${escapeHtml(data.name)}">` : ''}
    <p>${escapeHtml(description)}</p>
    <ul>
      ${data.city ? `<li>Oraș: ${escapeHtml(data.city)}</li>` : ''}
      ${data.listingsCount != null ? `<li>Cărți listate: ${escapeHtml(data.listingsCount)}</li>` : ''}
    </ul>
  `;
  return {
    title: `${data.name} | ShelfShare`,
    description,
    image: data.profileImage,
    url: `${siteUrl}/users/${id}`,
    bodyHtml,
    jsonLd: {
      '@context': 'https://schema.org',
      '@type': 'Person',
      name: data.name,
      ...(data.profileImage ? { image: data.profileImage } : {}),
      url: `${siteUrl}/users/${id}`,
    },
  };
}

const ROBOTS_TXT = `User-agent: *
Disallow: /library
Disallow: /library/
Disallow: /chat
Disallow: /chat/
Disallow: /notifications
Disallow: /admin
Disallow: /onboarding
Disallow: /wishlist
Disallow: /exchanges
Disallow: /seller-analytics
Disallow: /smart-matches
Disallow: /activity-feed
Disallow: /auth/google/callback
Allow: /

Sitemap: ${siteUrl}/sitemap.xml
`;

const APP_ADS_TXT = `google.com, pub-7014376175927154, DIRECT, f08c47fec0942fa0
`;

const mime = {
  '.html': 'text/html',
  '.js': 'application/javascript',
  '.json': 'application/json',
  '.css': 'text/css',
  '.png': 'image/png',
  '.jpg': 'image/jpeg',
  '.svg': 'image/svg+xml',
  '.ico': 'image/x-icon',
  '.wasm': 'application/wasm',
  '.otf': 'font/otf',
  '.ttf': 'font/ttf',
};

http.createServer((req, res) => {
  let reqPath = decodeURIComponent(req.url.split('?')[0]);

  if (reqPath === '/robots.txt') {
    res.writeHead(200, { 'Content-Type': 'text/plain', 'Cache-Control': 'public, max-age=3600' });
    res.end(ROBOTS_TXT);
    return;
  }

  // Autorizarea AdMob (standardul IAB app-ads.txt): declară public ce conturi
  // au dreptul să vândă reclame în aplicațiile care listează shelfshare.ro la
  // "Website" în magazin. Crawler-ul cere fix /app-ads.txt din rădăcină - fără
  // ruta asta cererea ar cădea pe fallback-ul de SPA de mai jos și ar primi
  // index.html cu 200, adică "găsit, dar invalid", nu "lipsă".
  //
  // ATENȚIE: fișierul e autoritar pentru TOATE aplicațiile care trimit aici,
  // nu doar pentru cea care l-a cerut prima (Werewolf Companion). Fără fișier
  // înseamnă "nu mă pronunț"; cu fișier înseamnă "doar cine e pe listă are
  // voie să vândă, restul e fraudă". Deci dacă ShelfShare primește vreodată
  // reclame pe alt cont AdMob sau pe altă rețea (Unity Ads, AppLovin), adaugă
  // o linie nouă aici - altfel îți declari singur propriul inventar ca
  // neautorizat și cumpărătorii îl filtrează. Pe același cont nu e nevoie de
  // nimic: linia de mai sus îl acoperă deja.
  //
  // Nu adăuga /app-ads.txt în Disallow-urile din ROBOTS_TXT: crawler-ul n-ar
  // mai putea citi fișierul, iar verificarea din AdMob ar pica fără vreo
  // eroare vizibilă.
  if (reqPath === '/app-ads.txt') {
    res.writeHead(200, { 'Content-Type': 'text/plain', 'Cache-Control': 'public, max-age=3600' });
    res.end(APP_ADS_TXT);
    return;
  }
  if (reqPath === '/sitemap.xml') {
    buildSitemap().then((xml) => {
      res.writeHead(200, { 'Content-Type': 'application/xml', 'Cache-Control': 'no-cache, must-revalidate' });
      res.end(xml);
    });
    return;
  }

  if (STATIC_HTML_PAGES[reqPath]) {
    fs.readFile(STATIC_HTML_PAGES[reqPath], (err, data) => {
      if (err) {
        res.writeHead(404);
        res.end('Not found');
        return;
      }
      res.writeHead(200, { 'Content-Type': 'text/html', 'Cache-Control': 'public, max-age=300' });
      res.end(data);
    });
    return;
  }

  const bookMatch = reqPath.match(/^\/books\/([^/]+)$/);
  const userMatch = reqPath.match(/^\/users\/([^/]+)$/);
  const fetchMeta = bookMatch
    ? () => fetchBookMeta(bookMatch[1])
    : userMatch
      ? () => fetchProfileMeta(userMatch[1])
      : reqPath === '/leaderboard'
        ? fetchLeaderboardMeta
        : reqPath === '/global-stats'
          ? fetchGlobalStatsMeta
          : null;
  if (fetchMeta) {
    fs.readFile(path.join(root, 'index.html'), 'utf8', (err, template) => {
      if (err) {
        res.writeHead(404);
        res.end('Not found');
        return;
      }
      fetchMeta()
        .then((meta) => (meta ? renderPageHtml(template, meta) : template))
        .catch(() => template)
        .then((html) => {
          res.writeHead(200, { 'Content-Type': 'text/html', 'Cache-Control': 'no-cache, must-revalidate' });
          res.end(html);
        });
    });
    return;
  }

  if (reqPath === '/') reqPath = '/index.html';
  let filePath = path.join(root, reqPath);

  if (!filePath.startsWith(root)) {
    res.writeHead(403);
    res.end('Forbidden');
    return;
  }

  // NICIUN fișier din build-ul Flutter web (main.dart.js, index.html, DAR și
  // tot ce e sub /assets/ - fonturi, imagini, AssetManifest.json) nu are hash
  // în nume: numele rămâne identic de la un build la altul, doar conținutul
  // se schimbă. Am tratat /assets/ ca "imuabil, cache 1 an" inițial, dar
  // asta a fost o presupunere greșită - ex. MaterialIcons-Regular.otf e
  // tree-shaken în funcție de iconițele folosite în cod, deci conținutul lui
  // SE schimbă de la un deploy la altul (o iconiță nouă adăugată la o feature
  // înseamnă un font nou, la același URL) - un vizitator care a cache-uit
  // fontul vechi (fără glyph-ul nou) va vedea acea iconiță nouă invizibilă
  // la nesfârșit (butonul tot funcționează - doar glyph-ul lipsește din
  // fontul cache-uit), fără nicio eroare vizibilă. Deci ETag+revalidare
  // pentru TOATE fișierele, nu doar cele din afara /assets/.
  const serve = (data, contentType) => {
    const etag = `"${crypto.createHash('sha1').update(data).digest('hex')}"`;
    const headers = {
      'Content-Type': contentType,
      'Cache-Control': 'no-cache, must-revalidate',
      'ETag': etag,
    };

    if (req.headers['if-none-match'] === etag) {
      res.writeHead(304, headers);
      res.end();
      return;
    }
    res.writeHead(200, headers);
    res.end(data);
  };

  fs.readFile(filePath, (err, data) => {
    if (err) {
      fs.readFile(path.join(root, 'index.html'), (err2, indexData) => {
        if (err2) {
          res.writeHead(404);
          res.end('Not found');
          return;
        }
        serve(indexData, 'text/html');
      });
      return;
    }
    const ext = path.extname(filePath);
    serve(data, mime[ext] || 'application/octet-stream');
  });
}).listen(port, '127.0.0.1', () => {
  console.log(`Static server running at http://127.0.0.1:${port}`);
});
