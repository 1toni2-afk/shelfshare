/**
 * Import în masă în `books` din dump-ul COMBINAT Open Library („cdump"):
 * un .txt.gz de ~49 GB, cu toate tipurile de înregistrări amestecate
 * (/type/edition, /type/work, /type/author, /type/redirect, ...), câte un
 * obiect JSON pe linie.
 *
 * Format verificat EMPIRIC pe fișierul real (ol_cdump_2026-07-31.txt.gz),
 * nu presupus: exact 5 coloane separate prin TAB
 *     type \t key \t revision \t last_modified \t json
 * (300k linii verificate: 100% au fix 5 coloane).
 *
 * Fișierul NU se decomprimă pe disc niciodată (ar ajunge la 200+ GB): se
 * citește ca stream `createReadStream -> gunzip -> readline`.
 *
 * ---------------------------------------------------------------------------
 * DE CE DOUĂ TRECERI
 * ---------------------------------------------------------------------------
 * O ediție (/type/edition) are ISBN, coperți, limbă, editură, pagini; lucrarea
 * (/type/work) are `subjects` + `description`. Liniile sunt intercalate (nu
 * grupate), deci nu poți corela dintr-o singură trecere fără să ții tot
 * fișierul în memorie.
 *
 *   Trecerea 1: doar liniile /type/work, doar cele care au `subjects` -> map
 *               workKey -> { subjects, description }. Cheia se stochează ca
 *               NUMĂR (OL<id>W -> id), nu ca string: un Map cu chei numerice e
 *               semnificativ mai compact la ~20-30M de intrări.
 *   Trecerea 2: doar liniile /type/edition care trec pre-filtrul ieftin de
 *               substring, se caută lucrarea în map și se compune rândul.
 *
 * Pre-filtru ieftin (înainte de JSON.parse, care e partea scumpă): se cere ca
 * linia să conțină textual `"covers":`, `"isbn_1` și `/languages/eng` sau
 * `/languages/rum`. Aruncă majoritatea liniilor fără să le parseze - măsurat,
 * asta urcă debitul de la ~4.7 MB/s (parse pe tot) la ~17 MB/s comprimat.
 *
 * OBSERVAT PE FIȘIERUL REAL, contează pentru corectitudine: legătura
 * ediție -> lucrare LIPSEȘTE de pe majoritatea înregistrărilor vechi (în
 * primele 3M de linii doar 1.1% dintre ediții au `works`), în schimb 83%
 * dintre ediții au `subjects` DIRECT pe ele. De asta, dacă lucrarea nu se
 * găsește în map, se cade pe subiectele proprii ale ediției - altfel importul
 * ar arunca aproape tot.
 *
 * ---------------------------------------------------------------------------
 * AUTOR - decizie asumată
 * ---------------------------------------------------------------------------
 * Numele autorilor sunt în înregistrări /type/author separate; edițiile au
 * doar referințe `authors: [{key: "/authors/OL...A"}]`. Măsurat pe dump:
 *   - 93% dintre edițiile care trec filtrul AU referințe de autor;
 *   - dar doar ~1-3% au `by_statement` (numele scris pe ediție).
 * Deci fără corelația cu /type/author aproape toate rândurile ar avea
 * `author: null`.
 *
 * Compromisul ales: NU o a treia trecere peste 49 GB (+50% timp), ci
 * indexarea numelor CHIAR ÎN trecerea 1, care oricum citește tot fișierul -
 * dar OPȚIONAL, sub `--authors`, pentru că e singura parte care costă RAM
 * serios. Măsurat: 2.49M de autori indexați = 534 MB RSS (~200 B/intrare).
 * Map-ul e cheie numerică (OL<id>A -> id), nu string. `--max-authors`
 * plafonează indexul ca să nu pice cu OOM la ore de rulare.
 *
 * Fără `--authors` se folosește doar `by_statement` (pe ediție, gratis): se
 * curăță prefixul „by ", se taie la primul `;` („; illustrated by ..."). Dacă
 * nu se rezolvă niciun nume, `author` rămâne null - preferăm null decât un
 * nume inventat (aceeași convenție ca normalize-book-genres.js pentru `genre`).
 *
 * ---------------------------------------------------------------------------
 * RULARE
 * ---------------------------------------------------------------------------
 * Implicit: DRY-RUN + slice mărginit (primele MAX_LINES linii), nu scrie nimic:
 *   node prisma/import-openlibrary-cdump.js --file D:/.../ol_cdump.txt.gz
 *
 * Import real (ambele flag-uri sunt obligatorii - `--full` ca să atace tot
 * fișierul, `--apply` ca să scrie în bază). Fișierul stă pe D: pe gazdă, iar
 * Postgres nu e expus pe gazdă - deci un container one-off pe rețeaua compose,
 * cu directorul montat read-only, fără să copiem cei 49 GB nicăieri:
 *
 *   docker compose -f docker-compose.prod.yml run --rm \
 *     -v "D:\ol_cdump_2026-07-31:/data:ro" backend \
 *     node --max-old-space-size=8192 prisma/import-openlibrary-cdump.js \
 *     --full --apply --authors
 *
 * Flag-uri:
 *   --file <cale>      implicit $OL_CDUMP_FILE sau /data/ol_cdump_2026-07-31.txt.gz
 *   --full             procesează tot fișierul (altfel: doar --max-lines)
 *   --apply            scrie efectiv în bază (altfel: dry-run)
 *   --authors          indexează numele autorilor (vezi mai sus; costă RAM)
 *   --max-authors N    plafonul indexului de autori (implicit 20.000.000)
 *   --max-lines N      limita pentru modul mărginit (implicit 3.000.000)
 *   --samples N        câte rânduri exemplu se tipăresc în dry-run (implicit 15)
 *   --limit-rows N     oprește după N rânduri acceptate (test/plafon)
 *
 * Versiune .js (nu .ts): imaginea de producție nu are pnpm/ts-node.
 */
require('dotenv/config');

const fs = require('fs');
const zlib = require('zlib');
const readline = require('readline');

// ---------------------------------------------------------------------------
// CLI
// ---------------------------------------------------------------------------

function argValue(name, fallback) {
  const i = process.argv.indexOf(name);
  return i >= 0 && process.argv[i + 1] ? process.argv[i + 1] : fallback;
}

const FILE =
  argValue('--file', process.env.OL_CDUMP_FILE || '/data/ol_cdump_2026-07-31.txt.gz');
const FULL = process.argv.includes('--full');
const APPLY = process.argv.includes('--apply');
const MAX_LINES = parseInt(argValue('--max-lines', '3000000'), 10);
const SAMPLES = parseInt(argValue('--samples', '15'), 10);
const LIMIT_ROWS = parseInt(argValue('--limit-rows', '0'), 10) || Infinity;
/** Vezi „AUTOR - decizie asumată" din antet. Costă RAM, deci e opțional. */
const AUTHORS = process.argv.includes('--authors');
/**
 * Plafon de siguranță pentru map-ul de autori. Măsurat pe fișierul real:
 * ~200 de octeți RSS pe intrare (2.49M autori = 534 MB RSS). 20M de intrări
 * ≈ 4 GB. Când se atinge plafonul se oprește indexarea și se avertizează,
 * în loc să pice cu OOM după o oră de rulare.
 */
const MAX_AUTHORS = parseInt(argValue('--max-authors', '20000000'), 10);

/** Marcaj de proveniență (cf. `curated_seed` din seed-curated-books.js). */
const SOURCE = 'ol_cdump_import';
const BATCH_SIZE = 1000;
const DESCRIPTION_MAX = 2000;
const PROGRESS_EVERY = 2_000_000;

/**
 * Limbile acceptate. Open Library folosește coduri MARC de 3 litere, verificat
 * pe fișierul real: `/languages/eng`, `/languages/rum` (NU `ron` - în 3M de
 * linii apar 3657 `rum` și 0 `ron`; `mol` = moldovenească, tot românește, dar
 * doar 34 de apariții, îl luăm și pe el).
 * Valoarea stocată în `books.language` e codul brut, exact ca în
 * BookLookupService (`languages[0].key.replace('/languages/','')`).
 */
const LANG_KEYS = new Map([
  ['/languages/eng', 'eng'],
  ['/languages/rum', 'rum'],
  ['/languages/mol', 'rum'],
]);

// ---------------------------------------------------------------------------
// Mapare subiecte -> gen canonic (adaptată din prisma/normalize-book-genres.js)
// ---------------------------------------------------------------------------

/** Copie a BOOK_GENRES - scriptul rulează cu `node`, nu poate importa din src/. */
const BOOK_GENRES = [
  'Ficțiune', 'Non-ficțiune', 'Clasic', 'Clasic românesc', 'Fantasy', 'SF',
  'Thriller', 'Mister', 'Distopie', 'Romantic', 'Istoric', 'Biografie',
  'Dezvoltare personală', 'Psihologie', 'Filosofie', 'Business', 'Poezie',
  'Copii', 'Young adult', 'Benzi desenate',
];

/** Identic cu `key()` din normalize-book-genres.js (aceleași reguli). */
function key(value) {
  return String(value)
    .normalize('NFD')
    .replace(/[\u0300-\u036f]/g, '')
    .replace(/[șş]/gi, 's')
    .replace(/[țţ]/gi, 't')
    .toLowerCase()
    .replace(/[^a-z0-9]/g, '');
}

/**
 * Tabelul din normalize-book-genres.js, extins cu formele în care apar
 * subiectele Open Library (headings LCSH: „Fiction", „Juvenile fiction",
 * „Detective and mystery stories", „Science fiction", ...).
 * Restul (locuri, persoane, subiecte prea specifice) nu se mapează -> `genre`
 * rămâne null. Mai bine null decât un gen ghicit.
 */
const RAW_MAPPING = {
  // --- Ficțiune ---
  'Fiction': 'Ficțiune', 'Fictiune': 'Ficțiune', 'Literary Fiction': 'Ficțiune',
  'Contemporary Fiction': 'Ficțiune', 'General Fiction': 'Ficțiune',
  'Novel': 'Ficțiune', 'Roman': 'Ficțiune', 'Proză': 'Ficțiune',
  'Short Stories': 'Ficțiune', 'Short stories, English': 'Ficțiune',
  'Short stories, American': 'Ficțiune', 'Nuvele': 'Ficțiune',
  'Literatură': 'Ficțiune', 'Literature': 'Ficțiune', 'Beletristică': 'Ficțiune',
  'Domestic fiction': 'Ficțiune', 'Psychological fiction': 'Ficțiune',
  'Love stories': 'Romantic', 'American fiction': 'Ficțiune',
  'English fiction': 'Ficțiune', 'Fiction, general': 'Ficțiune',
  'Fiction in English': 'Ficțiune',

  // --- Non-ficțiune ---
  'Nonfiction': 'Non-ficțiune', 'Non-fiction': 'Non-ficțiune',
  'Non fictiune': 'Non-ficțiune', 'Science': 'Non-ficțiune',
  'Popular Science': 'Non-ficțiune', 'Știință': 'Non-ficțiune',
  'Educational': 'Non-ficțiune', 'Reference': 'Non-ficțiune',
  'Eseu': 'Non-ficțiune', 'Essays': 'Non-ficțiune', 'Travel': 'Non-ficțiune',
  'Călătorii': 'Non-ficțiune', 'Health': 'Non-ficțiune',
  'Cooking': 'Non-ficțiune', 'Cookery': 'Non-ficțiune',
  'Gastronomie': 'Non-ficțiune', 'Religion': 'Non-ficțiune',
  'Religie': 'Non-ficțiune', 'Spirituality': 'Non-ficțiune',
  'Spiritualitate': 'Non-ficțiune', 'Description and travel': 'Non-ficțiune',
  'Natural history': 'Non-ficțiune', 'Medicine': 'Non-ficțiune',
  'Nature': 'Non-ficțiune', 'Christian life': 'Non-ficțiune',
  'Bible': 'Non-ficțiune', 'Theology': 'Non-ficțiune',
  'Agriculture': 'Non-ficțiune', 'Mathematics': 'Non-ficțiune',
  'Physics': 'Non-ficțiune', 'Chemistry': 'Non-ficțiune',
  'Biology': 'Non-ficțiune', 'Astronomy': 'Non-ficțiune',
  'Architecture': 'Non-ficțiune', 'Art': 'Non-ficțiune',
  'Music': 'Non-ficțiune', 'Education': 'Non-ficțiune',
  'Sports': 'Non-ficțiune', 'Gardening': 'Non-ficțiune',
  'Politics and government': 'Non-ficțiune', 'Social life and customs': 'Non-ficțiune',
  'Memoir': 'Biografie',

  // --- Clasic ---
  'Classic': 'Clasic', 'Classics': 'Clasic', 'Clasici': 'Clasic',
  'Clasice': 'Clasic', 'Literatură clasică': 'Clasic',
  'Classic Literature': 'Clasic', 'Literatură universală': 'Clasic',
  'Classical literature': 'Clasic',

  // --- Clasic românesc ---
  'Romanian Literature': 'Clasic românesc', 'Romanian fiction': 'Clasic românesc',
  'Romanian poetry': 'Poezie', 'Literatură română': 'Clasic românesc',
  'Literatura romana': 'Clasic românesc', 'Clasici români': 'Clasic românesc',
  'Roman românesc': 'Clasic românesc', 'Autori români': 'Clasic românesc',

  // --- Fantasy ---
  'Fantasy': 'Fantasy', 'Fantezie': 'Fantasy', 'Fantasy fiction': 'Fantasy',
  'High Fantasy': 'Fantasy', 'Epic Fantasy': 'Fantasy', 'Urban Fantasy': 'Fantasy',
  'Magic': 'Fantasy', 'Basme': 'Fantasy', 'Fairy Tales': 'Fantasy',
  'Fairy tales': 'Fantasy', 'Folklore': 'Fantasy', 'Mitologie': 'Fantasy',
  'Mythology': 'Fantasy', 'Legends': 'Fantasy', 'Wizards': 'Fantasy',
  'Dragons': 'Fantasy',

  // --- SF ---
  'Science Fiction': 'SF', 'Science fiction': 'SF', 'Sci-Fi': 'SF',
  'Scifi': 'SF', 'Sci fi': 'SF', 'S.F.': 'SF', 'Space Opera': 'SF',
  'Cyberpunk': 'SF', 'Ficțiune științifică': 'SF', 'Fictiune stiintifica': 'SF',
  'Science-Fiction': 'SF', 'SF&F': 'SF', 'Space flight': 'SF',
  'Science fiction, American': 'SF', 'Science fiction, English': 'SF',

  // --- Thriller ---
  'Thriller': 'Thriller', 'Suspense': 'Thriller', 'Horror': 'Thriller',
  'Horror tales': 'Thriller', 'Horror stories': 'Thriller', 'Groază': 'Thriller',
  'Psychological Thriller': 'Thriller', 'Action': 'Thriller',
  'Acțiune': 'Thriller', 'Aventură': 'Thriller', 'Adventure': 'Thriller',
  'Adventure stories': 'Thriller', 'Adventure and adventurers': 'Thriller',
  'Spionaj': 'Thriller', 'Spy': 'Thriller', 'Spy stories': 'Thriller',
  'Suspense fiction': 'Thriller',

  // --- Mister ---
  'Mystery': 'Mister', 'Mystery fiction': 'Mister',
  'Detective and mystery stories': 'Mister', 'Crime': 'Mister',
  'Crime fiction': 'Mister', 'Detective': 'Mister', 'Detectiv': 'Mister',
  'Detectives': 'Mister', 'Polițist': 'Mister', 'Politist': 'Mister',
  'Roman polițist': 'Mister', 'Whodunit': 'Mister', 'Noir': 'Mister',
  'Murder': 'Mister', 'Private investigators': 'Mister',

  // --- Distopie ---
  'Dystopia': 'Distopie', 'Dystopias': 'Distopie', 'Dystopian': 'Distopie',
  'Distopic': 'Distopie', 'Post-apocalyptic': 'Distopie',
  'Postapocaliptic': 'Distopie',

  // --- Romantic ---
  'Romance': 'Romantic', 'Romance fiction': 'Romantic',
  'Love stories, American': 'Romantic', 'Dragoste': 'Romantic',
  'Romanță': 'Romantic', 'Love Story': 'Romantic', 'Chick Lit': 'Romantic',
  'Contemporary Romance': 'Romantic', 'Erotic': 'Romantic',
  'Man-woman relationships': 'Romantic',

  // --- Istoric ---
  'Historical': 'Istoric', 'Historical fiction': 'Istoric',
  'Historical Fiction': 'Istoric', 'History': 'Istoric', 'Istorie': 'Istoric',
  'Roman istoric': 'Istoric', 'War': 'Istoric', 'Război': 'Istoric',
  'World War, 1939-1945': 'Istoric', 'World War, 1914-1918': 'Istoric',
  'Historiography': 'Istoric', 'Antiquities': 'Istoric',
  'Archaeology': 'Istoric', 'Civilization': 'Istoric',

  // --- Biografie ---
  'Biography': 'Biografie', 'Biografie': 'Biografie',
  'Autobiography': 'Biografie', 'Autobiografie': 'Biografie',
  'Memorii': 'Biografie', 'Memoirs': 'Biografie', 'Jurnal': 'Biografie',
  'Diaries': 'Biografie', 'Correspondence': 'Biografie',
  'Biography & Autobiography': 'Biografie',

  // --- Dezvoltare personală ---
  'Self-help': 'Dezvoltare personală', 'Self help': 'Dezvoltare personală',
  'Selfhelp': 'Dezvoltare personală', 'Self-actualization (Psychology)': 'Dezvoltare personală',
  'Personal Development': 'Dezvoltare personală', 'Personal Growth': 'Dezvoltare personală',
  'Motivational': 'Dezvoltare personală', 'Motivațional': 'Dezvoltare personală',
  'Productivity': 'Dezvoltare personală', 'Productivitate': 'Dezvoltare personală',
  'Habits': 'Dezvoltare personală', 'Habit': 'Dezvoltare personală',
  'Obiceiuri': 'Dezvoltare personală', 'Lifestyle': 'Dezvoltare personală',
  'Wellness': 'Dezvoltare personală', 'Conduct of life': 'Dezvoltare personală',
  'Success': 'Dezvoltare personală',

  // --- Psihologie ---
  'Psychology': 'Psihologie', 'Psihologia': 'Psihologie',
  'Cognitive Science': 'Psihologie', 'Behavioral Economics': 'Psihologie',
  'Psihanaliză': 'Psihologie', 'Psychoanalysis': 'Psihologie',
  'Mental Health': 'Psihologie', 'Sănătate mintală': 'Psihologie',
  'Psychotherapy': 'Psihologie', 'Psychiatry': 'Psihologie',

  // --- Filosofie ---
  'Philosophy': 'Filosofie', 'Filozofie': 'Filosofie', 'Stoicism': 'Filosofie',
  'Stoicism practic': 'Filosofie', 'Ethics': 'Filosofie', 'Etică': 'Filosofie',
  'Logic': 'Filosofie', 'Metaphysics': 'Filosofie', 'Aesthetics': 'Filosofie',

  // --- Business ---
  'Economics': 'Business', 'Economie': 'Business', 'Finance': 'Business',
  'Finanțe': 'Business', 'Management': 'Business', 'Marketing': 'Business',
  'Entrepreneurship': 'Business', 'Antreprenoriat': 'Business',
  'Business & Economics': 'Business', 'Business': 'Business',
  'Investing': 'Business', 'Investiții': 'Business', 'Leadership': 'Business',
  'Startup': 'Business', 'Commerce': 'Business',
  'Economic conditions': 'Business', 'Accounting': 'Business',

  // --- Poezie ---
  'Poetry': 'Poezie', 'Poems': 'Poezie', 'Poeme': 'Poezie',
  'Poezii': 'Poezie', 'Versuri': 'Poezie', 'Lirică': 'Poezie',
  'American poetry': 'Poezie', 'English poetry': 'Poezie',

  // --- Copii ---
  'Children': 'Copii', "Children's": 'Copii', "Children's Books": 'Copii',
  "Children's fiction": 'Copii', "Children's stories": 'Copii',
  "Children's literature": 'Copii', "Children's poetry": 'Copii',
  'Juvenile fiction': 'Copii', 'Juvenile Fiction': 'Copii',
  'Juvenile literature': 'Copii', 'Juvenile': 'Copii',
  'Picture Book': 'Copii', 'Picture books for children': 'Copii',
  'Carte pentru copii': 'Copii', 'Literatură pentru copii': 'Copii',
  'Preșcolari': 'Copii', 'Readers': 'Copii',

  // --- Young adult ---
  'YA': 'Young adult', 'Young adult fiction': 'Young adult',
  'Young Adult Fiction': 'Young adult', 'Young adult literature': 'Young adult',
  'Teen': 'Young adult', 'Teenagers': 'Young adult',
  'Adolescenți': 'Young adult', 'Coming of Age': 'Young adult',

  // --- Benzi desenate ---
  'Comics': 'Benzi desenate', 'Comic': 'Benzi desenate',
  'Comic books, strips, etc': 'Benzi desenate',
  'Comic books, strips, etc.': 'Benzi desenate',
  'Graphic Novel': 'Benzi desenate', 'Graphic novels': 'Benzi desenate',
  'Graphic Novels': 'Benzi desenate', 'Manga': 'Benzi desenate',
  'BD': 'Benzi desenate', 'Bandă desenată': 'Benzi desenate',
  'Cartoons and caricatures': 'Benzi desenate',
};

/** cheie normalizată -> gen canonic */
const MAPPING = new Map();
for (const canonical of BOOK_GENRES) MAPPING.set(key(canonical), canonical);
for (const [variant, target] of Object.entries(RAW_MAPPING)) {
  const k = key(variant);
  if (!MAPPING.has(k)) MAPPING.set(k, target);
}

/**
 * Primul subiect care se potrivește pe lista canonică. Subiectele OL sunt
 * headings LCSH cu calificatori („Biography: general", „Detective and mystery
 * stories -- England").
 *
 * Ordinea subiectelor din Open Library e semnificativă (primul e cel mai
 * relevant), deci se merge subiect cu subiect: pentru fiecare, întâi
 * potrivirea exactă pe subiectul întreg, apoi pe segmentele despărțite de
 * `--`, `,`, `:`, `(`, `)`, `/`. Abia dacă subiectul 1 nu dă nimic se trece la
 * subiectul 2 - altfel „Biography: general" (primul) ar pierde în fața lui
 * „History" (al doilea, potrivire exactă) și cartea ar ajunge „Istoric".
 */
function mapGenre(subjects) {
  if (!subjects || subjects.length === 0) return null;
  for (const raw of subjects) {
    if (typeof raw !== 'string') continue;
    const s = raw.trim();
    if (!s) continue;
    const direct = MAPPING.get(key(s));
    if (direct) return direct;
    for (const part of s.split(/--|[,:()\/]/)) {
      const t = part.trim();
      if (!t) continue;
      const hit = MAPPING.get(key(t));
      if (hit) return hit;
    }
  }
  return null;
}

// ---------------------------------------------------------------------------
// Helperi de câmp
// ---------------------------------------------------------------------------

/** „/works/OL8418427W" -> 8418427 (cheie numerică, map mai compact). */
function workKeyToId(k) {
  if (typeof k !== 'string') return null;
  const m = /^\/works\/OL(\d+)W$/.exec(k);
  return m ? Number(m[1]) : null;
}

/** „/authors/OL2809340A" -> 2809340 */
function authorKeyToId(k) {
  if (typeof k !== 'string') return null;
  const m = /^\/authors\/OL(\d+)A$/.exec(k);
  return m ? Number(m[1]) : null;
}

/** OL descriptions sunt fie string, fie `{type, value}`. Tratăm ambele. */
function textOf(value) {
  if (!value) return null;
  const s = typeof value === 'string' ? value : typeof value.value === 'string' ? value.value : null;
  if (!s) return null;
  // Subsolul „----------\n[source]..." de pe descrierile OL nu e conținut util.
  const clean = s.split('\n----------')[0].replace(/\(\[source\]\[\d+\]\)/g, '').trim();
  if (!clean) return null;
  return clean.length > DESCRIPTION_MAX ? clean.slice(0, DESCRIPTION_MAX - 1).trimEnd() + '…' : clean;
}

/**
 * `publish_date` e text liber („November 1, 2002", „c1997", „[1892]", „1892?").
 * Fără `\b` la început: în „c1997" litera lipește de cifră și `\b` n-ar prinde,
 * iar forma asta (copyright) e foarte frecventă în înregistrările MARC vechi.
 */
function extractYear(dateStr) {
  if (!dateStr) return null;
  const m = String(dateStr).match(/(1[0-9]{3}|20[0-9]{2})(?![0-9])/);
  if (!m) return null;
  const y = parseInt(m[1], 10);
  const now = new Date().getFullYear() + 1;
  return y >= 1400 && y <= now ? y : null;
}

/**
 * `by_statement` -> nume de autor. Vezi nota din antet: e singura sursă de
 * nume disponibilă fără o a treia trecere peste fișier.
 */
function authorFromByStatement(by) {
  if (typeof by !== 'string') return null;
  let s = by.split(';')[0].trim();
  s = s.replace(/^(by|By|BY)\s+/, '').replace(/\s*[.,]\s*$/, '').trim();
  // „edited by X", „translated by X" - tot un nume real, îl păstrăm curățat.
  s = s.replace(/^(edited|translated|compiled|illustrated|selected)\s+by\s+/i, '').trim();
  if (s.length < 3 || s.length > 120) return null;
  // Fără litere = gunoi („1892-", „[s.n.]").
  if (!/\p{L}{2}/u.test(s)) return null;
  return s;
}

/** ISBN-13 e preferat; se păstrează doar cifrele (+X final la ISBN-10). */
function normIsbn(v) {
  if (typeof v !== 'string') return null;
  const s = v.replace(/[^0-9Xx]/g, '').toUpperCase();
  if (s.length === 13 && /^\d{13}$/.test(s)) return s;
  if (s.length === 10 && /^\d{9}[\dX]$/.test(s)) return s;
  return null;
}

function pickIsbn(ed) {
  for (const v of ed.isbn_13 || []) { const n = normIsbn(v); if (n && n.length === 13) return n; }
  for (const v of ed.isbn_10 || []) { const n = normIsbn(v); if (n) return n; }
  return null;
}

function pickLanguage(ed) {
  for (const l of ed.languages || []) {
    const k = typeof l === 'string' ? l : l && l.key;
    const hit = LANG_KEYS.get(k);
    if (hit) return hit;
  }
  return null;
}

function cleanTitle(ed) {
  let t = typeof ed.title === 'string' ? ed.title.trim() : '';
  if (!t) return null;
  if (typeof ed.subtitle === 'string' && ed.subtitle.trim()) {
    const sub = ed.subtitle.trim();
    if (t.length + sub.length + 2 <= 300) t = `${t}: ${sub}`;
  }
  return t.length > 300 ? t.slice(0, 300) : t;
}

// ---------------------------------------------------------------------------
// Stream helper
// ---------------------------------------------------------------------------

/**
 * `onLine(line, n, ctl)` primește un `ctl` cu:
 *   ctl.stop()          - oprește citirea (și distruge stream-ul)
 *   ctl.await(promise)  - pune stream-ul pe pauză până se rezolvă promisiunea
 *                         (backpressure real pentru scrierile în bază: altfel
 *                         readline continuă să emită linii cât timp scrierea e
 *                         în curs și batch-urile se adună în memorie)
 */
function streamLines(file, onLine) {
  return new Promise((resolve, reject) => {
    const raw = fs.createReadStream(file, { highWaterMark: 1 << 22 });
    const gunzip = zlib.createGunzip({ chunkSize: 1 << 20 });
    const rl = readline.createInterface({ input: raw.pipe(gunzip), crlfDelay: Infinity });

    let stopped = false;
    let paused = 0;
    const ctl = {
      stop() {
        if (stopped) return;
        stopped = true;
        rl.close();
        raw.destroy();        // NU se decomprimă mai departe; nimic pe disc.
        gunzip.destroy();
      },
      await(promise) {
        paused++;
        rl.pause();
        promise.then(
          () => { if (--paused === 0 && !stopped) rl.resume(); },
          (e) => { paused--; ctl.stop(); reject(e); },
        );
      },
    };

    let n = 0;
    rl.on('line', (line) => {
      if (stopped) return;
      n++;
      onLine(line, n, ctl);
      if (!stopped && !FULL && n >= MAX_LINES) ctl.stop();
    });
    rl.on('close', () => resolve({ lines: n, bytes: raw.bytesRead }));
    raw.on('error', (e) => { if (!stopped) reject(e); });
    gunzip.on('error', (e) => { if (!stopped) reject(e); });
  });
}

/** Începutul coloanei 5 (JSON) dintr-o linie cu 5 coloane TAB. */
function jsonStart(line) {
  let i = -1;
  for (let c = 0; c < 4; c++) {
    i = line.indexOf('\t', i + 1);
    if (i < 0) return -1;
  }
  return i + 1;
}

const mb = (b) => (b / 1e6).toFixed(0);
const rssMB = () => Math.round(process.memoryUsage().rss / 1e6);

// ---------------------------------------------------------------------------
// TRECEREA 1 - map workId -> { subjects, description }
// ---------------------------------------------------------------------------

async function passOne() {
  console.log(
    '--- Trecerea 1: se indexează lucrările (/type/work) cu subiecte' +
    (AUTHORS ? ' + numele autorilor (--authors)' : '') + ' ---',
  );
  // Obiect simplu, NU Map: V8 aruncă "RangeError: Map maximum size exceeded"
  // undeva peste ~16.7M intrări, prag pe care catalogul combinat OL îl trece
  // ușor (confirmat live: crash la 27.87M lucrări indexate). Un obiect plain
  // (dictionary mode în V8) nu are acest plafon structural fix - doar limita
  // de memorie disponibilă. `.size`/`.get`/`.set` devin lungime urmărită
  // manual / acces direct pe proprietate.
  const works = Object.create(null);
  const authorNames = Object.create(null);
  let seen = 0, kept = 0, authorsCapped = false, authorCount = 0;
  const t0 = Date.now();

  const res = await streamLines(FILE, (line, n) => {
    if (n % PROGRESS_EVERY === 0) {
      const s = (Date.now() - t0) / 1000;
      console.log(
        `  [p1] ${n.toLocaleString()} linii | lucrări ${kept.toLocaleString()}` +
        (AUTHORS ? ` | autori ${authorCount.toLocaleString()}` : '') +
        ` | ${mb(process.memoryUsage().rss)} MB RSS | ${Math.round(n / s).toLocaleString()} linii/s`,
      );
    }

    const c = line.charCodeAt(6);

    if (AUTHORS && !authorsCapped && c === 97 /* 'a' din "/type/author" */ && line.startsWith('/type/author\t')) {
      if (authorCount >= MAX_AUTHORS) {
        authorsCapped = true;
        console.warn(
          `  [p1] ATENȚIE: s-a atins plafonul de ${MAX_AUTHORS.toLocaleString()} autori indexați ` +
          `(RSS ${rssMB()} MB). Restul autorilor nu mai intră în index — rândurile afectate ` +
          'vor cădea pe by_statement sau vor rămâne cu author=null. ' +
          'Crește --max-authors și --max-old-space-size dacă vrei acoperire completă.',
        );
        return;
      }
      const at = jsonStart(line);
      if (at < 0) return;
      let a;
      try { a = JSON.parse(line.slice(at)); } catch { return; }
      const id = authorKeyToId(a.key);
      if (id === null) return;
      const name = typeof a.name === 'string' ? a.name
        : typeof a.personal_name === 'string' ? a.personal_name : null;
      if (!name) return;
      const clean = name.trim().replace(/\s*[,;]\s*$/, '');
      if (clean.length >= 2 && clean.length <= 120) { authorNames[id] = clean; authorCount++; }
      return;
    }

    // Pre-filtru pe text brut: doar liniile de tip work care conțin subiecte.
    if (c !== 119 /* 'w' din "/type/work" */) return;
    if (!line.startsWith('/type/work\t')) return;
    seen++;
    if (line.indexOf('"subjects":') < 0) return;

    const at = jsonStart(line);
    if (at < 0) return;
    let j;
    try { j = JSON.parse(line.slice(at)); } catch { return; }
    if (!Array.isArray(j.subjects) || j.subjects.length === 0) return;

    const id = workKeyToId(j.key);
    if (id === null) return;

    // Se reține DOAR genul deja mapat (string scurt sau null) + descrierea,
    // nu tot array-ul de subiecte: la zeci de milioane de lucrări, array-urile
    // de stringuri ar fi partea grea din memorie.
    const genre = mapGenre(j.subjects);
    const description = textOf(j.description);
    const authorId = AUTHORS
      ? authorKeyToId((j.authors || []).map((x) => x && x.author && x.author.key).find(Boolean))
      : null;
    if (genre === null && description === null && authorId === null) return; // n-ar aduce nimic
    works[id] = description === null && authorId === null ? genre : [genre, description, authorId];
    kept++;
  });

  const secs = (Date.now() - t0) / 1000;
  console.log(
    `  [p1] gata: ${res.lines.toLocaleString()} linii, ${mb(res.bytes)} MB comprimat, ` +
    `${secs.toFixed(0)}s (${Math.round(res.lines / secs).toLocaleString()} linii/s, ` +
    `${(res.bytes / 1e6 / secs).toFixed(1)} MB/s)`,
  );
  console.log(
    `  [p1] lucrări văzute: ${seen.toLocaleString()} | indexate: ${kept.toLocaleString()}` +
    (AUTHORS ? ` | autori indexați: ${authorCount.toLocaleString()}` : '') +
    ` | RSS ${rssMB()} MB\n`,
  );
  return { works, authorNames, stats: { ...res, secs, seen, kept } };
}

/** Map-ul stochează fie `genre` (string|null), fie `[genre, description, authorId]`. */
function workEntry(v) {
  if (v === undefined) return null;
  return Array.isArray(v)
    ? { genre: v[0], description: v[1], authorId: v[2] }
    : { genre: v, description: null, authorId: null };
}

// ---------------------------------------------------------------------------
// TRECEREA 2 - ediții -> rânduri Book
// ---------------------------------------------------------------------------

async function passTwo(works, authorNames, existingIsbns, prisma) {
  console.log('--- Trecerea 2: se selectează edițiile și se compun rândurile ---');

  const stats = {
    editions: 0, prefiltered: 0, noIsbn: 0, noCover: 0, noLang: 0,
    noSubjects: 0, dupIsbn: 0, noTitle: 0, accepted: 0, written: 0, failedBatches: 0,
    withWork: 0, withAuthor: 0, withGenre: 0, withDescription: 0, ro: 0,
  };
  const genreHist = new Map();
  const samples = [];
  let batch = [];
  const t0 = Date.now();

  /** O singură scriere la un moment dat, cu stream-ul pe pauză cât durează. */
  async function writeBatch(rows) {
    try {
      const r = await prisma.book.createMany({ data: rows, skipDuplicates: true });
      stats.written += r.count;
    } catch (e) {
      // Un batch picat nu trebuie să oprească un import de ore; îl raportăm.
      stats.failedBatches++;
      console.error(`  [p2] batch eșuat (${rows.length} rânduri): ${e.message}`);
    }
  }

  const res = await streamLines(FILE, (line, n, ctl) => {
    if (n % PROGRESS_EVERY === 0) {
      const s = (Date.now() - t0) / 1000;
      console.log(
        `  [p2] ${n.toLocaleString()} linii | acceptate ${stats.accepted.toLocaleString()}` +
        `${APPLY ? ` | scrise ${stats.written.toLocaleString()}` : ''} | ` +
        `${mb(process.memoryUsage().rss)} MB RSS | ${Math.round(n / s).toLocaleString()} linii/s`,
      );
    }
    if (line.charCodeAt(6) !== 101 /* 'e' din "/type/edition" */) return;
    if (!line.startsWith('/type/edition\t')) return;
    stats.editions++;

    // Pre-filtru ieftin pe text brut, ÎNAINTE de JSON.parse (partea scumpă).
    if (line.indexOf('"covers":') < 0) { stats.noCover++; return; }
    if (line.indexOf('"isbn_1') < 0) { stats.noIsbn++; return; }
    if (line.indexOf('/languages/eng') < 0 &&
        line.indexOf('/languages/rum') < 0 &&
        line.indexOf('/languages/mol') < 0) { stats.noLang++; return; }
    stats.prefiltered++;

    const at = jsonStart(line);
    if (at < 0) return;
    let ed;
    try { ed = JSON.parse(line.slice(at)); } catch { return; }

    const isbn = pickIsbn(ed);
    if (!isbn) { stats.noIsbn++; return; }
    if (existingIsbns.has(isbn)) { stats.dupIsbn++; return; }

    const coverId = (ed.covers || []).find((c) => Number.isInteger(c) && c > 0);
    if (!coverId) { stats.noCover++; return; }

    const language = pickLanguage(ed);
    if (!language) { stats.noLang++; return; }

    const title = cleanTitle(ed);
    if (!title) { stats.noTitle++; return; }

    // Corelația cu lucrarea (trecerea 1). Dacă ediția nu are `works` sau
    // lucrarea n-a fost indexată, se cade pe subiectele PROPRII ale ediției:
    // în dump-ul real 83% dintre ediții au `subjects` direct pe ele, iar
    // legătura `works` lipsește de pe majoritatea înregistrărilor vechi.
    let genre = null, description = null, workAuthorId = null, matchedWork = false;
    for (const w of ed.works || []) {
      const entry = workEntry(works[workKeyToId(w && w.key)]);
      if (!entry) continue;
      matchedWork = true;
      genre = genre ?? entry.genre;
      description = description ?? entry.description;
      workAuthorId = workAuthorId ?? entry.authorId;
      if (genre && description) break;
    }
    if (genre === null) genre = mapGenre(ed.subjects) || mapGenre(ed.genres);
    if (description === null) description = textOf(ed.description);

    // Autor: numele indexat (doar cu --authors), întâi de pe ediție, apoi de pe
    // lucrare; altfel `by_statement`, care e pe ediție și nu costă nimic.
    let author = null;
    if (AUTHORS) {
      for (const a of ed.authors || []) {
        const name = authorNames[authorKeyToId(a && a.key)];
        if (name) { author = name; break; }
      }
      if (!author && workAuthorId !== null) author = authorNames[workAuthorId] || null;
    }
    if (!author) author = authorFromByStatement(ed.by_statement);

    // Pragul de calitate: fără niciun subiect utilizabil (nici de pe lucrare,
    // nici de pe ediție) rândul n-ar avea gen -> nu intră în catalog.
    if (genre === null) { stats.noSubjects++; return; }

    const row = {
      isbn,
      title,
      author,
      description,
      coverUrl: `https://covers.openlibrary.org/b/id/${coverId}-L.jpg`,
      publisher: typeof (ed.publishers || [])[0] === 'string' ? ed.publishers[0].slice(0, 200) : null,
      publishedYear: extractYear(ed.publish_date),
      pageCount: Number.isInteger(ed.number_of_pages) && ed.number_of_pages > 0 && ed.number_of_pages < 20000
        ? ed.number_of_pages : null,
      language,
      genre,
      source: SOURCE,
      // popularityScore rămâne null: import bulk, n-avem semnal de popularitate.
    };

    // Dedup și în interiorul rulării (ISBN e unic în DB; același ISBN poate
    // apărea pe mai multe ediții OL).
    existingIsbns.add(isbn);

    stats.accepted++;
    if (matchedWork) stats.withWork++;
    if (row.author) stats.withAuthor++;
    if (row.genre) stats.withGenre++;
    if (row.description) stats.withDescription++;
    if (language === 'rum') stats.ro++;
    genreHist.set(genre, (genreHist.get(genre) || 0) + 1);
    if (samples.length < SAMPLES) samples.push(row);

    batch.push(row);
    if (batch.length >= BATCH_SIZE) {
      const pending = batch;
      batch = [];
      // Stream pe pauză cât durează scrierea: fără asta readline continuă să
      // emită linii și batch-urile s-ar aduna nelimitat în memorie.
      if (APPLY) ctl.await(writeBatch(pending));
    }

    if (stats.accepted >= LIMIT_ROWS) ctl.stop();
  });

  if (APPLY && batch.length > 0) await writeBatch(batch);

  const secs = (Date.now() - t0) / 1000;
  return { res, secs, stats, samples, genreHist };
}

// ---------------------------------------------------------------------------

async function main() {
  console.log('=== Import Open Library cdump -> books ===');
  console.log(`Fișier:  ${FILE}`);
  console.log(`Mod:     ${FULL ? 'FULL (tot fișierul)' : `MĂRGINIT (primele ${MAX_LINES.toLocaleString()} linii)`}`);
  console.log(`Scriere: ${APPLY ? 'APPLY (se scrie în bază)' : 'DRY RUN (nu se scrie nimic)'}`);
  console.log(`Autori:  ${AUTHORS ? '--authors (map de nume în RAM, vezi antetul)' : 'doar by_statement (fără --authors, majoritatea rândurilor rămân cu author=null)'}`);
  if (FULL && !APPLY) console.log('NOTĂ: --full fără --apply = citire completă fără scriere (durează la fel de mult).');
  if (!FULL) console.log('NOTĂ: fără --full nu se procesează tot fișierul — e doar un test de corectitudine.');
  console.log('');

  if (!fs.existsSync(FILE)) {
    console.error(`Fișierul nu există: ${FILE}\nDă calea cu --file sau OL_CDUMP_FILE.`);
    process.exitCode = 1;
    return;
  }
  console.log(`Dimensiune fișier: ${(fs.statSync(FILE).size / 1e9).toFixed(1)} GB (comprimat)\n`);

  // ISBN-urile existente, o singură dată (nu o interogare pe rând).
  let prisma = null;
  const existingIsbns = new Set();
  const needDb = APPLY || process.env.DATABASE_URL;
  if (needDb) {
    try {
      const { PrismaClient } = require('@prisma/client');
      const { PrismaPg } = require('@prisma/adapter-pg');
      const adapter = new PrismaPg({ connectionString: process.env.DATABASE_URL });
      prisma = new PrismaClient({ adapter });
      const rows = await prisma.book.findMany({ where: { isbn: { not: null } }, select: { isbn: true } });
      for (const r of rows) existingIsbns.add(r.isbn);
      console.log(`ISBN-uri deja în catalog: ${existingIsbns.size.toLocaleString()}\n`);
    } catch (e) {
      if (APPLY) throw e;
      console.log(`(fără bază de date: ${e.message} — dedup pe ISBN se face doar în interiorul rulării)\n`);
      prisma = null;
    }
  }

  const { works, authorNames, stats: p1 } = await passOne();
  const { res, secs, stats, samples, genreHist } = await passTwo(works, authorNames, existingIsbns, prisma);

  console.log(
    `  [p2] gata: ${res.lines.toLocaleString()} linii, ${mb(res.bytes)} MB comprimat, ` +
    `${secs.toFixed(0)}s (${Math.round(res.lines / secs).toLocaleString()} linii/s)\n`,
  );

  console.log('=== Rânduri exemplu (primele ' + samples.length + ') ===');
  for (const r of samples) {
    console.log(
      `  ${r.isbn}  ${JSON.stringify(r.title).slice(0, 70)}\n` +
      `      autor=${r.author ?? '-'} | gen=${r.genre ?? '-'} | limbă=${r.language} | ` +
      `an=${r.publishedYear ?? '-'} | pag=${r.pageCount ?? '-'} | editură=${(r.publisher ?? '-').slice(0, 40)}\n` +
      `      copertă=${r.coverUrl}\n` +
      `      descriere=${r.description ? JSON.stringify(r.description.slice(0, 110)) : '-'}`,
    );
  }

  console.log('\n=== Filtrare ===');
  console.log(`  ediții văzute:              ${stats.editions.toLocaleString()}`);
  console.log(`  trecute de pre-filtru:      ${stats.prefiltered.toLocaleString()}`);
  console.log(`  respinse (fără copertă):    ${stats.noCover.toLocaleString()}`);
  console.log(`  respinse (fără ISBN):       ${stats.noIsbn.toLocaleString()}`);
  console.log(`  respinse (limbă):           ${stats.noLang.toLocaleString()}`);
  console.log(`  respinse (fără subiecte):   ${stats.noSubjects.toLocaleString()}`);
  console.log(`  respinse (ISBN duplicat):   ${stats.dupIsbn.toLocaleString()}`);
  console.log(`  ACCEPTATE:                  ${stats.accepted.toLocaleString()}`);
  if (stats.accepted > 0) {
    const pct = (v) => `${((v / stats.accepted) * 100).toFixed(1)}%`;
    console.log(`    din care cu lucrare corelată: ${stats.withWork.toLocaleString()} (${pct(stats.withWork)})`);
    console.log(
      `    cu autor:                    ${stats.withAuthor.toLocaleString()} (${pct(stats.withAuthor)})` +
      (AUTHORS ? ' [index de nume + by_statement]' : ' [doar by_statement]'),
    );
    console.log(`    cu descriere:                ${stats.withDescription.toLocaleString()} (${pct(stats.withDescription)})`);
    console.log(`    în română:                   ${stats.ro.toLocaleString()} (${pct(stats.ro)})`);
  }
  if (APPLY) {
    console.log(`  SCRISE ÎN BAZĂ:             ${stats.written.toLocaleString()}`);
    if (stats.failedBatches > 0) console.log(`  batch-uri eșuate:           ${stats.failedBatches}`);
  }

  console.log('\n=== Distribuția genurilor ===');
  for (const [g, c] of [...genreHist.entries()].sort((a, b) => b[1] - a[1])) {
    console.log(`  ${g.padEnd(22)} ${c.toLocaleString()}`);
  }

  const totalSecs = p1.secs + secs;
  const fileSize = fs.statSync(FILE).size;
  if (!FULL) {
    const scale = fileSize / Math.max(1, p1.bytes);
    console.log(
      `\n=== Extrapolare pentru tot fișierul ===\n` +
      `  slice-ul citit: ${mb(p1.bytes)} MB din ${(fileSize / 1e9).toFixed(1)} GB (1/${scale.toFixed(0)})\n` +
      `  2 treceri au durat ${totalSecs.toFixed(0)}s pe slice -> ` +
      `~${((totalSecs * scale) / 3600).toFixed(1)} h pe tot fișierul\n` +
      `  ATENȚIE: începutul fișierului e ordonat pe ID-uri OL mici (importuri MARC vechi,\n` +
      `  sub 1% cu copertă). Pe restul fișierului densitatea de coperți/lucrări e mult mai\n` +
      `  mare, deci: randamentul real în rânduri e MULT peste ce se vede aici, iar durata\n` +
      `  de mai sus e SUBESTIMATĂ (se parsează mult mai mult JSON). Ia-o ca limită de jos.`,
    );
  }

  if (!APPLY) console.log('\nDRY RUN — nu s-a scris nimic. Adaugă --apply (și --full) pentru importul real.');
  if (prisma) await prisma.$disconnect();
}

main().catch((e) => {
  console.error(e);
  process.exitCode = 1;
});
