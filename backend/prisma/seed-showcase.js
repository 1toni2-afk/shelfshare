/**
 * Repopulează baza de date cu un set de date „de vitrină", pentru capturile
 * de ecran din pagina Google Play: doar titluri mari, recunoscute (aceleași
 * din lista curatoriată folosită la onboarding / Book Match), cu COPERTA CEA
 * MAI RECENTĂ găsită în Open Library / Google Books, plus interacțiunile care
 * fac aplicația să arate „vie": istoricul unei cărți pe mai multe schimburi
 * succesive, conversații, oferte, recenzii, favorite, notificări.
 *
 * Rulează pe rând 5 faze (toate implicit, sau doar una cu --only=<fază>):
 *
 *   nume      - scoate prefixul „TEST_" din numele conturilor demo (capturile
 *               nu trebuie să arate „TEST_Andrei Popescu") și pune avatare
 *               celor fără poză.
 *   coperte   - pentru fiecare titlu din vitrină găsește ediția cea mai
 *               recentă CU copertă și scrie `books.coverUrl` (verificând că
 *               imaginea chiar există, nu placeholderul gol al Open Library).
 *   anunturi  - ȘTERGE TOATE anunțurile existente și le recreează folosind
 *               doar titlurile din vitrină: ~5 per cont demo + 8 pe contul
 *               proprietarului, împărțite pe cele 4 categorii (schimb /
 *               vânzare / donație / licitație).
 *   istoric   - 3 cărți cu lanț de re-listări (previousListingId): una cu
 *               istoric mic (2 verigi), una mediu (4), una lung (8), fiecare
 *               verigă cu transferul ei real (ofertă acceptată sau schimb
 *               finalizat, cu evaluări) și cu date întinse pe ani.
 *   chat      - conversații, oferte în curs, favorite, raft public, recenzii,
 *               urmăritori și notificări, centrate pe contul proprietarului.
 *
 * DRY-RUN implicit: fără `--apply` doar spune ce ar face (faza „coperte"
 * chiar interoghează API-urile, ca să poți vedea ce coperte ar pune).
 *
 * ATENȚIE: faza „anunturi" șterge TOATE `UserBook`-urile din baza de date
 * (cascadă: licitații, oferte, cereri de schimb, vizualizări). E o bază de
 * date demo - rulează scriptul doar acolo.
 *
 * Versiune .js (nu .ts): imaginea de producție nu are pnpm/ts-node.
 *
 * Rulare (scriptul nu e în imagine dacă tocmai l-ai scris - copiază-l întâi):
 *   docker cp backend/prisma/seed-showcase.js shelfshare-backend-1:/app/prisma/
 *   docker compose -f docker-compose.prod.yml exec backend \
 *     node prisma/seed-showcase.js            # dry-run
 *   docker compose -f docker-compose.prod.yml exec backend \
 *     node prisma/seed-showcase.js --apply
 */
require('dotenv/config');
const { PrismaClient } = require('@prisma/client');
const { PrismaPg } = require('@prisma/adapter-pg');

const adapter = new PrismaPg({ connectionString: process.env.DATABASE_URL });
const prisma = new PrismaClient({ adapter });

const APPLY = process.argv.includes('--apply');
const ONLY = (process.argv.find((a) => a.startsWith('--only=')) ?? '').split('=')[1] || null;
const PHASES = ['nume', 'coperte', 'dedup', 'anunturi', 'istoric', 'poze', 'chat', 'feed', 'licitatii'];

const OWNER_EMAIL = 'dtoniyi@yahoo.com';
/** Conturi de sistem - nu primesc anunțuri demo și nu se redenumesc. */
const SYSTEM_EMAILS = ['google.review@shelfshare.ro', 'test.chatgpt@shelfshare.ro'];
/** Conturile demo din care se compune „comunitatea" din capturi. */
const DEMO_DOMAINS = ['shelfshare.test', 'shelfshare.demo'];

const SOURCE = 'showcase_seed';
const BOOKS_PER_DEMO_USER = 5;
const OWNER_LISTINGS = 8;
const REQUEST_DELAY_MS = 250;

const DAY = 86_400_000;
const now = new Date();
const ago = (days) => new Date(now.getTime() - days * DAY);
const ahead = (days) => new Date(now.getTime() + days * DAY);

// ---------------------------------------------------------------------------
// Vitrina: titlurile. Aceleași cărți pe care le vede un user nou la onboarding
// (vezi seed-curated-books.js), reduse la cele cu adevărat recunoscibile - o
// captură de ecran trebuie să fie citită dintr-o privire.
// ---------------------------------------------------------------------------

const RO = 'Română';
const EN = 'Engleză';

const SHOWCASE = [
  { title: 'The Alchemist', author: 'Paulo Coelho', genre: 'Ficțiune', language: EN },
  { title: 'Norwegian Wood', author: 'Haruki Murakami', genre: 'Ficțiune', language: EN },
  { title: 'The Kite Runner', author: 'Khaled Hosseini', genre: 'Ficțiune', language: EN },
  { title: 'One Hundred Years of Solitude', author: 'Gabriel Garcia Marquez', genre: 'Ficțiune', language: EN },
  { title: 'A Man Called Ove', author: 'Fredrik Backman', genre: 'Ficțiune', language: EN },
  { title: 'Sapiens: A Brief History of Humankind', author: 'Yuval Noah Harari', genre: 'Non-ficțiune', language: EN },
  { title: 'A Brief History of Time', author: 'Stephen Hawking', genre: 'Non-ficțiune', language: EN, cover: 'https://covers.openlibrary.org/b/id/15139590-L.jpg' },
  { title: 'Cosmos', author: 'Carl Sagan', genre: 'Non-ficțiune', language: EN },
  { title: 'Crime and Punishment', author: 'Fyodor Dostoevsky', genre: 'Clasic', language: EN, cover: 'https://covers.openlibrary.org/b/id/13116014-L.jpg' },
  { title: 'The Great Gatsby', author: 'F. Scott Fitzgerald', genre: 'Clasic', language: EN },
  { title: 'Pride and Prejudice', author: 'Jane Austen', genre: 'Clasic', language: EN },
  { title: 'Anna Karenina', author: 'Leo Tolstoy', genre: 'Clasic', language: EN },
  { title: 'Jane Eyre', author: 'Charlotte Bronte', genre: 'Clasic', language: EN },
  { title: 'Ion', author: 'Liviu Rebreanu', genre: 'Clasic românesc', language: RO },
  { title: 'Moromeții', author: 'Marin Preda', genre: 'Clasic românesc', language: RO },
  { title: 'Baltagul', author: 'Mihail Sadoveanu', genre: 'Clasic românesc', language: RO , cover: 'https://covers.openlibrary.org/b/id/12512713-L.jpg' },
  { title: 'Enigma Otiliei', author: 'George Călinescu', genre: 'Clasic românesc', language: RO },
  { title: 'Amintiri din copilărie', author: 'Ion Creangă', genre: 'Clasic românesc', language: RO },
  { title: 'Maitreyi', author: 'Mircea Eliade', genre: 'Clasic românesc', language: RO , cover: 'https://covers.openlibrary.org/b/id/140608-L.jpg' },
  { title: 'The Hobbit', author: 'J. R. R. Tolkien', genre: 'Fantasy', language: EN },
  { title: 'A Game of Thrones', author: 'George R. R. Martin', genre: 'Fantasy', language: EN, cover: 'https://covers.openlibrary.org/b/id/8134208-L.jpg' },
  {
    title: "Harry Potter and the Philosopher's Stone",
    author: 'J. K. Rowling',
    genre: 'Fantasy',
    language: EN,
    cover: 'https://covers.openlibrary.org/b/id/15155833-L.jpg',
  },
  { title: 'The Name of the Wind', author: 'Patrick Rothfuss', genre: 'Fantasy', language: EN },
  { title: 'Mistborn: The Final Empire', author: 'Brandon Sanderson', genre: 'Fantasy', language: EN , cover: 'https://covers.openlibrary.org/b/id/14658160-L.jpg' },
  { title: 'American Gods', author: 'Neil Gaiman', genre: 'Fantasy', language: EN },
  { title: 'Dune', author: 'Frank Herbert', genre: 'SF', language: EN, cover: 'https://covers.openlibrary.org/b/id/15202643-L.jpg' },
  { title: 'Foundation', author: 'Isaac Asimov', genre: 'SF', language: EN , cover: 'https://covers.openlibrary.org/b/id/14637494-L.jpg' },
  { title: 'The Martian', author: 'Andy Weir', genre: 'SF', language: EN },
  { title: "Ender's Game", author: 'Orson Scott Card', genre: 'SF', language: EN },
  { title: 'Neuromancer', author: 'William Gibson', genre: 'SF', language: EN },
  { title: 'The Girl with the Dragon Tattoo', author: 'Stieg Larsson', genre: 'Thriller', language: EN },
  { title: 'Gone Girl', author: 'Gillian Flynn', genre: 'Thriller', language: EN },
  { title: 'The Da Vinci Code', author: 'Dan Brown', genre: 'Thriller', language: EN },
  { title: 'The Shining', author: 'Stephen King', genre: 'Thriller', language: EN },
  { title: 'Murder on the Orient Express', author: 'Agatha Christie', genre: 'Mister', language: EN },
  { title: 'And Then There Were None', author: 'Agatha Christie', genre: 'Mister', language: EN },
  { title: 'The Name of the Rose', author: 'Umberto Eco', genre: 'Mister', language: EN },
  { title: 'Nineteen Eighty-Four', author: 'George Orwell', genre: 'Distopie', language: EN },
  { title: 'Animal Farm', author: 'George Orwell', genre: 'Distopie', language: EN },
  { title: 'Brave New World', author: 'Aldous Huxley', genre: 'Distopie', language: EN, cover: 'https://covers.openlibrary.org/b/id/8231823-L.jpg' },
  { title: 'Fahrenheit 451', author: 'Ray Bradbury', genre: 'Distopie', language: EN },
  { title: "The Handmaid's Tale", author: 'Margaret Atwood', genre: 'Distopie', language: EN },
  { title: 'The Hunger Games', author: 'Suzanne Collins', genre: 'Distopie', language: EN },
  { title: 'Normal People', author: 'Sally Rooney', genre: 'Romantic', language: EN },
  { title: 'Me Before You', author: 'Jojo Moyes', genre: 'Romantic', language: EN },
  { title: 'Wuthering Heights', author: 'Emily Bronte', genre: 'Romantic', language: EN },
  { title: 'The Book Thief', author: 'Markus Zusak', genre: 'Istoric', language: EN },
  { title: 'All the Light We Cannot See', author: 'Anthony Doerr', genre: 'Istoric', language: EN },
  { title: 'The Pillars of the Earth', author: 'Ken Follett', genre: 'Istoric', language: EN },
  { title: 'Educated', author: 'Tara Westover', genre: 'Biografie', language: EN, cover: 'https://covers.openlibrary.org/b/id/8314077-L.jpg' },
  { title: 'Becoming', author: 'Michelle Obama', genre: 'Biografie', language: EN },
  { title: 'Steve Jobs', author: 'Walter Isaacson', genre: 'Biografie', language: EN },
  { title: 'The Diary of a Young Girl', author: 'Anne Frank', genre: 'Biografie', language: EN },
  {
    title: 'Atomic Habits',
    author: 'James Clear',
    genre: 'Dezvoltare personală',
    language: EN,
    cover: 'https://covers.openlibrary.org/b/id/12539702-L.jpg',
  },
  { title: 'Deep Work', author: 'Cal Newport', genre: 'Dezvoltare personală', language: EN },
  { title: 'The Subtle Art of Not Giving a F*ck', author: 'Mark Manson', genre: 'Dezvoltare personală', language: EN },
  { title: 'Thinking, Fast and Slow', author: 'Daniel Kahneman', genre: 'Psihologie', language: EN },
  { title: "Man's Search for Meaning", author: 'Viktor E. Frankl', genre: 'Psihologie', language: EN },
  { title: 'Meditations', author: 'Marcus Aurelius', genre: 'Filosofie', language: EN },
  { title: 'The Prince', author: 'Niccolo Machiavelli', genre: 'Filosofie', language: EN },
  { title: 'Zero to One', author: 'Peter Thiel', genre: 'Business', language: EN },
  { title: 'Shoe Dog', author: 'Phil Knight', genre: 'Business', language: EN },
  { title: 'Poezii', author: 'Mihai Eminescu', genre: 'Poezie', language: RO },
  { title: 'Leaves of Grass', author: 'Walt Whitman', genre: 'Poezie', language: EN },
  { title: 'The Little Prince', author: 'Antoine de Saint-Exupery', genre: 'Copii', language: EN , cover: 'https://covers.openlibrary.org/b/id/1472834-L.jpg' },
  { title: 'Matilda', author: 'Roald Dahl', genre: 'Copii', language: EN },
  { title: 'Charlie and the Chocolate Factory', author: 'Roald Dahl', genre: 'Copii', language: EN, cover: 'https://covers.openlibrary.org/b/id/10654857-L.jpg' },
  { title: 'The Fault in Our Stars', author: 'John Green', genre: 'Young adult', language: EN },
  { title: 'Six of Crows', author: 'Leigh Bardugo', genre: 'Young adult', language: EN },
  { title: 'Maus', author: 'Art Spiegelman', genre: 'Benzi desenate', language: EN },
  { title: 'Persepolis', author: 'Marjane Satrapi', genre: 'Benzi desenate', language: EN },
  { title: 'Watchmen', author: 'Alan Moore', genre: 'Benzi desenate', language: EN },
];

const CITIES = [
  'București', 'Cluj-Napoca', 'Timișoara', 'Iași', 'Brașov', 'Constanța',
  'Craiova', 'Sibiu', 'Oradea', 'Ploiești', 'Galați', 'Târgu Mureș',
  'Bacău', 'Arad', 'Pitești', 'Baia Mare',
];
const CONDITIONS = ['NOUA', 'FOARTE_BUNA', 'BUNA', 'ACCEPTABILA'];
const EDITIONS = [null, 'Ediție cartonată', 'Ediție de buzunar', 'Ediție ilustrată', 'Ediție aniversară', 'Ediție de colecție'];
const TAG_POOL = [
  'must-read', 'clasic', 'recomandat', 'bestseller', 'premiat', 'de-colectie',
  'stare-impecabila', 'cadou-ideal', 'carte-de-noptiera', 'lectura-de-vara',
  'traducere-buna', 'editie-cartonata',
];
const LISTING_NOTES = [
  'Citită o singură dată, ținută în bibliotecă.',
  'Fără sublinieri, cotor drept.',
  'Am două exemplare, pe acesta îl dau mai departe.',
  'Ediție frumoasă, hârtie groasă.',
  'Am citit-o în vacanță, arată foarte bine.',
  'Colțuri ușor tocite, în rest impecabilă.',
  'Cadou primit dublu, nedeschisă.',
  'O dau cuiva care chiar o citește.',
];

const pick = (arr, i) => arr[((i % arr.length) + arr.length) % arr.length];

// ---------------------------------------------------------------------------
// Utilitare
// ---------------------------------------------------------------------------

const sleep = (ms) => new Promise((r) => setTimeout(r, ms));

function norm(value) {
  return String(value ?? '')
    .normalize('NFD')
    .replace(/[̀-ͯ]/g, '')
    .replace(/[șş]/gi, 's')
    .replace(/[țţ]/gi, 't')
    .toLowerCase()
    .replace(/[^a-z0-9]+/g, ' ')
    .trim();
}

/** `createdAt`/`updatedAt` nu se pot scrie prin Prisma acolo unde sunt
 * `@default(now())`/`@updatedAt` - dar istoricul unei cărți e tocmai despre
 * date din trecut, iar `transferredAt` din API se citește din `updatedAt`. */
async function stamp(table, id, createdAt, updatedAt) {
  await prisma.$executeRawUnsafe(
    `UPDATE "${table}" SET "createdAt" = $1, "updatedAt" = $2 WHERE id = $3`,
    createdAt,
    updatedAt ?? createdAt,
    id,
  );
}

async function stampCreatedOnly(table, id, createdAt) {
  await prisma.$executeRawUnsafe(
    `UPDATE "${table}" SET "createdAt" = $1 WHERE id = $2`,
    createdAt,
    id,
  );
}

async function getJson(url, timeoutMs = 15000) {
  const controller = new AbortController();
  const timer = setTimeout(() => controller.abort(), timeoutMs);
  try {
    const res = await fetch(url, {
      signal: controller.signal,
      headers: { 'User-Agent': 'shelfshare-showcase-seed/1.0' },
    });
    if (!res.ok) return null;
    return await res.json();
  } catch {
    return null;
  } finally {
    clearTimeout(timer);
  }
}

/** Open Library întoarce 200 și un placeholder gri pentru coperțile care nu
 * există; `?default=false` întoarce 404, deci putem verifica de-adevăratelea. */
async function coverExists(url) {
  const probe = url.includes('?') ? `${url}&default=false` : `${url}?default=false`;
  try {
    const res = await fetch(probe, { method: 'HEAD' });
    return res.ok;
  } catch {
    return false;
  }
}

// ---------------------------------------------------------------------------
// Faza „coperte": ediția cea mai recentă care chiar are copertă
// ---------------------------------------------------------------------------

function titleMatches(wanted, got) {
  const a = norm(wanted);
  const b = norm(got);
  if (!b) return false;
  return a === b || a.startsWith(b) || b.startsWith(a) || b.includes(a);
}

function yearOf(publishDate) {
  const m = String(publishDate ?? '').match(/\d{4}/);
  if (!m) return null;
  const y = parseInt(m[0], 10);
  return y >= 1800 && y <= new Date().getFullYear() ? y : null;
}

/**
 * Work-urile Open Library care se potrivesc titlului. Întoarcem mai multe,
 * nu doar primul: pentru clasici, primul rezultat e adesea un „work" stub,
 * fără nicio ediție cu copertă, în timp ce ediția reală stă pe alt work
 * (ex. „Anna Karenina" -> OL36073991W gol vs. OL27513W cu 40 de ediții).
 */
async function findWorks(title, author) {
  const fields = 'key,title,author_name,cover_i,isbn,edition_count,first_publish_year,number_of_pages_median';
  const searchTitle = title.split(':')[0].trim() || title;
  const attempts = [
    () => {
      const p = new URLSearchParams({ title: searchTitle, limit: '8' });
      if (author) p.set('author', author);
      return `https://openlibrary.org/search.json?${p}&fields=${fields}`;
    },
    // Fără diacritice: „Moromeții" nu întoarce nimic pe `title=`, „Morometii" da.
    () => {
      const p = new URLSearchParams({ title: norm(searchTitle), limit: '8' });
      if (author) p.set('author', norm(author));
      return `https://openlibrary.org/search.json?${p}&fields=${fields}`;
    },
    () => {
      const p = new URLSearchParams({ q: `${norm(searchTitle)} ${norm(author ?? '')}`.trim(), limit: '8' });
      return `https://openlibrary.org/search.json?${p}&fields=${fields}`;
    },
  ];

  for (const build of attempts) {
    const data = await getJson(build(), 25000);
    const docs = (data?.docs ?? []).filter((d) => titleMatches(title, d.title));
    if (docs.length > 0) {
      // Întâi work-urile cu multe ediții și cu o copertă cunoscută - acolo e
      // șansa cea mai mare să găsim și o tipăritură recentă.
      docs.sort(
        (a, b) =>
          (b.cover_i ? 1 : 0) - (a.cover_i ? 1 : 0) ||
          (b.edition_count ?? 0) - (a.edition_count ?? 0),
      );
      return docs.slice(0, 3);
    }
    await sleep(REQUEST_DELAY_MS);
  }
  return [];
}

/**
 * Coperta celei mai RECENTE ediții cu imagine, căutată prin toate work-urile
 * potrivite. Ordinea contează pentru cerința „coperta cea mai actuală":
 * `cover_i` din search.json e coperta ediției pe care Open Library o
 * consideră reprezentativă (de regulă una veche), nu a ultimei tipărituri -
 * de aceea o folosim doar ca rezervă.
 */
async function latestCover(works, isbnHint, wantedLanguage, wantedTitle) {
  const candidates = [];
  // Codurile de limbă folosite de Open Library pe ediții (`/languages/eng`).
  const wantedCode = wantedLanguage === RO ? 'rum' : 'eng';

  for (const work of works) {
    const editions = await getJson(
      `https://openlibrary.org${work.key}/editions.json?limit=400`,
      30000,
    );
    for (const e of editions?.entries ?? []) {
      const coverId = (e.covers ?? []).find((c) => typeof c === 'number' && c > 0);
      if (!coverId) continue;
      // Multe dintre cele mai noi „ediții" sunt audiobook-uri sau scanări -
      // coperta lor nu seamănă cu a cărții pe care o știe lumea.
      const format = `${e.physical_format ?? ''} ${(e.publishers ?? []).join(' ')} ${e.title ?? ''}`;
      if (/audio|cassette|\bcd\b|mp3|spoken|ebook/i.test(format)) continue;
      // Boxset-urile au pe copertă cinci cotoare, nu cartea cerută.
      if (/trilogy|boxed|box set|collection set|\d+\s*books?\b|omnibus/i.test(format)) continue;
      const codes = (e.languages ?? []).map((l) => String(l?.key ?? '').split('/').pop());
      candidates.push({
        // O ediție recentă în spaniolă e tot „cea mai actuală", dar pe cardul
        // din aplicație arată ca altă carte („Hàbits atòmics" cu titlul
        // „Atomic Habits" dedesubt) - deci limba și titlul bat anul. Titlul
        // ediției e semnalul cel mai sigur: multe traduceri nu au deloc
        // câmpul `languages` completat.
        // Limba trebuie declarată EXPLICIT: „fără câmp de limbă" a lăsat să
        // treacă traduceri (Sapiens în portugheză, Normal People în franceză)
        // doar fiindcă erau ediții mai noi decât orice tipăritură englezească.
        preferred: titleMatches(wantedTitle, e.title) && codes.includes(wantedCode),
        year: yearOf(e.publish_date) ?? 0,
        url: `https://covers.openlibrary.org/b/id/${coverId}-L.jpg`,
        label: `ediție ${e.publish_date ?? '?'}${codes.length ? ` [${codes[0]}]` : ''}`,
      });
    }
    await sleep(REQUEST_DELAY_MS);
  }

  // Doar edițiile în limba cerută, cu titlul cerut, intră în cursă. O ediție
  // care nu trece filtrul nu e „mai bună decât nimic": rezerva potrivită e
  // coperta reprezentativă a work-ului, adăugată mai jos, care e aproape
  // mereu ediția pe care o recunoaște toată lumea.
  const ordered = candidates.filter((c) => c.preferred).sort((a, b) => b.year - a.year);
  candidates.length = 0;
  candidates.push(...ordered);

  for (const work of works) {
    if (!work.cover_i) continue;
    candidates.push({
      preferred: true,
      year: 0,
      url: `https://covers.openlibrary.org/b/id/${work.cover_i}-L.jpg`,
      label: 'copertă reprezentativă OL',
    });
  }
  if (isbnHint) {
    candidates.push({
      preferred: true,
      year: 0,
      url: `https://covers.openlibrary.org/b/isbn/${isbnHint}-L.jpg`,
      label: 'copertă după ISBN',
    });
  }

  for (const c of candidates.slice(0, 14)) {
    if (await coverExists(c.url)) return c;
    await sleep(80);
  }
  return null;
}

/** Rezervă când Open Library nu are nicio copertă utilizabilă. Miniatura
 * Google Books vine la 128px; `zoom=3` cere aceeași imagine mai mare. */
async function googleCover(title, author) {
  const parts = [`intitle:${encodeURIComponent(title)}`];
  if (author) parts.push(`inauthor:${encodeURIComponent(author)}`);
  const data = await getJson(
    `https://www.googleapis.com/books/v1/volumes?q=${parts.join('+')}&maxResults=5&orderBy=newest`,
  );
  const item = (data?.items ?? []).find((it) => titleMatches(title, it.volumeInfo?.title));
  const thumb = item?.volumeInfo?.imageLinks?.thumbnail;
  if (!thumb) return null;
  return {
    year: yearOf(item.volumeInfo?.publishedDate) ?? 0,
    url: thumb.replace('http://', 'https://').replace('zoom=1', 'zoom=3').replace('&edge=curl', ''),
    label: 'Google Books',
    meta: item.volumeInfo,
  };
}

// ---------------------------------------------------------------------------
// Căutarea/creerea cărților din catalog
// ---------------------------------------------------------------------------

/**
 * Catalogul are ~3,7M de rânduri importate din Open Library, deci căutarea
 * per titlu se face O SINGURĂ dată, în bloc (`title in (...)`), nu câte un
 * scan pentru fiecare titlu din vitrină.
 */
async function resolveShowcaseBooks() {
  const rows = await prisma.book.findMany({
    where: { title: { in: SHOWCASE.map((b) => b.title) } },
    select: {
      id: true, title: true, author: true, isbn: true, coverUrl: true,
      genre: true, language: true, pageCount: true, publishedYear: true,
      description: true, source: true,
      _count: { select: { userBooks: true } },
    },
  });

  const resolved = [];
  for (const entry of SHOWCASE) {
    const authorKey = norm(entry.author).split(' ').pop(); // numele de familie
    const matches = rows.filter(
      (r) => norm(r.title) === norm(entry.title) && norm(r.author ?? '').includes(authorKey),
    );
    // Preferăm rândul „îngrijit" (curatoriat / cu copertă), nu unul oarecare
    // din importul masiv, ca anunțurile să nu pice pe un duplicat sărac.
    matches.sort((a, b) => {
      // Rândul pe care stau deja anunțurile bate orice: altfel faza „coperte"
      // poate muta vitrina pe alt duplicat decât cel ales de „dedup", iar în
      // feed reapare același titlu de două ori.
      if (a._count.userBooks !== b._count.userBooks) {
        return b._count.userBooks - a._count.userBooks;
      }
      const score = (r) =>
        (r.source === 'curated_seed' ? 4 : 0) +
        (r.source === SOURCE ? 4 : 0) +
        (r.coverUrl ? 2 : 0) +
        (r.description ? 1 : 0);
      // Departajare stabilă: fără ea, două rulări pot alege rânduri diferite
      // pentru același titlu și anunțurile ajung împrăștiate pe duplicate.
      return score(b) - score(a) || a.id.localeCompare(b.id);
    });
    resolved.push({ entry, book: matches[0] ?? null });
  }
  return resolved;
}

// ---------------------------------------------------------------------------
// FAZA 1: nume + avatare
// ---------------------------------------------------------------------------

async function phaseNume(users) {
  console.log('\n=== FAZA: nume ===');
  let renamed = 0;
  let avatars = 0;

  for (const [i, u] of users.entries()) {
    const data = {};
    const name = (u.name ?? '').trim();
    if (name.startsWith('TEST_')) data.name = name.slice(5);
    // pravatar.cc nu trimite antet CORS, iar Flutter web încarcă imaginile
    // prin XHR - avatarele de demo rămâneau goale exact în capturi. DiceBear
    // trimite `Access-Control-Allow-Origin: *` și e desen, nu poză de om real.
    if (!u.profileImage || u.profileImage.includes('pravatar.cc')) {
      data.profileImage =
        'https://api.dicebear.com/9.x/avataaars/png?size=300&seed=' +
        encodeURIComponent(u.username ?? u.email);
    }
    if (!u.city) data.city = pick(CITIES, i);
    if (Object.keys(data).length === 0) continue;

    if (data.name) renamed++;
    if (data.profileImage) avatars++;
    if (APPLY) await prisma.user.update({ where: { id: u.id }, data });
  }

  console.log(`  ${renamed} nume fără prefix „TEST_", ${avatars} avatare puse.`);
}

// ---------------------------------------------------------------------------
// FAZA 2: coperte
// ---------------------------------------------------------------------------

async function phaseCoperte(resolved) {
  console.log('\n=== FAZA: coperte ===');
  let updated = 0;
  let created = 0;
  let failed = 0;

  for (const item of resolved) {
    const { entry } = item;
    // „Cea mai recentă ediție" dă uneori o copertă pe care nimeni n-o
    // recunoaște (un boxset, o scanare a paginii de titlu). Pentru titlurile
    // alea, `cover` din listă fixează coperta clasică și sărim căutarea.
    if (entry.cover) {
      updated++;
      if (APPLY && item.book) {
        item.book = await prisma.book.update({
          where: { id: item.book.id },
          data: {
            coverUrl: entry.cover,
            title: entry.title,
            author: entry.author,
            genre: entry.genre,
            language: entry.language,
            popularityScore: 0.95,
          },
        });
      }
      console.log(`  ${entry.title.padEnd(46).slice(0, 46)}    -  copertă fixată manual`);
      continue;
    }

    const works = await findWorks(entry.title, entry.author);
    await sleep(REQUEST_DELAY_MS);
    const work = works[0] ?? null;

    let cover = await latestCover(
      works,
      item.book?.isbn ?? work?.isbn?.[0],
      entry.language,
      entry.title,
    );
    if (!cover) {
      // Google Books e doar plasă de siguranță: neautentificat, cota zilnică
      // per IP se epuizează repede (429) și atunci întoarce null.
      cover = await googleCover(entry.title, entry.author);
      await sleep(REQUEST_DELAY_MS);
    }

    // Coperta veche din catalog contează doar dacă chiar se încarcă: multe
    // rânduri au un URL /b/isbn/... care întoarce 404, iar aplicația arată în
    // locul ei un dreptunghi gol - exact ce nu vrem într-o captură de ecran.
    const keptCover = !cover && item.book?.coverUrl ? await coverExists(item.book.coverUrl) : false;
    if (!cover && !keptCover) {
      failed++;
      console.log(`  FĂRĂ COPERTĂ  ${entry.title} (rămâne în afara vitrinei)`);
      if (APPLY && item.book?.coverUrl) {
        await prisma.book.update({ where: { id: item.book.id }, data: { coverUrl: null } });
      }
      // Fără copertă titlul nu intră în anunțuri/istoric - vezi filtrul pe
      // `book.coverUrl` din fazele următoare.
      if (item.book) item.book.coverUrl = null;
      continue;
    }

    const data = {
      // Titlul și autorul se rescriu din listă: rândurile venite din importul
      // Open Library au adesea forma de catalog de bibliotecă („Tolstoy, Leo,
      // graf, 1828-1910"), care pe cardul din aplicație arată ca o eroare.
      title: entry.title,
      author: entry.author,
      genre: entry.genre,
      language: entry.language,
      popularityScore: 0.95,
    };
    // Fără copertă nouă păstrăm ce era deja în catalog - restul câmpurilor
    // (gen canonic, popularitate) se scriu oricum.
    if (cover) data.coverUrl = cover.url;

    if (!item.book) {
      // Titlu lipsă din catalog (rar - lista e din cea curatoriată): îl creăm,
      // ca vitrina să nu aibă goluri.
      data.isbn = work?.isbn?.[0] ?? null;
      data.pageCount = work?.number_of_pages_median ?? null;
      data.publishedYear = work?.first_publish_year ?? null;
      data.source = SOURCE;
      created++;
      if (APPLY) {
        // ISBN-ul întors de Open Library poate exista deja pe alt rând din
        // catalog (titlu scris altfel la importul masiv) - `isbn` e unic,
        // deci în cazul ăla actualizăm rândul acela în loc să creăm unul nou.
        const byIsbn = data.isbn
          ? await prisma.book.findUnique({ where: { isbn: data.isbn } })
          : null;
        item.book = byIsbn
          ? await prisma.book.update({ where: { id: byIsbn.id }, data: { ...data, isbn: undefined } })
          : await prisma.book.create({ data });
      }
    } else {
      updated++;
      if (APPLY) {
        item.book = await prisma.book.update({
          where: { id: item.book.id },
          data: {
            ...data,
            pageCount: item.book.pageCount ?? work?.number_of_pages_median ?? null,
            publishedYear: item.book.publishedYear ?? work?.first_publish_year ?? null,
          },
        });
      }
    }

    console.log(
      cover
        ? `  ${entry.title.padEnd(46).slice(0, 46)} ${String(cover.year || '?').padStart(4)}  ${cover.label}`
        : `  ${entry.title.padEnd(46).slice(0, 46)}    -  păstrez coperta existentă`,
    );
    await sleep(REQUEST_DELAY_MS);
  }

  console.log(`  ${updated} coperte actualizate, ${created} cărți create, ${failed} fără copertă.`);
}

// ---------------------------------------------------------------------------
// FAZA 3: anunțuri
// ---------------------------------------------------------------------------

const CATEGORY_CYCLE = ['swap', 'sale', 'donation', 'auction'];

function listingFor(category, book, entry, user, i, j) {
  const condition = pick(CONDITIONS, i + j);
  const edition = pick(EDITIONS, i * 3 + j);
  const cover = book.coverUrl ?? null;
  const base = {
    userId: user.id,
    bookId: book.id,
    condition,
    // Un exemplar poate fi în altă limbă decât ediția originală a titlului.
    language: entry.language === RO ? RO : (i + j) % 3 === 0 ? RO : EN,
    edition,
    isHardcover: (i + j) % 2 === 0,
    photos: cover ? [cover] : [],
    mainPhotoUrl: cover,
    description: pick(LISTING_NOTES, i * 2 + j),
    tags: [pick(TAG_POOL, i + j), pick(TAG_POOL, i + j + 5)].filter((t, k, a) => a.indexOf(t) === k),
    city: (i + j) % 5 === 0 ? pick(CITIES, i + j + 3) : (user.city ?? pick(CITIES, i)),
    viewCount: 8 + ((i * 7 + j * 13) % 180),
    createdAt: ago(1 + ((i * 3 + j * 5) % 60)),
  };

  switch (category) {
    case 'swap':
      return { ...base, availableForSwap: true, isForSale: false, swapSalePrice: (i + j) % 3 === 0 ? 20 + ((i + j) % 5) * 5 : null };
    case 'sale':
      return { ...base, availableForSwap: false, isForSale: true, salePrice: 22 + ((i * 5 + j * 11) % 55), isNegotiable: (i + j) % 2 === 0 };
    case 'donation':
      return { ...base, availableForSwap: true, isForSale: true, salePrice: 0, isNegotiable: false };
    case 'auction':
      return { ...base, availableForSwap: false, isForSale: false, isAuction: true };
    default:
      throw new Error(`Categorie necunoscută: ${category}`);
  }
}

async function phaseAnunturi(resolved, demoUsers, owner) {
  console.log('\n=== FAZA: anunturi ===');
  const usable = resolved.filter((r) => r.book && r.book.coverUrl);
  if (usable.length < 20) {
    throw new Error(`Doar ${usable.length} titluri rezolvate - rulează întâi faza „coperte" cu --apply.`);
  }

  const existing = await prisma.userBook.count();
  console.log(`  șterg ${existing} anunțuri existente (cascadă: licitații, oferte, cereri, vizualizări)`);
  if (APPLY) await prisma.userBook.deleteMany({});

  const targets = [
    ...demoUsers.map((u) => ({ user: u, count: BOOKS_PER_DEMO_USER })),
    { user: owner, count: OWNER_LISTINGS },
  ];

  let created = 0;
  for (const [i, target] of targets.entries()) {
    // Pas coprim cu lungimea listei: useri consecutivi nu primesc titluri
    // vecine, dar în ansamblu fiecare titlu apare de câteva ori (realist:
    // aceeași carte listată de mai mulți oameni, în orașe diferite).
    const step = 7;
    for (let j = 0; j < target.count; j++) {
      const { entry, book } = usable[(i * 3 + j * step) % usable.length];
      const category = CATEGORY_CYCLE[(i + j) % CATEGORY_CYCLE.length];
      const data = listingFor(category, book, entry, target.user, i, j);
      if (target.user.isPremium && j === 0) data.isPromoted = true;

      if (APPLY) {
        const ub = await prisma.userBook.create({ data });
        if (category === 'auction') {
          const start = 20 + ((i + j) % 8) * 5;
          await prisma.auction.create({
            data: {
              userBookId: ub.id,
              startingPrice: start,
              currentPrice: start + ((i + j) % 4) * 5,
              endsAt: ahead(1 + ((i + j) % 6)),
              status: 'ACTIVE',
            },
          });
        }
      }
      created++;
    }
  }

  console.log(`  ${created} anunțuri noi (${demoUsers.length} conturi demo + proprietarul).`);
}

// ---------------------------------------------------------------------------
// FAZA 4: istoricul cărților (lanțul de re-listări)
// ---------------------------------------------------------------------------

/**
 * Trei cărți cu istoric de lungimi diferite - exact ce se vede în secțiunea
 * „Istoricul acestei cărți" de pe pagina anunțului (GET /books/:id/history):
 * fiecare verigă e un anunț separat, cu proprietarul, starea declarată și
 * felul transferului (vânzare / schimb).
 */
const CHAINS = [
  { label: 'mic', title: 'Normal People', links: 2, spanDays: 90, endsWithOwner: false },
  { label: 'mediu', title: 'The Book Thief', links: 4, spanDays: 420, endsWithOwner: false },
  { label: 'lung', title: 'The Little Prince', links: 8, spanDays: 1250, endsWithOwner: true },
];

const CHAIN_NOTES = [
  'Cumpărată nouă din librărie, am ținut-o doi ani în bibliotecă.',
  'Am primit-o la schimb și am citit-o într-un weekend.',
  'A stat pe noptieră o iarnă întreagă. O trimit mai departe.',
  'Am citit-o în tren, între Cluj și București. Cotorul e încă drept.',
  'Cadou de la cineva care a primit-o tot prin ShelfShare.',
  'Am subliniat două pagini cu creionul, restul e intact.',
  'A trecut prin multe mâini și încă arată bine.',
  'O păstrez acum eu - poate merge mai departe la anul.',
];

async function chainTransfer(kind, fromUser, toUser, listing, at, price) {
  if (kind === 'sale') {
    const offer = await prisma.priceOffer.create({
      data: {
        buyerId: toUser.id,
        ownerId: fromUser.id,
        userBookId: listing.id,
        amount: price,
        message: 'Aș vrea să o iau, dacă mai e disponibilă.',
        status: 'ACCEPTED',
        acceptedAt: at,
        meetingTime: at,
        meetingLocation: `Librăria Humanitas, ${fromUser.city ?? 'București'}`,
        meetingAcceptedAt: at,
        buyerSafetyAckAt: at,
        ownerSafetyAckAt: at,
        buyerDoneAt: at,
        ownerDoneAt: at,
      },
    });
    await stamp('price_offers', offer.id, new Date(at.getTime() - 3 * DAY), at);
    return offer;
  }

  const exchange = await prisma.exchangeRequest.create({
    data: {
      requesterId: toUser.id,
      ownerId: fromUser.id,
      requestedBookId: listing.id,
      message: 'Te-ar interesa un schimb pentru ea?',
      status: 'COMPLETED',
      acceptedAt: new Date(at.getTime() - 2 * DAY),
      meetingTime: at,
      meetingLocation: `Ceainăria Centrală, ${fromUser.city ?? 'Cluj-Napoca'}`,
      meetingAcceptedAt: new Date(at.getTime() - 2 * DAY),
      requesterSafetyAckAt: at,
      ownerSafetyAckAt: at,
      requesterDoneAt: at,
      ownerDoneAt: at,
      requesterRatingForOwner: 5,
      ownerRatingForRequester: 5,
      requesterReviewForOwner: 'Punctual și cartea exact cum arăta în poze.',
      ownerReviewForRequester: 'Discuție ușoară, ne-am întâlnit fix la ora stabilită.',
      requesterCommunicationForOwner: 5,
      requesterPunctualityForOwner: 5,
      requesterConditionForOwner: 5,
      ownerCommunicationForRequester: 5,
      ownerPunctualityForRequester: 4,
    },
  });
  await stamp('exchange_requests', exchange.id, new Date(at.getTime() - 4 * DAY), at);
  return exchange;
}

/**
 * Catalogul importat din Open Library are mai multe rânduri pentru același
 * titlu (ediții diferite ale aceleiași opere). Fără curățare, feed-ul arată
 * „The Little Prince" de două ori, cu coperte diferite, iar „Cărți similare"
 * se umple de clone. Păstrăm rândul cu cele mai multe anunțuri, mutăm
 * anunțurile celorlalte pe el și scoatem duplicatele din vitrină.
 *
 * Duplicatele NU se șterg din catalog: sunt rânduri venite din importul Open
 * Library, cu ISBN-ul lor propriu, iar un rând fără anunțuri nu apare oricum
 * nicăieri în aplicație (feed-ul, „Cărți similare" și căutarea merg pe
 * `user_books`). Le luăm doar marcajul de vitrină (popularityScore), ca Book
 * Match să nu le mai împingă la cold start.
 */
async function phaseDedup(resolved) {
  console.log('\n=== FAZA: dedup ===');
  const keepIds = new Set(resolved.filter((r) => r.book).map((r) => r.book.id));

  const showcase = await prisma.book.findMany({
    where: { popularityScore: 0.95 },
    select: { id: true, title: true, _count: { select: { userBooks: true } } },
  });

  const byTitle = new Map();
  for (const b of showcase) {
    const list = byTitle.get(b.title) ?? [];
    list.push(b);
    byTitle.set(b.title, list);
  }

  let merged = 0;
  let moved = 0;
  for (const [title, rows] of byTitle) {
    if (rows.length < 2) continue;
    // Rândul „bun" e cel ales de resolver (cel pe care stau coperta și
    // metadatele scrise acum); dacă nu e printre ele, cel cu cele mai multe
    // anunțuri. Restul dispar.
    const keeper =
      rows.find((r) => keepIds.has(r.id)) ??
      rows.sort((a, b) => b._count.userBooks - a._count.userBooks)[0];

    for (const row of rows) {
      if (row.id === keeper.id) continue;
      merged++;
      moved += row._count.userBooks;
      if (APPLY) {
        await prisma.userBook.updateMany({
          where: { bookId: row.id },
          data: { bookId: keeper.id },
        });
        await prisma.book.update({
          where: { id: row.id },
          data: { popularityScore: null },
        });
      }
    }
    console.log(`  ${title.padEnd(46).slice(0, 46)} ${rows.length} rânduri -> 1`);
  }

  console.log(`  ${merged} duplicate scoase din vitrină, ${moved} anunțuri mutate pe rândul păstrat.`);
}

/**
 * Poza anunțului = coperta actuală a cărții. Faza „coperte" poate fi rulată
 * din nou după ce anunțurile există deja (ex. ca să prindă o ediție mai
 * nouă), iar atunci `photos`/`mainPhotoUrl` rămân pe URL-ul vechi - cardul
 * din feed ar arăta o copertă, pagina cărții alta.
 */
/**
 * „Feed"-ul (GET /profile/activity-feed) arată DOAR activitatea userilor pe
 * care îi urmărești, recompusă din date reale: anunțuri noi, cărți terminate,
 * vânzări încheiate și schimburi finalizate. Ca să aibă ce arăta la capturi,
 * generăm pentru conturile urmărite toate felurile de eveniment: schimburi
 * carte-contra-carte, vânzări încheiate, cărți terminate și progres de lectură.
 *
 * Cărțile schimbate primesc anunțuri PROPRII, marcate ca transferate - un
 * schimb finalizat pe un anunț activ l-ar scoate din feed-ul de căutare
 * (permanentlyTransferred), iar vitrina de anunțuri trebuie să rămână plină.
 */
const FEED_TAG = 'schimb-finalizat';
const FEED_EXCHANGES_PER_USER = 2;
const FEED_SALES_PER_USER = 1;
const FEED_FINISHED_PER_USER = 2;
const FEED_PROGRESS_PER_USER = 1;

const FEED_REVIEWS = [
  ['Ne-am întâlnit în centru, totul ca la carte.', 'Om de treabă, cartea impecabilă.'],
  ['A venit fix la ora stabilită.', 'Recomand, discuție plăcută despre cărți.'],
  ['Cartea arăta mai bine decât în poze.', 'Schimb rapid, fără bătăi de cap.'],
  ['Ne-am înțeles din primul mesaj.', 'Mulțumesc pentru schimb!'],
];

async function phaseFeed(resolved, demoUsers, owner) {
  console.log('\n=== FAZA: feed ===');
  const usable = resolved.filter((r) => r.book && r.book.coverUrl);

  const follows = await prisma.follow.findMany({
    where: { followerId: owner.id },
    select: { followingId: true },
  });
  const followedIds = new Set(follows.map((f) => f.followingId));
  const followed = demoUsers.filter((u) => followedIds.has(u.id));

  if (followed.length === 0) {
    throw new Error('Proprietarul nu urmărește niciun cont demo - rulează întâi faza „chat".');
  }

  // Idempotent: schimburile generate aici stau pe anunțuri marcate cu
  // FEED_TAG, deci a doua rulare le rescrie, nu le adună.
  const old = await prisma.userBook.count({ where: { tags: { has: FEED_TAG } } });
  console.log(`  ${old} anunțuri de schimb generate anterior (se refac)`);
  if (APPLY) await prisma.userBook.deleteMany({ where: { tags: { has: FEED_TAG } } });

  let created = 0;
  for (const [i, user] of followed.entries()) {
    for (let k = 0; k < FEED_EXCHANGES_PER_USER; k++) {
      // Partenerul de schimb e alt cont demo (poate fi și el urmărit -
      // evenimentul apare o singură dată, atribuit requesterului).
      const counterpart = demoUsers.find(
        (u, n) => u.id !== user.id && n === (i * 7 + k * 3 + 11) % demoUsers.length,
      ) ?? demoUsers.find((u) => u.id !== user.id);
      const wanted = usable[(i * 5 + k * 2) % usable.length];
      const given = usable[(i * 5 + k * 2 + 17) % usable.length];
      const at = ago(1 + ((i * 4 + k * 3) % 26));

      console.log(
        `  ${(user.name ?? user.email).padEnd(20)} „${wanted.entry.title}" <-> ` +
          `„${given.entry.title}" cu ${counterpart.name ?? counterpart.email}`,
      );
      created++;
      if (!APPLY) continue;

      const listedAt = new Date(at.getTime() - 12 * DAY);
      const sides = [
        { user, item: wanted },
        { user: counterpart, item: given },
      ];
      // listings[0] = cartea cerută (a userului urmărit), listings[1] = cea dată.
      const listings = [];
      for (const side of sides) {
        const listing = await prisma.userBook.create({
          data: {
            userId: side.user.id,
            bookId: side.item.book.id,
            condition: pick(CONDITIONS, i + k),
            language: side.item.entry.language,
            photos: [side.item.book.coverUrl],
            mainPhotoUrl: side.item.book.coverUrl,
            description: pick(LISTING_NOTES, i + k),
            tags: [FEED_TAG],
            city: side.user.city ?? pick(CITIES, i),
            viewCount: 20 + ((i * 9 + k * 5) % 60),
            createdAt: listedAt,
            availableForSwap: false,
            isForSale: false,
            permanentlyTransferred: true,
          },
        });
        await stamp('user_books', listing.id, listedAt, at);
        listings.push(listing);
      }

      const [reviewA, reviewB] = pick(FEED_REVIEWS, i + k);
      const exchange = await prisma.exchangeRequest.create({
        data: {
          requesterId: counterpart.id,
          ownerId: user.id,
          requestedBookId: listings[0].id,
          offeredBookId: listings[1].id,
          message: `Fac schimb „${given.entry.title}" pentru „${wanted.entry.title}"?`,
          status: 'COMPLETED',
          acceptedAt: new Date(at.getTime() - 3 * DAY),
          meetingTime: at,
          meetingLocation: `Librăria Cărturești, ${user.city ?? 'București'}`,
          meetingProposedBy: user.id,
          meetingAcceptedAt: new Date(at.getTime() - 3 * DAY),
          requesterSafetyAckAt: at,
          ownerSafetyAckAt: at,
          requesterDoneAt: at,
          ownerDoneAt: at,
          requesterRatingForOwner: 5,
          ownerRatingForRequester: (i + k) % 4 === 0 ? 4 : 5,
          requesterReviewForOwner: reviewA,
          ownerReviewForRequester: reviewB,
          requesterCommunicationForOwner: 5,
          requesterPunctualityForOwner: 5,
          requesterConditionForOwner: 5,
          ownerCommunicationForRequester: 5,
          ownerPunctualityForRequester: 4,
          ownerConditionForRequester: 5,
        },
      });
      await stamp('exchange_requests', exchange.id, new Date(at.getTime() - 5 * DAY), at);
    }
  }

  console.log(`  ${created} schimburi finalizate pe ${followed.length} conturi urmărite.`);

  // --- Vânzări încheiate („cineva a vândut X cu Y lei") ---
  // Feed-ul le atribuie VÂNZĂTORULUI (vezi maparea `sale` din
  // profile.service.ts), deci `ownerId` trebuie să fie contul urmărit;
  // cumpărătorul poate fi oricine.
  let sales = 0;
  for (const [i, user] of followed.entries()) {
    for (let k = 0; k < FEED_SALES_PER_USER; k++) {
      const item = usable[(i * 11 + k * 3 + 5) % usable.length];
      // Cumpărătorul nu poate fi vânzătorul: mergem la următorul cont demo
      // dacă indexul calculat cade chiar pe el (altfel pierdeam o vânzare).
      let buyerIndex = (i * 13 + k * 7 + 3) % demoUsers.length;
      if (demoUsers[buyerIndex].id === user.id) {
        buyerIndex = (buyerIndex + 1) % demoUsers.length;
      }
      const buyer = demoUsers[buyerIndex];
      const at = ago(2 + ((i * 5 + k * 4) % 24));
      const price = 28 + ((i * 7 + k * 5) % 42);

      console.log(`  ${(user.name ?? user.email).padEnd(20)} a vândut „${item.entry.title}" cu ${price} lei`);
      sales++;
      if (!APPLY) continue;

      const listedAt = new Date(at.getTime() - 15 * DAY);
      const listing = await prisma.userBook.create({
        data: {
          userId: user.id,
          bookId: item.book.id,
          condition: pick(CONDITIONS, i + k + 1),
          language: item.entry.language,
          photos: [item.book.coverUrl],
          mainPhotoUrl: item.book.coverUrl,
          description: pick(LISTING_NOTES, i * 3 + k),
          tags: [FEED_TAG],
          city: user.city ?? pick(CITIES, i + 2),
          viewCount: 35 + ((i * 11 + k * 6) % 90),
          createdAt: listedAt,
          availableForSwap: false,
          isForSale: false,
          salePrice: price,
          permanentlyTransferred: true,
        },
      });
      await stamp('user_books', listing.id, listedAt, at);

      const offer = await prisma.priceOffer.create({
        data: {
          buyerId: buyer.id,
          ownerId: user.id,
          userBookId: listing.id,
          amount: price,
          message: 'O iau eu, dacă mai e disponibilă.',
          status: 'COMPLETED',
          acceptedAt: new Date(at.getTime() - 2 * DAY),
          meetingTime: at,
          meetingLocation: `Librăria Humanitas, ${user.city ?? 'București'}`,
          meetingAcceptedAt: new Date(at.getTime() - 2 * DAY),
          buyerSafetyAckAt: at,
          ownerSafetyAckAt: at,
          buyerDoneAt: at,
          ownerDoneAt: at,
        },
      });
      await stamp('price_offers', offer.id, new Date(at.getTime() - 4 * DAY), at);
    }
  }
  console.log(`  ${sales} vânzări încheiate.`);

  // --- Cărți terminate („a terminat de citit X") ---
  // Rafturile conturilor urmărite se refac de la zero: sunt conturi demo,
  // n-au alte date de păstrat, iar `@@unique([userId, bookId])` ar bloca
  // oricum o a doua inserare a aceluiași titlu.
  let finished = 0;
  if (APPLY) {
    await prisma.bookshelfEntry.deleteMany({
      where: { userId: { in: followed.map((u) => u.id) } },
    });
  }
  for (const [i, user] of followed.entries()) {
    for (let k = 0; k < FEED_FINISHED_PER_USER; k++) {
      const item = usable[(i * 9 + k * 4 + 23) % usable.length];
      const at = ago(1 + ((i * 3 + k * 5) % 20));
      console.log(`  ${(user.name ?? user.email).padEnd(20)} a terminat „${item.entry.title}"`);
      finished++;
      if (!APPLY) continue;

      const entry = await prisma.bookshelfEntry.create({
        data: { userId: user.id, bookId: item.book.id, status: 'FINISHED' },
      });
      await stamp('bookshelf_entries', entry.id, new Date(at.getTime() - 20 * DAY), at);
    }
  }
  console.log(`  ${finished} cărți terminate.`);

  // --- Progres de lectură („e la pagina 180 din 400") ---
  // Feed-ul ignoră paginile sub 5 (zgomot), deci ținem procentele în zona
  // 25-75%. Cartea primește și un raft „în curs de citire", ca profilul
  // public al userului să spună același lucru ca feed-ul.
  let progress = 0;
  if (APPLY) {
    await prisma.readingProgress.deleteMany({
      where: { userId: { in: followed.map((u) => u.id) } },
    });
  }
  for (const [i, user] of followed.entries()) {
    for (let k = 0; k < FEED_PROGRESS_PER_USER; k++) {
      const item = usable[(i * 7 + k * 5 + 41) % usable.length];
      const at = ago(1 + ((i * 2 + k * 3) % 12));
      const pages = item.book.pageCount ?? 320;
      const currentPage = Math.max(12, Math.round(pages * (0.25 + ((i + k) % 3) * 0.25)));

      console.log(
        `  ${(user.name ?? user.email).padEnd(20)} citește „${item.entry.title}" - pagina ${currentPage}/${pages}`,
      );
      progress++;
      if (!APPLY) continue;

      const row = await prisma.readingProgress.create({
        data: { userId: user.id, bookId: item.book.id, currentPage },
      });
      await stamp('reading_progress', row.id, new Date(at.getTime() - 9 * DAY), at);

      // Raftul poate avea deja titlul ăsta ca „terminat" (unique userId+bookId),
      // caz în care progresul rămâne singur - nu suprascriem o carte terminată.
      const onShelf = await prisma.bookshelfEntry.findUnique({
        where: { userId_bookId: { userId: user.id, bookId: item.book.id } },
      });
      if (!onShelf) {
        const entry = await prisma.bookshelfEntry.create({
          data: { userId: user.id, bookId: item.book.id, status: 'READING' },
        });
        await stamp('bookshelf_entries', entry.id, new Date(at.getTime() - 9 * DAY), at);
      }
    }
  }
  console.log(`  ${progress} actualizări de progres de lectură.`);
}

/**
 * Licitațiile create la faza „anunturi" sunt active, dar goale: fără nicio
 * ofertă, cardul arată prețul de pornire și atât. Aici le dăm viață - ofertanți
 * diferiți, preț în creștere, termene eșalonate (de la câteva ore la câteva
 * zile) și urmăritori - inclusiv două la care proprietarul e cel mai mare
 * ofertant și una la care a fost depășit.
 *
 * Regulile din auctions.service.ts sunt respectate ca la un bid real: nimeni
 * nu licitează la propria licitație, fiecare ofertă e strict mai mare decât
 * precedenta, iar `currentPrice`/`highestBidderId` rămân în acord cu ultimul
 * rând din `bids`.
 */
const AUCTION_SEED_COUNT = 18;
const AUCTION_MIN_STEP = 3;

async function phaseLicitatii(demoUsers, owner) {
  console.log('\n=== FAZA: licitatii ===');

  const follows = await prisma.follow.findMany({
    where: { followerId: owner.id },
    select: { followingId: true },
  });
  const followedIds = new Set(follows.map((f) => f.followingId));

  const all = await prisma.auction.findMany({
    where: { status: 'ACTIVE' },
    include: { userBook: { include: { book: true, user: true } } },
    // Ordine stabilă: fără ea, două rulări aleg alte 18 licitații din cele
    // ~70 active, iar ofertele rămase pe cele părăsite nu mai sunt curățate.
    orderBy: { id: 'asc' },
  });

  // Întâi licitațiile conturilor urmărite (apar și în feed-ul de activitate,
  // ca anunțuri noi), apoi ale proprietarului (ca să aibă și el oferte
  // primite), apoi restul - ca browse-ul să nu arate un singur oraș.
  const rank = (a) => {
    if (followedIds.has(a.userBook.userId)) return 0;
    if (a.userBook.userId === owner.id) return 1;
    return 2;
  };
  const chosen = all.sort((x, y) => rank(x) - rank(y)).slice(0, AUCTION_SEED_COUNT);

  console.log(`  ${chosen.length} licitații din ${all.length} active`);
  if (!APPLY) return;

  // Se șterg TOATE ofertele și urmăririle, nu doar cele ale licitațiilor
  // alese acum: sunt integral date de seed (înainte de prima rulare tabela
  // `bids` era goală), iar altfel o rulare anterioară lăsa în urmă oferte pe
  // licitații care nu mai intră în selecție.
  await prisma.bid.deleteMany({});
  await prisma.auctionWatch.deleteMany({});
  // Preț curent înapoi pe cel de pornire peste tot (copiere coloană-la-coloană,
  // deci SQL brut) - o licitație rămasă din selecția anterioară ar fi păstrat
  // altfel un preț urcat, fără nicio ofertă în spate.
  await prisma.$executeRawUnsafe(
    `UPDATE "auctions" SET "currentPrice" = "startingPrice", "highestBidderId" = NULL WHERE status = 'ACTIVE'`,
  );
  await prisma.notification.deleteMany({ where: { userId: owner.id, type: 'OUTBID' } });

  let bidCount = 0;
  for (const [i, auction] of chosen.entries()) {
    const sellerId = auction.userBook.userId;
    const bidders = demoUsers.filter((u) => u.id !== sellerId);
    const rounds = 2 + ((i * 3) % 5); // 2-6 oferte
    const start = Number(auction.startingPrice);

    // Proprietarul intră ca ofertant pe câteva licitații ale altora: pe două
    // rămâne cel mai mare ofertant, pe una e depășit imediat după.
    const ownerBidsLast = sellerId !== owner.id && (i === 0 || i === 3);
    const ownerOutbid = sellerId !== owner.id && i === 6;

    // Termene eșalonate: câteva se termină azi (cronometrul e cel mai
    // convingător element din captură), restul în zilele următoare.
    const endsAt =
      i < 3
        ? new Date(now.getTime() + (3 + i * 4) * 3_600_000)
        : ahead(1 + ((i - 3) % 6));

    let price = start;
    let highestBidderId = null;
    for (let k = 0; k < rounds; k++) {
      // Pași mici (3-7 lei): pe o carte la mâna a doua, un salt de 15 lei
      // per ofertă ducea prețul curent la dublul celui de pornire.
      price += AUCTION_MIN_STEP + ((i + k) % 3) * 2;
      const isLast = k === rounds - 1;
      let bidder;
      if (ownerBidsLast && isLast) bidder = owner;
      else if (ownerOutbid && k === rounds - 2) bidder = owner;
      else bidder = bidders[(i * 5 + k * 7) % bidders.length];
      if (bidder.id === sellerId) bidder = bidders[(i + k) % bidders.length];

      const bid = await prisma.bid.create({
        data: { auctionId: auction.id, bidderId: bidder.id, amount: price },
      });
      // Ofertele se înghesuie spre prezent, ca la o licitație reală. Ancora e
      // ACUM, nu `endsAt`: o licitație care se termină peste două zile ar fi
      // primit altfel oferte cu dată în viitor, iar istoricul le arăta pe
      // toate ca „chiar acum".
      const hoursAgo = (rounds - k) * (6 + (i % 5));
      await stampCreatedOnly(
        'bids',
        bid.id,
        new Date(now.getTime() - hoursAgo * 3_600_000),
      );
      highestBidderId = bidder.id;
      bidCount++;
    }

    await prisma.auction.update({
      where: { id: auction.id },
      data: {
        currentPrice: price,
        highestBidderId,
        endsAt,
        // Preț de rezervă / „cumpără acum" doar pe o parte din ele, ca în UI
        // să apară ambele variante de card.
        reservePrice: i % 4 === 0 ? Math.round(price * 1.3) : null,
        buyNowPrice: i % 3 === 0 ? Math.round(price * 1.8) : null,
      },
    });

    // Urmăritori: proprietarul urmărește primele licitații ale altora, plus
    // câțiva ofertanți care nu au licitat încă.
    const watchers = [
      ...(sellerId !== owner.id && i < 5 ? [owner] : []),
      bidders[(i * 3 + 1) % bidders.length],
      bidders[(i * 3 + 2) % bidders.length],
    ];
    for (const w of watchers) {
      const exists = await prisma.auctionWatch.findUnique({
        where: { auctionId_userId: { auctionId: auction.id, userId: w.id } },
      });
      if (!exists) {
        await prisma.auctionWatch.create({
          data: { auctionId: auction.id, userId: w.id },
        });
      }
    }

    if (ownerOutbid) {
      const notification = await prisma.notification.create({
        data: {
          userId: owner.id,
          type: 'OUTBID',
          message: `Ai fost depășit la licitația pentru „${auction.userBook.book.title}"`,
          data: { auctionId: auction.id, userBookId: auction.userBookId },
          isRead: false,
        },
      });
      await stampCreatedOnly('notifications', notification.id, ago(0.3));
    }
  }

  console.log(
    `  ${bidCount} oferte pe ${chosen.length} licitații (3 se termină azi, ` +
      'proprietarul e cel mai mare ofertant la 2 și depășit la una).',
  );
}

async function phasePoze(resolved) {
  console.log('\n=== FAZA: poze ===');
  // Toate anunțurile, nu doar cele ale rândurilor rezolvate acum: același
  // titlu poate exista pe mai multe rânduri din catalogul importat, iar
  // anunțurile create într-o rulare anterioară pot trimite la altul.
  const listings = await prisma.userBook.findMany({
    where: { book: { coverUrl: { not: null } } },
    select: { id: true, mainPhotoUrl: true, book: { select: { coverUrl: true } } },
  });

  let synced = 0;
  for (const l of listings) {
    const cover = l.book.coverUrl;
    if (!cover || l.mainPhotoUrl === cover) continue;
    synced++;
    if (APPLY) {
      await prisma.userBook.update({
        where: { id: l.id },
        data: { photos: [cover], mainPhotoUrl: cover },
      });
    }
  }
  console.log(`  ${synced} anunțuri aduse pe coperta curentă (din ${listings.length}).`);
}

async function phaseIstoric(resolved, demoUsers, owner) {
  console.log('\n=== FAZA: istoric ===');
  const byTitle = new Map(
    resolved.filter((r) => r.book && r.book.coverUrl).map((r) => [r.entry.title, r]),
  );

  let userCursor = 0;
  for (const chain of CHAINS) {
    const item = byTitle.get(chain.title);
    if (!item) {
      console.log(`  sar peste „${chain.title}" - nu e în catalog`);
      continue;
    }

    const owners = [];
    for (let k = 0; k < chain.links; k++) {
      if (chain.endsWithOwner && k === chain.links - 1) owners.push(owner);
      else owners.push(demoUsers[(userCursor++ * 5 + 3) % demoUsers.length]);
    }

    console.log(
      `  ${chain.label.padEnd(6)} „${chain.title}": ${chain.links} verigi -> ` +
        owners.map((u) => (u.name ?? u.email).replace('TEST_', '')).join(' -> '),
    );
    if (!APPLY) continue;

    const gap = Math.round(chain.spanDays / chain.links);
    let previousId = null;

    for (let k = 0; k < chain.links; k++) {
      const isLast = k === chain.links - 1;
      const listedAt = ago(chain.spanDays - k * gap);
      const transferAt = ago(chain.spanDays - (k + 1) * gap + 3);
      const user = owners[k];
      const cover = item.book.coverUrl;

      const listing = await prisma.userBook.create({
        data: {
          userId: user.id,
          bookId: item.book.id,
          // Starea se degradează pe măsură ce cartea trece prin mâini.
          condition: CONDITIONS[Math.min(CONDITIONS.length - 1, Math.floor((k / chain.links) * 3.6))],
          language: item.entry.language,
          edition: k === 0 ? 'Ediție cartonată' : null,
          photos: cover ? [cover] : [],
          mainPhotoUrl: cover,
          description: pick(CHAIN_NOTES, k),
          tags: ['de-colectie', 'must-read'],
          city: user.city ?? pick(CITIES, k),
          viewCount: 30 + k * 24,
          previousListingId: previousId,
          createdAt: listedAt,
          // Verigile vechi sunt cărți deja date mai departe: nu mai sunt
          // disponibile, dar rămân în lanț (permanentlyTransferred).
          availableForSwap: isLast,
          isForSale: isLast && k % 2 === 1,
          salePrice: isLast && k % 2 === 1 ? 34 : null,
          isNegotiable: true,
          permanentlyTransferred: !isLast,
        },
      });
      await stamp('user_books', listing.id, listedAt, isLast ? listedAt : transferAt);

      if (!isLast) {
        const kind = k % 2 === 0 ? 'exchange' : 'sale';
        await chainTransfer(kind, user, owners[k + 1], listing, transferAt, 25 + k * 3);
      }
      previousId = listing.id;
    }
  }

  // Prețuri de vânzare încheiate pe alte exemplare ale acelorași titluri, ca
  // secțiunea „Istoricul prețurilor" (oferte COMPLETED, agregate per titlu)
  // să aibă din ce calcula media - lanțul de mai sus folosește ACCEPTED.
  if (APPLY) {
    let sales = 0;
    for (const chain of CHAINS) {
      const item = byTitle.get(chain.title);
      if (!item) continue;
      // Doar verigile deja transferate din lanț - o ofertă COMPLETED pe un
      // anunț încă activ l-ar face să pară vândut în ecranele de oferte.
      const copies = await prisma.userBook.findMany({
        where: { bookId: item.book.id, permanentlyTransferred: true },
        orderBy: { createdAt: 'asc' },
        take: 4,
      });
      for (const [n, copy] of copies.entries()) {
        const at = ago(20 + n * 25);
        const offer = await prisma.priceOffer.create({
          data: {
            buyerId: demoUsers[(n * 11 + 2) % demoUsers.length].id,
            ownerId: copy.userId,
            userBookId: copy.id,
            amount: 24 + n * 6,
            status: 'COMPLETED',
            acceptedAt: at,
            buyerDoneAt: at,
            ownerDoneAt: at,
          },
        });
        await stamp('price_offers', offer.id, new Date(at.getTime() - 2 * DAY), at);
        sales++;
      }
    }
    console.log(`  ${sales} vânzări încheiate (pentru istoricul de prețuri).`);
  }
}

// ---------------------------------------------------------------------------
// FAZA 5: conversații, oferte în curs, favorite, raft, recenzii, notificări
// ---------------------------------------------------------------------------

const CONVERSATIONS = [
  {
    // Ofertă de preț primită pe un anunț al proprietarului.
    kind: 'offer_received',
    messages: [
      ['them', 'Salut! Am văzut anunțul, mai e disponibilă?'],
      ['me', 'Salut! Da, e disponibilă.'],
      ['them', 'Arată foarte bine în poze. Ai vrea 40 de lei pentru ea?'],
      ['me', 'Hai să vedem, mă mai gândesc puțin :)'],
    ],
  },
  {
    // Cerere de schimb trimisă de proprietar.
    kind: 'exchange_sent',
    messages: [
      ['me', 'Bună! Am văzut că ai cartea la schimb.'],
      ['them', 'Da, e liberă. Ce ai la schimb?'],
      ['me', 'Ți-am trimis o cerere, spune-mi dacă te interesează.'],
      ['them', 'Mă uit diseară și îți zic.'],
    ],
  },
  {
    // Schimb acceptat, cu întâlnire programată - ecranul de întâlnire/safety.
    kind: 'exchange_accepted',
    messages: [
      ['them', 'Am acceptat schimbul, mă bucur!'],
      ['me', 'Super. Ne vedem mâine la 18:00 în centru?'],
      ['them', 'Perfect, la ceainărie. Iau cartea împachetată.'],
      ['me', 'Ne vedem acolo. Mulțumesc!'],
    ],
  },
  {
    kind: 'plain_location',
    messages: [
      ['them', 'Mai ai „Dune"? Aș da ceva la schimb pe ea.'],
      ['me', 'O mai am, da. Ce zici de sâmbătă?'],
      ['them', 'Merge. Unde ne întâlnim?'],
      ['me', '__LOCATION__'],
      ['them', 'Ok, notat. Pe sâmbătă!'],
    ],
  },
  {
    kind: 'plain_unread',
    messages: [
      ['me', 'Mulțumesc pentru schimbul de săptămâna trecută!'],
      ['them', 'Cu plăcere, a fost o plăcere. Am terminat-o deja :)'],
      ['them', 'Apropo, mi-a mai rămas un Murakami. Te interesează?'],
    ],
  },
];

async function findOrCreateConversation(aId, bId) {
  const [userAId, userBId] = [aId, bId].sort();
  const existing = await prisma.conversation.findUnique({
    where: { userAId_userBId: { userAId, userBId } },
  });
  return existing ?? prisma.conversation.create({ data: { userAId, userBId } });
}

async function phaseChat(resolved, demoUsers, owner) {
  console.log('\n=== FAZA: chat + interacțiuni ===');
  const usable = resolved.filter((r) => r.book && r.book.coverUrl);

  const ownerListings = await prisma.userBook.findMany({
    where: { userId: owner.id, deletedAt: null },
    include: { book: true },
    orderBy: { createdAt: 'desc' },
  });
  const ownerSale = ownerListings.find((l) => l.isForSale && Number(l.salePrice) > 0);
  const ownerSwap = ownerListings.find((l) => l.availableForSwap && !l.isForSale);

  if (!APPLY) {
    console.log(`  ${CONVERSATIONS.length} conversații, oferte în curs, favorite, raft public, recenzii, urmăritori, notificări`);
    return;
  }
  if (ownerListings.length === 0) {
    throw new Error('Proprietarul nu are anunțuri - rulează întâi faza „anunturi".');
  }

  // Partenerii de discuție: conturi demo distincte, cu anunțuri proprii.
  const partners = [];
  for (const u of demoUsers) {
    if (partners.length >= CONVERSATIONS.length) break;
    const listing = await prisma.userBook.findFirst({
      where: { userId: u.id, availableForSwap: true, deletedAt: null },
      include: { book: true },
    });
    if (listing) partners.push({ user: u, listing });
  }

  for (const [i, spec] of CONVERSATIONS.entries()) {
    const partner = partners[i % partners.length];
    const them = partner.user;
    const conversation = await findOrCreateConversation(owner.id, them.id);
    // Idempotent: conversația proprietarului se rescrie de la zero la fiecare
    // rulare, ca să nu se adune replici duplicate peste cele de data trecută.
    await prisma.message.deleteMany({ where: { conversationId: conversation.id } });

    let attachment = {};
    if (spec.kind === 'offer_received' && ownerSale) {
      const offer = await prisma.priceOffer.create({
        data: {
          buyerId: them.id,
          ownerId: owner.id,
          userBookId: ownerSale.id,
          amount: Math.max(15, Math.round(Number(ownerSale.salePrice) * 0.85)),
          message: 'Ofertă pentru cartea ta.',
          status: 'PENDING',
          expiresAt: ahead(6),
        },
      });
      await stamp('price_offers', offer.id, ago(1), ago(1));
      attachment = { priceOfferId: offer.id, at: 2 };
    }
    if (spec.kind === 'exchange_sent') {
      const request = await prisma.exchangeRequest.create({
        data: {
          requesterId: owner.id,
          ownerId: them.id,
          requestedBookId: partner.listing.id,
          offeredBookId: ownerSwap?.id ?? null,
          message: 'Ți-aș da la schimb una dintre cărțile mele.',
          status: 'PENDING',
          expiresAt: ahead(5),
        },
      });
      await stamp('exchange_requests', request.id, ago(2), ago(2));
      attachment = { exchangeRequestId: request.id, at: 2 };
    }
    if (spec.kind === 'exchange_accepted') {
      const request = await prisma.exchangeRequest.create({
        data: {
          requesterId: them.id,
          ownerId: owner.id,
          requestedBookId: ownerSwap?.id ?? ownerListings[0].id,
          message: 'Aș vrea cartea asta, dacă mai e liberă.',
          status: 'ACCEPTED',
          acceptedAt: ago(1),
          meetingTime: ahead(1),
          meetingLocation: 'Ceainăria Centrală, Cluj-Napoca',
          meetingProposedBy: owner.id,
          meetingAcceptedAt: ago(1),
          requesterSafetyAckAt: ago(1),
          ownerSafetyAckAt: ago(1),
          requesterContactPhone: '07xx xxx 214',
          requesterContactSharedAt: ago(1),
          expiresAt: ahead(6),
        },
      });
      await stamp('exchange_requests', request.id, ago(3), ago(1));
      attachment = { exchangeRequestId: request.id, at: 0 };
    }

    const total = spec.messages.length;
    for (const [k, [who, text]] of spec.messages.entries()) {
      const senderId = who === 'me' ? owner.id : them.id;
      const createdAt = new Date(now.getTime() - (i * 2 + 1) * DAY + k * 7 * 60_000);
      const isLastFromThem = k === total - 1 && who === 'them';

      const data = {
        conversationId: conversation.id,
        senderId,
        // Ultimul mesaj primit rămâne necitit, ca lista de conversații să
        // arate bulina de necitite în capturi.
        isRead: !isLastFromThem,
      };
      if (text === '__LOCATION__') {
        data.content = 'Aici, la intrarea în parc.';
        data.location = 'Parcul Central, Cluj-Napoca';
        data.locationLat = 46.7712;
        data.locationLng = 23.5878;
        data.meetingAt = ahead(2);
      } else {
        data.content = text;
      }
      if (attachment.priceOfferId && k === attachment.at) data.priceOfferId = attachment.priceOfferId;
      if (attachment.exchangeRequestId && k === attachment.at) data.exchangeRequestId = attachment.exchangeRequestId;

      const message = await prisma.message.create({ data });
      await stampCreatedOnly('messages', message.id, createdAt);
      if (k === total - 1) {
        await prisma.$executeRawUnsafe(
          'UPDATE "conversations" SET "updatedAt" = $1 WHERE id = $2',
          createdAt,
          conversation.id,
        );
      }
    }
  }
  console.log(`  ${CONVERSATIONS.length} conversații rescrise pe contul proprietarului.`);

  // Conversațiile mai vechi ale proprietarului (cu conturi de test personale,
  // despre anunțuri care nu mai există) se arhivează DOAR pentru el: rândurile
  // rămân, celălalt participant le vede mai departe, dar lista lui de chaturi
  // arată curat în capturi.
  const demoIds = new Set(partners.map((p) => p.user.id));
  const otherConversations = await prisma.conversation.findMany({
    where: { OR: [{ userAId: owner.id }, { userBId: owner.id }] },
  });
  let archived = 0;
  for (const c of otherConversations) {
    const partnerId = c.userAId === owner.id ? c.userBId : c.userAId;
    if (demoIds.has(partnerId)) continue;
    const field = c.userAId === owner.id ? 'userAArchivedAt' : 'userBArchivedAt';
    if (c[field]) continue;
    await prisma.conversation.update({ where: { id: c.id }, data: { [field]: now } });
    archived++;
  }
  console.log(`  ${archived} conversații vechi arhivate (doar pentru proprietar).`);

  // --- Favorite (inima de pe anunț) + wishlist de titlu din Book Match ---
  await prisma.wishlistItem.deleteMany({ where: { userId: owner.id } });
  const wishlistCandidates = await prisma.userBook.findMany({
    where: { userId: { not: owner.id }, deletedAt: null },
    orderBy: { viewCount: 'desc' },
    take: 40,
  });
  const seenBooks = new Set();
  let wished = 0;
  for (const ub of wishlistCandidates) {
    if (wished >= 6 || seenBooks.has(ub.bookId)) continue;
    seenBooks.add(ub.bookId);
    await prisma.wishlistItem.create({
      data: { userId: owner.id, bookId: ub.bookId, userBookId: ub.id, source: 'PERSONAL' },
    });
    wished++;
  }
  for (const r of usable.slice(20, 24)) {
    if (seenBooks.has(r.book.id)) continue;
    seenBooks.add(r.book.id);
    await prisma.wishlistItem.create({
      data: { userId: owner.id, bookId: r.book.id, source: 'BOOK_MATCH' },
    });
  }
  console.log(`  ${seenBooks.size} favorite pe contul proprietarului.`);

  // --- Raft public: citite / în curs / de citit + progres de lectură ---
  await prisma.bookshelfEntry.deleteMany({ where: { userId: owner.id } });
  await prisma.readingProgress.deleteMany({ where: { userId: owner.id } });
  const shelf = [
    ...usable.slice(0, 5).map((r) => ({ r, status: 'FINISHED' })),
    ...usable.slice(5, 7).map((r) => ({ r, status: 'READING' })),
    ...usable.slice(7, 10).map((r) => ({ r, status: 'WANT_TO_READ' })),
  ];
  for (const [k, s] of shelf.entries()) {
    const entry = await prisma.bookshelfEntry.create({
      data: { userId: owner.id, bookId: s.r.book.id, status: s.status },
    });
    await stamp('bookshelf_entries', entry.id, ago(120 - k * 9), ago(120 - k * 9));
    if (s.status === 'READING') {
      await prisma.readingProgress.create({
        data: {
          userId: owner.id,
          bookId: s.r.book.id,
          currentPage: Math.max(40, Math.round((s.r.book.pageCount ?? 300) * (k === 5 ? 0.42 : 0.68))),
        },
      });
    }
  }
  console.log(`  ${shelf.length} cărți pe raftul public (din care 2 în curs de citire).`);

  // --- Recenzii comunitare pe titlurile din vitrină ---
  const REVIEW_TEXTS = [
    ['Una dintre cărțile care chiar rămân cu tine după ce o închizi.', 5],
    ['Începe încet, dar ultima sută de pagini merită tot.', 4],
    ['Am recitit-o după zece ani și mi-a plăcut altfel.', 5],
    ['Bine scrisă, deși unele capitole se lungesc.', 4],
    ['Perfectă pentru cineva care abia intră în gen.', 5],
    ['Mi-a plăcut mai mult filmul, dar cartea are mai multă profunzime.', 3],
    ['O recomand oricui vrea ceva de citit într-un weekend.', 5],
    ['Traducerea românească e foarte bună.', 4],
  ];
  let reviews = 0;
  for (const [k, r] of usable.slice(0, 14).entries()) {
    const reviewer = k % 4 === 0 ? owner : demoUsers[(k * 7 + 1) % demoUsers.length];
    const [text, rating] = REVIEW_TEXTS[k % REVIEW_TEXTS.length];
    const existing = await prisma.review.findUnique({
      where: { userId_bookId: { userId: reviewer.id, bookId: r.book.id } },
    });
    if (existing) continue;
    const review = await prisma.review.create({
      data: { userId: reviewer.id, bookId: r.book.id, rating, text },
    });
    await stamp('reviews', review.id, ago(5 + k * 4), ago(5 + k * 4));
    reviews++;
  }
  console.log(`  ${reviews} recenzii comunitare.`);

  // --- Urmăritori ---
  let follows = 0;
  for (const u of demoUsers.slice(0, 8)) {
    const a = await prisma.follow.findFirst({ where: { followerId: u.id, followingId: owner.id } });
    if (!a) {
      await prisma.follow.create({ data: { followerId: u.id, followingId: owner.id } });
      follows++;
    }
  }
  for (const u of demoUsers.slice(3, 8)) {
    const b = await prisma.follow.findFirst({ where: { followerId: owner.id, followingId: u.id } });
    if (!b) {
      await prisma.follow.create({ data: { followerId: owner.id, followingId: u.id } });
      follows++;
    }
  }
  console.log(`  ${follows} relații de urmărire.`);

  // --- Notificări recente (clopoțelul) ---
  await prisma.notification.deleteMany({ where: { userId: owner.id } });
  const someListing = ownerListings[0];
  const NOTIFICATIONS = [
    ['PRICE_OFFER_RECEIVED', `Ai primit o ofertă pentru „${someListing.book.title}"`, { userBookId: someListing.id }, false, 0.2],
    ['NEW_MESSAGE', 'Ai un mesaj nou de la un utilizator', {}, false, 0.6],
    ['WISHLIST_BOOK_AVAILABLE', 'O carte de pe lista ta de dorințe tocmai a fost listată', {}, false, 1.2],
    ['EXCHANGE_MEETING_SCHEDULED', 'Întâlnirea pentru schimb a fost confirmată', {}, true, 2],
    ['EXCHANGE_COMPLETED', 'Schimbul a fost finalizat. Lasă o evaluare!', {}, true, 5],
    ['FOLLOWED_USER_NEW_BOOK', 'Un utilizator pe care îl urmărești a listat o carte nouă', {}, true, 8],
  ];
  for (const [type, message, data, isRead, days] of NOTIFICATIONS) {
    const n = await prisma.notification.create({ data: { userId: owner.id, type, message, data, isRead } });
    await stampCreatedOnly('notifications', n.id, ago(days));
  }
  console.log(`  ${NOTIFICATIONS.length} notificări (3 necitite).`);

  // --- Statistici de profil (nivel, streak, schimburi) ---
  const completedExchanges = await prisma.exchangeRequest.count({
    where: { status: 'COMPLETED', OR: [{ requesterId: owner.id }, { ownerId: owner.id }] },
  });
  await prisma.user.update({
    where: { id: owner.id },
    data: {
      booksExchangedCount: Math.max(completedExchanges, 7),
      booksSharedCount: ownerListings.length,
      booksReceivedCount: Math.max(completedExchanges, 4),
      xp: 1450,
      currentStreakDays: 12,
      longestStreakDays: 28,
      lastStreakDate: now,
      readingChallengeGoal: 24,
      rating: 4.9,
      avgCommunicationRating: 5,
      avgPunctualityRating: 4.8,
      avgConditionRating: 4.9,
    },
  });

  // Ratingurile celorlalți participanți la lanțurile de istoric, ca profilurile
  // lor din capturi să nu arate 0 stele lângă schimburi finalizate.
  const raters = await prisma.exchangeRequest.findMany({
    where: { status: 'COMPLETED' },
    select: { requesterId: true, ownerId: true },
  });
  const counts = new Map();
  for (const e of raters) {
    counts.set(e.requesterId, (counts.get(e.requesterId) ?? 0) + 1);
    counts.set(e.ownerId, (counts.get(e.ownerId) ?? 0) + 1);
  }
  for (const [userId, count] of counts) {
    if (userId === owner.id) continue;
    await prisma.user.update({
      where: { id: userId },
      data: {
        rating: 4.5 + (count % 5) / 10,
        booksExchangedCount: count,
        avgCommunicationRating: 4.6 + (count % 4) / 10,
        avgPunctualityRating: 4.5 + (count % 5) / 10,
        avgConditionRating: 4.7,
      },
    });
  }
  console.log(`  statistici de profil actualizate pentru proprietar + ${counts.size - 1} conturi demo.`);
}

// ---------------------------------------------------------------------------

async function main() {
  if (ONLY && !PHASES.includes(ONLY)) {
    throw new Error(`--only=${ONLY} necunoscut. Faze: ${PHASES.join(', ')}`);
  }
  const run = (phase) => !ONLY || ONLY === phase;

  console.log(APPLY ? '=== APLIC MODIFICĂRILE ===' : '=== DRY-RUN (fără --apply nu se scrie nimic) ===');

  const owner = await prisma.user.findUnique({ where: { email: OWNER_EMAIL } });
  if (!owner) throw new Error(`Contul proprietarului (${OWNER_EMAIL}) nu există.`);

  const demoUsers = await prisma.user.findMany({
    where: {
      OR: DEMO_DOMAINS.map((d) => ({ email: { endsWith: `@${d}` } })),
      email: { notIn: SYSTEM_EMAILS },
      isBanned: false,
    },
    orderBy: { email: 'asc' },
  });
  if (demoUsers.length === 0) throw new Error('Niciun cont demo (@shelfshare.test / @shelfshare.demo).');
  console.log(`Proprietar: ${owner.email} | conturi demo: ${demoUsers.length}`);

  if (run('nume')) await phaseNume(demoUsers);

  // Toate fazele de mai jos lucrează pe aceleași titluri rezolvate o dată.
  const resolved = await resolveShowcaseBooks();
  const missing = resolved.filter((r) => !r.book).length;
  console.log(`Titluri în vitrină: ${SHOWCASE.length} (${missing} lipsesc din catalog și se creează la faza „coperte")`);

  if (run('coperte')) await phaseCoperte(resolved);
  if (run('dedup')) await phaseDedup(resolved);
  if (run('anunturi')) await phaseAnunturi(resolved, demoUsers, owner);
  if (run('istoric')) await phaseIstoric(resolved, demoUsers, owner);
  if (run('poze')) await phasePoze(resolved);
  if (run('chat')) await phaseChat(resolved, demoUsers, owner);
  // După „chat": are nevoie de relațiile de urmărire create acolo.
  if (run('feed')) await phaseFeed(resolved, demoUsers, owner);
  // Tot după „chat": foloseste relatiile de urmarire si notificarile lui.
  if (run('licitatii')) await phaseLicitatii(demoUsers, owner);

  console.log(APPLY ? '\nGata.' : '\nDry-run încheiat - repetă cu --apply ca să scrie în baza de date.');
}

main()
  .catch((error) => {
    console.error(error);
    process.exitCode = 1;
  })
  .finally(() => prisma.$disconnect());
