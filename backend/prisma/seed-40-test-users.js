/**
 * Creează 40 de conturi de test („Nume Prenume - TEST"), fiecare cu câte 3
 * anunțuri din fiecare categorie de listare (Swap / Vânzare / Licitație /
 * Donație) = 12 anunțuri per user, 480 în total. Parola tuturor: `pass123`.
 *
 * ȘTERGE ÎNTÂI TOATE anunțurile din baza de date (toate `UserBook`-urile,
 * indiferent de cont) - decizie explicită a userului, nu doar cele
 * create anterior de acest script. Userii înșiși NU sunt șterși, doar
 * anunțurile lor. Rulează acest script DOAR pe o bază de date unde chiar
 * vrei să golești toate listările curente.
 *
 * E idempotent pentru partea proprie: la a doua rulare, cei 40 de useri
 * „- TEST" sunt recunoscuți după domeniul de email (@shelfshare.test) și
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
  'Bogdan', 'Alina', 'Florin', 'Bianca',
];
const LAST_NAMES = [
  'Popescu', 'Ionescu', 'Dumitru', 'Constantin', 'Georgescu', 'Marin', 'Stan', 'Voicu',
  'Rusu', 'Munteanu', 'Nistor', 'Enache', 'Toma', 'Pavel', 'Stanciu', 'Neagu',
  'Ilie', 'Barbu', 'Dinu', 'Chiriac',
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
];

/** 8 titluri per categorie - ciclate pe useri, ca fiecare user să primească
 * 3 titluri diferite din categoria respectivă, dar cărțile (catalogul) să
 * rămână partajate între useri, exact ca la un add-book normal. */
const SWAP_BOOKS = [
  { isbn: '9780439708180', title: "Harry Potter and the Sorcerer's Stone", author: 'J.K. Rowling', genre: 'Fantasy', language: 'Engleză', pageCount: 309, publishedYear: 1997 },
  { isbn: '9780547928227', title: 'The Hobbit', author: 'J.R.R. Tolkien', genre: 'Fantasy', language: 'Engleză', pageCount: 310, publishedYear: 1937 },
  { isbn: '9780451524935', title: '1984', author: 'George Orwell', genre: 'Distopie', language: 'Engleză', pageCount: 328, publishedYear: 1949 },
  { isbn: '9780060850524', title: 'Brave New World', author: 'Aldous Huxley', genre: 'Distopie', language: 'Engleză', pageCount: 311, publishedYear: 1932 },
  { isbn: '9780316769488', title: 'The Catcher in the Rye', author: 'J.D. Salinger', genre: 'Ficțiune', language: 'Engleză', pageCount: 277, publishedYear: 1951 },
  { isbn: '9780061120084', title: 'To Kill a Mockingbird', author: 'Harper Lee', genre: 'Ficțiune', language: 'Engleză', pageCount: 336, publishedYear: 1960 },
  { isbn: '9780756404741', title: 'The Name of the Wind', author: 'Patrick Rothfuss', genre: 'Fantasy', language: 'Engleză', pageCount: 662, publishedYear: 2007 },
  { isbn: '9780765311788', title: 'Mistborn', author: 'Brandon Sanderson', genre: 'Fantasy', language: 'Engleză', pageCount: 541, publishedYear: 2006 },
];
const SALE_BOOKS = [
  { isbn: '9780062316097', title: 'Sapiens', author: 'Yuval Noah Harari', genre: 'Non-ficțiune', language: 'Engleză', pageCount: 464, publishedYear: 2011, price: 45 },
  { isbn: '9780735211292', title: 'Atomic Habits', author: 'James Clear', genre: 'Dezvoltare personală', language: 'Engleză', pageCount: 320, publishedYear: 2018, price: 39 },
  { isbn: '9781250301697', title: 'The Silent Patient', author: 'Alex Michaelides', genre: 'Thriller', language: 'Engleză', pageCount: 336, publishedYear: 2019, price: 35 },
  { isbn: '9780735219090', title: 'Where the Crawdads Sing', author: 'Delia Owens', genre: 'Ficțiune', language: 'Engleză', pageCount: 384, publishedYear: 2018, price: 42 },
  { isbn: '9780525559474', title: 'The Midnight Library', author: 'Matt Haig', genre: 'Ficțiune', language: 'Engleză', pageCount: 288, publishedYear: 2020, price: 38 },
  { isbn: '9780399590504', title: 'Educated', author: 'Tara Westover', genre: 'Memorii', language: 'Engleză', pageCount: 352, publishedYear: 2018, price: 40 },
  { isbn: '9780593135204', title: 'Project Hail Mary', author: 'Andy Weir', genre: 'Science Fiction', language: 'Engleză', pageCount: 496, publishedYear: 2021, price: 48 },
  { isbn: '9780062060624', title: 'The Song of Achilles', author: 'Madeline Miller', genre: 'Ficțiune istorică', language: 'Engleză', pageCount: 416, publishedYear: 2011, price: 36 },
];
const AUCTION_BOOKS = [
  { isbn: '9780593098233', title: 'Dune Messiah', author: 'Frank Herbert', genre: 'Science Fiction', language: 'Engleză', pageCount: 256, publishedYear: 1969, startingPrice: 25 },
  { isbn: '9780553293357', title: 'Foundation', author: 'Isaac Asimov', genre: 'Science Fiction', language: 'Engleză', pageCount: 255, publishedYear: 1951, startingPrice: 30 },
  { isbn: '9780062572110', title: 'American Gods', author: 'Neil Gaiman', genre: 'Fantasy', language: 'Engleză', pageCount: 635, publishedYear: 2001, startingPrice: 28 },
  { isbn: '9780143034902', title: 'The Shadow of the Wind', author: 'Carlos Ruiz Zafón', genre: 'Mister', language: 'Engleză', pageCount: 487, publishedYear: 2001, startingPrice: 32 },
  { isbn: '9780060853976', title: 'Good Omens', author: 'Terry Pratchett & Neil Gaiman', genre: 'Fantasy', language: 'Engleză', pageCount: 288, publishedYear: 1990, startingPrice: 27 },
  { isbn: '9780307346612', title: 'World War Z', author: 'Max Brooks', genre: 'Science Fiction', language: 'Engleză', pageCount: 342, publishedYear: 2006, startingPrice: 22 },
  { isbn: '9780307387899', title: 'The Road', author: 'Cormac McCarthy', genre: 'Ficțiune', language: 'Engleză', pageCount: 287, publishedYear: 2006, startingPrice: 26 },
  { isbn: '9780440180296', title: 'Slaughterhouse-Five', author: 'Kurt Vonnegut', genre: 'Science Fiction', language: 'Engleză', pageCount: 275, publishedYear: 1969, startingPrice: 24 },
];
const DONATION_BOOKS = [
  { isbn: '9780062315007', title: 'The Alchemist', author: 'Paulo Coelho', genre: 'Ficțiune', language: 'Engleză', pageCount: 197, publishedYear: 1988 },
  { isbn: '9780807014295', title: "Man's Search for Meaning", author: 'Viktor Frankl', genre: 'Non-ficțiune', language: 'Engleză', pageCount: 165, publishedYear: 1946 },
  { isbn: '9780156012195', title: 'The Little Prince', author: 'Antoine de Saint-Exupéry', genre: 'Ficțiune', language: 'Engleză', pageCount: 96, publishedYear: 1943 },
  { isbn: '9780140177398', title: 'Of Mice and Men', author: 'John Steinbeck', genre: 'Ficțiune', language: 'Engleză', pageCount: 107, publishedYear: 1937 },
  { isbn: '9780451526342', title: 'Animal Farm', author: 'George Orwell', genre: 'Distopie', language: 'Engleză', pageCount: 112, publishedYear: 1945 },
  { isbn: '9780743273565', title: 'The Great Gatsby', author: 'F. Scott Fitzgerald', genre: 'Ficțiune', language: 'Engleză', pageCount: 180, publishedYear: 1925 },
  { isbn: '9781451673319', title: 'Fahrenheit 451', author: 'Ray Bradbury', genre: 'Science Fiction', language: 'Engleză', pageCount: 194, publishedYear: 1953 },
  { isbn: '9780141439518', title: 'Pride and Prejudice', author: 'Jane Austen', genre: 'Roman', language: 'Engleză', pageCount: 432, publishedYear: 1813 },
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

async function main() {
  console.log('Șterg TOATE anunțurile curente din producție (toate UserBook-urile)...');
  const wiped = await prisma.userBook.deleteMany({});
  console.log(`  - șterse ${wiped.count} anunțuri (cascadă: licitații/oferte/vizualizări asociate).`);

  const passwordHash = await bcrypt.hash(PASSWORD, SALT_ROUNDS);
  const now = new Date();

  for (let i = 0; i < USER_COUNT; i++) {
    const first = FIRST_NAMES[i % FIRST_NAMES.length];
    const last = LAST_NAMES[(i + 7) % LAST_NAMES.length];
    const displayName = `${first} ${last} - TEST`;
    const username = `${slugify(first)}_${slugify(last)}_${String(i + 1).padStart(2, '0')}`;
    const email = `${username}@${EMAIL_DOMAIN}`;
    const city = CITIES[i % CITIES.length];
    const bio = BIOS[i % BIOS.length];

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

    // Câte 3 titluri diferite din fiecare categorie, ciclate pe index ca
    // fiecare user să nu primească mereu exact aceleași 3 din pool (8).
    const swapPicks = [0, 1, 2].map((k) => SWAP_BOOKS[(i + k) % SWAP_BOOKS.length]);
    const salePicks = [0, 1, 2].map((k) => SALE_BOOKS[(i + k) % SALE_BOOKS.length]);
    const auctionPicks = [0, 1, 2].map((k) => AUCTION_BOOKS[(i + k) % AUCTION_BOOKS.length]);
    const donationPicks = [0, 1, 2].map((k) => DONATION_BOOKS[(i + k) % DONATION_BOOKS.length]);

    let created = 0;

    for (const [j, b] of swapPicks.entries()) {
      const book = await upsertBook(b);
      await prisma.userBook.create({
        data: {
          userId: user.id,
          bookId: book.id,
          condition: CONDITIONS[j % CONDITIONS.length],
          language: b.language,
          isHardcover: j === 0,
          availableForSwap: true,
          photos: photos(`${username}-swap-${j}`, 2),
        },
      });
      created++;
    }

    for (const [j, b] of salePicks.entries()) {
      const book = await upsertBook(b);
      await prisma.userBook.create({
        data: {
          userId: user.id,
          bookId: book.id,
          condition: CONDITIONS[j % CONDITIONS.length],
          language: b.language,
          isHardcover: j === 1,
          availableForSwap: false,
          isForSale: true,
          salePrice: b.price,
          isNegotiable: j !== 0,
          photos: photos(`${username}-sale-${j}`, 2),
        },
      });
      created++;
    }

    for (const [j, b] of donationPicks.entries()) {
      const book = await upsertBook(b);
      await prisma.userBook.create({
        data: {
          userId: user.id,
          bookId: book.id,
          condition: CONDITIONS[(j + 2) % CONDITIONS.length],
          language: b.language,
          isHardcover: false,
          availableForSwap: false,
          isForSale: true,
          salePrice: null,
          isNegotiable: false,
          photos: photos(`${username}-donation-${j}`, 2),
        },
      });
      created++;
    }

    for (const [j, b] of auctionPicks.entries()) {
      const book = await upsertBook(b);
      const userBook = await prisma.userBook.create({
        data: {
          userId: user.id,
          bookId: book.id,
          condition: CONDITIONS[j % CONDITIONS.length],
          language: b.language,
          isHardcover: j === 2,
          availableForSwap: false,
          isAuction: true,
          photos: photos(`${username}-auction-${j}`, 2),
        },
      });
      await prisma.auction.create({
        data: {
          userBookId: userBook.id,
          startingPrice: b.startingPrice,
          currentPrice: b.startingPrice,
          endsAt: new Date(now.getTime() + (5 + j) * 24 * 60 * 60 * 1000),
          status: AuctionStatus.ACTIVE,
        },
      });
      created++;
    }

    console.log(`${existing ? 'Actualizat' : 'Creat'}: ${email} (${displayName}) - ${created} anunțuri`);
  }

  console.log(`\nGata. ${USER_COUNT} useri „- TEST", parola pentru toți: ${PASSWORD}`);
}

main()
  .catch((error) => {
    console.error(error);
    process.exitCode = 1;
  })
  .finally(() => prisma.$disconnect());
