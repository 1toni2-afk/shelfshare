/**
 * Populează catalogul `books` cu lista de rezervă a Book Match: top ~100
 * titluri general-populare, din mai multe genuri, curatoriate manual.
 *
 * De ce e nevoie: `coldStartBatch` (book-match.service.ts) alege genul din
 * care compune batch-ul de cold start pe baza `favoriteGenres` declarate la
 * pasul 5 din onboarding. Dacă userul sare peste pasul de genuri (nu bifează
 * niciunul), nu mai există niciun semnal - fără lista asta, primele carduri
 * ar veni pur aleator din tot catalogul. Titlurile de aici au un
 * `popularityScore` peste orice altă carte curatoriată (vezi POPULARITY mai
 * jos), deci `coldStartBatch` le preferă puternic exact în acel caz, fără să
 * fie nevoie de vreun cod special pentru "userul n-a ales genuri" - se
 * bazează pe aceeași ponderare `1 + popularityScore` deja folosită la orice
 * cold start.
 *
 * Mecanica de căutare/dedup e identică cu seed-curated-books.js (vezi acolo
 * pentru detalii); singurele diferențe sunt lista de titluri, SOURCE și
 * POPULARITY, plus faptul că nu impunem un minim de titluri per gen - lista
 * e "cele mai populare cărți, din mai multe categorii", nu o acoperire
 * uniformă a tuturor genurilor canonice.
 *
 * Rulare (DRY-RUN implicit - interoghează API-urile și baza, dar NU scrie):
 *   docker compose -f docker-compose.prod.yml exec backend \
 *     node prisma/seed-bookmatch-fallback.js
 *   docker compose -f docker-compose.prod.yml exec backend \
 *     node prisma/seed-bookmatch-fallback.js --apply
 *
 * Verificare locală, fără bază de date (doar structura listei):
 *   node prisma/seed-bookmatch-fallback.js --self-test
 *
 * Versiune .js (nu .ts): imaginea de producție nu are pnpm/ts-node.
 */
require('dotenv/config');

const APPLY = process.argv.includes('--apply');
const SELF_TEST = process.argv.includes('--self-test');

/** Marcaj de proveniență pentru rândurile create de scriptul ăsta. */
const SOURCE = 'bookmatch_fallback_seed';

/**
 * Peste POPULARITY = 0.9 folosit de seed-curated-books.js, ca titlurile astea
 * să domine clar orice alt cold start fără genuri declarate (multiplicator
 * `1 + popularityScore` = 2.2, față de 1.9 pentru curatele obișnuite și 1.3
 * pentru restul catalogului).
 */
const POPULARITY = 1.2;

/** Pauză între apelurile externe, ca să nu batem API-urile publice. */
const REQUEST_DELAY_MS = 250;

/**
 * Lista de rezervă, grupată pe genul canonic (din src/common/constants/
 * book-genres.ts) cel mai apropiat - folosit doar ca etichetă pe rândul
 * inserat, nu ca o partiție strictă (cărțile astea sunt alese pentru cât de
 * cunoscute sunt, nu pentru acoperirea genurilor). Titlurile duplicate cu
 * seed-curated-books.js (ex. „Fahrenheit 451", deja în Distopie) se
 * auto-elimină prin dedup-ul de mai jos - rulează idempotent.
 */
const FALLBACK = {
  'Clasic': [
    { title: 'Pride and Prejudice', author: 'Jane Austen' },
    { title: 'Crime and Punishment', author: 'Fyodor Dostoevsky' },
    { title: 'The Picture of Dorian Gray', author: 'Oscar Wilde' },
    { title: 'The Catcher in the Rye', author: 'J.D. Salinger' },
    { title: 'To Kill a Mockingbird', author: 'Harper Lee' },
    { title: 'The Great Gatsby', author: 'F. Scott Fitzgerald' },
    { title: 'One Hundred Years of Solitude', author: 'Gabriel Garcia Marquez' },
  ],
  'Fantasy': [
    { title: "Harry Potter and the Philosopher's Stone", author: 'J.K. Rowling' },
    { title: 'The Fellowship of the Ring', author: 'J.R.R. Tolkien' },
    { title: 'The Hobbit', author: 'J.R.R. Tolkien' },
    { title: 'A Game of Thrones', author: 'George R.R. Martin' },
    { title: 'The Lion, the Witch and the Wardrobe', author: 'C.S. Lewis' },
    { title: 'The Name of the Wind', author: 'Patrick Rothfuss' },
    { title: 'Mistborn: The Final Empire', author: 'Brandon Sanderson' },
    { title: 'Circe', author: 'Madeline Miller' },
    { title: 'A Court of Thorns and Roses', author: 'Sarah J. Maas' },
    { title: 'The Song of Achilles', author: 'Madeline Miller' },
    { title: 'Fourth Wing', author: 'Rebecca Yarros' },
    { title: 'Iron Flame', author: 'Rebecca Yarros' },
    { title: 'Shadow and Bone', author: 'Leigh Bardugo' },
    { title: 'The Cruel Prince', author: 'Holly Black' },
    { title: 'American Gods', author: 'Neil Gaiman' },
    { title: 'Good Omens', author: 'Neil Gaiman' },
  ],
  'SF': [
    { title: 'Dune', author: 'Frank Herbert' },
    { title: 'Foundation', author: 'Isaac Asimov' },
    { title: 'Neuromancer', author: 'William Gibson' },
    { title: "Ender's Game", author: 'Orson Scott Card' },
    { title: 'The Martian', author: 'Andy Weir' },
    { title: 'Project Hail Mary', author: 'Andy Weir' },
    { title: 'Ready Player One', author: 'Ernest Cline' },
    { title: 'The Three-Body Problem', author: 'Liu Cixin' },
    { title: 'The Time Machine', author: 'H.G. Wells' },
  ],
  'Thriller': [
    { title: 'The Girl on the Train', author: 'Paula Hawkins' },
    { title: 'Gone Girl', author: 'Gillian Flynn' },
    { title: 'The Silent Patient', author: 'Alex Michaelides' },
    { title: 'The Da Vinci Code', author: 'Dan Brown' },
    { title: 'Angels & Demons', author: 'Dan Brown' },
    { title: 'Shutter Island', author: 'Dennis Lehane' },
  ],
  'Mister': [
    { title: 'And Then There Were None', author: 'Agatha Christie' },
    { title: 'Murder on the Orient Express', author: 'Agatha Christie' },
    { title: 'In the Woods', author: 'Tana French' },
    { title: 'The Name of the Rose', author: 'Umberto Eco' },
    { title: 'The Shadow of the Wind', author: 'Carlos Ruiz Zafon' },
    { title: 'Where the Crawdads Sing', author: 'Delia Owens' },
  ],
  'Distopie': [
    { title: 'Nineteen Eighty-Four', author: 'George Orwell' },
    { title: 'Fahrenheit 451', author: 'Ray Bradbury' },
    { title: 'The Hunger Games', author: 'Suzanne Collins' },
    { title: "The Handmaid's Tale", author: 'Margaret Atwood' },
    { title: 'Never Let Me Go', author: 'Kazuo Ishiguro' },
    { title: 'The Road', author: 'Cormac McCarthy' },
  ],
  'Romantic': [
    { title: 'The Notebook', author: 'Nicholas Sparks' },
    { title: 'It Ends with Us', author: 'Colleen Hoover' },
    { title: 'It Starts with Us', author: 'Colleen Hoover' },
    { title: 'The Love Hypothesis', author: 'Ali Hazelwood' },
    { title: 'Normal People', author: 'Sally Rooney' },
    { title: 'Me Before You', author: 'Jojo Moyes' },
    { title: 'Beach Read', author: 'Emily Henry' },
    { title: 'Book Lovers', author: 'Emily Henry' },
    { title: 'The Seven Husbands of Evelyn Hugo', author: 'Taylor Jenkins Reid' },
  ],
  'Istoric': [
    { title: 'The Book Thief', author: 'Markus Zusak' },
    { title: 'Night', author: 'Elie Wiesel' },
  ],
  'Biografie': [
    { title: 'Educated', author: 'Tara Westover' },
    { title: 'Becoming', author: 'Michelle Obama' },
    { title: 'Steve Jobs', author: 'Walter Isaacson' },
    { title: 'Leonardo da Vinci', author: 'Walter Isaacson' },
    { title: 'Alexander Hamilton', author: 'Ron Chernow' },
    { title: 'The Diary of a Young Girl', author: 'Anne Frank' },
    { title: 'Into the Wild', author: 'Jon Krakauer' },
  ],
  'Dezvoltare personală': [
    { title: 'Atomic Habits', author: 'James Clear' },
    { title: 'The Power of Now', author: 'Eckhart Tolle' },
    { title: 'The 7 Habits of Highly Effective People', author: 'Stephen R. Covey' },
    { title: 'Deep Work', author: 'Cal Newport' },
  ],
  'Psihologie': [
    { title: 'Thinking, Fast and Slow', author: 'Daniel Kahneman' },
    { title: "Man's Search for Meaning", author: 'Viktor E. Frankl' },
    { title: 'Quiet: The Power of Introverts', author: 'Susan Cain' },
  ],
  'Non-ficțiune': [
    { title: 'Sapiens: A Brief History of Humankind', author: 'Yuval Noah Harari' },
    { title: 'Factfulness', author: 'Hans Rosling' },
    { title: 'Homo Deus', author: 'Yuval Noah Harari' },
  ],
  'Business': [
    { title: 'The Psychology of Money', author: 'Morgan Housel' },
  ],
  'Ficțiune': [
    { title: 'The Alchemist', author: 'Paulo Coelho' },
    { title: 'Life of Pi', author: 'Yann Martel' },
    { title: 'The Kite Runner', author: 'Khaled Hosseini' },
    { title: 'A Thousand Splendid Suns', author: 'Khaled Hosseini' },
    { title: 'The Midnight Library', author: 'Matt Haig' },
    { title: 'Daisy Jones & The Six', author: 'Taylor Jenkins Reid' },
  ],
  'Copii': [
    { title: 'The Little Prince', author: 'Antoine de Saint-Exupery' },
  ],
  'Young adult': [
    { title: 'The Fault in Our Stars', author: 'John Green' },
    { title: 'Divergent', author: 'Veronica Roth' },
    { title: 'The Maze Runner', author: 'James Dashner' },
    { title: 'Six of Crows', author: 'Leigh Bardugo' },
  ],
};

// ---------------------------------------------------------------------------
// Apeluri externe - identice cu seed-curated-books.js (Open Library întâi,
// Google Books ca rezervă), doar copiate aici ca scriptul să ruleze de sine
// stătător fără dependințe între cele două fișiere.
// ---------------------------------------------------------------------------

const sleep = (ms) => new Promise((r) => setTimeout(r, ms));

async function getJson(url, timeoutMs = 8000) {
  const controller = new AbortController();
  const timer = setTimeout(() => controller.abort(), timeoutMs);
  try {
    const res = await fetch(url, {
      signal: controller.signal,
      headers: { 'User-Agent': 'shelfshare-bookmatch-fallback-seed/1.0' },
    });
    if (res.status === 429) return { __rateLimited: true };
    if (!res.ok) return null;
    return await res.json();
  } catch {
    return null;
  } finally {
    clearTimeout(timer);
  }
}

let rateLimitHits = 0;

async function getJsonWithRetry(url, attempts = 3) {
  let wait = 2000;
  for (let i = 0; i < attempts; i++) {
    const data = await getJson(url);
    if (!data?.__rateLimited) return data;
    rateLimitHits++;
    if (i < attempts - 1) {
      await sleep(wait);
      wait *= 3;
    }
  }
  return null;
}

function extractYear(dateStr) {
  if (!dateStr) return null;
  const m = String(dateStr).match(/\d{4}/);
  return m ? parseInt(m[0], 10) : null;
}

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

function titleMatches(wanted, got) {
  const a = norm(wanted);
  const b = norm(got);
  if (!b) return false;
  return a === b || a.startsWith(b) || b.startsWith(a) || b.includes(a);
}

async function fromOpenLibrary(title, author) {
  const searchTitle = title.split(':')[0].trim() || title;
  const params = new URLSearchParams({ title: searchTitle, limit: '5' });
  if (author) params.set('author', author);
  const url =
    `https://openlibrary.org/search.json?${params.toString()}` +
    '&fields=key,isbn,title,author_name,cover_i,publisher,first_publish_year,number_of_pages_median,language';

  const data = await getJson(url);
  const doc = (data?.docs ?? []).find((d) => titleMatches(title, d.title));
  if (!doc) return null;

  return {
    isbn: doc.isbn?.[0] ?? null,
    workKey: doc.key ?? null,
    title: doc.title ?? title,
    author: doc.author_name?.join(', ') ?? author,
    description: null,
    coverUrl: doc.cover_i
      ? `https://covers.openlibrary.org/b/id/${doc.cover_i}-L.jpg`
      : null,
    publisher: doc.publisher?.[0] ?? null,
    publishedYear: doc.first_publish_year ?? null,
    pageCount: doc.number_of_pages_median ?? null,
    language: doc.language?.[0] ?? null,
    provider: 'open_library',
  };
}

async function openLibraryDescription(workKey) {
  if (!workKey) return null;
  const data = await getJson(`https://openlibrary.org${workKey}.json`);
  const d = data?.description;
  const text = typeof d === 'string' ? d : (d?.value ?? null);
  if (!text) return null;
  return text.split('\n----------')[0].replace(/\(\[source\]\[\d+\]\)/g, '').trim();
}

async function fromGoogleBooks(title, author) {
  const parts = [`intitle:${encodeURIComponent(title)}`];
  if (author) parts.push(`inauthor:${encodeURIComponent(author)}`);
  const url = `https://www.googleapis.com/books/v1/volumes?q=${parts.join('+')}&maxResults=5`;

  const data = await getJsonWithRetry(url);
  const item = (data?.items ?? []).find((it) =>
    titleMatches(title, it.volumeInfo?.title),
  );
  if (!item) return null;

  const info = item.volumeInfo ?? {};
  const ids = info.industryIdentifiers ?? [];
  const isbn13 = ids.find((i) => i.type === 'ISBN_13')?.identifier;
  const isbn10 = ids.find((i) => i.type === 'ISBN_10')?.identifier;

  return {
    isbn: isbn13 ?? isbn10 ?? null,
    title: info.title ?? title,
    author: info.authors?.join(', ') ?? author,
    description: info.description ?? null,
    coverUrl: info.imageLinks?.thumbnail?.replace('http://', 'https://') ?? null,
    publisher: info.publisher ?? null,
    publishedYear: extractYear(info.publishedDate),
    pageCount: info.pageCount ?? null,
    language: info.language ?? null,
    provider: 'google_books',
  };
}

async function lookup(title, author) {
  const ol = await fromOpenLibrary(title, author);
  await sleep(REQUEST_DELAY_MS);

  if (ol && !ol.description && ol.workKey) {
    ol.description = await openLibraryDescription(ol.workKey);
    await sleep(REQUEST_DELAY_MS);
  }

  const needsGoogle = !ol || !ol.description || !ol.coverUrl || !ol.isbn;
  const gb = needsGoogle ? await fromGoogleBooks(title, author) : null;
  if (needsGoogle) await sleep(REQUEST_DELAY_MS);

  if (!ol && !gb) return null;
  if (!ol) return gb;
  if (!gb) return ol;

  return {
    ...ol,
    isbn: ol.isbn ?? gb.isbn,
    description: ol.description ?? gb.description,
    coverUrl: ol.coverUrl ?? gb.coverUrl,
    publisher: ol.publisher ?? gb.publisher,
    publishedYear: ol.publishedYear ?? gb.publishedYear,
    pageCount: ol.pageCount ?? gb.pageCount,
    language: ol.language ?? gb.language,
    provider: `${ol.provider}+${gb.provider}`,
  };
}

// ---------------------------------------------------------------------------

/** Validează structura listei fără rețea și fără bază de date. */
function validateFallback() {
  const problems = [];
  const seen = new Map();
  let total = 0;

  for (const [genre, books] of Object.entries(FALLBACK)) {
    total += books.length;
    for (const b of books) {
      if (!b.title || !b.author) {
        problems.push(`${genre}: intrare fără titlu/autor: ${JSON.stringify(b)}`);
        continue;
      }
      const k = `${norm(b.title)}|${norm(b.author)}`;
      if (seen.has(k)) {
        problems.push(`duplicat în listă: "${b.title}" (${seen.get(k)} și ${genre})`);
      } else {
        seen.set(k, genre);
      }
    }
  }

  return { total, problems, genreCount: Object.keys(FALLBACK).length };
}

async function selfTest() {
  console.log('=== SELF-TEST (fără bază de date) ===\n');
  const { total, problems, genreCount } = validateFallback();

  for (const [genre, books] of Object.entries(FALLBACK)) {
    console.log(`  ${genre.padEnd(24)} ${books.length}`);
  }
  console.log(`\nGenuri atinse: ${genreCount} | Titluri: ${total}`);

  if (problems.length > 0) {
    console.log('\nPROBLEME:');
    for (const p of problems) console.log('  - ' + p);
  } else {
    console.log('Structura listei: OK (fără duplicate, fără intrări incomplete).');
  }

  const samples = [
    { title: 'Dune', author: 'Frank Herbert' },
    { title: 'Nineteen Eighty-Four', author: 'George Orwell' },
    { title: 'Thinking, Fast and Slow', author: 'Daniel Kahneman' },
  ];

  console.log(`\nTest de lookup pe ${samples.length} titluri (verifică apelurile API):`);
  for (const s of samples) {
    const r = await lookup(s.title, s.author);
    console.log(
      r
        ? `  OK  ${s.title} -> isbn=${r.isbn ?? '-'} an=${r.publishedYear ?? '-'} ` +
          `copertă=${r.coverUrl ? 'da' : 'nu'} descriere=${r.description ? 'da' : 'nu'} [${r.provider}]`
        : `  FAIL ${s.title} — niciun rezultat`,
    );
  }

  if (problems.length > 0) process.exitCode = 1;
}

async function main() {
  const { PrismaClient } = require('@prisma/client');
  const { PrismaPg } = require('@prisma/adapter-pg');
  const adapter = new PrismaPg({ connectionString: process.env.DATABASE_URL });
  const prisma = new PrismaClient({ adapter });

  console.log(
    APPLY
      ? '=== APLIC (se scriu rânduri noi în books) ==='
      : '=== DRY RUN (nu se scrie nimic) — adaugă --apply ca să insereze ===',
  );

  const { total, problems } = validateFallback();
  if (problems.length > 0) {
    console.log('Lista de rezervă are probleme, opresc:');
    for (const p of problems) console.log('  - ' + p);
    await prisma.$disconnect();
    process.exitCode = 1;
    return;
  }
  console.log(`Titluri de procesat: ${total}\n`);

  const stats = { inserted: 0, skippedExisting: 0, notFound: 0 };
  const perGenre = {};

  for (const [genre, books] of Object.entries(FALLBACK)) {
    perGenre[genre] = { inserted: 0, skipped: 0, notFound: 0 };
    console.log(`--- ${genre} ---`);

    for (const wanted of books) {
      const meta = await lookup(wanted.title, wanted.author);
      if (!meta) {
        stats.notFound++;
        perGenre[genre].notFound++;
        console.log(`  ? negăsit: ${wanted.title} — ${wanted.author}`);
        continue;
      }

      // Dedup: ISBN identic, altfel titlu+autor case-insensitive - inclusiv
      // fața de rândurile deja inserate de seed-curated-books.js.
      let existing = null;
      if (meta.isbn) {
        existing = await prisma.book.findUnique({ where: { isbn: meta.isbn } });
      }
      if (!existing) {
        existing = await prisma.book.findFirst({
          where: {
            title: { equals: meta.title, mode: 'insensitive' },
            author: meta.author
              ? { equals: meta.author, mode: 'insensitive' }
              : undefined,
          },
        });
      }
      if (!existing) {
        existing = await prisma.book.findFirst({
          where: {
            title: { equals: wanted.title, mode: 'insensitive' },
            author: { contains: wanted.author.split(' ').pop(), mode: 'insensitive' },
          },
        });
      }

      if (existing) {
        // Cartea există deja (posibil din seed-curated-books.js) - o ridicăm
        // la popularitatea de fallback, ca oricum să domine cold start-ul
        // fără genuri declarate, fără să creăm un rând duplicat.
        if (APPLY && (existing.popularityScore ?? 0) < POPULARITY) {
          await prisma.book.update({
            where: { id: existing.id },
            data: { popularityScore: POPULARITY },
          });
        }
        stats.skippedExisting++;
        perGenre[genre].skipped++;
        console.log(`  = există deja, popularitate ridicată: ${meta.title}`);
        continue;
      }

      const data = {
        isbn: meta.isbn,
        title: meta.title,
        author: meta.author,
        description: meta.description,
        coverUrl: meta.coverUrl,
        publisher: meta.publisher,
        publishedYear: meta.publishedYear,
        pageCount: meta.pageCount,
        language: meta.language,
        genre,
        source: SOURCE,
        popularityScore: POPULARITY,
      };

      if (APPLY) {
        try {
          await prisma.book.create({ data });
        } catch (e) {
          if (e?.code === 'P2002') {
            stats.skippedExisting++;
            perGenre[genre].skipped++;
            console.log(`  = există deja (ISBN unic): ${meta.title}`);
            continue;
          }
          throw e;
        }
      }
      stats.inserted++;
      perGenre[genre].inserted++;
      console.log(
        `  + ${APPLY ? 'inserat' : 'ar insera'}: ${meta.title} — ${meta.author} ` +
          `(${meta.publishedYear ?? '?'}, isbn=${meta.isbn ?? '-'}, copertă=${meta.coverUrl ? 'da' : 'nu'})`,
      );
    }
  }

  console.log('\n=== Rezumat ===');
  for (const [genre, s] of Object.entries(perGenre)) {
    console.log(
      `  ${genre.padEnd(24)} +${s.inserted}  (existente: ${s.skipped}, negăsite: ${s.notFound})`,
    );
  }
  console.log(
    `\nTotal ${APPLY ? 'inserate' : 'de inserat'}: ${stats.inserted} | ` +
      `sărite (deja în catalog): ${stats.skippedExisting} | negăsite în API: ${stats.notFound}`,
  );
  if (rateLimitHits > 0) {
    console.log(
      `Google Books a răspuns 429 de ${rateLimitHits} ori — cărțile afectate au ` +
        'doar metadatele de la Open Library (posibil fără descriere/copertă).',
    );
  }
  if (!APPLY) console.log('\nDRY RUN — nu s-a scris nimic. Rulează cu --apply.');

  await prisma.$disconnect();
}

if (SELF_TEST) {
  selfTest();
} else {
  main().catch((e) => {
    console.error(e);
    process.exitCode = 1;
  });
}
