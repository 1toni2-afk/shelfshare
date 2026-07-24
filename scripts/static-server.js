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
];

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
  return html;
}

async function fetchBookMeta(id) {
  const data = await fetchJson(`${apiUrl}/books/${id}/preview`);
  if (!data) return null;
  const byline = data.author ? `${data.title} de ${data.author}` : data.title;
  const priceClause = data.salePrice != null ? ` - ${data.salePrice} lei` : '';
  const description = data.description
    ? data.description.slice(0, 200)
    : `${byline}, disponibilă pe ShelfShare${data.city ? ` în ${data.city}` : ''}${priceClause}.`;
  return {
    title: `${byline} | ShelfShare`,
    description,
    image: data.coverUrl,
    url: `${siteUrl}/books/${id}`,
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
  return {
    title: `${data.name} | ShelfShare`,
    description: data.bio || `Profilul lui ${data.name} pe ShelfShare${data.city ? ` (${data.city})` : ''} - ${data.listingsCount ?? 0} cărți listate.`,
    image: data.profileImage,
    url: `${siteUrl}/users/${id}`,
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
  if (reqPath === '/sitemap.xml') {
    buildSitemap().then((xml) => {
      res.writeHead(200, { 'Content-Type': 'application/xml', 'Cache-Control': 'no-cache, must-revalidate' });
      res.end(xml);
    });
    return;
  }

  const bookMatch = reqPath.match(/^\/books\/([^/]+)$/);
  const userMatch = reqPath.match(/^\/users\/([^/]+)$/);
  if (bookMatch || userMatch) {
    fs.readFile(path.join(root, 'index.html'), 'utf8', (err, template) => {
      if (err) {
        res.writeHead(404);
        res.end('Not found');
        return;
      }
      const id = (bookMatch || userMatch)[1];
      const fetchMeta = bookMatch ? fetchBookMeta : fetchProfileMeta;
      fetchMeta(id)
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
