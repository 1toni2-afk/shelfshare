/**
 * Serverul static pentru beta.shelfshare.ro - noul frontend (web/dist).
 *
 * Rulează în paralel cu static-server.js, pe alt port. Cele două nu se
 * influențeaza deloc: shelfshare.ro rămâne pe Flutter (port 5959), beta merge
 * pe ăsta (5960). Comutarea finală înseamnă doar schimbarea regulii de ingress
 * din tunelul Cloudflare, fără să se atingă nimic din ce rulează acum.
 *
 * Ca și static-server.js, citește fișierele la fiecare cerere - un build nou
 * în web/dist e live imediat, fără repornire.
 */
const http = require('http');
const fs = require('fs');
const path = require('path');
const crypto = require('crypto');
const { STATIC_HTML_PAGES } = require('./static-pages');
const {
  ROBOTS_TXT,
  buildSitemap,
  isPrivatePath,
  metaFor,
  negotiateLocale,
  renderPage,
} = require('./beta-seo');

const root = path.join(__dirname, '..', 'web', 'dist');
const port = Number(process.env.BETA_PORT || 5960);

const mime = {
  '.html': 'text/html; charset=utf-8',
  '.js': 'text/javascript; charset=utf-8',
  '.mjs': 'text/javascript; charset=utf-8',
  '.css': 'text/css; charset=utf-8',
  '.json': 'application/json; charset=utf-8',
  '.webmanifest': 'application/manifest+json; charset=utf-8',
  '.map': 'application/json; charset=utf-8',
  '.png': 'image/png',
  '.jpg': 'image/jpeg',
  '.jpeg': 'image/jpeg',
  '.gif': 'image/gif',
  '.svg': 'image/svg+xml',
  '.ico': 'image/x-icon',
  '.webp': 'image/webp',
  '.ttf': 'font/ttf',
  '.woff': 'font/woff',
  '.woff2': 'font/woff2',
  '.txt': 'text/plain; charset=utf-8',
  '.xml': 'application/xml; charset=utf-8',
};

/**
 * E o cerere pentru un FIȘIER, nu pentru o rută a aplicației?
 *
 * Aceeași logică (și același motiv) ca în static-server.js: o rută necunoscută
 * (`/books/123`, `/wishlist`) trebuie să primească index.html, ca routerul din
 * browser s-o rezolve; un fișier lipsă trebuie să primească 404, nu HTML cu
 * 200 - altfel browserul cere JavaScript, primește HTML și eșuează la parsare,
 * ceea ce e mult mai greu de diagnosticat decât un 404 curat.
 *
 * Testul e pe lista de extensii cunoscute, NU pe „conține un punct": un
 * username ca `/users/ion.popescu` are extname `.popescu`, care nu e un tip de
 * fișier, deci rămâne rută de aplicație.
 */
function looksLikeFileRequest(reqPath) {
  return Object.hasOwn(mime, path.extname(reqPath).toLowerCase());
}

const COMMON_HEADERS = {
  'X-Content-Type-Options': 'nosniff',
};

/**
 * `X-Robots-Tag: noindex` - acum PE RUTĂ, nu pe tot site-ul.
 *
 * Până la deschiderea paginilor publice, antetul stătea pe fiecare răspuns:
 * beta era o copie completă a site-ului, iar indexarea ei ar fi produs
 * conținut duplicat în concurență cu shelfshare.ro. Acum beta are pagini
 * publice care TREBUIE să ajungă în index (vezi PUBLIC_ROUTES din
 * web/src/app/router.tsx), deci antetul rămâne doar pe ce ține de contul
 * cuiva: bibliotecă, conversații, schimburi, admin.
 *
 * Distincția e pe CALEA cerută, niciodată pe cine cere - nu există nicăieri în
 * server o ramură pe User-Agent.
 *
 * ATENȚIE la conținutul duplicat: shelfshare.ro (servit de static-server.js,
 * neatins) rămâne indexabil separat, cu aceleași cărți. Cât timp cele două
 * rulează în paralel, aceleași anunțuri există la două adrese. Când beta ia
 * locul producției, dispare de la sine; până atunci e un compromis asumat.
 */
function robotsHeaderFor(reqPath) {
  return isPrivatePath(reqPath) ? { 'X-Robots-Tag': 'noindex, nofollow' } : {};
}

/**
 * Doar `/assets/` primește cache lung, și doar pentru că Vite pune un hash de
 * conținut în numele fiecărui fișier de acolo - un conținut nou înseamnă un
 * nume nou, deci nu există „copie veche servită din greșeală".
 *
 * ATENȚIE: regula asta NU se poate copia la static-server.js. Acolo fișierele
 * din /assets/ sunt asset-urile Flutter, care NU au hash în nume - marcate
 * immutable, au produs un bug de iconițe invizibile care a ținut până la
 * golirea manuală a cache-ului. Aici e invers, și numai fiindcă numele sunt
 * hash-uite. Restul (index.html, /fonts, /icons, manifest) rămâne no-cache:
 * sunt copiate ca atare din public/, fără hash.
 */
function cacheHeaderFor(reqPath) {
  return reqPath.startsWith('/assets/')
    ? 'public, max-age=31536000, immutable'
    : 'no-cache, must-revalidate';
}

http
  .createServer((req, res) => {
    let reqPath;
    try {
      reqPath = decodeURIComponent(req.url.split('?')[0]);
    } catch {
      // URL cu procentaje invalide (%ZZ) - decodeURIComponent aruncă.
      res.writeHead(400, { ...COMMON_HEADERS, 'Content-Type': 'text/plain' });
      return res.end('Bad Request');
    }

    // Sonda de sanatate, INAINTE de orice atingere de disc.
    //
    // Healthcheck-ul trebuie sa distinga „event loop blocat" de „discul e
    // lent". Daca sonda ar citi un fisier, o furtuna de I/O ar arata identic
    // cu o intepenire si am reporni un server perfect sanatos - exact invers
    // decat vrem. Raspunsul de aici e un string din memorie.
    if (reqPath === '/__health') {
      res.writeHead(200, {
        ...COMMON_HEADERS,
        'Content-Type': 'text/plain; charset=utf-8',
        'Cache-Control': 'no-store',
      });
      return res.end('ok');
    }

    /*
      robots.txt și sitemap.xml se rezolvă înaintea oricărei căutări pe disc:
      nu sunt fișiere în web/dist, ci se generează din rutele publice și din
      anunțurile luate de la API. Fără ele, cererea ar fi căzut pe fallback-ul
      de SPA și ar fi primit index.html cu 200 - adică „găsit, dar invalid",
      ceea ce un crawler raportează mult mai neclar decât un 404.
    */
    if (reqPath === '/robots.txt') {
      res.writeHead(200, {
        ...COMMON_HEADERS,
        'Content-Type': mime['.txt'],
        'Cache-Control': 'public, max-age=3600',
      });
      return res.end(ROBOTS_TXT);
    }

    if (reqPath === '/sitemap.xml') {
      return buildSitemap()
        .then((xml) => {
          res.writeHead(200, {
            ...COMMON_HEADERS,
            'Content-Type': mime['.xml'],
            'Cache-Control': 'no-cache, must-revalidate',
          });
          res.end(xml);
        })
        .catch(() => {
          // Sitemap-ul depinde de API; dacă acela tace, un 503 e răspunsul
          // corect. Un sitemap gol servit cu 200 i-ar spune lui Google că
          // site-ul chiar n-are pagini, iar el ar scoate din index ce are.
          res.writeHead(503, { ...COMMON_HEADERS, 'Content-Type': 'text/plain' });
          res.end('Sitemap indisponibil');
        });
    }

    /*
      Limba primului cadru, din `Accept-Language`.

      Pana acum HTML-ul pre-randat era scris fix in romana, deci un om cu
      browserul pe engleza vedea o clipa romana inainte ca aplicatia sa
      porneasca si sa comute. Antetul asta e exact sursa din care isi alege
      limba si aplicatia (`navigator.languages`), deci cele doua ajung la
      acelasi rezultat si tranzitia nu se mai vede.

      Nu e cloaking si nu incalca regula casei: nu ne uitam la User-Agent
      nicaieri. Un robot care cere engleza primeste ce primeste si un om
      care cere engleza.
    */
    const locale = negotiateLocale(req.headers['accept-language']);
    const pageMeta = metaFor(reqPath, locale);
    if (pageMeta) {
      /*
        Pagină publică: livrăm shell-ul aplicației CU metadatele și conținutul
        ei deja scrise înăuntru. Așa, un crawler sau un vizitator fără
        JavaScript primește titlul, descrierea, textul și linkurile paginii
        din prima, fără să execute nimic.

        Aceiași octeți pleacă spre oricine cere adresa. Nu ne uităm la
        User-Agent nicăieri - cine are JavaScript vede pur și simplu, o clipă
        mai târziu, varianta interactivă a aceluiași conținut.
      */
      return fs.readFile(path.join(root, 'index.html'), 'utf8', (indexErr, template) => {
        if (indexErr) {
          res.writeHead(500, { ...COMMON_HEADERS, 'Content-Type': 'text/plain' });
          return res.end('web/dist/index.html lipseste - ruleaza scripts/deploy-beta.ps1');
        }

        Promise.resolve(pageMeta)
          // `meta` null = anunț/profil inexistent sau API mut. Servim shell-ul
          // ca atare: routerul din browser va afișa ecranul de „nu există",
          // iar metadatele rămân cele implicite.
          .then((meta) => (meta ? renderPage(template, meta, locale) : template))
          .catch(() => template)
          .then((html) => {
            res.writeHead(200, {
              ...COMMON_HEADERS,
              'Content-Type': mime['.html'],
              'Content-Language': locale,
              /*
                OBLIGATORIU alaturi de negocierea de mai sus: raspunsul
                depinde acum de `Accept-Language`, deci orice cache de pe drum
                - inclusiv Cloudflare - trebuie sa tina variante separate. Fara
                el, primul vizitator ar fixa limba pentru toti ceilalti, iar
                simptomul ar fi un site care apare in germana pentru romani,
                intermitent si imposibil de reprodus local.
              */
              Vary: 'Accept-Language',
              'Cache-Control': 'no-cache, must-revalidate',
            });
            res.end(html);
          });
      });
    }

    if (reqPath === '/') reqPath = '/index.html';

    // Normalizarea taie orice „..": fără ea, `/../../.env` ar ieși din root.
    const safePath = path.normalize(path.join(root, reqPath));
    if (!safePath.startsWith(root)) {
      res.writeHead(403, { ...COMMON_HEADERS, 'Content-Type': 'text/plain' });
      return res.end('Forbidden');
    }

    // Calculat o dată, din calea CERUTĂ: `reqPath` a fost deja rescris în
    // „/index.html" mai sus pentru rădăcină, iar rădăcina e publică oricum.
    const robots = robotsHeaderFor(reqPath);

    const serve = (data, contentType, cacheControl) => {
      const etag = `"${crypto.createHash('sha1').update(data).digest('hex')}"`;
      if (req.headers['if-none-match'] === etag) {
        res.writeHead(304, { ...COMMON_HEADERS, ...robots, ETag: etag, 'Cache-Control': cacheControl });
        return res.end();
      }
      res.writeHead(200, {
        ...COMMON_HEADERS,
        ...robots,
        'Content-Type': contentType,
        'Cache-Control': cacheControl,
        ETag: etag,
      });
      res.end(data);
    };

    /*
      Paginile publice plain-HTML (centrul de siguranta, intrebari frecvente,
      despre dezvoltator, confidentialitate, termeni) se rezolva INAINTE de
      web/dist. Sunt legate din Setari, dar nu sunt rute ale aplicatiei: fara
      verificarea asta cadeau pe index.html, iar routerul React le arata ca
      „pagina inexistenta".

      Cautarea e pe cheie exacta in harta, nu pe disc, deci nu are nevoie de
      garda de traversare de mai sus.
    */
    const staticPage = STATIC_HTML_PAGES[reqPath];
    if (staticPage) {
      return fs.readFile(staticPage, (pageErr, pageData) => {
        if (pageErr) {
          res.writeHead(404, {
            ...COMMON_HEADERS,
            'Content-Type': 'text/plain; charset=utf-8',
            'Cache-Control': 'no-cache',
          });
          return res.end('Not Found');
        }
        serve(pageData, mime['.html'], 'no-cache, must-revalidate');
      });
    }

    fs.readFile(safePath, (err, data) => {
      if (!err) {
        const type = mime[path.extname(safePath).toLowerCase()] || 'application/octet-stream';
        return serve(data, type, cacheHeaderFor(reqPath));
      }

      // Fișier cerut explicit și inexistent: 404, nu index.html deghizat.
      if (looksLikeFileRequest(reqPath)) {
        res.writeHead(404, { ...COMMON_HEADERS, 'Content-Type': 'text/plain', 'Cache-Control': 'no-cache' });
        return res.end('Not Found');
      }

      // Rută de aplicație: index.html, ca routerul s-o rezolve în browser.
      fs.readFile(path.join(root, 'index.html'), (indexErr, indexData) => {
        if (indexErr) {
          res.writeHead(500, { ...COMMON_HEADERS, 'Content-Type': 'text/plain' });
          return res.end('web/dist/index.html lipseste - ruleaza scripts/deploy-beta.ps1');
        }
        serve(indexData, mime['.html'], 'no-cache, must-revalidate');
      });
    });
  })
  // 127.0.0.1, nu 0.0.0.0: singurul lucru care trebuie să ajungă aici e
  // tunelul Cloudflare, care rulează pe aceeași mașină. Expus pe toate
  // interfețele, serverul ar fi accesibil direct din LAN, ocolind tunelul.
  .listen(port, '127.0.0.1', () => {
    console.log(`[beta] servesc ${root} pe http://127.0.0.1:${port}`);
    if (!fs.existsSync(path.join(root, 'index.html'))) {
      console.warn('[beta] ATENTIE: web/dist/index.html inca nu exista.');
    }
  });
