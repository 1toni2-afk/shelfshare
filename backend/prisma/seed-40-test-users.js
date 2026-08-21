/**
 * Creează 40 de conturi de test („TEST_Prenume Nume"), fiecare cu câte 5
 * anunțuri, cât mai diferite unele de altele: cărți diferite (dintr-un pool
 * mare, cu genuri și limbi variate), categorii diferite (Swap / Vânzare /
 * Licitație / Donație), și cât mai multe câmpuri de anunț folosite - ediție,
 * tag-uri, descriere, oraș propriu al anunțului, mai multe poze + copertă
 * principală aleasă manual, preț negociabil vs. fix, „sau vinde cu X lei" pe
 * un Schimb, contor de vizualizări (istoric de interes) și, pentru o parte
 * din useri, cont Premium cu un anunț promovat. Parola tuturor: `pass123`.
 *
 * ȘTERGE ÎNTÂI TOATE anunțurile din baza de date (toate `UserBook`-urile,
 * indiferent de cont) - decizie explicită a userului, nu doar cele
 * create anterior de acest script. Userii înșiși NU sunt șterși, doar
 * anunțurile lor. Rulează acest script DOAR pe o bază de date unde chiar
 * vrei să golești toate listările curente.
 *
 * E idempotent pentru partea proprie: la a doua rulare, cei 40 de useri
 * „TEST_" sunt recunoscuți după domeniul de email (@shelfshare.test) și
 * anunțurile lor recreate de la zero, fără duplicare.
 *
 * Versiune .js (nu .ts): imaginea de producție nu are pnpm/ts-node - doar
 * `node dist/main`. @prisma/client, @prisma/adapter-pg, bcrypt și dotenv
 * rămân în node_modules după `pnpm prune --prod` (sunt dependencies, nu
 * devDependencies), deci scriptul rulează direct cu `node`, fără compilare.
 *
 * Rulează în interiorul containerului backend (DATABASE_URL rezolvă "postgres"
 * ca host doar acolo):
 *   docker compose -f docker-compose.prod.yml exec backend \
 *     node prisma/seed-40-test-users.js
 */
require('dotenv/config');
const { PrismaClient, BookCondition, AuctionStatus } = require('@prisma/client');
const { PrismaPg } = require('@prisma/adapter-pg');
const bcrypt = require('bcrypt');
const crypto = require('crypto');

const adapter = new PrismaPg({ connectionString: process.env.DATABASE_URL });
const prisma = new PrismaClient({ adapter });

const PASSWORD = 'pass123';
const SALT_ROUNDS = 10;
const USER_COUNT = 40;
const BOOKS_PER_USER = 5;
const EMAIL_DOMAIN = 'shelfshare.test';
/** Marcaj pe cărțile create de scriptul ăsta, ca să le putem recunoaște. */
const SOURCE = '40-test-users-seed';

const CONDITIONS = [
  BookCondition.NOUA,
  BookCondition.FOARTE_BUNA,
  BookCondition.BUNA,
  BookCondition.ACCEPTABILA,
];

const FIRST_NAMES = [
  'Andrei', 'Maria', 'Ștefan', 'Elena', 'Radu', 'Ioana', 'Alexandru', 'Cristina',
  'Mihai', 'Ana', 'Vlad', 'Diana', 'George', 'Simona', 'Cătălin', 'Roxana',
  'Bogdan', 'Alina', 'Florin', 'Bianca', 'Tudor', 'Larisa', 'Sebastian', 'Oana',
  'Cosmin', 'Irina', 'Daniel', 'Adriana', 'Paul', 'Camelia', 'Robert', 'Nicoleta',
  'Marius', 'Delia', 'Victor', 'Gabriela', 'Emil', 'Raluca', 'Iulian', 'Corina',
];
const LAST_NAMES = [
  'Popescu', 'Ionescu', 'Dumitru', 'Constantin', 'Georgescu', 'Marin', 'Stan', 'Voicu',
  'Rusu', 'Munteanu', 'Nistor', 'Enache', 'Toma', 'Pavel', 'Stanciu', 'Neagu',
  'Ilie', 'Barbu', 'Dinu', 'Chiriac', 'Petrescu', 'Radu', 'Matei', 'Iordache',
  'Oprea', 'Ciobanu', 'Manea', 'Sandu', 'Florea', 'Bălan', 'Vasile', 'Coman',
  'Diaconu', 'Preda', 'Tudose', 'Anghel', 'Zamfir', 'Lupu', 'Bratu', 'Șerban',
];
const CITIES = [
  'București', 'Cluj-Napoca', 'Timișoara', 'Iași', 'Brașov', 'Constanța',
  'Craiova', 'Sibiu', 'Oradea', 'Ploiești', 'Galați', 'Târgu Mureș',
  'Bacău', 'Arad', 'Pitești', 'Baia Mare', 'Satu Mare', 'Buzău',
  'Piatra Neamț', 'Râmnicu Vâlcea',
];
const BIOS = [
  'Citesc orice imi pica',
  'Fan de schimburi de carti',
  'Colectionez editii vechi',
  'Cititor de weekend',
  'Mereu cu o carte la mine',
  'Downsizing biblioteca',
  'Caut editii cartonate',
  'Recomand ce citesc',
];
const EDITIONS = [
  null,
  'Ediție cartonată',
  'Ediție de buzunar',
  'Ediție ilustrată',
  'Ediție aniversară',
  'Prima ediție',
  'Ediție colecție',
];
const TAG_POOL = [
  'lectura-de-vara', 'editie-rara', 'must-read', 'coming-of-age', 'clasic',
  'recomandat', 'premiat', 'bestseller', 'de-colectie', 'usor-de-citit',
  'traducere-buna', 'stare-impecabila', 'cadou-ideal', 'carte-de-noptiera',
];

/** Pool mare și eterogen de cărți - genuri, limbi și epoci diferite, ca
 * anunțurile a 40 de useri să nu semene între ele. Fiecare user primește 5
 * titluri distincte, alese cu un pas mare prin acest pool. */
const BOOK_POOL = [
  { isbn: '9780439708180', title: "Harry Potter and the Sorcerer's Stone", author: 'J.K. Rowling', genre: 'Fantasy', language: 'Engleză', pageCount: 309, publishedYear: 1997 },
  { isbn: '9780547928227', title: 'The Hobbit', author: 'J.R.R. Tolkien', genre: 'Fantasy', language: 'Engleză', pageCount: 310, publishedYear: 1937 },
  { isbn: '9780451524935', title: '1984', author: 'George Orwell', genre: 'Distopie', language: 'Engleză', pageCount: 328, publishedYear: 1949 },
  { isbn: '9780060850524', title: 'Brave New World', author: 'Aldous Huxley', genre: 'Distopie', language: 'Engleză', pageCount: 311, publishedYear: 1932 },
  { isbn: '9780316769488', title: 'The Catcher in the Rye', author: 'J.D. Salinger', genre: 'Ficțiune', language: 'Engleză', pageCount: 277, publishedYear: 1951 },
  { isbn: '9780061120084', title: 'To Kill a Mockingbird', author: 'Harper Lee', genre: 'Ficțiune', language: 'Engleză', pageCount: 336, publishedYear: 1960 },
  { isbn: '9780756404741', title: 'The Name of the Wind', author: 'Patrick Rothfuss', genre: 'Fantasy', language: 'Engleză', pageCount: 662, publishedYear: 2007 },
  { isbn: '9780765311788', title: 'Mistborn', author: 'Brandon Sanderson', genre: 'Fantasy', language: 'Engleză', pageCount: 541, publishedYear: 2006 },
  { isbn: '9780062316097', title: 'Sapiens', author: 'Yuval Noah Harari', genre: 'Non-ficțiune', language: 'Engleză', pageCount: 464, publishedYear: 2011 },
  { isbn: '9780735211292', title: 'Atomic Habits', author: 'James Clear', genre: 'Dezvoltare personală', language: 'Engleză', pageCount: 320, publishedYear: 2018 },
  { isbn: '9781250301697', title: 'The Silent Patient', author: 'Alex Michaelides', genre: 'Thriller', language: 'Engleză', pageCount: 336, publishedYear: 2019 },
  { isbn: '9780735219090', title: 'Where the Crawdads Sing', author: 'Delia Owens', genre: 'Ficțiune', language: 'Engleză', pageCount: 384, publishedYear: 2018 },
  { isbn: '9780525559474', title: 'The Midnight Library', author: 'Matt Haig', genre: 'Ficțiune', language: 'Engleză', pageCount: 288, publishedYear: 2020 },
  { isbn: '9780399590504', title: 'Educated', author: 'Tara Westover', genre: 'Memorii', language: 'Engleză', pageCount: 352, publishedYear: 2018 },
  { isbn: '9780593135204', title: 'Project Hail Mary', author: 'Andy Weir', genre: 'Science Fiction', language: 'Engleză', pageCount: 496, publishedYear: 2021 },
  { isbn: '9780062060624', title: 'The Song of Achilles', author: 'Madeline Miller', genre: 'Ficțiune istorică', language: 'Engleză', pageCount: 416, publishedYear: 2011 },
  { isbn: '9780593098233', title: 'Dune Messiah', author: 'Frank Herbert', genre: 'Science Fiction', language: 'Engleză', pageCount: 256, publishedYear: 1969 },
  { isbn: '9780553293357', title: 'Foundation', author: 'Isaac Asimov', genre: 'Science Fiction', language: 'Engleză', pageCount: 255, publishedYear: 1951 },
  { isbn: '9780062572110', title: 'American Gods', author: 'Neil Gaiman', genre: 'Fantasy', language: 'Engleză', pageCount: 635, publishedYear: 2001 },
  { isbn: '9780143034902', title: 'The Shadow of the Wind', author: 'Carlos Ruiz Zafón', genre: 'Mister', language: 'Engleză', pageCount: 487, publishedYear: 2001 },
  { isbn: '9780060853976', title: 'Good Omens', author: 'Terry Pratchett & Neil Gaiman', genre: 'Fantasy', language: 'Engleză', pageCount: 288, publishedYear: 1990 },
  { isbn: '9780307346612', title: 'World War Z', author: 'Max Brooks', genre: 'Science Fiction', language: 'Engleză', pageCount: 342, publishedYear: 2006 },
  { isbn: '9780307387899', title: 'The Road', author: 'Cormac McCarthy', genre: 'Ficțiune', language: 'Engleză', pageCount: 287, publishedYear: 2006 },
  { isbn: '9780440180296', title: 'Slaughterhouse-Five', author: 'Kurt Vonnegut', genre: 'Science Fiction', language: 'Engleză', pageCount: 275, publishedYear: 1969 },
  { isbn: '9780062315007', title: 'The Alchemist', author: 'Paulo Coelho', genre: 'Ficțiune', language: 'Engleză', pageCount: 197, publishedYear: 1988 },
  { isbn: '9780807014295', title: "Man's Search for Meaning", author: 'Viktor Frankl', genre: 'Non-ficțiune', language: 'Engleză', pageCount: 165, publishedYear: 1946 },
  { isbn: '9780156012195', title: 'The Little Prince', author: 'Antoine de Saint-Exupéry', genre: 'Ficțiune', language: 'Engleză', pageCount: 96, publishedYear: 1943 },
  { isbn: '9780140177398', title: 'Of Mice and Men', author: 'John Steinbeck', genre: 'Ficțiune', language: 'Engleză', pageCount: 107, publishedYear: 1937 },
  { isbn: '9780451526342', title: 'Animal Farm', author: 'George Orwell', genre: 'Distopie', language: 'Engleză', pageCount: 112, publishedYear: 1945 },
  { isbn: '9780743273565', title: 'The Great Gatsby', author: 'F. Scott Fitzgerald', genre: 'Ficțiune', language: 'Engleză', pageCount: 180, publishedYear: 1925 },
  { isbn: '9781451673319', title: 'Fahrenheit 451', author: 'Ray Bradbury', genre: 'Science Fiction', language: 'Engleză', pageCount: 194, publishedYear: 1953 },
  { isbn: '9780141439518', title: 'Pride and Prejudice', author: 'Jane Austen', genre: 'Roman', language: 'Engleză', pageCount: 432, publishedYear: 1813 },
  { isbn: '9789731047560', title: 'Baltagul', author: 'Mihail Sadoveanu', genre: 'Ficțiune', language: 'Română', pageCount: 192, publishedYear: 1930 },
  { isbn: '9789734603312', title: 'Moromeții', author: 'Marin Preda', genre: 'Ficțiune', language: 'Română', pageCount: 560, publishedYear: 1955 },
  { isbn: '9789731043128', title: 'Enigma Otiliei', author: 'George Călinescu', genre: 'Ficțiune', language: 'Română', pageCount: 448, publishedYear: 1938 },
  { isbn: '9789734635382', title: 'Fahrenheit 451 (RO)', author: 'Ray Bradbury', genre: 'Science Fiction', language: 'Română', pageCount: 208, publishedYear: 1953 },
  { isbn: '9789736897457', title: 'Ion', author: 'Liviu Rebreanu', genre: 'Ficțiune', language: 'Română', pageCount: 480, publishedYear: 1920 },
  { isbn: '9789733405543', title: 'Amintiri din copilărie', author: 'Ion Creangă', genre: 'Memorii', language: 'Română', pageCount: 220, publishedYear: 1892 },
  { isbn: '9789734625345', title: 'Ultima noapte de dragoste, întâia noapte de război', author: 'Camil Petrescu', genre: 'Ficțiune', language: 'Română', pageCount: 304, publishedYear: 1930 },
  { isbn: '9789731049090', title: 'Cel mai iubit dintre pământeni', author: 'Marin Preda', genre: 'Ficțiune', language: 'Română', pageCount: 850, publishedYear: 1980 },
  { isbn: '9780062073488', title: 'Crima din Orient Express', author: 'Agatha Christie', genre: 'Mister', language: 'Română', pageCount: 256, publishedYear: 1934 },
  { isbn: '9780307454546', title: 'Fata cu un dragon tatuat', author: 'Stieg Larsson', genre: 'Thriller', language: 'Română', pageCount: 480, publishedYear: 2005 },
  { isbn: '9780345539434', title: 'Gone Girl', author: 'Gillian Flynn', genre: 'Thriller', language: 'Engleză', pageCount: 432, publishedYear: 2012 },
  { isbn: '9780593135211', title: 'Circe', author: 'Madeline Miller', genre: 'Fantasy', language: 'Engleză', pageCount: 393, publishedYear: 2018 },
  { isbn: '9780857197689', title: 'Mistborn: The Final Empire', author: 'Brandon Sanderson', genre: 'Fantasy', language: 'Engleză', pageCount: 647, publishedYear: 2006 },
  { isbn: '9780199535569', title: 'Jane Eyre', author: 'Charlotte Brontë', genre: 'Roman', language: 'Engleză', pageCount: 532, publishedYear: 1847 },
  { isbn: '9780199537011', title: 'Wuthering Heights', author: 'Emily Brontë', genre: 'Roman', language: 'Engleză', pageCount: 416, publishedYear: 1847 },
  { isbn: '9780679783268', title: 'Crime and Punishment', author: 'Fyodor Dostoevsky', genre: 'Ficțiune', language: 'Engleză', pageCount: 671, publishedYear: 1866 },
  { isbn: '9780679783305', title: 'Anna Karenina', author: 'Leo Tolstoy', genre: 'Ficțiune', language: 'Engleză', pageCount: 864, publishedYear: 1877 },
  { isbn: '9780241983810', title: 'Sherlock Holmes: A Study in Scarlet', author: 'Arthur Conan Doyle', genre: 'Mister', language: 'Engleză', pageCount: 176, publishedYear: 1887 },
  { isbn: '9780451529760', title: 'Hamlet', author: 'William Shakespeare', genre: 'Teatru', language: 'Engleză', pageCount: 336, publishedYear: 1603 },
  { isbn: '9780199537099', title: 'Frankenstein', author: 'Mary Shelley', genre: 'Horror', language: 'Engleză', pageCount: 280, publishedYear: 1818 },
  { isbn: '9780486282114', title: 'Dracula', author: 'Bram Stoker', genre: 'Horror', language: 'Engleză', pageCount: 418, publishedYear: 1897 },
  { isbn: '9780316055437', title: 'The Girl with All the Gifts', author: 'M.R. Carey', genre: 'Horror', language: 'Engleză', pageCount: 460, publishedYear: 2014 },
  { isbn: '9780345534893', title: 'Ready Player One', author: 'Ernest Cline', genre: 'Science Fiction', language: 'Engleză', pageCount: 374, publishedYear: 2011 },
  { isbn: '9780765326355', title: 'The Way of Kings', author: 'Brandon Sanderson', genre: 'Fantasy', language: 'Engleză', pageCount: 1007, publishedYear: 2010 },
  { isbn: '9780316017930', title: 'Twilight', author: 'Stephenie Meyer', genre: 'Romantism', language: 'Engleză', pageCount: 498, publishedYear: 2005 },
  { isbn: '9780062024039', title: 'Divergent', author: 'Veronica Roth', genre: 'Distopie', language: 'Engleză', pageCount: 487, publishedYear: 2011 },
  { isbn: '9780439023528', title: 'The Hunger Games', author: 'Suzanne Collins', genre: 'Distopie', language: 'Engleză', pageCount: 374, publishedYear: 2008 },
  { isbn: '9780062457714', title: 'The Subtle Art of Not Giving a F*ck', author: 'Mark Manson', genre: 'Dezvoltare personală', language: 'Engleză', pageCount: 224, publishedYear: 2016 },
];

function coverUrl(isbn) {
  return `https://covers.openlibrary.org/b/isbn/${isbn}-M.jpg`;
}

function photos(seedKey, count) {
  return Array.from(
    { length: count },
    (_, i) => `https://picsum.photos/seed/${seedKey}-${i}/600/800`,
  );
}

function slugify(text) {
  return text
    .normalize('NFD')
    .replace(/[̀-ͯ]/g, '')
    .toLowerCase()
    .replace(/[^a-z0-9]+/g, '_')
    .replace(/^_+|_+$/g, '');
}

function pick(arr, i) {
  return arr[((i % arr.length) + arr.length) % arr.length];
}

/** Cod de referral unic, la fel ca în UsersService.generateReferralCode. */
async function uniqueReferralCode() {
  for (;;) {
    const code = crypto.randomBytes(8).toString('hex').toUpperCase().slice(0, 8);
    const exists = await prisma.user.findUnique({ where: { referralCode: code } });
    if (!exists) return code;
  }
}

async function upsertBook(b) {
  const existing = await prisma.book.findFirst({ where: { isbn: b.isbn } });
  if (existing) return existing;
  return prisma.book.create({
    data: {
      isbn: b.isbn,
      title: b.title,
      author: b.author,
      genre: b.genre,
      language: b.language,
      pageCount: b.pageCount,
      publishedYear: b.publishedYear,
      coverUrl: coverUrl(b.isbn),
      source: SOURCE,
      description: `${b.title}, de ${b.author}.`,
    },
  });
}

/** Câte 5 titluri distincte per user, alese cu un pas mare prin pool-ul de
 * 60 de cărți, ca useri consecutivi să nu primească seturi apropiate. */
function booksForUser(i) {
  const step = 13; // coprim cu lungimea pool-ului (60), acoperă tot pool-ul
  const start = (i * 7) % BOOK_POOL.length;
  const picked = [];
  const seen = new Set();
  let idx = start;
  while (picked.length < BOOKS_PER_USER) {
    if (!seen.has(idx)) {
      seen.add(idx);
      picked.push(BOOK_POOL[idx]);
    }
    idx = (idx + step) % BOOK_POOL.length;
  }
  return picked;
}

const CATEGORY_CYCLE = ['swap', 'sale', 'donation', 'auction'];

/** Construiește datele unui singur anunț, cu cât mai multe câmpuri diferite
 * folosite, în funcție de categorie și de un index `j` (varietate în cadrul
 * userului) și `i` (varietate între useri). */
function listingData(category, book, userId, bookId, i, j, username, userCity) {
  const condition = pick(CONDITIONS, i + j);
  const edition = pick(EDITIONS, i * 3 + j);
  const tags = [pick(TAG_POOL, i + j), pick(TAG_POOL, i + j + 5)].filter(
    (t, idx, arr) => arr.indexOf(t) === idx,
  );
  const photoCount = 2 + ((i + j) % 3); // 2-4 poze, variat
  const photoList = photos(`${username}-${category}-${j}`, photoCount);
  // Orașul anunțului diferă uneori de orașul userului (funcționalitate
  // folosită real când userul are cărți în alt oraș decât reședința).
  const listingCity = (i + j) % 4 === 0 ? pick(CITIES, i + j + 3) : userCity;
  const base = {
    userId,
    bookId,
    condition,
    language: book.language,
    edition,
    isHardcover: (i + j) % 2 === 0,
    photos: photoList,
    mainPhotoUrl: (i + j) % 3 === 0 ? photoList[photoList.length - 1] : null,
    description: `Exemplar în stare ${condition.toLowerCase().replace('_', ' ')}${edition ? `, ${edition.toLowerCase()}` : ''}.`,
    tags,
    city: listingCity,
    viewCount: (i * 3 + j * 7) % 40,
  };

  switch (category) {
    case 'swap':
      return {
        ...base,
        availableForSwap: true,
        isForSale: false,
        // O parte din anunțurile de schimb acceptă și bani ("sau vinde cu X lei").
        swapSalePrice: (i + j) % 3 === 0 ? 20 + ((i + j) % 5) * 5 : null,
      };
    case 'sale':
      return {
        ...base,
        availableForSwap: false,
        isForSale: true,
        salePrice: 25 + ((i * 5 + j * 11) % 60),
        isNegotiable: (i + j) % 2 === 0,
      };
    case 'donation': {
      const dedicated = { ...base };
      // Donație = vânzare cu preț 0, dar rămâne "disponibilă la schimb" ca
      // cererea de donație (ExchangeRequest) să funcționeze din book detail,
      // exact ca la un anunț real (vezi bookDetailScreen: isDonation = isForSale && salePrice == 0).
      return {
        ...dedicated,
        availableForSwap: true,
        isForSale: true,
        salePrice: 0,
        isNegotiable: false,
      };
    }
    case 'auction':
      return {
        ...base,
        availableForSwap: false,
        isForSale: false,
        isAuction: true,
      };
    default:
      throw new Error(`Categorie necunoscută: ${category}`);
  }
}

async function main() {
  console.log('Șterg TOATE anunțurile curente din baza de date (toate UserBook-urile)...');
  const wiped = await prisma.userBook.deleteMany({});
  console.log(`  - șterse ${wiped.count} anunțuri (cascadă: licitații/oferte/vizualizări asociate).`);

  const passwordHash = await bcrypt.hash(PASSWORD, SALT_ROUNDS);
  const now = new Date();

  for (let i = 0; i < USER_COUNT; i++) {
    const first = FIRST_NAMES[i % FIRST_NAMES.length];
    const last = LAST_NAMES[(i + 7) % LAST_NAMES.length];
    const displayName = `TEST_${first} ${last}`;
    const username = `test_${slugify(first)}_${slugify(last)}_${String(i + 1).padStart(2, '0')}`;
    const email = `${username}@${EMAIL_DOMAIN}`;
    const city = CITIES[i % CITIES.length];
    const bio = BIOS[i % BIOS.length];
    // O cincime din useri sunt Premium, ca funcționalitatea de "Promoted
    // Listings" să aibă cine s-o folosească în seed.
    const isPremium = i % 8 === 0;

    const existing = await prisma.user.findUnique({ where: { email } });
    const profile = {
      password: passwordHash,
      isEmailVerified: true,
      emailVerifyToken: null,
      emailVerifyExpiry: null,
      name: displayName,
      username,
      nameVisible: true,
      city,
      bio,
      isPremium,
      readingSurveyCompletedAt: now,
      deletionScheduledAt: null,
      isBanned: false,
    };

    const user = existing
      ? await prisma.user.update({ where: { id: existing.id }, data: profile })
      : await prisma.user.create({
          data: {
            email,
            referralCode: await uniqueReferralCode(),
            ...profile,
          },
        });

    const books = booksForUser(i);
    // Categoriile celor 5 anunțuri pornesc dintr-un punct diferit al
    // ciclului pentru fiecare user, ca ordinea și distribuția să nu fie
    // identice de la un cont la altul.
    const categories = Array.from(
      { length: BOOKS_PER_USER },
      (_, j) => CATEGORY_CYCLE[(i + j) % CATEGORY_CYCLE.length],
    );

    let created = 0;
    for (let j = 0; j < books.length; j++) {
      const b = books[j];
      const category = categories[j];
      const book = await upsertBook(b);
      const data = listingData(category, b, user.id, book.id, i, j, username, city);
      // Doar userii Premium pot avea anunțuri promovate - un singur anunț
      // promovat per user Premium, pe primul lui anunț.
      if (isPremium && j === 0) data.isPromoted = true;

      const userBook = await prisma.userBook.create({ data });

      if (category === 'auction') {
        await prisma.auction.create({
          data: {
            userBookId: userBook.id,
            startingPrice: 20 + ((i + j) % 8) * 5,
            currentPrice: 20 + ((i + j) % 8) * 5,
            endsAt: new Date(now.getTime() + (3 + ((i + j) % 7)) * 24 * 60 * 60 * 1000),
            status: AuctionStatus.ACTIVE,
          },
        });
      }
      created++;
    }

    console.log(`${existing ? 'Actualizat' : 'Creat'}: ${email} (${displayName}) - ${created} anunțuri`);
  }

  console.log(`\nGata. ${USER_COUNT} useri „TEST_", câte ${BOOKS_PER_USER} anunțuri fiecare, parola pentru toți: ${PASSWORD}`);
}

main()
  .catch((error) => {
    console.error(error);
    process.exitCode = 1;
  })
  .finally(() => prisma.$disconnect());
