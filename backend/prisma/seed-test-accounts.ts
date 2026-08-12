/**
 * Creează cele cinci conturi de test folosite pentru probe manuale
 * (test1-test5@yahoo.com, parola `pass123`), cu emailul deja verificat
 * și cu profilul completat: username, oraș, bio, chestionarul de cititor
 * marcat ca parcurs și câteva cărți listate, ca să se poată da schimburi,
 * oferte și mesaje între ele.
 *
 * SPRE DEOSEBIRE de `seed.ts`, scriptul ăsta NU șterge nimic. E idempotent:
 * rularea repetată actualizează aceleași cinci conturi și nu duplică anunțuri
 * (cărțile sunt legate de un `source` propriu, iar `UserBook`-urile existente
 * ale conturilor sunt recreate, nu adăugate peste). Poate fi rulat în
 * siguranță pe o bază de date cu utilizatori reali - nicio altă înregistrare
 * nu e atinsă.
 *
 * Rulează în interiorul containerului backend (DATABASE_URL rezolvă "postgres"
 * ca host doar acolo):
 *   docker compose -f docker-compose.prod.yml exec backend \
 *     pnpm exec ts-node prisma/seed-test-accounts.ts
 */
import 'dotenv/config';
import { PrismaClient, BookCondition } from '@prisma/client';
import { PrismaPg } from '@prisma/adapter-pg';
import * as bcrypt from 'bcrypt';
import * as crypto from 'crypto';

const adapter = new PrismaPg({ connectionString: process.env.DATABASE_URL });
const prisma = new PrismaClient({ adapter });

const PASSWORD = 'pass123';
const SALT_ROUNDS = 10;

/** Marcaj pe cărțile create de scriptul ăsta, ca să le putem recunoaște. */
const SOURCE = 'test-accounts-seed';

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

/** Câte trei cărți per cont, ca fiecare să aibă ce oferi la schimb. */
const BOOKS_PER_ACCOUNT = [
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

const CONDITIONS: BookCondition[] = [
  BookCondition.FOARTE_BUNA,
  BookCondition.BUNA,
  BookCondition.ACCEPTABILA,
];

function coverUrl(isbn: string): string {
  return `https://covers.openlibrary.org/b/isbn/${isbn}-M.jpg`;
}

function photos(seedKey: string, count: number): string[] {
  return Array.from(
    { length: count },
    (_, i) => `https://picsum.photos/seed/${seedKey}-${i}/600/800`,
  );
}

/** Cod de referral unic, la fel ca în UsersService.generateReferralCode. */
async function uniqueReferralCode(): Promise<string> {
  for (;;) {
    const code = crypto.randomBytes(8).toString('hex').toUpperCase().slice(0, 8);
    const exists = await prisma.user.findUnique({ where: { referralCode: code } });
    if (!exists) return code;
  }
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

    // Anunțurile contului se refac de la zero la fiecare rulare, ca scriptul
    // să rămână idempotent: altfel a doua rulare ar tripla biblioteca.
    const removed = await prisma.userBook.deleteMany({
      where: { userId: user.id, book: { source: SOURCE } },
    });
    if (removed.count > 0) {
      console.log(`  - am șters ${removed.count} anunțuri din rularea anterioară`);
    }

    for (let j = 0; j < BOOKS_PER_ACCOUNT[i].length; j++) {
      const b = BOOKS_PER_ACCOUNT[i][j];
      // Cartea (catalogul) e partajată între useri - o refolosim dacă există
      // deja după ISBN, exact ca la adăugarea normală dintr-un anunț.
      const book =
        (await prisma.book.findFirst({ where: { isbn: b.isbn } })) ??
        (await prisma.book.create({
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
        }));

      await prisma.userBook.create({
        data: {
          userId: user.id,
          bookId: book.id,
          condition: CONDITIONS[j % CONDITIONS.length],
          language: b.language,
          isHardcover: j === 0,
          availableForSwap: true,
          // Aplicația cere minim o poză per anunț.
          photos: photos(`${account.username}-${j}`, 2),
        },
      });
    }

    console.log(`  - ${BOOKS_PER_ACCOUNT[i].length} anunțuri listate`);
  }

  console.log(`\nGata. Parola pentru toate trei: ${PASSWORD}`);
}

main()
  .catch((error) => {
    console.error(error);
    process.exitCode = 1;
  })
  .finally(() => prisma.$disconnect());
