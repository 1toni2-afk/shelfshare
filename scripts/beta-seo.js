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
const DEFAULT_IMAGE = `${SITE_URL}/icons/Icon-512.png`;

/**
 * Limbile în care se poate servi pagina, în ordinea în care le încearcă
 * negocierea. Aceleași patru ca în aplicație (web/src/lib/i18n/index.ts).
 */
const LOCALES = ['ro', 'en', 'de', 'hu'];
const DEFAULT_LOCALE = 'ro';

/**
 * Alege limba paginii din antetul `Accept-Language`.
 *
 * ASTA NU E CLOAKING, iar distincția merită scrisă: `Accept-Language` e un
 * antet pe care browserul îl trimite ca să spună ce limbă vrea OMUL din fața
 * lui, iar negocierea de conținut pe el e exact mecanismul pentru care a fost
 * inventat. Regula pe care o ținem mai departe e aceeași ca înainte: nu ne
 * uităm NICĂIERI la User-Agent și nu există nicio ramură „pentru Google".
 * Un robot care trimite `Accept-Language: en` primește fix ce primește și un
 * om care trimite `Accept-Language: en`.
 *
 * Perechea obligatorie a acestei funcții e `Vary: Accept-Language` pe răspuns
 * (vezi beta-server.js): fără el, primul vizitator ar umple cache-ul
 * intermediar - inclusiv Cloudflare - cu limba lui, iar toți ceilalți ar primi
 * pagina în limba aia. Vezi nota despre Cloudflare din README-ul de deploy.
 *
 * Ce facem aici trebuie să ajungă la ACELAȘI rezultat ca `initialLocale()` din
 * web/src/lib/i18n/index.ts, care citește `navigator.languages` - aceeași
 * sursă, altă cale. Singura nepotrivire posibilă e omul care și-a ales manual
 * altă limbă în aplicație: pentru el, primul cadru vine în limba browserului,
 * iar aplicația comută la preferința lui salvată o clipă mai târziu. Înainte
 * primul cadru era română pentru toată lumea, deci e strict mai aproape.
 */
function negotiateLocale(acceptLanguage) {
  if (!acceptLanguage) return DEFAULT_LOCALE;

  /*
    `ro-RO,ro;q=0.9,en-US;q=0.8` -> [{tag:'ro', q:1}, ...], sortat descrescător
    după calitate. `q` lipsă înseamnă 1, iar un `q` nevalid e tratat ca 0, ca o
    valoare aiurea să nu urce accidental în fața uneia reale.
  */
  const parsed = String(acceptLanguage)
    .split(',')
    .map((part, index) => {
      const [tag, ...params] = part.trim().split(';');
      const qParam = params.find((p) => p.trim().startsWith('q='));
      const q = qParam ? Number.parseFloat(qParam.trim().slice(2)) : 1;
      // `index` rupe egalitățile păstrând ordinea din antet, care e
      // semnificativă când mai multe limbi au același q.
      return { tag: tag.trim().toLowerCase(), q: Number.isFinite(q) ? q : 0, index };
    })
    .filter((entry) => entry.tag && entry.q > 0)
    .sort((a, b) => b.q - a.q || a.index - b.index);

  for (const entry of parsed) {
    if (entry.tag === '*') return DEFAULT_LOCALE;
    // Potrivim pe limba de bază: „de-AT" și „de-CH" sunt tot germană.
    const base = entry.tag.split('-')[0];
    if (LOCALES.includes(base)) return base;
  }

  return DEFAULT_LOCALE;
}

/** Limba cerută, dacă o cunoaștem; altfel româna. */
function localeOf(locale) {
  return LOCALES.includes(locale) ? locale : DEFAULT_LOCALE;
}

/**
 * Textele fixe ale paginilor pre-randate, pe limbi.
 *
 * Nu citim fișierele .arb ale aplicației: acolo cheile sunt scrise pentru
 * ecrane interactive („Creează cont gratuit"), iar aici avem nevoie de fraze
 * de pagină de prezentare, care sunt altele. În schimb TITLURILE și
 * DESCRIERILE trebuie să rămână în oglindă cu web/src/lib/seo/routes.ts,
 * exact ca înainte - doar că acum oglinda are patru fețe.
 */
const STRINGS = {
  ro: {
    defaultDescription:
      'ShelfShare - schimbă, vinde sau cumpără cărți second-hand de la alți cititori din România.',
    landingTitle: 'ShelfShare - schimbă și cumpără cărți second-hand în România',
    landingDescription:
      'Comunitatea de cititori din România unde cărțile citite își găsesc un cititor nou. Îți listezi cărțile, cauți ce vrei să citești și te înțelegi direct cu proprietarul - prin schimb sau la un preț stabilit de voi.',
    landingHeadline: 'Dă-ți cărțile citite mai departe',
    howItWorks: 'Cum funcționează',
    step1: 'Îți listezi cărțile: scanezi codul ISBN sau cauți titlul, iar datele se completează singure.',
    step2: 'Cauți ce vrei să citești, filtrat după autor, gen sau orașul tău.',
    step3: 'Vă înțelegeți direct în chat și stabiliți predarea. ShelfShare nu ia comision.',
    recentBooks: 'Cărți adăugate recent',
    furtherOn: 'Mai departe',
    fullCatalogue: 'Catalogul complet de cărți',
    readersLeaderboard: 'Clasamentul cititorilor',
    globalStats: 'Statistici globale',
    faq: 'Întrebări frecvente',
    safetyCenter: 'Centrul de siguranță',
    privacy: 'Politica de confidențialitate',
    terms: 'Termeni și condiții',
    browseTitle: 'Catalog de cărți second-hand | ShelfShare',
    browseDescription:
      'Caută printre cărțile puse la schimb sau la vânzare de cititorii ShelfShare. Filtrează după titlu, autor, gen, stare și oraș.',
    browseHeadline: 'Catalog de cărți second-hand',
    noListings: 'Momentan nu sunt cărți listate.',
    book: 'Carte',
    by: 'de',
    city: 'Oraș',
    price: 'Preț',
    availableForSwap: 'Disponibilă pentru schimb',
    condition: 'Stare',
    seeAllBooks: 'Vezi toate cărțile disponibile',
    booksListed: 'Cărți listate',
    booksFrom: (name) => `Cărți de la ${name}`,
    profileDescription: (name, city, count) =>
      `Profilul lui ${name} pe ShelfShare${city ? ` (${city})` : ''} - ${count} cărți listate.`,
    members: 'Membri',
    catalogueLink: 'Catalogul de cărți ShelfShare',
    groupDescription: (name, count) =>
      `${name} - club de lectură pe ShelfShare, cu ${count} membri.`,
    leaderboardTitle: `Clasament cititori | ${SITE_NAME}`,
    leaderboardHeadline: 'Clasament cititori',
    leaderboardDescription: (names) =>
      `Clasamentul cititorilor cu cele mai multe schimburi de cărți pe ShelfShare: ${names} și alții.`,
    swaps: 'schimburi',
    statsTitle: `Statistici globale | ${SITE_NAME}`,
    statsDescription:
      'Statistici globale ShelfShare: cele mai schimbate cărți, cărți în tendințe și autori populari printre cititorii din România.',
    mostSwapped: 'Cele mai schimbate cărți',
    trending: 'În tendințe',
    popularAuthors: 'Autori populari',
    bookTitle: (title, author) => (author ? `${title} de ${author}` : title),
    bookDescription: ({ byline, city, forSale, price }) =>
      `${byline}, disponibilă pe ShelfShare${city ? ` în ${city}` : ''}${
        forSale ? ` - ${price} lei` : ' - disponibilă pentru schimb'
      }.`,
  },
  en: {
    defaultDescription:
      'ShelfShare - swap, sell or buy second-hand books from other readers in Romania.',
    landingTitle: 'ShelfShare - swap and buy second-hand books in Romania',
    landingDescription:
      'The community of readers in Romania where books that have been read find a new reader. You list your books, look for what you want to read and settle it directly with the owner - by swap or at a price the two of you set.',
    landingHeadline: 'Pass your read books on',
    howItWorks: 'How it works',
    step1: 'You list your books: scan the ISBN or search the title and the details fill themselves in.',
    step2: 'You look for what you want to read, filtered by author, genre or your city.',
    step3: 'You agree directly in the chat and settle the handover. ShelfShare takes no commission.',
    recentBooks: 'Recently added books',
    furtherOn: 'Further on',
    fullCatalogue: 'The full book catalogue',
    readersLeaderboard: 'The readers leaderboard',
    globalStats: 'Global statistics',
    faq: 'FAQ',
    safetyCenter: 'Safety Center',
    privacy: 'Privacy policy',
    terms: 'Terms and conditions',
    browseTitle: 'Second-hand book catalogue | ShelfShare',
    browseDescription:
      'Search through the books put up for swap or sale by ShelfShare readers. Filter by title, author, genre, condition and city.',
    browseHeadline: 'Second-hand book catalogue',
    noListings: 'There are no books listed at the moment.',
    book: 'Book',
    by: 'by',
    city: 'City',
    price: 'Price',
    availableForSwap: 'Available for swap',
    condition: 'Condition',
    seeAllBooks: 'See all available books',
    booksListed: 'Books listed',
    booksFrom: (name) => `Books from ${name}`,
    profileDescription: (name, city, count) =>
      `${name}'s profile on ShelfShare${city ? ` (${city})` : ''} - ${count} books listed.`,
    members: 'Members',
    catalogueLink: 'The ShelfShare book catalogue',
    groupDescription: (name, count) =>
      `${name} - a reading club on ShelfShare, with ${count} members.`,
    leaderboardTitle: `Readers leaderboard | ${SITE_NAME}`,
    leaderboardHeadline: 'Readers leaderboard',
    leaderboardDescription: (names) =>
      `The readers with the most book swaps on ShelfShare: ${names} and others.`,
    swaps: 'swaps',
    statsTitle: `Global statistics | ${SITE_NAME}`,
    statsDescription:
      'ShelfShare global statistics: the most swapped books, trending books and popular authors among readers in Romania.',
    mostSwapped: 'Most swapped books',
    trending: 'Trending',
    popularAuthors: 'Popular authors',
    bookTitle: (title, author) => (author ? `${title} by ${author}` : title),
    bookDescription: ({ byline, city, forSale, price }) =>
      `${byline}, available on ShelfShare${city ? ` in ${city}` : ''}${
        forSale ? ` - ${price} lei` : ' - available for swap'
      }.`,
  },
  de: {
    defaultDescription:
      'ShelfShare - tausche, verkaufe oder kaufe gebrauchte Bücher von anderen Lesern in Rumänien.',
    landingTitle: 'ShelfShare - gebrauchte Bücher tauschen und kaufen in Rumänien',
    landingDescription:
      'Die Lesergemeinschaft in Rumänien, in der gelesene Bücher einen neuen Leser finden. Du stellst deine Bücher ein, suchst, was du lesen willst, und einigst dich direkt mit dem Besitzer - per Tausch oder zu einem Preis, den ihr beide festlegt.',
    landingHeadline: 'Gib deine gelesenen Bücher weiter',
    howItWorks: 'So funktioniert es',
    step1: 'Du stellst deine Bücher ein: Scanne die ISBN oder suche den Titel - die Daten füllen sich von selbst aus.',
    step2: 'Du suchst, was du lesen willst, gefiltert nach Autor, Genre oder deiner Stadt.',
    step3: 'Ihr einigt euch direkt im Chat und klärt die Übergabe. ShelfShare nimmt keine Provision.',
    recentBooks: 'Neu hinzugefügte Bücher',
    furtherOn: 'Weiter',
    fullCatalogue: 'Der vollständige Buchkatalog',
    readersLeaderboard: 'Die Leser-Rangliste',
    globalStats: 'Globale Statistiken',
    faq: 'Häufige Fragen',
    safetyCenter: 'Sicherheitszentrum',
    privacy: 'Datenschutzerklärung',
    terms: 'Allgemeine Geschäftsbedingungen',
    browseTitle: 'Katalog gebrauchter Bücher | ShelfShare',
    browseDescription:
      'Durchsuche die Bücher, die ShelfShare-Leser zum Tausch oder Verkauf eingestellt haben. Filtere nach Titel, Autor, Genre, Zustand und Stadt.',
    browseHeadline: 'Katalog gebrauchter Bücher',
    noListings: 'Derzeit sind keine Bücher eingestellt.',
    book: 'Buch',
    by: 'von',
    city: 'Stadt',
    price: 'Preis',
    availableForSwap: 'Zum Tausch verfügbar',
    condition: 'Zustand',
    seeAllBooks: 'Alle verfügbaren Bücher ansehen',
    booksListed: 'Eingestellte Bücher',
    booksFrom: (name) => `Bücher von ${name}`,
    profileDescription: (name, city, count) =>
      `Profil von ${name} auf ShelfShare${city ? ` (${city})` : ''} - ${count} eingestellte Bücher.`,
    members: 'Mitglieder',
    catalogueLink: 'Der ShelfShare-Buchkatalog',
    groupDescription: (name, count) =>
      `${name} - ein Lesekreis auf ShelfShare, mit ${count} Mitgliedern.`,
    leaderboardTitle: `Leser-Rangliste | ${SITE_NAME}`,
    leaderboardHeadline: 'Leser-Rangliste',
    leaderboardDescription: (names) =>
      `Die Leser mit den meisten Buchtauschen auf ShelfShare: ${names} und andere.`,
    swaps: 'Tausche',
    statsTitle: `Globale Statistiken | ${SITE_NAME}`,
    statsDescription:
      'Globale ShelfShare-Statistiken: die meistgetauschten Bücher, Bücher im Trend und beliebte Autoren unter den Lesern in Rumänien.',
    mostSwapped: 'Meistgetauschte Bücher',
    trending: 'Im Trend',
    popularAuthors: 'Beliebte Autoren',
    bookTitle: (title, author) => (author ? `${title} von ${author}` : title),
    bookDescription: ({ byline, city, forSale, price }) =>
      `${byline}, verfügbar auf ShelfShare${city ? ` in ${city}` : ''}${
        forSale ? ` - ${price} Lei` : ' - zum Tausch verfügbar'
      }.`,
  },
  hu: {
    defaultDescription:
      'ShelfShare - cserélj, adj el vagy vásárolj használt könyveket más romániai olvasóktól.',
    landingTitle: 'ShelfShare - használt könyvek cseréje és vásárlása Romániában',
    landingDescription:
      'A romániai olvasók közössége, ahol az elolvasott könyvek új olvasóra találnak. Felteszed a könyveidet, megkeresed, amit olvasni szeretnél, és közvetlenül megegyezel a tulajdonossal - cserével vagy olyan áron, amelyben ti ketten állapodtok meg.',
    landingHeadline: 'Add tovább az elolvasott könyveidet',
    howItWorks: 'Hogyan működik',
    step1: 'Felteszed a könyveidet: beolvasod az ISBN-kódot vagy rákeresel a címre, az adatok pedig maguktól kitöltődnek.',
    step2: 'Megkeresed, amit olvasni szeretnél, szerző, műfaj vagy a városod szerint szűrve.',
    step3: 'Közvetlenül a csevegőben egyeztek meg, és megbeszélitek az átadást. A ShelfShare nem kér jutalékot.',
    recentBooks: 'Nemrég hozzáadott könyvek',
    furtherOn: 'Tovább',
    fullCatalogue: 'A teljes könyvkatalógus',
    readersLeaderboard: 'Az olvasók ranglistája',
    globalStats: 'Globális statisztikák',
    faq: 'Gyakori kérdések',
    safetyCenter: 'Biztonsági központ',
    privacy: 'Adatvédelmi szabályzat',
    terms: 'Felhasználási feltételek',
    browseTitle: 'Használt könyvek katalógusa | ShelfShare',
    browseDescription:
      'Keress a ShelfShare olvasói által cserére vagy eladásra feltett könyvek között. Szűrj cím, szerző, műfaj, állapot és város szerint.',
    browseHeadline: 'Használt könyvek katalógusa',
    noListings: 'Jelenleg nincsenek feltett könyvek.',
    book: 'Könyv',
    by: '-',
    city: 'Város',
    price: 'Ár',
    availableForSwap: 'Cserére elérhető',
    condition: 'Állapot',
    seeAllBooks: 'Az összes elérhető könyv megtekintése',
    booksListed: 'Feltett könyvek',
    booksFrom: (name) => `${name} könyvei`,
    profileDescription: (name, city, count) =>
      `${name} profilja a ShelfShare-en${city ? ` (${city})` : ''} - ${count} feltett könyv.`,
    members: 'Tagok',
    catalogueLink: 'A ShelfShare könyvkatalógusa',
    groupDescription: (name, count) =>
      `${name} - olvasókör a ShelfShare-en, ${count} taggal.`,
    leaderboardTitle: `Olvasók ranglistája | ${SITE_NAME}`,
    leaderboardHeadline: 'Olvasók ranglistája',
    leaderboardDescription: (names) =>
      `A legtöbb könyvcserével rendelkező olvasók a ShelfShare-en: ${names} és mások.`,
    swaps: 'csere',
    statsTitle: `Globális statisztikák | ${SITE_NAME}`,
    statsDescription:
      'ShelfShare globális statisztikák: a legtöbbet cserélt könyvek, a felkapott könyvek és a népszerű szerzők a romániai olvasók körében.',
    mostSwapped: 'A legtöbbet cserélt könyvek',
    trending: 'Felkapott',
    popularAuthors: 'Népszerű szerzők',
    bookTitle: (title, author) => (author ? `${author}: ${title}` : title),
    bookDescription: ({ byline, city, forSale, price }) =>
      `${byline} - elérhető a ShelfShare-en${city ? `, ${city}` : ''}${
        forSale ? `, ${price} lej` : ', cserére'
      }.`,
  },
};

/**
 * Adresa unei pagini plain-HTML in limba ceruta.
 *
 * Paginile EXISTA in toate cele patru limbi (vezi TRANSLATED_PAGES din
 * scripts/static-pages.js), dar linkurile din pagina pre-randata erau scrise
 * fix: `/privacy`. Adica o pagina servita in germana trimitea spre politica de
 * confidentialitate in romana, desi `/de/privacy` era acolo si chiar e in
 * sitemap. Traducerea nu lipsea - lipsea drumul spre ea.
 *
 * Oglinda lui staticPageUrl din web/src/lib/staticPages.ts.
 */
function staticPageUrl(slug, locale) {
  const lang = localeOf(locale);
  return lang === DEFAULT_LOCALE ? `/${slug}` : `/${lang}/${slug}`;
}

/** Textele limbii cerute. */
function s(locale) {
  return STRINGS[localeOf(locale)];
}

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
function bookTitle(title, author, locale) {
  return `${s(locale).bookTitle(title, author)} | ${SITE_NAME}`;
}

async function bookMeta(id, locale) {
  // `/preview`, nu `/books/:id`: e endpointul făcut exact pentru asta și NU
  // incrementează contorul de vizualizări, deci trecerea unui crawler nu umflă
  // statisticile proprietarului.
  const data = await fetchJson(`${API_URL}/books/${encodeURIComponent(id)}/preview`);
  if (!data || !data.title) return null;

  const t = s(locale);
  const byline = t.bookTitle(data.title, data.author);
  // `salePrice` poate rămâne setat pe un anunț doar-de-schimb (câmpul nu se
  // golește când proprietarul oprește vânzarea), deci `isForSale` e sursa de
  // adevăr - altfel am anunța în Google un preț pentru o carte care nu se vinde.
  const price = Number(data.salePrice);
  const forSale = data.isForSale && Number.isFinite(price) && price > 0;
  const description =
    clamp(data.description) ||
    t.bookDescription({ byline, city: data.city, forSale, price });

  return {
    title: bookTitle(data.title, data.author, locale),
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
      ${data.author ? `<p>${t.by} ${escapeHtml(data.author)}</p>` : ''}
      <p>${escapeHtml(description)}</p>
      <ul>
        ${data.city ? `<li>${t.city}: ${escapeHtml(data.city)}</li>` : ''}
        <li>${forSale ? `${t.price}: ${escapeHtml(price)} lei` : t.availableForSwap}</li>
        ${data.condition ? `<li>${t.condition}: ${escapeHtml(data.condition)}</li>` : ''}
      </ul>
      <p><a href="/browse">${t.seeAllBooks}</a></p>
    `,
  };
}

async function profileMeta(id, locale) {
  const data = await fetchJson(`${API_URL}/profile/${encodeURIComponent(id)}`);
  if (!data || !(data.name || data.username)) return null;

  const t = s(locale);
  const name = data.name || data.username;
  const listed = Array.isArray(data.listedBooks) ? data.listedBooks : [];
  const description =
    clamp(data.bio) || t.profileDescription(name, data.city, listed.length);

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
        ${data.city ? `<li>${t.city}: ${escapeHtml(data.city)}</li>` : ''}
        <li>${t.booksListed}: ${escapeHtml(listed.length)}</li>
      </ul>
      ${
        listed.length
          ? `<h2>${escapeHtml(t.booksFrom(name))}</h2><ul>${listed
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

async function groupMeta(id, locale) {
  const data = await fetchJson(`${API_URL}/groups/${encodeURIComponent(id)}`);
  if (!data || !data.name) return null;

  const t = s(locale);
  const description =
    clamp(data.description) || t.groupDescription(data.name, data.memberCount ?? 0);

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
      <ul><li>${t.members}: ${escapeHtml(data.memberCount ?? 0)}</li></ul>
      <p><a href="/browse">${t.catalogueLink}</a></p>
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
async function landingMeta(locale) {
  const listings = await fetchPublicListings(12);
  const t = s(locale);
  const meta = { title: t.landingTitle, description: t.landingDescription };

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
      <h1>${escapeHtml(t.landingHeadline)}</h1>
      <p>${escapeHtml(meta.description)}</p>
      <h2>${escapeHtml(t.howItWorks)}</h2>
      <ol>
        <li>${escapeHtml(t.step1)}</li>
        <li>${escapeHtml(t.step2)}</li>
        <li>${escapeHtml(t.step3)}</li>
      </ol>
      ${
        listings.length
          ? `<h2>${escapeHtml(t.recentBooks)}</h2><ul>${listings
              .map(
                (item) =>
                  `<li><a href="/books/${escapeHtml(item.id)}">${escapeHtml(
                    item.book?.title ?? t.book,
                  )}${item.book?.author ? ` - ${escapeHtml(item.book.author)}` : ''}</a>${
                    item.city ? ` (${escapeHtml(item.city)})` : ''
                  }</li>`,
              )
              .join('')}</ul>`
          : ''
      }
      <h2>${escapeHtml(t.furtherOn)}</h2>
      <ul>
        <li><a href="/browse">${escapeHtml(t.fullCatalogue)}</a></li>
        <li><a href="/leaderboard">${escapeHtml(t.readersLeaderboard)}</a></li>
        <li><a href="/global-stats">${escapeHtml(t.globalStats)}</a></li>
        <li><a href="${staticPageUrl('help-center', locale)}">${escapeHtml(t.faq)}</a></li>
        <li><a href="${staticPageUrl('safety-center', locale)}">${escapeHtml(t.safetyCenter)}</a></li>
        <li><a href="${staticPageUrl('privacy', locale)}">${escapeHtml(t.privacy)}</a></li>
        <li><a href="${staticPageUrl('terms', locale)}">${escapeHtml(t.terms)}</a></li>
      </ul>
    `,
  };
}

async function browseMeta(locale) {
  const listings = await fetchPublicListings(40);
  const t = s(locale);
  const meta = { title: t.browseTitle, description: t.browseDescription };

  return {
    ...meta,
    path: '/browse',
    /*
      Pagina e PARTIAL inchisa si o spunem explicit.

      Aici, in HTML-ul servit, crawlerul primeste catalogul intreg; aplicatia
      arata unui om fara cont doar primele cateva carti, apoi estompeaza (vezi
      GUEST_BROWSE_LIMIT din web/src/features/books/BrowseScreen.tsx).
      Diferenta dintre ce vede robotul si ce vede omul TREBUIE declarata -
      nedeclarata, se citeste ca cloaking, iar pedeapsa e scoaterea din index.
      `isAccessibleForFree: false` e mecanismul oficial pentru exact asta.

      Marcajul sta si in `useDocumentMeta` din ecran: cele doua cai trebuie sa
      spuna acelasi lucru, ca si titlul sau descrierea.
    */
    jsonLd: {
      '@context': 'https://schema.org',
      '@type': 'CollectionPage',
      isAccessibleForFree: false,
      hasPart: {
        '@type': 'WebPageElement',
        isAccessibleForFree: false,
        cssSelector: '.ss-guest-restricted',
      },
    },
    bodyHtml: `
      <h1>${escapeHtml(t.browseHeadline)}</h1>
      <p>${escapeHtml(meta.description)}</p>
      ${
        listings.length
          ? `<ul>${listings
              .map(
                (item) =>
                  `<li><a href="/books/${escapeHtml(item.id)}">${escapeHtml(
                    item.book?.title ?? t.book,
                  )}${item.book?.author ? ` - ${escapeHtml(item.book.author)}` : ''}</a>${
                    item.city ? ` (${escapeHtml(item.city)})` : ''
                  }</li>`,
              )
              .join('')}</ul>`
          : `<p>${escapeHtml(t.noListings)}</p>`
      }
    `,
  };
}

async function leaderboardMeta(locale) {
  const data = await fetchJson(`${API_URL}/profile/leaderboard/national`);
  if (!Array.isArray(data) || data.length === 0) return null;

  const t = s(locale);
  const top = data.slice(0, 10);
  const description = t.leaderboardDescription(
    top
      .slice(0, 3)
      .map((u) => u.name)
      .join(', '),
  );

  return {
    title: t.leaderboardTitle,
    description,
    path: '/leaderboard',
    bodyHtml: `
      <h1>${escapeHtml(t.leaderboardHeadline)}</h1>
      <p>${escapeHtml(description)}</p>
      <ol>${top
        .map(
          (u) =>
            `<li>${escapeHtml(u.name)}${u.city ? ` (${escapeHtml(u.city)})` : ''} - ${escapeHtml(
              u.booksExchangedCount,
            )} ${escapeHtml(t.swaps)}</li>`,
        )
        .join('')}</ol>
    `,
  };
}

async function globalStatsMeta(locale) {
  const [mostShared, trending, authors] = await Promise.all([
    fetchJson(`${API_URL}/books/most-shared`),
    fetchJson(`${API_URL}/books/trending`),
    fetchJson(`${API_URL}/books/popular-authors`),
  ]);
  const shared = Array.isArray(mostShared) ? mostShared.slice(0, 5) : [];
  const trend = Array.isArray(trending) ? trending.slice(0, 5) : [];
  const people = Array.isArray(authors) ? authors.slice(0, 5) : [];
  if (!shared.length && !trend.length && !people.length) return null;

  const t = s(locale);
  const description = t.statsDescription;
  const bookItem = (entry) =>
    `<li>${escapeHtml(entry.book?.title)}${
      entry.book?.author ? ` ${t.by} ${escapeHtml(entry.book.author)}` : ''
    } - ${escapeHtml(entry.count)}</li>`;

  return {
    title: t.statsTitle,
    description,
    path: '/global-stats',
    bodyHtml: `
      <h1>${escapeHtml(t.globalStats)}</h1>
      <p>${escapeHtml(description)}</p>
      ${shared.length ? `<h2>${escapeHtml(t.mostSwapped)}</h2><ul>${shared.map(bookItem).join('')}</ul>` : ''}
      ${trend.length ? `<h2>${escapeHtml(t.trending)}</h2><ul>${trend.map(bookItem).join('')}</ul>` : ''}
      ${
        people.length
          ? `<h2>${escapeHtml(t.popularAuthors)}</h2><ul>${people
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
function metaFor(reqPath, locale) {
  /*
    Limba intră în CHEIA de cache, nu doar în randare. Fără ea, primul
    vizitator ar umple cache-ul cu varianta lui, iar următorul - alt browser,
    altă limbă - ar primi-o pe a lui pentru încă un minut. Exact bug-ul pe
    care `Vary: Accept-Language` îl previne în cache-urile de pe drum; aici e
    aceeași grijă, un nivel mai jos.
  */
  const lang = localeOf(locale);
  if (reqPath === '/') return cached(`landing:${lang}`, () => landingMeta(lang));
  if (reqPath === '/browse') return cached(`browse:${lang}`, () => browseMeta(lang));
  if (reqPath === '/leaderboard')
    return cached(`leaderboard:${lang}`, () => leaderboardMeta(lang));
  if (reqPath === '/global-stats') return cached(`stats:${lang}`, () => globalStatsMeta(lang));

  const book = reqPath.match(/^\/books\/([^/]+)$/);
  if (book) return cached(`book:${lang}:${book[1]}`, () => bookMeta(book[1], lang));

  const user = reqPath.match(/^\/users\/([^/]+)$/);
  if (user) return cached(`user:${lang}:${user[1]}`, () => profileMeta(user[1], lang));

  const group = reqPath.match(/^\/groups\/([^/]+)$/);
  if (group) return cached(`group:${lang}:${group[1]}`, () => groupMeta(group[1], lang));

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
function renderPage(template, meta, locale) {
  const lang = localeOf(locale);
  const title = escapeHtml(meta.title);
  const description = escapeHtml(meta.description || s(lang).defaultDescription);
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

  /*
    `<html lang>` trebuie sa spuna adevarul despre limba in care e scrisa
    pagina: pe el se bazeaza cititoarele de ecran cand aleg pronuntia si
    motoarele de cautare cand decid cui o arata. Shell-ul e salvat cu
    `lang="ro"`, deci pentru orice alta limba il rescriem.
  */
  html = html.replace(/<html([^>]*)\slang="[^"]*"/i, `<html$1 lang="${lang}"`);

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
  LOCALES,
  DEFAULT_LOCALE,
  buildSitemap,
  isPrivatePath,
  metaFor,
  negotiateLocale,
  renderPage,
};
