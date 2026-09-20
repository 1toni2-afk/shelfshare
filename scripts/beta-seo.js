/**
 * Metadatele și conținutul text al paginilor PUBLICE de pe beta.shelfshare.ro.
 *
 * De ce există ca modul separat de beta-server.js: serverul se ocupă de
 * fișiere, cache și rutare; asta se ocupă de ce scrie în pagină. Amestecate,
 * fișierul ar fi trecut de 600 de linii, iar partea care trebuie ținută în
 * oglindă cu aplicația (web/src/lib/seo/routes.ts) s-ar fi pierdut printre
 * antete HTTP.
 *
 * REGULA care ține totul în picioare: ce scriem aici trebuie să fie același
 * lucru pe care îl arată aplicația după ce pornește. Nu ne uităm NICĂIERI la
 * User-Agent și nu avem o ramură „pentru Google": fiecare vizitator, om sau
 * robot, primește exact aceiași octeți. Cine are JavaScript vede apoi varianta
 * interactivă a aceluiași conținut - progressive enhancement, nu cloaking.
 *
 * Sursa de date e API-ul public al backendului (fără gardieni: `GET
 * /books/browse`, `/books/:id/preview`, `/profile/:id`, `/groups/:id`,
 * `/profile/leaderboard/national`). Nimic din ce cere autentificare nu ajunge
 * aici - nici email, nici telefon, nici mesaje, nici schimburi.
 */
const http = require('http');
const https = require('https');

const SITE_URL = process.env.BETA_SITE_URL || 'https://beta.shelfshare.ro';

/**
 * API-ul de la care luăm datele pentru pagini.
 *
 * Implicit `http://localhost:3999`, adică EXACT backendul pe care îl folosește
 * și bundle-ul livrat pe beta (vezi ingress-ul `api-beta.shelfshare.ro` din
 * cloudflared-config.beta.yml). Trebuie să fie același, altfel textul din HTML
 * ar descrie alte cărți decât cele pe care le încarcă aplicația o secundă mai
 * târziu - adică fix diferența pe care o penalizează motoarele de căutare.
 *
 * Lovim direct portul local, nu prin `https://api-beta.shelfshare.ro`: acolo
 * cererea ar ieși prin tunelul Cloudflare și s-ar întoarce pe aceeași mașină,
 * adăugând o traversare de rețea la fiecare pagină.
 *
 * Când beta va fi mutat pe API-ul de producție, se schimbă variabila, nu codul.
 */
const API_URL = process.env.BETA_API_URL || 'http://localhost:3999';

const SITE_NAME = 'ShelfShare';
const DEFAULT_DESCRIPTION =
  'ShelfShare - schimbă, vinde sau cumpără cărți second-hand de la alți cititori din România.';
const DEFAULT_IMAGE = `${SITE_URL}/icons/Icon-512.png`;

/**
 * Paginile publice cu text fix.
 *
 * Oglindă exactă a lui LANDING_META / BROWSE_META din
 * web/src/lib/seo/routes.ts. Cine schimbă un titlu acolo îl schimbă și aici -
 * altfel pagina servită și pagina randată de aplicație ar anunța două titluri
 * diferite pentru aceeași adresă.
 */
const PUBLIC_PAGE_META = {
  '/': {
    title: 'ShelfShare - schimbă și cumpără cărți second-hand în România',
    description:
      'Comunitatea de cititori din România unde cărțile citite își găsesc un cititor nou. Îți listezi cărțile, cauți ce vrei să citești și te înțelegi direct cu proprietarul - prin schimb sau la un preț stabilit de voi.',
  },
  '/browse': {
    title: 'Catalog de cărți second-hand | ShelfShare',
    description:
      'Caută printre cărțile puse la schimb sau la vânzare de cititorii ShelfShare. Filtrează după titlu, autor, gen, stare și oraș.',
  },
};

/**
 * Rutele aplicației care NU au voie în index: tot ce ține de contul cuiva.
 *
 * Servesc la două lucruri deodată - `Disallow` în robots.txt și
 * `X-Robots-Tag: noindex` pe răspuns. Amândouă, fiindcă fac lucruri diferite:
 * robots.txt oprește crawlarea, dar un URL blocat acolo poate ajunge totuși
 * indexat dacă îl leagă cineva (robotul n-are voie să deschidă pagina, deci nu
 * vede niciodată directiva noindex). Antetul e cel care chiar ține pagina
 * afară, iar el se vede doar dacă robotul are voie să ceară pagina.
 */
const PRIVATE_PREFIXES = [
  '/library',
  '/chat',
  '/notifications',
  '/admin',
  '/onboarding',
  '/wishlist',
  '/collections',
  '/saved-searches',
  '/exchanges',
  '/offers',
  '/settings',
  '/profile',
  '/following',
  '/activity-feed',
  '/seller-analytics',
  '/smart-matches',
  '/book-match',
  '/book-requests',
  '/bookshelf',
  '/import',
  '/feedback',
  '/support',
  '/auth',
  '/login',
  '/register',
  '/forgot-password',
  '/verify-email',
  '/pre-register',
  '/search',
];

/** Ruta curentă e una privată (deci noindex)? */
function isPrivatePath(reqPath) {
  return PRIVATE_PREFIXES.some(
    (prefix) => reqPath === prefix || reqPath.startsWith(`${prefix}/`),
  );
}

function escapeHtml(value) {
  return String(value ?? '').replace(
    /[<>&'"]/g,
    (c) => ({ '<': '&lt;', '>': '&gt;', '&': '&amp;', "'": '&apos;', '"': '&quot;' })[c],
  );
}

/** Taie un text la o lungime rezonabilă de descriere, fără să rupă un cuvânt. */
function clamp(text, max = 200) {
  const clean = String(text ?? '').replace(/\s+/g, ' ').trim();
  if (clean.length <= max) return clean;
  const cut = clean.slice(0, max);
  return `${cut.slice(0, cut.lastIndexOf(' ') || max)}...`;
}

/**
 * GET JSON, cu timeout.
 *
 * Orice eșec întoarce `null`, nu aruncă: dacă backendul nu răspunde, pagina
 * trebuie să plece oricum - cu metadatele implicite. O eroare de API n-are
 * voie să transforme o pagină de site într-un 500.
 */
function fetchJson(url) {
  const client = url.startsWith('https:') ? https : http;
  return new Promise((resolve) => {
    const request = client.get(url, { timeout: 4000 }, (res) => {
      if (res.statusCode && res.statusCode >= 400) {
        res.resume();
        return resolve(null);
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
    });
    request.on('timeout', () => {
      request.destroy();
      resolve(null);
    });
    request.on('error', () => resolve(null));
  });
}

/**
 * Cache scurt, în memorie, pentru metadatele paginilor.
 *
 * Fără el, fiecare cerere către o pagină publică ar însemna o cerere către
 * backend - inclusiv cele câteva zeci pe care le face un crawler într-o
 * rafală. 60 de secunde e suficient cât să nu se vadă în latență și prea
 * puțin cât să conteze pentru prospețimea unui anunț.
 */
const CACHE_TTL_MS = 60_000;
const cache = new Map();

async function cached(key, produce) {
  const hit = cache.get(key);
  if (hit && hit.expires > Date.now()) return hit.value;

  const value = await produce();
  cache.set(key, { value, expires: Date.now() + CACHE_TTL_MS });

  // Plafon simplu: harta nu are voie să crească la nesfârșit dacă un crawler
  // cere mii de anunțuri. Se golește de tot, nu pe cel mai vechi - e un cache
  // de 60 de secunde, nu o structură pe care merită s-o ținem ordonată.
  if (cache.size > 500) cache.clear();
  return value;
}

/** Titlul unei pagini de carte. Oglindit în web/src/lib/seo/routes.ts. */
function bookTitle(title, author) {
  return `${author ? `${title} de ${author}` : title} | ${SITE_NAME}`;
}

async function bookMeta(id) {
  // `/preview`, nu `/books/:id`: e endpointul făcut exact pentru asta și NU
  // incrementează contorul de vizualizări, deci trecerea unui crawler nu umflă
  // statisticile proprietarului.
  const data = await fetchJson(`${API_URL}/books/${encodeURIComponent(id)}/preview`);
  if (!data || !data.title) return null;

  const byline = data.author ? `${data.title} de ${data.author}` : data.title;
  // `salePrice` poate rămâne setat pe un anunț doar-de-schimb (câmpul nu se
  // golește când proprietarul oprește vânzarea), deci `isForSale` e sursa de
  // adevăr - altfel am anunța în Google un preț pentru o carte care nu se vinde.
  const price = Number(data.salePrice);
  const forSale = data.isForSale && Number.isFinite(price) && price > 0;
  const description =
    clamp(data.description) ||
    `${byline}, disponibilă pe ShelfShare${data.city ? ` în ${data.city}` : ''}${
      forSale ? ` - ${price} lei` : ' - disponibilă pentru schimb'
    }.`;

  return {
    title: bookTitle(data.title, data.author),
    description,
    image: data.coverUrl,
    path: `/books/${id}`,
    jsonLd: {
      '@context': 'https://schema.org',
      '@type': 'Book',
      name: data.title,
      ...(data.author ? { author: { '@type': 'Person', name: data.author } } : {}),
      ...(data.isbn ? { isbn: data.isbn } : {}),
      ...(data.coverUrl ? { image: data.coverUrl } : {}),
      url: `${SITE_URL}/books/${id}`,
      ...(forSale
        ? {
            offers: {
              '@type': 'Offer',
              price,
              priceCurrency: 'RON',
              itemCondition: 'https://schema.org/UsedCondition',
              availability: 'https://schema.org/InStock',
            },
          }
        : {}),
    },
    bodyHtml: `
      <h1>${escapeHtml(data.title)}</h1>
      ${data.author ? `<p>de ${escapeHtml(data.author)}</p>` : ''}
      <p>${escapeHtml(description)}</p>
      <ul>
        ${data.city ? `<li>Oraș: ${escapeHtml(data.city)}</li>` : ''}
        <li>${forSale ? `Preț: ${escapeHtml(price)} lei` : 'Disponibilă pentru schimb'}</li>
        ${data.condition ? `<li>Stare: ${escapeHtml(data.condition)}</li>` : ''}
      </ul>
      <p><a href="/browse">Vezi toate cărțile disponibile</a></p>
    `,
  };
}

async function profileMeta(id) {
  const data = await fetchJson(`${API_URL}/profile/${encodeURIComponent(id)}`);
  if (!data || !(data.name || data.username)) return null;

  const name = data.name || data.username;
  const listed = Array.isArray(data.listedBooks) ? data.listedBooks : [];
  const description =
    clamp(data.bio) ||
    `Profilul lui ${name} pe ShelfShare${data.city ? ` (${data.city})` : ''} - ${listed.length} cărți listate.`;

  /*
    Ce NU intră aici, deși backendul are câmpurile: emailul, telefonul,
    schimburile, conversațiile. Un profil public înseamnă numele, orașul,
    raftul și reputația - nimic din ce ai spune doar cuiva cu care faci un
    schimb. Structured data are voie să fie mai săracă decât pagina; n-are
    voie să fie mai indiscretă.
  */
  return {
    title: `${name} | ${SITE_NAME}`,
    description,
    image: data.profileImage,
    path: `/users/${id}`,
    jsonLd: {
      '@context': 'https://schema.org',
      '@type': 'Person',
      name,
      ...(data.profileImage ? { image: data.profileImage } : {}),
      ...(data.city
        ? { address: { '@type': 'PostalAddress', addressLocality: data.city } }
        : {}),
      url: `${SITE_URL}/users/${id}`,
    },
    bodyHtml: `
      <h1>${escapeHtml(name)}</h1>
      <p>${escapeHtml(description)}</p>
      <ul>
        ${data.city ? `<li>Oraș: ${escapeHtml(data.city)}</li>` : ''}
        <li>Cărți listate: ${escapeHtml(listed.length)}</li>
      </ul>
      ${
        listed.length
          ? `<h2>Cărți de la ${escapeHtml(name)}</h2><ul>${listed
              .slice(0, 20)
              .map(
                (item) =>
                  `<li><a href="/books/${escapeHtml(item.id)}">${escapeHtml(
                    item.book?.title ?? 'Carte',
                  )}${item.book?.author ? ` - ${escapeHtml(item.book.author)}` : ''}</a></li>`,
              )
              .join('')}</ul>`
          : ''
      }
    `,
  };
}

async function groupMeta(id) {
  const data = await fetchJson(`${API_URL}/groups/${encodeURIComponent(id)}`);
  if (!data || !data.name) return null;

  const description =
    clamp(data.description) ||
    `${data.name} - club de lectură pe ShelfShare, cu ${data.memberCount ?? 0} membri.`;

  /*
    Discuția grupului NU se pre-randează, deși pagina o afișează și deși
    backendul o dă și anonimilor. Sunt mesaje scrise de oameni pentru grupul
    lor; un fragment dintr-o discuție ajuns în descrierea din rezultatele
    Google e cu totul altceva decât un club listat public. La fel, lista de
    membri rămâne în afara HTML-ului indexabil.
  */
  return {
    title: `${data.name} | ${SITE_NAME}`,
    description,
    path: `/groups/${id}`,
    bodyHtml: `
      <h1>${escapeHtml(data.name)}</h1>
      <p>${escapeHtml(description)}</p>
      <ul><li>Membri: ${escapeHtml(data.memberCount ?? 0)}</li></ul>
      <p><a href="/browse">Catalogul de cărți ShelfShare</a></p>
    `,
  };
}

/**
 * Pagina de prezentare: text fix plus o listă cu cele mai recente anunțuri.
 *
 * Linkurile către cărți sunt singurul drum prin care un robot pornit de la
 * rădăcină ajunge la paginile de anunț fără să treacă prin sitemap - de-asta
 * sunt `<a href>` reale, nu doar carduri desenate de aplicație.
 */
async function landingMeta() {
  const listings = await fetchPublicListings(12);
  const meta = PUBLIC_PAGE_META['/'];

  return {
    ...meta,
    path: '/',
    jsonLd: {
      '@context': 'https://schema.org',
      '@type': 'WebSite',
      name: SITE_NAME,
      url: `${SITE_URL}/`,
      description: meta.description,
    },
    bodyHtml: `
      <h1>Dă-ți cărțile citite mai departe</h1>
      <p>${escapeHtml(meta.description)}</p>
      <h2>Cum funcționează</h2>
      <ol>
        <li>Îți listezi cărțile: scanezi codul ISBN sau cauți titlul, iar datele se completează singure.</li>
        <li>Cauți ce vrei să citești, filtrat după autor, gen sau orașul tău.</li>
        <li>Vă înțelegeți direct în chat și stabiliți predarea. ShelfShare nu ia comision.</li>
      </ol>
      ${
        listings.length
          ? `<h2>Cărți adăugate recent</h2><ul>${listings
              .map(
                (item) =>
                  `<li><a href="/books/${escapeHtml(item.id)}">${escapeHtml(
                    item.book?.title ?? 'Carte',
                  )}${item.book?.author ? ` - ${escapeHtml(item.book.author)}` : ''}</a>${
                    item.city ? ` (${escapeHtml(item.city)})` : ''
                  }</li>`,
              )
              .join('')}</ul>`
          : ''
      }
      <h2>Mai departe</h2>
      <ul>
        <li><a href="/browse">Catalogul complet de cărți</a></li>
        <li><a href="/leaderboard">Clasamentul cititorilor</a></li>
        <li><a href="/global-stats">Statistici globale</a></li>
        <li><a href="/help-center">Întrebări frecvente</a></li>
        <li><a href="/safety-center">Centrul de siguranță</a></li>
        <li><a href="/privacy">Politica de confidențialitate</a></li>
        <li><a href="/terms">Termeni și condiții</a></li>
      </ul>
    `,
  };
}

async function browseMeta() {
  const listings = await fetchPublicListings(40);
  const meta = PUBLIC_PAGE_META['/browse'];

  return {
    ...meta,
    path: '/browse',
    bodyHtml: `
      <h1>Catalog de cărți second-hand</h1>
      <p>${escapeHtml(meta.description)}</p>
      ${
        listings.length
          ? `<ul>${listings
              .map(
                (item) =>
                  `<li><a href="/books/${escapeHtml(item.id)}">${escapeHtml(
                    item.book?.title ?? 'Carte',
                  )}${item.book?.author ? ` - ${escapeHtml(item.book.author)}` : ''}</a>${
                    item.city ? ` (${escapeHtml(item.city)})` : ''
                  }</li>`,
              )
              .join('')}</ul>`
          : '<p>Momentan nu sunt cărți listate.</p>'
      }
    `,
  };
}

async function leaderboardMeta() {
  const data = await fetchJson(`${API_URL}/profile/leaderboard/national`);
  if (!Array.isArray(data) || data.length === 0) return null;

  const top = data.slice(0, 10);
  const description = `Clasamentul cititorilor cu cele mai multe schimburi de cărți pe ShelfShare: ${top
    .slice(0, 3)
    .map((u) => u.name)
    .join(', ')} și alții.`;

  return {
    title: `Clasament cititori | ${SITE_NAME}`,
    description,
    path: '/leaderboard',
    bodyHtml: `
      <h1>Clasament cititori</h1>
      <p>${escapeHtml(description)}</p>
      <ol>${top
        .map(
          (u) =>
            `<li>${escapeHtml(u.name)}${u.city ? ` (${escapeHtml(u.city)})` : ''} - ${escapeHtml(
              u.booksExchangedCount,
            )} schimburi</li>`,
        )
        .join('')}</ol>
    `,
  };
}

async function globalStatsMeta() {
  const [mostShared, trending, authors] = await Promise.all([
    fetchJson(`${API_URL}/books/most-shared`),
    fetchJson(`${API_URL}/books/trending`),
    fetchJson(`${API_URL}/books/popular-authors`),
  ]);
  const shared = Array.isArray(mostShared) ? mostShared.slice(0, 5) : [];
  const trend = Array.isArray(trending) ? trending.slice(0, 5) : [];
  const people = Array.isArray(authors) ? authors.slice(0, 5) : [];
  if (!shared.length && !trend.length && !people.length) return null;

  const description =
    'Statistici globale ShelfShare: cele mai schimbate cărți, cărți în tendințe și autori populari printre cititorii din România.';
  const bookItem = (entry) =>
    `<li>${escapeHtml(entry.book?.title)}${
      entry.book?.author ? ` de ${escapeHtml(entry.book.author)}` : ''
    } - ${escapeHtml(entry.count)}</li>`;

  return {
    title: `Statistici globale | ${SITE_NAME}`,
    description,
    path: '/global-stats',
    bodyHtml: `
      <h1>Statistici globale</h1>
      <p>${escapeHtml(description)}</p>
      ${shared.length ? `<h2>Cele mai schimbate cărți</h2><ul>${shared.map(bookItem).join('')}</ul>` : ''}
      ${trend.length ? `<h2>În tendințe</h2><ul>${trend.map(bookItem).join('')}</ul>` : ''}
      ${
        people.length
          ? `<h2>Autori populari</h2><ul>${people
              .map((entry) => `<li>${escapeHtml(entry.author)} - ${escapeHtml(entry.count)}</li>`)
              .join('')}</ul>`
          : ''
      }
    `,
  };
}

/**
 * Numărul maxim de anunțuri pe care le acceptă `GET /books/browse` într-o
 * cerere (`limit must not be greater than 100`, vezi SearchLibraryDto).
 *
 * Contează: o cerere cu `limit=200` NU întoarce 100 de rezultate, ci un 400 -
 * pe care `fetchJson` îl transformă în `null`, deci într-o listă goală. Prima
 * versiune a sitemap-ului avea exact bug-ul ăsta și conținea doar rutele fixe,
 * fără nicio carte, fără nicio eroare vizibilă nicăieri.
 */
const BROWSE_PAGE_SIZE = 100;

/** Plafon pentru sitemap: peste atât ar trebui oricum un sitemap-index. */
const SITEMAP_MAX_LISTINGS = 1000;

async function fetchPublicListings(limit) {
  const items = [];

  for (let offset = 0; items.length < limit; offset += BROWSE_PAGE_SIZE) {
    const size = Math.min(BROWSE_PAGE_SIZE, limit - items.length);
    const page = await fetchJson(
      `${API_URL}/books/browse?limit=${size}&offset=${offset}&sort=recent`,
    );
    const batch = Array.isArray(page?.items) ? page.items : [];
    items.push(...batch);
    // Pagină incompletă = am ajuns la capătul catalogului. Fără verificarea
    // asta, bucla ar cere la nesfârșit pagini goale până la plafon.
    if (batch.length < size) break;
  }

  return items;
}

/**
 * Metadatele pentru o cale, sau `null` dacă nu e o pagină publică cunoscută.
 *
 * Potrivirea e pe CALE, nu pe cine cere pagina. Asta e tot ce ține soluția
 * departe de cloaking: nu există nicio ramură care să întrebe cine e la capăt.
 */
function metaFor(reqPath) {
  if (reqPath === '/') return cached('landing', landingMeta);
  if (reqPath === '/browse') return cached('browse', browseMeta);
  if (reqPath === '/leaderboard') return cached('leaderboard', leaderboardMeta);
  if (reqPath === '/global-stats') return cached('stats', globalStatsMeta);

  const book = reqPath.match(/^\/books\/([^/]+)$/);
  if (book) return cached(`book:${book[1]}`, () => bookMeta(book[1]));

  const user = reqPath.match(/^\/users\/([^/]+)$/);
  if (user) return cached(`user:${user[1]}`, () => profileMeta(user[1]));

  const group = reqPath.match(/^\/groups\/([^/]+)$/);
  if (group) return cached(`group:${group[1]}`, () => groupMeta(group[1]));

  return null;
}

const HEAD_MARKERS = /<!--ss-head-->[\s\S]*?<!--\/ss-head-->/;
const BODY_MARKER = '<!--ss-body-->';

/**
 * Scrie metadatele și conținutul paginii în shell-ul `index.html`.
 *
 * Înlocuirea e pe marcaje (`<!--ss-head-->`), nu pe tag-uri exacte: varianta
 * cu `.replace('<title>ShelfShare</title>', ...)` din static-server.js merge,
 * dar se rupe tăcut la prima reformatare a fișierului - rezultatul e o pagină
 * validă, doar cu titlul generic, adică un bug pe care nu-l vede nimeni până
 * nu se uită cineva în Search Console.
 */
function renderPage(template, meta) {
  const title = escapeHtml(meta.title);
  const description = escapeHtml(meta.description || DEFAULT_DESCRIPTION);
  const image = escapeHtml(meta.image || DEFAULT_IMAGE);
  const url = escapeHtml(SITE_URL + meta.path);

  const head = [
    `<title>${title}</title>`,
    `<meta name="description" content="${description}" />`,
    `<link rel="canonical" href="${url}" />`,
    `<meta property="og:type" content="${meta.path.startsWith('/books/') ? 'book' : 'website'}" />`,
    `<meta property="og:site_name" content="${SITE_NAME}" />`,
    `<meta property="og:title" content="${title}" />`,
    `<meta property="og:description" content="${description}" />`,
    `<meta property="og:url" content="${url}" />`,
    `<meta property="og:image" content="${image}" />`,
    `<meta name="twitter:card" content="summary_large_image" />`,
    `<meta name="twitter:title" content="${title}" />`,
    `<meta name="twitter:description" content="${description}" />`,
    `<meta name="twitter:image" content="${image}" />`,
    ...(meta.jsonLd
      ? [`<script type="application/ld+json">${JSON.stringify(meta.jsonLd)}</script>`]
      : []),
  ].join('\n  ');

  let html = template.replace(HEAD_MARKERS, `<!--ss-head-->\n  ${head}\n  <!--/ss-head-->`);

  if (meta.bodyHtml) {
    /*
      Conținutul e VIZIBIL, nu ascuns: un bloc `display:none` pe care îl vede
      doar robotul e exact ce penalizează motoarele de căutare. Îl scoate
      main.tsx după ce aplicația desenează primul cadru - până atunci e ce
      vede și un om fără JavaScript.

      Stilul minim e inline fiindcă blocul trăiește înainte ca foaia de stil a
      aplicației să conteze, iar o pagină de text nestilizat pe toată lățimea
      ecranului arată ca o eroare.
    */
    html = html.replace(
      BODY_MARKER,
      `<div id="seo-content" style="max-width:52rem;margin:0 auto;padding:2rem 1.25rem;font-family:system-ui,sans-serif;line-height:1.6">${meta.bodyHtml}</div>`,
    );
  }

  return html;
}

/**
 * Rutele fixe din sitemap. Paginile plain-HTML (documentele legale, centrul de
 * siguranță) apar cu adresa FĂRĂ „.html": aia e cea canonică din fișierele
 * respective, deci dublura n-are ce căuta în sitemap.
 */
const STATIC_SITEMAP_ROUTES = [
  { path: '/', priority: '1.0' },
  { path: '/browse', priority: '0.9' },
  { path: '/leaderboard', priority: '0.5' },
  { path: '/global-stats', priority: '0.5' },
  { path: '/safety-center', priority: '0.4' },
  { path: '/help-center', priority: '0.4' },
  { path: '/about-dev', priority: '0.3' },
  { path: '/privacy', priority: '0.3' },
  { path: '/terms', priority: '0.3' },
  ...['en', 'de', 'hu'].flatMap((lang) =>
    ['privacy', 'terms', 'safety-center', 'help-center', 'about-dev'].map((doc) => ({
      path: `/${lang}/${doc}`,
      priority: '0.2',
    })),
  ),
];

async function buildSitemap() {
  const [listings, groups] = await Promise.all([
    fetchPublicListings(SITEMAP_MAX_LISTINGS),
    fetchJson(`${API_URL}/groups/public`),
  ]);

  // Profilurile intră în sitemap prin proprietarii anunțurilor publice, nu
  // printr-o listă de useri: n-avem un endpoint public de utilizatori, și e
  // bine că nu avem - un director complet de membri e cu totul altceva decât
  // profilul cuiva care a listat o carte.
  const owners = new Map();
  for (const item of listings) {
    if (item.user?.id && !owners.has(item.user.id)) owners.set(item.user.id, item.updatedAt);
  }

  const urls = [
    ...STATIC_SITEMAP_ROUTES.map(
      (route) =>
        `  <url><loc>${SITE_URL}${route.path}</loc><priority>${route.priority}</priority></url>`,
    ),
    ...listings.map((item) => {
      const lastmod = new Date(item.updatedAt ?? item.createdAt).toISOString();
      return `  <url><loc>${SITE_URL}/books/${escapeHtml(item.id)}</loc><lastmod>${lastmod}</lastmod><priority>0.7</priority></url>`;
    }),
    ...[...owners.keys()].map(
      (id) => `  <url><loc>${SITE_URL}/users/${escapeHtml(id)}</loc><priority>0.5</priority></url>`,
    ),
    ...(Array.isArray(groups) ? groups : []).map(
      (group) =>
        `  <url><loc>${SITE_URL}/groups/${escapeHtml(group.id)}</loc><priority>0.4</priority></url>`,
    ),
  ];

  return `<?xml version="1.0" encoding="UTF-8"?>\n<urlset xmlns="http://www.sitemaps.org/schemas/sitemap/0.9">\n${urls.join('\n')}\n</urlset>\n`;
}

/**
 * robots.txt.
 *
 * `Disallow` pe rutele personale, `Allow: /` pentru restul. Nu blochează
 * niciun robot anume și nu are reguli separate pe User-Agent: un crawler de AI
 * și Googlebot primesc aceeași listă, ca și paginile.
 */
const ROBOTS_TXT = `User-agent: *
${PRIVATE_PREFIXES.map((prefix) => `Disallow: ${prefix}`).join('\n')}
Allow: /

Sitemap: ${SITE_URL}/sitemap.xml
`;

module.exports = {
  API_URL,
  SITE_URL,
  ROBOTS_TXT,
  buildSitemap,
  isPrivatePath,
  metaFor,
  renderPage,
};
