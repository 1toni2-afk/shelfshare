/**
 * Configurează cele șase conturi de test folosite pentru probe manuale între
 * mine și userii de test (dtoniyi@yahoo.com + test1-5@yahoo.com, parola
 * pentru test1-5 e `pass123`) - fiecare cu profilul completat și cu 8
 * anunțuri (3 cărți originale de schimb + 5 noi, distribuite pe toate cele
 * patru categorii: Swap / Vânzare / Licitație / Donație), ca între aceste
 * șase conturi să existe suficiente anunțuri variate pentru oferte reale
 * (vezi seed-category-offers.js, care creează 4 oferte per categorie exact
 * între aceste conturi).
 *
 * dtoniyi@yahoo.com e contul meu real, nu unul creat de acest script: NU îi
 * atingem parola sau profilul, doar îi adăugăm anunțuri. Scriptul aruncă
 * eroare dacă acest cont nu există deja - nu-l creează.
 *
 * SPRE DEOSEBIRE de `seed.ts`, scriptul ăsta NU șterge alte anunțuri.
 * E idempotent: rularea repetată actualizează aceleași șase conturi și nu
 * duplică anunțuri (cărțile sunt legate de un `source` propriu, iar
 * `UserBook`-urile existente ale conturilor sunt recreate, nu adăugate
 * peste). Poate fi rulat în siguranță pe o bază de date cu utilizatori
 * reali - nicio altă înregistrare nu e atinsă.
 *
 * Versiune .js (nu .ts): imaginea de producție nu are pnpm/ts-node - doar
 * `node dist/main`. @prisma/client, @prisma/adapter-pg, bcrypt și dotenv
 * rămân în node_modules după `pnpm prune --prod` (sunt dependencies, nu
 * devDependencies), deci scriptul rulează direct cu `node`, fără compilare.
 *
 * Rulează în interiorul containerului backend (DATABASE_URL rezolvă "postgres"
 * ca host doar acolo):
 *   docker compose -f docker-compose.prod.yml exec backend \
 *     node prisma/seed-test-accounts.js
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

/** Marcaj pe cărțile create de scriptul ăsta, ca să le putem recunoaște. */
const SOURCE = 'test-accounts-seed';

/** Contul meu real - doar primește anunțuri, profilul/parola nu se ating. */
const ADMIN_EMAIL = 'dtoniyi@yahoo.com';

/**
 * Bio-ul e limitat la 20 de caractere (vezi UpdateProfileDto.bio și
 * kBioMaxLength din frontend) - textele de mai jos respectă limita.
 */
const ACCOUNTS = [
  {
    email: 'test1@yahoo.com',
    username: 'test_unu',
    name: 'Test Unu',
    city: 'Cluj-Napoca',
    bio: 'Citesc SF si fantasy',
    favoriteGenres: ['Fantasy', 'Science Fiction'],
    favoriteAuthors: ['J.R.R. Tolkien', 'Frank Herbert'],
    readingPace: 'moderat',
  },
  {
    email: 'test2@yahoo.com',
    username: 'test_doi',
    name: 'Test Doi',
    city: 'Aiud',
    bio: 'Thriller si crime',
    favoriteGenres: ['Thriller', 'Mister'],
    favoriteAuthors: ['Agatha Christie', 'Stieg Larsson'],
    readingPace: 'rapid',
  },
  {
    email: 'test3@yahoo.com',
    username: 'test_trei',
    name: 'Test Trei',
    city: 'București',
    bio: 'Clasici romanesti',
    favoriteGenres: ['Ficțiune', 'Poezie'],
    favoriteAuthors: ['Mihail Sadoveanu', 'Marin Preda'],
    readingPace: 'lent',
  },
  {
    email: 'test4@yahoo.com',
    username: 'test_patru',
    name: 'Test Patru',
    city: 'Timișoara',
    bio: 'Dezvoltare personala',
    favoriteGenres: ['Non-ficțiune', 'Biografie'],
    favoriteAuthors: ['James Clear', 'Yuval Noah Harari'],
    readingPace: 'moderat',
  },
  {
    email: 'test5@yahoo.com',
    username: 'test_cinci',
    name: 'Test Cinci',
    city: 'Iași',
    bio: 'Aventura si istorie',
    favoriteGenres: ['Aventură', 'Istorie'],
    favoriteAuthors: ['Isaac Asimov', 'Ken Follett'],
    readingPace: 'rapid',
  },
];

const CONDITIONS = [
  BookCondition.NOUA,
  BookCondition.FOARTE_BUNA,
  BookCondition.BUNA,
  BookCondition.ACCEPTABILA,
];

/** Cărțile "clasice" de schimb, câte 3 per cont - neschimbate față de
 * versiunea inițială a scriptului, ca legăturile deja create manual
 * (conversații, oferte) să nu-și piardă sensul. */
const SWAP_BOOKS_PER_ACCOUNT = [
  [
    { isbn: '9780261102354', title: 'The Fellowship of the Ring', author: 'J.R.R. Tolkien', genre: 'Fantasy', language: 'Engleză', pageCount: 432, publishedYear: 1954 },
    { isbn: '9780441013593', title: 'Dune', author: 'Frank Herbert', genre: 'Science Fiction', language: 'Engleză', pageCount: 688, publishedYear: 1965 },
    { isbn: '9789734635382', title: 'Fahrenheit 451', author: 'Ray Bradbury', genre: 'Science Fiction', language: 'Română', pageCount: 208, publishedYear: 1953 },
  ],
  [
    { isbn: '9780062073488', title: 'Crima din Orient Express', author: 'Agatha Christie', genre: 'Mister', language: 'Română', pageCount: 256, publishedYear: 1934 },
    { isbn: '9780307454546', title: 'Fata cu un dragon tatuat', author: 'Stieg Larsson', genre: 'Thriller', language: 'Română', pageCount: 480, publishedYear: 2005 },
    { isbn: '9780345539434', title: 'Gone Girl', author: 'Gillian Flynn', genre: 'Thriller', language: 'Engleză', pageCount: 432, publishedYear: 2012 },
  ],
  [
    { isbn: '9789731047560', title: 'Baltagul', author: 'Mihail Sadoveanu', genre: 'Ficțiune', language: 'Română', pageCount: 192, publishedYear: 1930 },
    { isbn: '9789734603312', title: 'Moromeții', author: 'Marin Preda', genre: 'Ficțiune', language: 'Română', pageCount: 560, publishedYear: 1955 },
    { isbn: '9789731043128', title: 'Enigma Otiliei', author: 'George Călinescu', genre: 'Ficțiune', language: 'Română', pageCount: 448, publishedYear: 1938 },
  ],
  [
    { isbn: '9780735211292', title: 'Atomic Habits', author: 'James Clear', genre: 'Dezvoltare personală', language: 'Engleză', pageCount: 320, publishedYear: 2018 },
    { isbn: '9780062316097', title: 'Sapiens', author: 'Yuval Noah Harari', genre: 'Non-ficțiune', language: 'Engleză', pageCount: 464, publishedYear: 2011 },
    { isbn: '9780399590504', title: 'Educated', author: 'Tara Westover', genre: 'Memorii', language: 'Engleză', pageCount: 352, publishedYear: 2018 },
  ],
  [
    { isbn: '9780553293357', title: 'Foundation', author: 'Isaac Asimov', genre: 'Science Fiction', language: 'Engleză', pageCount: 255, publishedYear: 1951 },
    { isbn: '9780593135204', title: 'Project Hail Mary', author: 'Andy Weir', genre: 'Science Fiction', language: 'Engleză', pageCount: 496, publishedYear: 2021 },
    { isbn: '9780307346612', title: 'World War Z', author: 'Max Brooks', genre: 'Science Fiction', language: 'Engleză', pageCount: 342, publishedYear: 2006 },
  ],
];

/** +5 cărți noi per cont (incl. dtoniyi, index 5), câte una din fiecare
 * categorie (Swap / Vânzare / Donație / Licitație) + o a cincea variată, ca
 * fiecare din cele 6 conturi să aibă anunțuri eligibile pentru oferte în
 * toate categoriile - vezi seed-category-offers.js. */
const EXTRA_BOOKS_PER_ACCOUNT = [
  // test1@yahoo.com
  [
    { category: 'swap', isbn: '9780765311788', title: 'Mistborn', author: 'Brandon Sanderson', genre: 'Fantasy', language: 'Engleză', pageCount: 541, publishedYear: 2006 },
    { category: 'sale', isbn: '9780593135211', title: 'Circe', author: 'Madeline Miller', genre: 'Fantasy', language: 'Engleză', pageCount: 393, publishedYear: 2018, price: 42 },
    { category: 'donation', isbn: '9780451526342', title: 'Animal Farm', author: 'George Orwell', genre: 'Distopie', language: 'Engleză', pageCount: 112, publishedYear: 1945 },
    { category: 'auction', isbn: '9780765326355', title: 'The Way of Kings', author: 'Brandon Sanderson', genre: 'Fantasy', language: 'Engleză', pageCount: 1007, publishedYear: 2010, startingPrice: 45 },
    { category: 'swap', isbn: '9780756404741', title: 'The Name of the Wind', author: 'Patrick Rothfuss', genre: 'Fantasy', language: 'Engleză', pageCount: 662, publishedYear: 2007 },
  ],
  // test2@yahoo.com
  [
    { category: 'swap', isbn: '9780143034902', title: 'The Shadow of the Wind', author: 'Carlos Ruiz Zafón', genre: 'Mister', language: 'Engleză', pageCount: 487, publishedYear: 2001 },
    { category: 'sale', isbn: '9781250301697', title: 'The Silent Patient', author: 'Alex Michaelides', genre: 'Thriller', language: 'Engleză', pageCount: 336, publishedYear: 2019, price: 35 },
    { category: 'donation', isbn: '9780241983810', title: 'Sherlock Holmes: A Study in Scarlet', author: 'Arthur Conan Doyle', genre: 'Mister', language: 'Engleză', pageCount: 176, publishedYear: 1887 },
    { category: 'auction', isbn: '9780486282114', title: 'Dracula', author: 'Bram Stoker', genre: 'Horror', language: 'Engleză', pageCount: 418, publishedYear: 1897, startingPrice: 30 },
    { category: 'sale', isbn: '9780199537099', title: 'Frankenstein', author: 'Mary Shelley', genre: 'Horror', language: 'Engleză', pageCount: 280, publishedYear: 1818, price: 28 },
  ],
  // test3@yahoo.com
  [
    { category: 'swap', isbn: '9789736897457', title: 'Ion', author: 'Liviu Rebreanu', genre: 'Ficțiune', language: 'Română', pageCount: 480, publishedYear: 1920 },
    { category: 'sale', isbn: '9789734625345', title: 'Ultima noapte de dragoste, întâia noapte de război', author: 'Camil Petrescu', genre: 'Ficțiune', language: 'Română', pageCount: 304, publishedYear: 1930, price: 30 },
    { category: 'donation', isbn: '9789733405543', title: 'Amintiri din copilărie', author: 'Ion Creangă', genre: 'Memorii', language: 'Română', pageCount: 220, publishedYear: 1892 },
    { category: 'auction', isbn: '9789731049090', title: 'Cel mai iubit dintre pământeni', author: 'Marin Preda', genre: 'Ficțiune', language: 'Română', pageCount: 850, publishedYear: 1980, startingPrice: 35 },
    { category: 'swap', isbn: '9780141439518', title: 'Pride and Prejudice', author: 'Jane Austen', genre: 'Roman', language: 'Engleză', pageCount: 432, publishedYear: 1813 },
  ],
  // test4@yahoo.com
  [
    { category: 'swap', isbn: '9780062457714', title: 'The Subtle Art of Not Giving a F*ck', author: 'Mark Manson', genre: 'Dezvoltare personală', language: 'Engleză', pageCount: 224, publishedYear: 2016 },
    { category: 'sale', isbn: '9780807014295', title: "Man's Search for Meaning", author: 'Viktor Frankl', genre: 'Non-ficțiune', language: 'Engleză', pageCount: 165, publishedYear: 1946, price: 32 },
    { category: 'donation', isbn: '9780062315007', title: 'The Alchemist', author: 'Paulo Coelho', genre: 'Ficțiune', language: 'Engleză', pageCount: 197, publishedYear: 1988 },
    { category: 'auction', isbn: '9780525559474', title: 'The Midnight Library', author: 'Matt Haig', genre: 'Ficțiune', language: 'Engleză', pageCount: 288, publishedYear: 2020, startingPrice: 25 },
    { category: 'sale', isbn: '9780735219090', title: 'Where the Crawdads Sing', author: 'Delia Owens', genre: 'Ficțiune', language: 'Engleză', pageCount: 384, publishedYear: 2018, price: 38 },
  ],
  // test5@yahoo.com
  [
    { category: 'swap', isbn: '9780345534893', title: 'Ready Player One', author: 'Ernest Cline', genre: 'Science Fiction', language: 'Engleză', pageCount: 374, publishedYear: 2011 },
    { category: 'sale', isbn: '9781451673319', title: 'Fahrenheit 451 (ediție SF)', author: 'Ray Bradbury', genre: 'Science Fiction', language: 'Engleză', pageCount: 194, publishedYear: 1953, price: 27 },
    { category: 'donation', isbn: '9780440180296', title: 'Slaughterhouse-Five', author: 'Kurt Vonnegut', genre: 'Science Fiction', language: 'Engleză', pageCount: 275, publishedYear: 1969 },
    { category: 'auction', isbn: '9780062572110', title: 'American Gods', author: 'Neil Gaiman', genre: 'Fantasy', language: 'Engleză', pageCount: 635, publishedYear: 2001, startingPrice: 40 },
    { category: 'swap', isbn: '9780199535569', title: 'Jane Eyre', author: 'Charlotte Brontë', genre: 'Roman', language: 'Engleză', pageCount: 532, publishedYear: 1847 },
  ],
  // dtoniyi@yahoo.com (adminul)
  [
    { category: 'swap', isbn: '9780547928227', title: 'The Hobbit', author: 'J.R.R. Tolkien', genre: 'Fantasy', language: 'Engleză', pageCount: 310, publishedYear: 1937 },
    { category: 'sale', isbn: '9780593098233', title: 'Dune Messiah', author: 'Frank Herbert', genre: 'Science Fiction', language: 'Engleză', pageCount: 256, publishedYear: 1969, price: 33 },
    { category: 'donation', isbn: '9780156012195', title: 'The Little Prince', author: 'Antoine de Saint-Exupéry', genre: 'Ficțiune', language: 'Engleză', pageCount: 96, publishedYear: 1943 },
    { category: 'auction', isbn: '9780553293364', title: 'Foundation and Empire', author: 'Isaac Asimov', genre: 'Science Fiction', language: 'Engleză', pageCount: 247, publishedYear: 1952, startingPrice: 28 },
    { category: 'sale', isbn: '9780743273565', title: 'The Great Gatsby', author: 'F. Scott Fitzgerald', genre: 'Ficțiune', language: 'Engleză', pageCount: 180, publishedYear: 1925, price: 24 },
  ],
];

const EDITIONS = [null, 'Ediție cartonată', 'Ediție de buzunar', 'Ediție ilustrată', 'Ediție aniversară'];
const TAG_POOL = ['lectura-de-vara', 'editie-rara', 'must-read', 'recomandat', 'de-colectie', 'stare-impecabila'];

function coverUrl(isbn) {
  return `https://covers.openlibrary.org/b/isbn/${isbn}-M.jpg`;
}

function photos(seedKey, count) {
  return Array.from(
    { length: count },
    (_, i) => `https://picsum.photos/seed/${seedKey}-${i}/600/800`,
  );
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

/** Datele unui UserBook în funcție de categorie - vezi seed-40-test-users.js
 * pentru aceeași logică pe scară mai mare (donația e isForSale+salePrice:0,
 * DAR availableForSwap:true, ca cererea de donație din book detail să
 * meargă). */
function listingData(item, userId, bookId, username, i, city) {
  const condition = pick(CONDITIONS, i);
  const edition = pick(EDITIONS, i + 1);
  const photoList = photos(`${username}-extra-${item.category}-${i}`, 2 + (i % 3));
  const base = {
    userId,
    bookId,
    condition,
    language: item.language,
    edition,
    isHardcover: i % 2 === 0,
    photos: photoList,
    mainPhotoUrl: i % 3 === 0 ? photoList[photoList.length - 1] : null,
    description: `Exemplar în stare ${condition.toLowerCase().replace('_', ' ')}${edition ? `, ${edition.toLowerCase()}` : ''}.`,
    tags: [pick(TAG_POOL, i), pick(TAG_POOL, i + 2)].filter((t, idx, arr) => arr.indexOf(t) === idx),
    city,
    viewCount: (i * 5) % 30,
  };

  switch (item.category) {
    case 'swap':
      return { ...base, availableForSwap: true, isForSale: false, swapSalePrice: i % 2 === 0 ? 25 : null };
    case 'sale':
      return { ...base, availableForSwap: false, isForSale: true, salePrice: item.price, isNegotiable: true };
    case 'donation':
      return { ...base, availableForSwap: true, isForSale: true, salePrice: 0, isNegotiable: false };
    case 'auction':
      return { ...base, availableForSwap: false, isForSale: false, isAuction: true };
    default:
      throw new Error(`Categorie necunoscută: ${item.category}`);
  }
}

async function seedListingsFor(user, username, city, swapBooks, extraBooks, now) {
  // Anunțurile contului se refac de la zero la fiecare rulare, ca scriptul
  // să rămână idempotent: altfel a doua rulare ar tripla biblioteca.
  const removed = await prisma.userBook.deleteMany({
    where: { userId: user.id, book: { source: SOURCE } },
  });
  if (removed.count > 0) {
    console.log(`  - am șters ${removed.count} anunțuri din rularea anterioară`);
  }

  let count = 0;

  for (let j = 0; j < swapBooks.length; j++) {
    const b = swapBooks[j];
    const book = await upsertBook(b);
    await prisma.userBook.create({
      data: {
        userId: user.id,
        bookId: book.id,
        condition: CONDITIONS[j % CONDITIONS.length],
        language: b.language,
        isHardcover: j === 0,
        availableForSwap: true,
        photos: photos(`${username}-${j}`, 2),
      },
    });
    count++;
  }

  for (let i = 0; i < extraBooks.length; i++) {
    const item = extraBooks[i];
    const book = await upsertBook(item);
    const data = listingData(item, user.id, book.id, username, i, city);
    const userBook = await prisma.userBook.create({ data });
    if (item.category === 'auction') {
      await prisma.auction.create({
        data: {
          userBookId: userBook.id,
          startingPrice: item.startingPrice,
          currentPrice: item.startingPrice,
          endsAt: new Date(now.getTime() + (5 + i) * 24 * 60 * 60 * 1000),
          status: AuctionStatus.ACTIVE,
        },
      });
    }
    count++;
  }

  console.log(`  - ${count} anunțuri listate (${swapBooks.length} schimb + ${extraBooks.length} noi, toate categoriile)`);
}

async function main() {
  const passwordHash = await bcrypt.hash(PASSWORD, SALT_ROUNDS);
  const now = new Date();

  for (let i = 0; i < ACCOUNTS.length; i++) {
    const account = ACCOUNTS[i];
    const email = account.email.toLowerCase();

    const existing = await prisma.user.findUnique({ where: { email } });

    const profile = {
      password: passwordHash,
      isEmailVerified: true,
      emailVerifyToken: null,
      emailVerifyExpiry: null,
      name: account.name,
      username: account.username,
      nameVisible: true,
      city: account.city,
      bio: account.bio,
      favoriteGenres: account.favoriteGenres,
      favoriteAuthors: account.favoriteAuthors,
      readingPace: account.readingPace,
      // Fără asta, routerul trimite contul direct în chestionarul de cititor
      // la primul login și nu se poate ajunge în aplicație.
      readingSurveyCompletedAt: now,
      // Un cont de test programat pentru ștergere ar dispărea peste 15 zile.
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

    console.log(`${existing ? 'Actualizat' : 'Creat'}: ${email} (${user.id})`);
    await seedListingsFor(
      user,
      account.username,
      account.city,
      SWAP_BOOKS_PER_ACCOUNT[i],
      EXTRA_BOOKS_PER_ACCOUNT[i],
      now,
    );
  }

  // Contul meu real - doar anunțuri noi, nu-i ating parola/profilul.
  const admin = await prisma.user.findUnique({ where: { email: ADMIN_EMAIL } });
  if (!admin) {
    throw new Error(
      `Contul ${ADMIN_EMAIL} nu există în baza de date - loghează-te măcar o dată cu el înainte de a rula scriptul.`,
    );
  }
  console.log(`Găsit: ${admin.email} (${admin.id}) - adaug anunțuri, fără să ating profilul`);
  await seedListingsFor(
    admin,
    'dtoniyi',
    admin.city ?? 'București',
    [],
    EXTRA_BOOKS_PER_ACCOUNT[5],
    now,
  );

  console.log(`\nGata. Parola pentru test1-5: ${PASSWORD}. dtoniyi@yahoo.com neschimbat, doar cu anunțuri noi.`);
}

main()
  .catch((error) => {
    console.error(error);
    process.exitCode = 1;
  })
  .finally(() => prisma.$disconnect());
