/**
 * Populează catalogul `books` cu titluri reale, cunoscute, câte 8-10 pentru
 * fiecare din cele 20 de genuri canonice (BOOK_GENRES), ca Book Match să aibă
 * din ce compune batch-ul de cold start.
 *
 * De ce e nevoie: coldStartBatch (book-match.service.ts) ia max
 * COLD_START_PER_GENRE titluri din fiecare gen canonic, ponderate cu
 * `1 + popularityScore`. Cu 92 de cărți în catalog, majoritatea genurilor
 * aveau bucket gol, deci primele swipe-uri arătau mereu aceleași titluri.
 *
 * Lista de titluri e curatoriată manual aici (cărți reale, recunoscute); din
 * API (Open Library, cu Google Books ca rezervă - aceleași endpointuri publice
 * ca BookLookupService) luăm DOAR metadatele: ISBN, copertă, an, editură,
 * descriere, număr de pagini.
 *
 * `genre` NU se ia din API - subiectele lor sunt text liber și inconsistent
 * (exact sursa fragmentării pe care o repară normalize-book-genres.js). Se
 * scrie genul canonic țintit de listă.
 *
 * Dedup (idempotent): sare cartea dacă există deja un `Book` cu același ISBN
 * sau, pentru cele fără ISBN de la API, dacă există deja titlu+autor
 * (case-insensitive). A doua rulare nu creează duplicate.
 *
 * Rulare (DRY-RUN implicit - interoghează API-urile și baza, dar NU scrie):
 *   docker compose -f docker-compose.prod.yml exec backend \
 *     node prisma/seed-curated-books.js
 *   docker compose -f docker-compose.prod.yml exec backend \
 *     node prisma/seed-curated-books.js --apply
 *
 * Verificare locală, fără bază de date (doar structura listei + un apel API):
 *   node prisma/seed-curated-books.js --self-test
 *
 * Versiune .js (nu .ts): imaginea de producție nu are pnpm/ts-node.
 */
require('dotenv/config');

const APPLY = process.argv.includes('--apply');
const SELF_TEST = process.argv.includes('--self-test');

/** Marcaj de proveniență pentru rândurile create de scriptul ăsta. */
const SOURCE = 'curated_seed';

/**
 * Titlurile astea sunt „ancorele" cold-start-ului: vrem să tragă mai tare
 * decât o carte oarecare din catalog. Multiplicatorul e `1 + popularityScore`,
 * iar necuratele folosesc BOOK_MATCH_DEFAULT_POPULARITY = 0.3 (deci 1.3).
 * 0.9 => multiplicator 1.9, ~1.5x față de restul catalogului.
 */
const POPULARITY = 0.9;

/** Pauză între apelurile externe, ca să nu batem API-urile publice. */
const REQUEST_DELAY_MS = 250;

/**
 * Genurile canonice din src/common/constants/book-genres.ts, fiecare cu
 * titluri reale reprezentative. Cheile TREBUIE să fie identice cu BOOK_GENRES.
 */
const CURATED = {
  'Ficțiune': [
    { title: 'The Alchemist', author: 'Paulo Coelho' },
    { title: 'Norwegian Wood', author: 'Haruki Murakami' },
    { title: 'The Kite Runner', author: 'Khaled Hosseini' },
    { title: 'Life of Pi', author: 'Yann Martel' },
    { title: 'The God of Small Things', author: 'Arundhati Roy' },
    { title: 'Beloved', author: 'Toni Morrison' },
    { title: 'One Hundred Years of Solitude', author: 'Gabriel Garcia Marquez' },
    { title: 'The Remains of the Day', author: 'Kazuo Ishiguro' },
    { title: 'A Man Called Ove', author: 'Fredrik Backman' },
  ],
  'Non-ficțiune': [
    { title: 'Sapiens: A Brief History of Humankind', author: 'Yuval Noah Harari' },
    { title: 'Homo Deus', author: 'Yuval Noah Harari' },
    { title: 'Guns, Germs, and Steel', author: 'Jared Diamond' },
    { title: 'A Short History of Nearly Everything', author: 'Bill Bryson' },
    { title: 'The Selfish Gene', author: 'Richard Dawkins' },
    { title: 'Cosmos', author: 'Carl Sagan' },
    { title: 'Freakonomics', author: 'Steven D. Levitt' },
    { title: 'Silent Spring', author: 'Rachel Carson' },
    { title: 'A Brief History of Time', author: 'Stephen Hawking' },
  ],
  'Clasic': [
    { title: 'Crime and Punishment', author: 'Fyodor Dostoevsky' },
    { title: 'The Brothers Karamazov', author: 'Fyodor Dostoevsky' },
    { title: 'War and Peace', author: 'Leo Tolstoy' },
    { title: 'Anna Karenina', author: 'Leo Tolstoy' },
    { title: 'Pride and Prejudice', author: 'Jane Austen' },
    { title: 'Jane Eyre', author: 'Charlotte Bronte' },
    { title: 'Madame Bovary', author: 'Gustave Flaubert' },
    { title: 'The Great Gatsby', author: 'F. Scott Fitzgerald' },
    { title: 'Moby-Dick', author: 'Herman Melville' },
    { title: 'Don Quixote', author: 'Miguel de Cervantes' },
  ],
  'Clasic românesc': [
    { title: 'Ion', author: 'Liviu Rebreanu' },
    { title: 'Pădurea spânzuraților', author: 'Liviu Rebreanu' },
    { title: 'Enigma Otiliei', author: 'George Călinescu' },
    { title: 'Moromeții', author: 'Marin Preda' },
    { title: 'Cel mai iubit dintre pământeni', author: 'Marin Preda' },
    { title: 'Baltagul', author: 'Mihail Sadoveanu' },
    { title: 'Craii de Curtea-Veche', author: 'Mateiu Caragiale' },
    { title: 'Amintiri din copilărie', author: 'Ion Creangă' },
    { title: 'Ultima noapte de dragoste, întâia noapte de război', author: 'Camil Petrescu' },
    { title: 'Maitreyi', author: 'Mircea Eliade' },
  ],
  'Fantasy': [
    { title: 'The Hobbit', author: 'J. R. R. Tolkien' },
    { title: 'The Fellowship of the Ring', author: 'J. R. R. Tolkien' },
    { title: 'A Game of Thrones', author: 'George R. R. Martin' },
    { title: 'The Name of the Wind', author: 'Patrick Rothfuss' },
    { title: 'The Lion, the Witch and the Wardrobe', author: 'C. S. Lewis' },
    { title: "Harry Potter and the Philosopher's Stone", author: 'J. K. Rowling' },
    { title: 'The Last Wish', author: 'Andrzej Sapkowski' },
    { title: 'Mistborn: The Final Empire', author: 'Brandon Sanderson' },
    { title: 'A Wizard of Earthsea', author: 'Ursula K. Le Guin' },
    { title: 'American Gods', author: 'Neil Gaiman' },
  ],
  'SF': [
    { title: 'Dune', author: 'Frank Herbert' },
    { title: 'Foundation', author: 'Isaac Asimov' },
    { title: 'I, Robot', author: 'Isaac Asimov' },
    { title: 'Solaris', author: 'Stanislaw Lem' },
    { title: 'Neuromancer', author: 'William Gibson' },
    { title: 'Hyperion', author: 'Dan Simmons' },
    { title: 'The Left Hand of Darkness', author: 'Ursula K. Le Guin' },
    { title: "Ender's Game", author: 'Orson Scott Card' },
    { title: 'The Martian', author: 'Andy Weir' },
    { title: 'Do Androids Dream of Electric Sheep?', author: 'Philip K. Dick' },
  ],
  'Thriller': [
    { title: 'The Silence of the Lambs', author: 'Thomas Harris' },
    { title: 'The Girl with the Dragon Tattoo', author: 'Stieg Larsson' },
    { title: 'Gone Girl', author: 'Gillian Flynn' },
    { title: 'The Da Vinci Code', author: 'Dan Brown' },
    { title: 'The Firm', author: 'John Grisham' },
    { title: 'The Bourne Identity', author: 'Robert Ludlum' },
    { title: 'The Shining', author: 'Stephen King' },
    { title: 'Shutter Island', author: 'Dennis Lehane' },
    { title: 'The Girl on the Train', author: 'Paula Hawkins' },
  ],
  'Mister': [
    { title: 'Murder on the Orient Express', author: 'Agatha Christie' },
    { title: 'And Then There Were None', author: 'Agatha Christie' },
    { title: 'The Hound of the Baskervilles', author: 'Arthur Conan Doyle' },
    { title: 'The Adventures of Sherlock Holmes', author: 'Arthur Conan Doyle' },
    { title: 'The Name of the Rose', author: 'Umberto Eco' },
    { title: 'The Big Sleep', author: 'Raymond Chandler' },
    { title: 'The Maltese Falcon', author: 'Dashiell Hammett' },
    { title: 'In the Woods', author: 'Tana French' },
    { title: "The Cuckoo's Calling", author: 'Robert Galbraith' },
  ],
  'Distopie': [
    { title: 'Nineteen Eighty-Four', author: 'George Orwell' },
    { title: 'Animal Farm', author: 'George Orwell' },
    { title: 'Brave New World', author: 'Aldous Huxley' },
    { title: 'Fahrenheit 451', author: 'Ray Bradbury' },
    { title: "The Handmaid's Tale", author: 'Margaret Atwood' },
    { title: 'We', author: 'Yevgeny Zamyatin' },
    { title: 'The Road', author: 'Cormac McCarthy' },
    { title: 'The Hunger Games', author: 'Suzanne Collins' },
    { title: 'Never Let Me Go', author: 'Kazuo Ishiguro' },
  ],
  'Romantic': [
    { title: 'Persuasion', author: 'Jane Austen' },
    { title: 'Wuthering Heights', author: 'Emily Bronte' },
    { title: 'Outlander', author: 'Diana Gabaldon' },
    { title: 'Me Before You', author: 'Jojo Moyes' },
    { title: 'The Notebook', author: 'Nicholas Sparks' },
    { title: 'Normal People', author: 'Sally Rooney' },
    { title: 'It Ends with Us', author: 'Colleen Hoover' },
    { title: "The Time Traveler's Wife", author: 'Audrey Niffenegger' },
    { title: "Bridget Jones's Diary", author: 'Helen Fielding' },
  ],
  'Istoric': [
    { title: 'The Pillars of the Earth', author: 'Ken Follett' },
    { title: 'Wolf Hall', author: 'Hilary Mantel' },
    { title: 'All the Light We Cannot See', author: 'Anthony Doerr' },
    { title: 'The Book Thief', author: 'Markus Zusak' },
    { title: 'Memoirs of a Geisha', author: 'Arthur Golden' },
    { title: 'I, Claudius', author: 'Robert Graves' },
    { title: 'The Nightingale', author: 'Kristin Hannah' },
    { title: 'Shogun', author: 'James Clavell' },
    { title: 'The Other Boleyn Girl', author: 'Philippa Gregory' },
  ],
  'Biografie': [
    { title: 'Steve Jobs', author: 'Walter Isaacson' },
    { title: 'Educated', author: 'Tara Westover' },
    { title: 'The Diary of a Young Girl', author: 'Anne Frank' },
    { title: 'Long Walk to Freedom', author: 'Nelson Mandela' },
    { title: 'Becoming', author: 'Michelle Obama' },
    { title: 'Einstein: His Life and Universe', author: 'Walter Isaacson' },
    { title: 'Leonardo da Vinci', author: 'Walter Isaacson' },
    { title: 'The Autobiography of Malcolm X', author: 'Malcolm X' },
    { title: 'Open', author: 'Andre Agassi' },
  ],
  'Dezvoltare personală': [
    { title: 'Atomic Habits', author: 'James Clear' },
    { title: 'The 7 Habits of Highly Effective People', author: 'Stephen R. Covey' },
    { title: 'How to Win Friends and Influence People', author: 'Dale Carnegie' },
    { title: 'The Power of Habit', author: 'Charles Duhigg' },
    { title: 'Deep Work', author: 'Cal Newport' },
    { title: 'Mindset: The New Psychology of Success', author: 'Carol S. Dweck' },
    { title: 'The Subtle Art of Not Giving a F*ck', author: 'Mark Manson' },
    { title: 'The 4-Hour Workweek', author: 'Timothy Ferriss' },
    { title: 'Ikigai: The Japanese Secret to a Long and Happy Life', author: 'Hector Garcia' },
  ],
  'Psihologie': [
    { title: 'Thinking, Fast and Slow', author: 'Daniel Kahneman' },
    { title: "Man's Search for Meaning", author: 'Viktor E. Frankl' },
    { title: 'The Body Keeps the Score', author: 'Bessel van der Kolk' },
    { title: 'Influence: The Psychology of Persuasion', author: 'Robert B. Cialdini' },
    { title: 'Emotional Intelligence', author: 'Daniel Goleman' },
    { title: 'Predictably Irrational', author: 'Dan Ariely' },
    { title: 'Quiet: The Power of Introverts', author: 'Susan Cain' },
    { title: 'Games People Play', author: 'Eric Berne' },
    { title: 'The Interpretation of Dreams', author: 'Sigmund Freud' },
    { title: 'Man and His Symbols', author: 'Carl Jung' },
  ],
  'Filosofie': [
    { title: 'Meditations', author: 'Marcus Aurelius' },
    { title: 'The Republic', author: 'Plato' },
    { title: 'Beyond Good and Evil', author: 'Friedrich Nietzsche' },
    { title: 'Thus Spoke Zarathustra', author: 'Friedrich Nietzsche' },
    { title: 'The Myth of Sisyphus', author: 'Albert Camus' },
    { title: 'Letters from a Stoic', author: 'Seneca' },
    { title: 'Nicomachean Ethics', author: 'Aristotle' },
    { title: 'Critique of Pure Reason', author: 'Immanuel Kant' },
    { title: 'Tao Te Ching', author: 'Lao Tzu' },
    { title: 'The Prince', author: 'Niccolo Machiavelli' },
  ],
  'Business': [
    { title: 'Zero to One', author: 'Peter Thiel' },
    { title: 'The Lean Startup', author: 'Eric Ries' },
    { title: 'Good to Great', author: 'Jim Collins' },
    { title: 'Rich Dad Poor Dad', author: 'Robert T. Kiyosaki' },
    { title: 'The Intelligent Investor', author: 'Benjamin Graham' },
    { title: 'Shoe Dog', author: 'Phil Knight' },
    { title: 'Built to Last', author: 'Jim Collins' },
    { title: "The Innovator's Dilemma", author: 'Clayton M. Christensen' },
    { title: 'Principles: Life and Work', author: 'Ray Dalio' },
  ],
  'Poezie': [
    { title: 'Poezii', author: 'Mihai Eminescu' },
    { title: 'Cuvinte potrivite', author: 'Tudor Arghezi' },
    { title: 'Poemele luminii', author: 'Lucian Blaga' },
    { title: 'Leaves of Grass', author: 'Walt Whitman' },
    { title: 'Les Fleurs du mal', author: 'Charles Baudelaire' },
    { title: 'The Waste Land', author: 'T. S. Eliot' },
    { title: 'Duino Elegies', author: 'Rainer Maria Rilke' },
    { title: 'Milk and Honey', author: 'Rupi Kaur' },
    { title: 'The Sonnets', author: 'William Shakespeare' },
  ],
  'Copii': [
    { title: 'Winnie-the-Pooh', author: 'A. A. Milne' },
    { title: 'Charlie and the Chocolate Factory', author: 'Roald Dahl' },
    { title: 'Matilda', author: 'Roald Dahl' },
    { title: 'The Little Prince', author: 'Antoine de Saint-Exupery' },
    { title: "Alice's Adventures in Wonderland", author: 'Lewis Carroll' },
    { title: 'Pippi Longstocking', author: 'Astrid Lindgren' },
    { title: 'The Gruffalo', author: 'Julia Donaldson' },
    { title: 'Where the Wild Things Are', author: 'Maurice Sendak' },
    { title: 'The Jungle Book', author: 'Rudyard Kipling' },
  ],
  'Young adult': [
    { title: 'The Fault in Our Stars', author: 'John Green' },
    { title: 'Looking for Alaska', author: 'John Green' },
    { title: 'Divergent', author: 'Veronica Roth' },
    { title: 'The Perks of Being a Wallflower', author: 'Stephen Chbosky' },
    { title: 'Twilight', author: 'Stephenie Meyer' },
    { title: 'The Lightning Thief', author: 'Rick Riordan' },
    { title: 'Eleanor & Park', author: 'Rainbow Rowell' },
    { title: 'Six of Crows', author: 'Leigh Bardugo' },
    { title: 'The Maze Runner', author: 'James Dashner' },
  ],
  'Benzi desenate': [
    { title: 'Maus', author: 'Art Spiegelman' },
    { title: 'Persepolis', author: 'Marjane Satrapi' },
    { title: 'Watchmen', author: 'Alan Moore' },
    { title: 'V for Vendetta', author: 'Alan Moore' },
    { title: 'Batman: The Dark Knight Returns', author: 'Frank Miller' },
    { title: 'The Sandman: Preludes & Nocturnes', author: 'Neil Gaiman' },
    { title: 'Asterix the Gaul', author: 'Rene Goscinny' },
    { title: 'Tintin in Tibet', author: 'Herge' },
    { title: 'Saga, Volume 1', author: 'Brian K. Vaughan' },
  ],
};

// ---------------------------------------------------------------------------
// Apeluri externe - aceleași endpointuri publice ca BookLookupService, doar că
// aici cu `fetch` global (Node 22 în imagine), fără DI.
// ---------------------------------------------------------------------------

const sleep = (ms) => new Promise((r) => setTimeout(r, ms));

async function getJson(url, timeoutMs = 8000) {
  const controller = new AbortController();
  const timer = setTimeout(() => controller.abort(), timeoutMs);
  try {
    const res = await fetch(url, {
      signal: controller.signal,
      headers: { 'User-Agent': 'shelfshare-curated-seed/1.0' },
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

/**
 * Google Books limitează dur cererile neautentificate de pe un IP (429). La
 * 429 așteptăm crescător și reîncercăm de câteva ori; dacă tot nu merge,
 * întoarcem null și cartea se salvează doar cu ce a dat Open Library.
 */
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

let rateLimitHits = 0;

function extractYear(dateStr) {
  if (!dateStr) return null;
  const m = String(dateStr).match(/\d{4}/);
  return m ? parseInt(m[0], 10) : null;
}

/** Normalizare pentru comparații de titlu/autor (diacritice, punctuație). */
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

/**
 * Rezultatul API-ului e acceptat doar dacă titlul lui seamănă cu ce am cerut -
 * altfel căutarea „Ion / Liviu Rebreanu" poate întoarce orice carte care are
 * cuvântul în titlu, și am insera o carte greșită sub genul curatoriat.
 */
function titleMatches(wanted, got) {
  const a = norm(wanted);
  const b = norm(got);
  if (!b) return false;
  return a === b || a.startsWith(b) || b.startsWith(a) || b.includes(a);
}

async function fromOpenLibrary(title, author) {
  // Open Library caută pe titlul exact: cu subtitlu cu tot („Sapiens: A Brief
  // History of Humankind") întoarce 0 rezultate, deși „Sapiens" le găsește.
  // Căutăm pe titlul scurt; potrivirea se face tot pe titlul complet.
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
    workKey: doc.key ?? null, // ex. "/works/OL45883W" - de aici luăm descrierea
    title: doc.title ?? title,
    author: doc.author_name?.join(', ') ?? author,
    description: null, // search.json nu întoarce descriere; vezi openLibraryDescription
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

/**
 * Descrierea unei lucrări Open Library (`/works/OL...W.json`). search.json nu
 * o întoarce, iar cardul de Book Match arată descrierea - fără ea, jumătate
 * din carduri ar fi goale când Google Books e throttled.
 */
async function openLibraryDescription(workKey) {
  if (!workKey) return null;
  const data = await getJson(`https://openlibrary.org${workKey}.json`);
  const d = data?.description;
  const text = typeof d === 'string' ? d : (d?.value ?? null);
  if (!text) return null;
  // Descrierile OL au adesea un subsol de tip "([source][1])" / linkuri wiki.
  return text.split('\n----------')[0].replace(/\(\[source\]\[\d+\]\)/g, '').trim();
}

/**
 * `q` NU se encodează în bloc: Google Books folosește `+` ca ȘI între
 * restricțiile de câmp, iar encodeURIComponent l-ar transforma în `%2B`
 * (plus literal), caz în care `inauthor:` e ignorat și primim cărți greșite.
 * Encodăm doar valorile, separatorul rămâne `+`.
 */
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

/**
 * Open Library întâi (mai bogată pe clasici, are cover_i gratis) + descrierea
 * lucrării; Google Books ca rezervă pentru ce lipsește. Ordinea contează:
 * Google Books throttlează neautentificat (429), deci nu ne bazăm pe el.
 */
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
function validateCurated() {
  const BOOK_GENRES = Object.keys(CURATED);
  const problems = [];
  const seen = new Map();
  let total = 0;

  for (const [genre, books] of Object.entries(CURATED)) {
    const usable = books;
    total += usable.length;
    if (usable.length < 6) {
      problems.push(`${genre}: doar ${usable.length} titluri (minim 6)`);
    }
    for (const b of usable) {
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

  return { total, problems, genreCount: BOOK_GENRES.length };
}

async function selfTest() {
  console.log('=== SELF-TEST (fără bază de date) ===\n');
  const { total, problems, genreCount } = validateCurated();

  for (const [genre, books] of Object.entries(CURATED)) {
    const n = books.length;
    console.log(`  ${genre.padEnd(24)} ${n}`);
  }
  console.log(`\nGenuri: ${genreCount} | Titluri curatoriate: ${total}`);

  if (problems.length > 0) {
    console.log('\nPROBLEME:');
    for (const p of problems) console.log('  - ' + p);
  } else {
    console.log('Structura listei: OK (fiecare gen >= 6 titluri, fără duplicate).');
  }

  // `--wide`: primul titlu din fiecare gen, doar prin Open Library (Google
  // Books throttlează neautentificat, iar aici verificăm titleMatches, nu
  // completarea metadatelor).
  const WIDE = process.argv.includes('--wide');
  const samples = WIDE
    ? Object.entries(CURATED).map(([genre, books]) => ({ ...books[0], genre }))
    : [
        { title: 'Dune', author: 'Frank Herbert' },
        { title: 'Moromeții', author: 'Marin Preda' },
        { title: 'Thinking, Fast and Slow', author: 'Daniel Kahneman' },
      ];

  console.log(`\nTest de lookup pe ${samples.length} titluri (verifică apelurile API):`);
  for (const s of samples) {
    const r = WIDE
      ? await fromOpenLibrary(s.title, s.author)
      : await lookup(s.title, s.author);
    if (WIDE) await sleep(REQUEST_DELAY_MS);
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

  const { total, problems } = validateCurated();
  if (problems.length > 0) {
    console.log('Lista curatoriată are probleme, opresc:');
    for (const p of problems) console.log('  - ' + p);
    await prisma.$disconnect();
    process.exitCode = 1;
    return;
  }
  console.log(`Titluri de procesat: ${total}\n`);

  const stats = { inserted: 0, skippedExisting: 0, notFound: 0 };
  const perGenre = {};

  for (const [genre, books] of Object.entries(CURATED)) {
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

      // Dedup: ISBN identic, altfel titlu+autor case-insensitive.
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
      // Și pe titlul din lista curatoriată, nu doar pe cel întors de API
      // (ediția externă poate avea subtitlu, ex. „Dune (Dune Chronicles #1)").
      if (!existing) {
        existing = await prisma.book.findFirst({
          where: {
            title: { equals: wanted.title, mode: 'insensitive' },
            author: { contains: wanted.author.split(' ').pop(), mode: 'insensitive' },
          },
        });
      }

      if (existing) {
        stats.skippedExisting++;
        perGenre[genre].skipped++;
        console.log(`  = există deja: ${meta.title}`);
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
        genre, // canonic, NU ce zice API-ul
        source: SOURCE,
        popularityScore: POPULARITY,
      };

      if (APPLY) {
        try {
          await prisma.book.create({ data });
        } catch (e) {
          // Cursa pe ISBN unic (altă rulare/paralel) - o tratăm ca „există deja".
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
