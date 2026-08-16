/**
 * Normalizează `books.genre` la lista canonică din
 * `src/common/constants/book-genres.ts` (BOOK_GENRES).
 *
 * Catalogul a acumulat variante fragmentate ale aceluiași gen („SF" /
 * „Science Fiction" / „Scifi" / „Sci-Fi") pentru că importurile externe scriu
 * text liber în câmp, iar Book Match grupează candidații STRICT pe valoarea
 * exactă a genului (vezi coldStartBatch în book-match.service.ts) - deci
 * fiecare variantă e un bucket separat, cu prea puține cărți în el.
 *
 * Ce face:
 *   - mapează fiecare variantă cunoscută la genul canonic;
 *   - pune `null` pe valorile-gunoi („Test", „idk", string gol) - mai bine
 *     fără gen decât cu un gen inventat: coldStartBatch tratează null ca
 *     bucket separat, nu îl bagă într-un gen real;
 *   - raportează valorile pe care nu le recunoaște, ca să poată fi adăugate
 *     în tabel la o rulare următoare (le lasă neatinse, nu ghicește).
 *
 * IDEMPOTENT: valorile canonice se mapează la ele însele, deci a doua rulare
 * nu mai are ce actualiza (0 rânduri afectate). Verificabil: după rulare,
 * `--dry-run` raportează 0 modificări.
 *
 * Rulare (DRY-RUN implicit - nu scrie nimic fără `--apply`):
 *   docker compose -f docker-compose.prod.yml exec backend \
 *     node prisma/normalize-book-genres.js
 *   docker compose -f docker-compose.prod.yml exec backend \
 *     node prisma/normalize-book-genres.js --apply
 *
 * Versiune .js (nu .ts): imaginea de producție nu are pnpm/ts-node.
 */
require('dotenv/config');
const { PrismaClient } = require('@prisma/client');
const { PrismaPg } = require('@prisma/adapter-pg');

const adapter = new PrismaPg({ connectionString: process.env.DATABASE_URL });
const prisma = new PrismaClient({ adapter });

const APPLY = process.argv.includes('--apply');

/** Copie a BOOK_GENRES - scriptul rulează cu `node`, nu poate importa din src/. */
const BOOK_GENRES = [
  'Ficțiune',
  'Non-ficțiune',
  'Clasic',
  'Clasic românesc',
  'Fantasy',
  'SF',
  'Thriller',
  'Mister',
  'Distopie',
  'Romantic',
  'Istoric',
  'Biografie',
  'Dezvoltare personală',
  'Psihologie',
  'Filosofie',
  'Business',
  'Poezie',
  'Copii',
  'Young adult',
  'Benzi desenate',
];

/**
 * Cheie de potrivire: lowercase, fără diacritice, fără punctuație/spații.
 * Așa „Sci-Fi", „sci fi" și „scifi" cad pe aceeași intrare din tabel și nu
 * trebuie enumerate toate variantele de scriere.
 */
function key(value) {
  return String(value)
    .normalize('NFD')
    .replace(/[̀-ͯ]/g, '')
    // ș/ț cu virgulă vs. sedilă nu se descompun uniform - le pliem manual.
    .replace(/[șş]/gi, 's')
    .replace(/[țţ]/gi, 't')
    .toLowerCase()
    .replace(/[^a-z0-9]/g, '');
}

/**
 * variantă -> gen canonic (sau null = gunoi, se șterge valoarea).
 * Genurile canonice sunt adăugate automat mai jos (se mapează la ele însele).
 */
const RAW_MAPPING = {
  // --- Ficțiune ---
  'Fiction': 'Ficțiune',
  'Cosmologia': 'Non-ficțiune',
  'Ficțiune istorică': 'Istoric',
  'Fictiune': 'Ficțiune',
  'Literary Fiction': 'Ficțiune',
  'Contemporary Fiction': 'Ficțiune',
  'General Fiction': 'Ficțiune',
  'Novel': 'Ficțiune',
  'Roman': 'Ficțiune',
  'Proză': 'Ficțiune',
  'Short Stories': 'Ficțiune',
  'Nuvele': 'Ficțiune',
  'Literatură': 'Ficțiune',
  'Literature': 'Ficțiune',
  'Beletristică': 'Ficțiune',

  // --- Non-ficțiune ---
  'Nonfiction': 'Non-ficțiune',
  'Non-fiction': 'Non-ficțiune',
  'Non fictiune': 'Non-ficțiune',
  'Science': 'Non-ficțiune',
  'Popular Science': 'Non-ficțiune',
  'Știință': 'Non-ficțiune',
  'Educational': 'Non-ficțiune',
  'Reference': 'Non-ficțiune',
  'Eseu': 'Non-ficțiune',
  'Essays': 'Non-ficțiune',
  'Travel': 'Non-ficțiune',
  'Călătorii': 'Non-ficțiune',
  'Health': 'Non-ficțiune',
  'Cooking': 'Non-ficțiune',
  'Gastronomie': 'Non-ficțiune',
  'Religion': 'Non-ficțiune',
  'Religie': 'Non-ficțiune',
  'Spirituality': 'Non-ficțiune',
  'Spiritualitate': 'Non-ficțiune',
  'Memoir': 'Biografie', // memoriile sunt cel mai aproape de Biografie

  // --- Clasic ---
  'Classic': 'Clasic',
  'Classics': 'Clasic',
  'Clasici': 'Clasic',
  'Clasice': 'Clasic',
  'Literatură clasică': 'Clasic',
  'Classic Literature': 'Clasic',
  'Literatură universală': 'Clasic',

  // --- Clasic românesc ---
  'Romanian Literature': 'Clasic românesc',
  'Literatură română': 'Clasic românesc',
  'Literatura romana': 'Clasic românesc',
  'Clasici români': 'Clasic românesc',
  'Roman românesc': 'Clasic românesc',
  'Autori români': 'Clasic românesc',

  // --- Fantasy ---
  'Fantezie': 'Fantasy',
  'High Fantasy': 'Fantasy',
  'Epic Fantasy': 'Fantasy',
  'Urban Fantasy': 'Fantasy',
  'Magic': 'Fantasy',
  'Basme': 'Fantasy',
  'Fairy Tales': 'Fantasy',
  'Mitologie': 'Fantasy',
  'Mythology': 'Fantasy',

  // --- SF ---
  'Science Fiction': 'SF',
  'Sci-Fi': 'SF',
  'Scifi': 'SF',
  'Sci fi': 'SF',
  'S.F.': 'SF',
  'Space Opera': 'SF',
  'Cyberpunk': 'SF',
  'Ficțiune științifică': 'SF',
  'Fictiune stiintifica': 'SF',
  'Science-Fiction': 'SF',
  'SF&F': 'SF',

  // --- Thriller ---
  'Suspense': 'Thriller',
  'Horror': 'Thriller', // nu există gen canonic „Horror"; Thriller e cel mai apropiat
  'Groază': 'Thriller',
  'Psychological Thriller': 'Thriller',
  'Action': 'Thriller',
  'Acțiune': 'Thriller',
  'Aventură': 'Thriller',
  'Adventure': 'Thriller',
  'Spionaj': 'Thriller',
  'Spy': 'Thriller',

  // --- Mister ---
  'Mystery': 'Mister',
  'Crime': 'Mister',
  'Detective': 'Mister',
  'Detectiv': 'Mister',
  'Polițist': 'Mister',
  'Politist': 'Mister',
  'Roman polițist': 'Mister',
  'Whodunit': 'Mister',
  'Noir': 'Mister',

  // --- Distopie ---
  'Dystopia': 'Distopie',
  'Dystopian': 'Distopie',
  'Distopic': 'Distopie',
  'Post-apocalyptic': 'Distopie',
  'Postapocaliptic': 'Distopie',

  // --- Romantic ---
  'Romance': 'Romantic',
  'Dragoste': 'Romantic',
  'Romanță': 'Romantic',
  'Love Story': 'Romantic',
  'Chick Lit': 'Romantic',
  'Contemporary Romance': 'Romantic',
  'Erotic': 'Romantic',

  // --- Istoric ---
  'Historical': 'Istoric',
  'Historical Fiction': 'Istoric',
  'History': 'Istoric',
  'Istorie': 'Istoric',
  'Roman istoric': 'Istoric',
  'War': 'Istoric',
  'Război': 'Istoric',

  // --- Biografie ---
  'Biography': 'Biografie',
  'Autobiography': 'Biografie',
  'Autobiografie': 'Biografie',
  'Memorii': 'Biografie',
  'Memoirs': 'Biografie',
  'Jurnal': 'Biografie',

  // --- Dezvoltare personală ---
  'Self-help': 'Dezvoltare personală',
  'Self help': 'Dezvoltare personală',
  'Selfhelp': 'Dezvoltare personală',
  'Personal Development': 'Dezvoltare personală',
  'Personal Growth': 'Dezvoltare personală',
  'Motivational': 'Dezvoltare personală',
  'Motivațional': 'Dezvoltare personală',
  'Productivity': 'Dezvoltare personală',
  'Productivitate': 'Dezvoltare personală',
  'Habits': 'Dezvoltare personală',
  'Habit': 'Dezvoltare personală', // vezi nota din raport: „Habit" venea din Atomic Habits
  'Obiceiuri': 'Dezvoltare personală',
  'Lifestyle': 'Dezvoltare personală',
  'Wellness': 'Dezvoltare personală',

  // --- Psihologie ---
  'Psychology': 'Psihologie',
  'Psihologia': 'Psihologie',
  'Cognitive Science': 'Psihologie',
  'Behavioral Economics': 'Psihologie',
  'Psihanaliză': 'Psihologie',
  'Psychoanalysis': 'Psihologie',
  'Mental Health': 'Psihologie',
  'Sănătate mintală': 'Psihologie',

  // --- Filosofie ---
  'Philosophy': 'Filosofie',
  'Filozofie': 'Filosofie',
  'Stoicism': 'Filosofie',
  'Stoicism practic': 'Filosofie',
  'Ethics': 'Filosofie',
  'Etică': 'Filosofie',
  'Logic': 'Filosofie',

  // --- Business ---
  'Economics': 'Business',
  'Economie': 'Business',
  'Finance': 'Business',
  'Finanțe': 'Business',
  'Management': 'Business',
  'Marketing': 'Business',
  'Entrepreneurship': 'Business',
  'Antreprenoriat': 'Business',
  'Business & Economics': 'Business',
  'Investing': 'Business',
  'Investiții': 'Business',
  'Leadership': 'Business',
  'Startup': 'Business',

  // --- Poezie ---
  'Poetry': 'Poezie',
  'Poems': 'Poezie',
  'Poeme': 'Poezie',
  'Poezii': 'Poezie',
  'Versuri': 'Poezie',
  'Lirică': 'Poezie',

  // --- Copii ---
  'Children': 'Copii',
  "Children's": 'Copii',
  "Children's Books": 'Copii',
  'Juvenile Fiction': 'Copii',
  'Juvenile': 'Copii',
  'Picture Book': 'Copii',
  'Carte pentru copii': 'Copii',
  'Literatură pentru copii': 'Copii',
  'Preșcolari': 'Copii',

  // --- Young adult ---
  'YA': 'Young adult',
  'Young Adult Fiction': 'Young adult',
  'Teen': 'Young adult',
  'Adolescenți': 'Young adult',
  'Coming of Age': 'Young adult',

  // --- Benzi desenate ---
  'Comics': 'Benzi desenate',
  'Comic': 'Benzi desenate',
  'Graphic Novel': 'Benzi desenate',
  'Graphic Novels': 'Benzi desenate',
  'Manga': 'Benzi desenate',
  'BD': 'Benzi desenate',
  'Bandă desenată': 'Benzi desenate',

  // --- gunoi: se pune null, NU se forțează într-un gen ---
  'Test': null,
  'test123': null,
  'idk': null,
  'asd': null,
  'asdf': null,
  'aaa': null,
  'xxx': null,
  'n/a': null,
  'na': null,
  'none': null,
  'null': null,
  'undefined': null,
  'necunoscut': null,
  'altele': null,
  'other': null,
  'Various': null,
  'General': null,
  '-': null,
  '.': null,
  '?': null,
};

/** cheie normalizată -> { target, junk } */
const MAPPING = new Map();
for (const canonical of BOOK_GENRES) {
  MAPPING.set(key(canonical), { target: canonical, junk: false });
}
for (const [variant, target] of Object.entries(RAW_MAPPING)) {
  const k = key(variant);
  // Nu suprascriem un gen canonic cu o variantă (ex. „SF" e deja canonic).
  if (MAPPING.has(k) && MAPPING.get(k).target !== null) continue;
  MAPPING.set(k, { target, junk: target === null });
}

/** String gol / doar spații -> gunoi, indiferent de tabel. */
function resolve(current) {
  if (current == null) return { known: true, target: null };
  const k = key(current);
  if (k === '') return { known: true, target: null };
  const hit = MAPPING.get(k);
  if (!hit) return { known: false, target: current };
  return { known: true, target: hit.target };
}

async function main() {
  console.log(APPLY ? '=== APLIC modificările ===' : '=== DRY RUN (fără scriere) — adaugă --apply ca să scrie ===');

  const groups = await prisma.book.groupBy({
    by: ['genre'],
    _count: { _all: true },
    orderBy: { _count: { genre: 'desc' } },
  });

  const changes = []; // { from, to, count }
  const unchanged = [];
  const unknown = [];

  for (const g of groups) {
    const from = g.genre;
    const count = g._count._all;
    if (from == null) {
      unchanged.push({ from: '(null)', count });
      continue;
    }
    const { known, target } = resolve(from);
    if (!known) {
      unknown.push({ from, count });
      continue;
    }
    if (target === from) unchanged.push({ from, count });
    else changes.push({ from, to: target, count });
  }

  console.log(`\nValori distincte în books.genre: ${groups.length}`);

  console.log('\n--- Deja canonice / neatinse ---');
  for (const u of unchanged) console.log(`  ${JSON.stringify(u.from)}  (${u.count})`);

  console.log('\n--- De remapat ---');
  if (changes.length === 0) console.log('  (nimic — catalogul e deja normalizat)');
  for (const c of changes) {
    console.log(`  ${JSON.stringify(c.from)} -> ${c.to === null ? 'NULL (gunoi)' : JSON.stringify(c.to)}  (${c.count})`);
  }

  if (unknown.length > 0) {
    console.log('\n--- NERECUNOSCUTE (lăsate neatinse; adaugă-le în RAW_MAPPING și rulează din nou) ---');
    for (const u of unknown) console.log(`  ${JSON.stringify(u.from)}  (${u.count})`);
  }

  const totalRows = changes.reduce((s, c) => s + c.count, 0);
  console.log(`\nRânduri care s-ar modifica: ${totalRows} (din ${groups.reduce((s, g) => s + g._count._all, 0)} cărți).`);

  if (!APPLY) {
    console.log('\nDRY RUN — nu s-a scris nimic. Rulează cu --apply.');
    return;
  }

  let written = 0;
  for (const c of changes) {
    const res = await prisma.book.updateMany({
      where: { genre: c.from },
      data: { genre: c.to },
    });
    written += res.count;
    console.log(`  actualizat ${res.count}: ${JSON.stringify(c.from)} -> ${c.to === null ? 'NULL' : c.to}`);
  }

  // Stringurile goale/whitespace nu apar neapărat ca grup separat dacă au
  // forme diferite (' ', '  ') - le curățăm oricum la final.
  const blanks = await prisma.book.updateMany({
    where: { genre: '' },
    data: { genre: null },
  });
  if (blanks.count > 0) console.log(`  actualizat ${blanks.count}: '' -> NULL`);

  console.log(`\nGata. Rânduri scrise: ${written + blanks.count}.`);
  console.log('Rulează din nou fără --apply: ar trebui să raporteze 0 de remapat (idempotent).');
}

main()
  .catch((e) => {
    console.error(e);
    process.exitCode = 1;
  })
  .finally(() => prisma.$disconnect());
