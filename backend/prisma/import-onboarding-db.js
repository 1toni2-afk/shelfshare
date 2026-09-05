/**
 * Marchează în `books` cele ~200 de titluri din lista de onboarding, punându-le
 * `onboardingRank` = poziția din listă.
 *
 * ---------------------------------------------------------------------------
 * DE CE EXISTĂ
 * ---------------------------------------------------------------------------
 * Book Match servea la onboarding fie din catalogul curat (~1900 de titluri),
 * fie dintr-o listă de titluri hardcodată în cod (COLD_START_FALLBACK_TITLES).
 * Lista de onboarding e aleasă manual - vezi
 * `scripts/targulcartii/onboarding_books.txt` - și e singura care contează cât
 * timp userul e în onboarding: primele swipe-uri decid dacă omul înțelege la
 * ce se uită.
 *
 * ---------------------------------------------------------------------------
 * CUM POTRIVEȘTE
 * ---------------------------------------------------------------------------
 * 1. după ISBN, când scrape-ul l-a găsit (exact, e cheie unică);
 * 2. altfel după titlu + autor, prin `immutable_unaccent` - titlurile din
 *    scrape vin FĂRĂ diacritice („Razboi si pace"), iar catalogul le are
 *    („Război și pace"), deci o comparație simplă n-ar potrivi aproape nimic.
 *
 * Amândouă se fac într-o SINGURĂ trecere peste tabelă, nu una per titlu.
 * `immutable_unaccent(lower(title))` nu e indexat (indexul FTS e pentru
 * căutare, nu pentru egalitate pe expresie), deci fiecare potrivire e un seq
 * scan de ~1,4s pe 3,68M de rânduri - măsurat. Cu 197 de titluri ar fi
 * însemnat ~5 minute; într-o interogare, ~2 secunde.
 *
 * Normalizarea o face tot Postgres, și pentru rândurile din catalog, și pentru
 * titlurile din listă: dacă am reimplementa unaccent în Node, cele două
 * variante ar diverge tăcut exact pe diacriticele care contează aici.
 *
 * Când mai multe rânduri se potrivesc (importul Open Library are zeci de
 * ediții pentru un titlu popular), câștigă cel mai complet: întâi cele
 * `curatedAt`, apoi cele cu copertă, descriere și gen. Altfel lista ar putea
 * nimeri exact ediția fără copertă, iar cartea n-ar mai fi servibilă.
 *
 * NU creează cărți noi implicit, ca `import-scp-db.js`. Cu `--create-missing`
 * le creează din metadatele scrape-ului (titlu, autor, copertă, an, editură,
 * pagini) - util dacă un titlu din listă chiar lipsește din catalog.
 *
 * Rularea e IDEMPOTENTĂ: șterge întâi toate `onboardingRank`-urile, apoi le
 * pune la loc din fișier. Așa un titlu scos din listă chiar dispare din
 * onboarding, iar rularea de mai multe ori nu lasă resturi.
 *
 * Rulare (din containerul backend, care are deja DATABASE_URL):
 *   docker exec shelfshare-backend-1 node prisma/import-onboarding-db.js [--dry-run] [--create-missing]
 */

require('dotenv/config');

const fs = require('fs');

const DB_PATH =
  process.env.ONBOARDING_DB_PATH || '/onboarding/Onboarding_Books_DB.json';

const DRY_RUN = process.argv.includes('--dry-run');
const CREATE_MISSING = process.argv.includes('--create-missing');

function cleanIsbn(value) {
  return String(value || '')
    .replace(/[-\s]/g, '')
    .trim();
}

/**
 * Un `coverUrl` e bun doar dacă e absolut și nu e placeholder-ul „fără
 * imagine" al librăriei - aceeași verificare ca la import-scp-db.js, unde
 * lipsa ei a stricat 8 coperți care funcționau.
 */
function usableCoverUrl(url) {
  if (typeof url !== 'string') return null;
  const trimmed = url.trim();
  if (!/^https?:\/\//i.test(trimmed)) return null;
  if (/noimg|no-image|placeholder/i.test(trimmed)) return null;
  return trimmed;
}

/**
 * Fără diacritice și cu litere mici. Lista vine de la scrape fără diacritice,
 * catalogul le are - „Bronte" trebuie să se potrivească cu „Brontë".
 */
function fold(value) {
  return String(value || '')
    .normalize('NFD')
    .replace(/\p{Diacritic}/gu, '')
    .toLowerCase();
}

/** Ultimul cuvânt „lung" din numele autorului - de regulă numele de familie. */
function authorKey(author) {
  const parts = fold(author)
    .split(/\s+/)
    .filter((p) => p.length >= 4);
  return parts.length ? parts[parts.length - 1] : '';
}

async function main() {
  const { PrismaClient } = require('@prisma/client');
  const { PrismaPg } = require('@prisma/adapter-pg');

  const adapter = new PrismaPg({ connectionString: process.env.DATABASE_URL });
  const prisma = new PrismaClient({ adapter });

  const db = JSON.parse(fs.readFileSync(DB_PATH, 'utf8'));
  const books = db.books || [];
  console.log(
    `Lista de onboarding: ${books.length} titluri (generat ${db.generatedAt}, ${db.found} găsite la scrape)`,
  );
  if (DRY_RUN) console.log('DRY RUN - nu se scrie nimic\n');

  const stats = {
    matched: 0,
    matchedWithoutAuthor: 0,
    created: 0,
    notInCatalog: 0,
    failed: 0,
  };
  const missing = [];

  // Golim înainte, ca lista din fișier să fie singura sursă de adevăr.
  if (!DRY_RUN) {
    const cleared = await prisma.book.updateMany({
      where: { onboardingRank: { not: null } },
      data: { onboardingRank: null },
    });
    console.log(`Curățat ${cleared.count} marcaje vechi.\n`);
  }

  // ---- o singură trecere peste catalog, pentru toate titlurile ----
  const titles = books
    .map((e) => e.title || e.requestedTitle)
    .filter((t) => typeof t === 'string' && t.trim() !== '');
  const isbns = books.map((e) => cleanIsbn(e.isbn)).filter((i) => i !== '');

  // Cheia normalizată pentru fiecare titlu din listă, calculată de Postgres cu
  // aceeași funcție ca pentru rândurile din catalog.
  const keyRows = await prisma.$queryRaw`
    SELECT t AS original, immutable_unaccent(lower(t)) AS key
    FROM unnest(${titles}::text[]) AS t
  `;
  const keyOf = new Map(keyRows.map((r) => [r.original, r.key]));

  const titleRows = await prisma.$queryRaw`
    SELECT immutable_unaccent(lower("title")) AS key,
           id, "author", "coverUrl", "curatedAt"
    FROM "books"
    WHERE immutable_unaccent(lower("title")) IN (
      SELECT immutable_unaccent(lower(t)) FROM unnest(${titles}::text[]) AS t
    )
    ORDER BY
      ("curatedAt" IS NOT NULL) DESC,
      ("coverUrl" IS NOT NULL) DESC,
      ("description" IS NOT NULL) DESC,
      ("genre" IS NOT NULL) DESC
  `;
  const byTitleKey = new Map();
  for (const row of titleRows) {
    const bucket = byTitleKey.get(row.key);
    if (bucket) bucket.push(row);
    else byTitleKey.set(row.key, [row]);
  }

  const isbnRows = isbns.length
    ? await prisma.book.findMany({
        where: { isbn: { in: isbns } },
        select: { id: true, isbn: true, author: true, coverUrl: true, curatedAt: true },
      })
    : [];
  const byIsbn = new Map(isbnRows.map((r) => [r.isbn, r]));

  console.log(
    `Potriviri în catalog: ${byIsbn.size} după ISBN, ${byTitleKey.size} titluri distincte.
`,
  );

  let rank = 0;

  for (const entry of books) {
    const title = entry.title || entry.requestedTitle;
    const author = entry.author || entry.requestedAuthor;
    if (!title) continue;

    rank += 1;

    try {
      const isbn = cleanIsbn(entry.isbn);
      let match = (isbn && byIsbn.get(isbn)) || null;

      if (!match) {
        const key = keyOf.get(title);
        const candidates = key ? byTitleKey.get(key) : null;
        if (candidates && candidates.length) {
          // Autorul e PREFERINȚĂ, nu filtru. Ca filtru dur pierdea potriviri
          // evidente: importul Open Library păstrează numele în scrierea
          // originală, deci „Anna Karenina" are autorul „Лев Толстой", pe care
          // „Lev Nikolaevici Tolstoi" din listă nu-l va confirma niciodată.
          // Măsurat pe lista de azi: 58 de potriviri cu filtru dur, față de 61
          // fără el.
          //
          // Titlul e deja o dovadă puternică (egalitate exactă, nu „conține"),
          // iar `candidates` vine sortat cu ediția cea mai completă prima -
          // deci când autorul nu confirmă, tot cea mai bună ediție iese.
          const wanted = authorKey(author);
          const confirmed = wanted
            ? candidates.find((c) => fold(c.author).includes(wanted))
            : null;
          match = confirmed || candidates[0];
          if (!confirmed) stats.matchedWithoutAuthor += 1;
        }
      }

      if (!match) {
        if (!CREATE_MISSING) {
          stats.notInCatalog += 1;
          missing.push(`${title} - ${author || '?'}`);
          rank -= 1; // rangul rămâne compact, fără găuri
          continue;
        }
        if (!DRY_RUN) {
          await prisma.book.create({
            data: {
              title,
              author: author || null,
              isbn: isbn || null,
              publisher: entry.publisher || null,
              publishedYear: entry.publishedYear || null,
              pageCount: entry.pageCount || null,
              language: entry.language || null,
              coverUrl: usableCoverUrl(entry.coverUrl),
              source: 'onboarding_list',
              curatedAt: new Date(),
              onboardingRank: rank,
            },
          });
        }
        stats.created += 1;
        continue;
      }

      if (!DRY_RUN) {
        await prisma.book.update({
          where: { id: match.id },
          data: {
            onboardingRank: rank,
            // Coperta e obligatorie ca să fie servibilă la swipe: dacă rândul
            // n-are una, luăm ce a găsit scrape-ul.
            coverUrl: match.coverUrl || usableCoverUrl(entry.coverUrl),
            curatedAt: match.curatedAt || new Date(),
          },
        });
      }
      stats.matched += 1;
    } catch (error) {
      stats.failed += 1;
      rank -= 1;
      console.error(`  ! ${title}: ${error.message}`);
    }
  }

  // Cât din listă e chiar servibilă la onboarding: Book Match cere copertă
  // (vezi BookMatchService.onboardingCandidates), deci un rând marcat dar fără
  // copertă nu ajunge niciodată pe ecran.
  const servable = DRY_RUN
    ? 0
    : await prisma.book.count({
        where: { onboardingRank: { not: null }, coverUrl: { not: null } },
      });

  console.log('\n--- rezultat ---');
  console.log(`  potrivite în catalog: ${stats.matched}`);
  console.log(
    `    din care doar după titlu (autor neconfirmat): ${stats.matchedWithoutAuthor}`,
  );
  console.log(`  create:               ${stats.created}`);
  console.log(`  lipsă din catalog:    ${stats.notInCatalog}`);
  console.log(`  eșuate:               ${stats.failed}`);
  if (!DRY_RUN) {
    console.log(`  servibile (cu copertă): ${servable}`);
  }
  if (missing.length) {
    console.log(
      `\nNu există în \`books\`${CREATE_MISSING ? '' : ' (rulează cu --create-missing ca să le creezi)'}:`,
    );
    missing.slice(0, 25).forEach((m) => console.log(`  ${m}`));
    if (missing.length > 25) {
      console.log(`  ... și încă ${missing.length - 25}`);
    }
  }

  await prisma.$disconnect();
}

main().catch((error) => {
  console.error(error);
  process.exit(1);
});
