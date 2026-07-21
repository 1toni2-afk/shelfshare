/**
 * Populeaza baza de date cu date demo: utilizatori, carti, biblioteci
 * personale, cereri de schimb (istoric complet - PENDING/ACCEPTED/
 * REJECTED/CANCELLED/COMPLETED), conversatii+mesaje, wishlist si
 * notificari. Scop: sa arate ca o aplicatie deja folosita, nu goala.
 *
 * Ruleaza in interiorul containerului backend (DATABASE_URL rezolva
 * "postgres" ca host doar acolo):
 *   docker compose exec backend pnpm exec ts-node prisma/seed.ts
 */
import 'dotenv/config';
import {
  PrismaClient,
  BookCondition,
  ExchangeStatus,
  User,
  Book,
  UserBook,
  ExchangeRequest,
} from '@prisma/client';
import { PrismaPg } from '@prisma/adapter-pg';
import * as bcrypt from 'bcrypt';

type UserBookWithMeta = UserBook & { ownerId: string; bookTitle: string };
type ExchangeWithMeta = ExchangeRequest & { bookTitle: string };

const adapter = new PrismaPg({ connectionString: process.env.DATABASE_URL });
const prisma = new PrismaClient({ adapter });

const DEMO_PASSWORD = 'Parola123!';

function daysAgo(n: number): Date {
  const d = new Date();
  d.setDate(d.getDate() - n);
  return d;
}

function pick<T>(arr: T[]): T {
  return arr[Math.floor(Math.random() * arr.length)];
}

function pickSeeded<T>(arr: T[], seed: number): T {
  return arr[seed % arr.length];
}

const USERS = [
  { name: 'Andrei Popescu', city: 'București', bio: 'Pasionat de SF și fantasy, citesc cam o carte pe săptămână.' },
  { name: 'Maria Ionescu', city: 'Cluj-Napoca', bio: 'Îmi place literatura română clasică și poezia.' },
  { name: 'Ștefan Dumitru', city: 'Timișoara', bio: 'Colecționez cărți de dezvoltare personală și biografii.' },
  { name: 'Elena Constantin', city: 'Iași', bio: 'Cititoare împătimită de thriller și crime fiction.' },
  { name: 'Radu Georgescu', city: 'Brașov', bio: 'Dau la schimb cărți de istorie și non-ficțiune.' },
  { name: 'Ioana Marin', city: 'Constanța', bio: 'Îmi plac cărțile pentru copii - am doi copii mici.' },
  { name: 'Alexandru Stan', city: 'Craiova', bio: 'Fan Tolkien și Rowling, mereu în căutare de fantasy bun.' },
  { name: 'Cristina Voicu', city: 'Sibiu', bio: 'Citesc orice, dar prefer clasicii internaționali.' },
  { name: 'Mihai Radu', city: 'Oradea', bio: 'Pasionat de SF hard și distopii.' },
  { name: 'Ana Munteanu', city: 'Ploiești', bio: 'Îmi place să descopăr autori noi prin schimburi.' },
  { name: 'Vlad Nistor', city: 'Galați', bio: 'Biografii, memorii și cărți de business.' },
  { name: 'Diana Enache', city: 'Târgu Mureș', bio: 'Cititoare de weekend, prefer romane contemporane.' },
  { name: 'George Toma', city: 'Bacău', bio: 'Colecționez ediții vechi și cărți de istorie.' },
  { name: 'Simona Pavel', city: 'Arad', bio: 'Fantasy și YA - mereu deschisă la schimburi.' },
  { name: 'Bogdan Iliescu', city: 'Sfântu Gheorghe', bio: 'Citesc mai ales seara, thriller și SF.' },
  { name: 'Laura Barbu', city: 'Suceava', bio: 'Carti pentru copii si literatura romana - schimb des.' },
];

const BOOKS = [
  { title: 'Ion', author: 'Liviu Rebreanu', isbn: null, genre: 'Clasic românesc', publishedYear: 1920, language: 'Română', pageCount: 480 },
  { title: 'Enigma Otiliei', author: 'George Călinescu', isbn: null, genre: 'Clasic românesc', publishedYear: 1938, language: 'Română', pageCount: 480 },
  { title: 'Moromeții', author: 'Marin Preda', isbn: null, genre: 'Clasic românesc', publishedYear: 1955, language: 'Română', pageCount: 400 },
  { title: 'Baltagul', author: 'Mihail Sadoveanu', isbn: null, genre: 'Clasic românesc', publishedYear: 1930, language: 'Română', pageCount: 200 },
  { title: 'Craii de Curtea-Veche', author: 'Mateiu Caragiale', isbn: null, genre: 'Clasic românesc', publishedYear: 1929, language: 'Română', pageCount: 160 },
  { title: 'Amintiri din copilărie', author: 'Ion Creangă', isbn: null, genre: 'Clasic românesc', publishedYear: 1892, language: 'Română', pageCount: 220 },
  { title: '1984', author: 'George Orwell', isbn: '9780451524935', genre: 'Distopie', publishedYear: 1949, language: 'Engleză', pageCount: 328 },
  { title: 'Crimă și pedeapsă', author: 'Feodor Dostoievski', isbn: '9780486415871', genre: 'Clasic', publishedYear: 1866, language: 'Română', pageCount: 671 },
  { title: 'Micul Prinț', author: 'Antoine de Saint-Exupéry', isbn: '9780156012195', genre: 'Ficțiune', publishedYear: 1943, language: 'Română', pageCount: 96 },
  { title: 'Harry Potter și Piatra Filosofală', author: 'J.K. Rowling', isbn: '9780747532699', genre: 'Fantasy', publishedYear: 1997, language: 'Română', pageCount: 320 },
  { title: 'Stăpânul Inelelor: Frăția Inelului', author: 'J.R.R. Tolkien', isbn: '9780618346257', genre: 'Fantasy', publishedYear: 1954, language: 'Română', pageCount: 423 },
  { title: 'Jocurile Foamei', author: 'Suzanne Collins', isbn: '9780439023528', genre: 'SF', publishedYear: 2008, language: 'Română', pageCount: 374 },
  { title: 'Leul, Vrăjitoarea și Dulapul', author: 'C.S. Lewis', isbn: '9780064404990', genre: 'Fantasy', publishedYear: 1950, language: 'Română', pageCount: 206 },
  { title: 'Sapiens: Scurtă istorie a omenirii', author: 'Yuval Noah Harari', isbn: '9780062316097', genre: 'Non-ficțiune', publishedYear: 2011, language: 'Română', pageCount: 443 },
  { title: 'Atomic Habits', author: 'James Clear', isbn: '9780735211292', genre: 'Dezvoltare personală', publishedYear: 2018, language: 'Engleză', pageCount: 320 },
  { title: 'Alchimistul', author: 'Paulo Coelho', isbn: '9780062315007', genre: 'Ficțiune', publishedYear: 1988, language: 'Română', pageCount: 208 },
  { title: 'Să ucizi o pasăre cântătoare', author: 'Harper Lee', isbn: '9780061120084', genre: 'Clasic', publishedYear: 1960, language: 'Română', pageCount: 336 },
  { title: 'Mândrie și prejudecată', author: 'Jane Austen', isbn: '9780141439518', genre: 'Clasic', publishedYear: 1813, language: 'Română', pageCount: 432 },
  { title: 'Hobbitul', author: 'J.R.R. Tolkien', isbn: '9780547928227', genre: 'Fantasy', publishedYear: 1937, language: 'Română', pageCount: 310 },
  { title: 'Dune', author: 'Frank Herbert', isbn: '9780441013593', genre: 'SF', publishedYear: 1965, language: 'Engleză', pageCount: 412 },
  { title: 'Fahrenheit 451', author: 'Ray Bradbury', isbn: '9781451673319', genre: 'Distopie', publishedYear: 1953, language: 'Română', pageCount: 256 },
  { title: 'Minunata lume nouă', author: 'Aldous Huxley', isbn: '9780060850524', genre: 'Distopie', publishedYear: 1932, language: 'Română', pageCount: 311 },
  { title: 'Codul lui Da Vinci', author: 'Dan Brown', isbn: '9780307474278', genre: 'Thriller', publishedYear: 2003, language: 'Română', pageCount: 489 },
  { title: 'Educated', author: 'Tara Westover', isbn: '9780399590504', genre: 'Biografie', publishedYear: 2018, language: 'Engleză', pageCount: 334 },
  { title: 'Pădurea Norvegiană', author: 'Haruki Murakami', isbn: '9780375704024', genre: 'Ficțiune', publishedYear: 1987, language: 'Română', pageCount: 296 },
  { title: 'Vânătorul de zmeie', author: 'Khaled Hosseini', isbn: '9781594631931', genre: 'Ficțiune', publishedYear: 2003, language: 'Română', pageCount: 371 },
  { title: 'Viața lui Pi', author: 'Yann Martel', isbn: '9780156027328', genre: 'Ficțiune', publishedYear: 2001, language: 'Română', pageCount: 319 },
  { title: 'Strălucirea', author: 'Stephen King', isbn: '9780307743657', genre: 'Thriller', publishedYear: 1977, language: 'Română', pageCount: 447 },
  { title: 'Percy Jackson și Fulgerul Furat', author: 'Rick Riordan', isbn: '9780786838653', genre: 'Fantasy', publishedYear: 2005, language: 'Română', pageCount: 377 },
  { title: 'Divergent', author: 'Veronica Roth', isbn: '9780062024039', genre: 'SF', publishedYear: 2011, language: 'Română', pageCount: 487 },
  { title: 'Frankenstein', author: 'Mary Shelley', isbn: '9780486282114', genre: 'Clasic', publishedYear: 1818, language: 'Română', pageCount: 280 },
  { title: 'Steve Jobs', author: 'Walter Isaacson', isbn: '9781451648539', genre: 'Biografie', publishedYear: 2011, language: 'Română', pageCount: 656 },
  { title: 'Winnie de Pluș', author: 'A.A. Milne', isbn: '9780525444435', genre: 'Copii', publishedYear: 1926, language: 'Română', pageCount: 176 },
  { title: 'Charlie și Fabrica de Ciocolată', author: 'Roald Dahl', isbn: '9780142410318', genre: 'Copii', publishedYear: 1964, language: 'Română', pageCount: 176 },
  { title: 'Matilda', author: 'Roald Dahl', isbn: '9780142410370', genre: 'Copii', publishedYear: 1988, language: 'Română', pageCount: 240 },
  { title: 'Război și pace', author: 'Lev Tolstoi', isbn: '9781400079988', genre: 'Clasic', publishedYear: 1869, language: 'Română', pageCount: 1225 },
  { title: 'Cel mai iubit dintre pământeni', author: 'Marin Preda', isbn: null, genre: 'Clasic românesc', publishedYear: 1980, language: 'Română', pageCount: 640 },
];

const CONDITIONS: BookCondition[] = ['NOUA', 'FOARTE_BUNA', 'BUNA', 'ACCEPTABILA'];

function coverUrl(isbn: string | null): string | null {
  if (!isbn) return null;
  return `https://covers.openlibrary.org/b/isbn/${isbn}-M.jpg`;
}

async function main() {
  console.log('Curăț datele existente (doar tabelele demo, nu users creați manual cu alte email-uri)...');
  await prisma.notification.deleteMany({ where: { user: { email: { endsWith: '@shelfshare.demo' } } } });
  await prisma.message.deleteMany({ where: { sender: { email: { endsWith: '@shelfshare.demo' } } } });
  await prisma.conversation.deleteMany({
    where: {
      OR: [
        { userA: { email: { endsWith: '@shelfshare.demo' } } },
        { userB: { email: { endsWith: '@shelfshare.demo' } } },
      ],
    },
  });
  await prisma.wishlistItem.deleteMany({ where: { user: { email: { endsWith: '@shelfshare.demo' } } } });
  await prisma.exchangeRequest.deleteMany({
    where: {
      OR: [
        { requester: { email: { endsWith: '@shelfshare.demo' } } },
        { owner: { email: { endsWith: '@shelfshare.demo' } } },
      ],
    },
  });
  await prisma.userBook.deleteMany({ where: { user: { email: { endsWith: '@shelfshare.demo' } } } });
  await prisma.book.deleteMany({ where: { source: 'demo-seed' } });
  await prisma.user.deleteMany({ where: { email: { endsWith: '@shelfshare.demo' } } });

  console.log('Creez utilizatori...');
  const passwordHash = await bcrypt.hash(DEMO_PASSWORD, 12);
  const users: User[] = [];
  for (let i = 0; i < USERS.length; i++) {
    const u = USERS[i];
    const emailSlug = u.name.toLowerCase().replace(/ș/g, 's').replace(/ț/g, 't').replace(/ă/g, 'a').replace(/â|î/g, 'i').replace(/\s+/g, '.');
    const user = await prisma.user.create({
      data: {
        email: `${emailSlug}@shelfshare.demo`,
        password: passwordHash,
        isEmailVerified: true,
        name: u.name,
        city: u.city,
        bio: u.bio,
        profileImage: `https://i.pravatar.cc/300?img=${(i % 70) + 1}`,
        rating: 0,
        booksExchangedCount: 0,
        createdAt: daysAgo(200 - i * 5),
      },
    });
    users.push(user);
  }

  console.log('Creez cărți...');
  const books: Book[] = [];
  for (const b of BOOKS) {
    const book = await prisma.book.create({
      data: {
        isbn: b.isbn,
        title: b.title,
        author: b.author,
        genre: b.genre,
        publishedYear: b.publishedYear,
        language: b.language,
        pageCount: b.pageCount,
        coverUrl: coverUrl(b.isbn),
        source: 'demo-seed',
        description: `${b.title}, de ${b.author}.`,
      },
    });
    books.push(book);
  }

  console.log('Distribui cărțile în bibliotecile utilizatorilor...');
  const userBooks: UserBookWithMeta[] = [];
  for (let i = 0; i < books.length; i++) {
    const owner = pickSeeded(users, i * 3 + 1);
    const userBook = await prisma.userBook.create({
      data: {
        userId: owner.id,
        bookId: books[i].id,
        condition: pickSeeded(CONDITIONS, i),
        language: books[i].language,
        isHardcover: i % 3 === 0,
        availableForSwap: true,
        photos: [],
        createdAt: daysAgo(180 - i * 4),
      },
    });
    userBooks.push({ ...userBook, ownerId: owner.id, bookTitle: books[i].title });
  }

  // câteva cărți duplicate în alte biblioteci, ca să existe suprapuneri
  for (let i = 0; i < 6; i++) {
    const book = pickSeeded(books, i * 7 + 2);
    const owner = pickSeeded(users, i * 5 + 3);
    const userBook = await prisma.userBook.create({
      data: {
        userId: owner.id,
        bookId: book.id,
        condition: pickSeeded(CONDITIONS, i + 2),
        language: book.language,
        isHardcover: false,
        availableForSwap: true,
        photos: [],
        createdAt: daysAgo(90 - i * 3),
      },
    });
    userBooks.push({ ...userBook, ownerId: owner.id, bookTitle: book.title });
  }

  console.log(`Creez cererile de schimb (istoric complet)...`);
  const exchangeCount = new Map<string, number>();
  const bump = (userId: string) => exchangeCount.set(userId, (exchangeCount.get(userId) ?? 0) + 1);

  type Plan = { status: ExchangeStatus; daysBack: number };
  const plans: Plan[] = [
    ...Array(11).fill(null).map((_, i) => ({ status: 'COMPLETED' as ExchangeStatus, daysBack: 150 - i * 10 })),
    ...Array(4).fill(null).map((_, i) => ({ status: 'ACCEPTED' as ExchangeStatus, daysBack: 20 - i * 3 })),
    ...Array(6).fill(null).map((_, i) => ({ status: 'PENDING' as ExchangeStatus, daysBack: 6 - i })),
    ...Array(3).fill(null).map((_, i) => ({ status: 'REJECTED' as ExchangeStatus, daysBack: 45 - i * 8 })),
    ...Array(2).fill(null).map((_, i) => ({ status: 'CANCELLED' as ExchangeStatus, daysBack: 60 - i * 5 })),
  ];

  const conversationsMap = new Map<string, { id: string; a: string; b: string }>();
  const exchanges: ExchangeWithMeta[] = [];

  for (let i = 0; i < plans.length; i++) {
    const plan = plans[i];
    const requestedUB = pickSeeded(userBooks, i * 4 + 1);
    let requester = pickSeeded(users, i * 6 + 2);
    // solicitantul nu poate fi proprietarul cărții
    if (requester.id === requestedUB.ownerId) {
      requester = users[(users.indexOf(requester) + 1) % users.length];
    }

    const offerOwn = i % 3 !== 0;
    let offeredBookId: string | null = null;
    if (offerOwn) {
      const own = userBooks.filter((ub) => ub.ownerId === requester.id);
      if (own.length > 0) offeredBookId = pickSeeded(own, i).id;
    }

    const createdAt = daysAgo(plan.daysBack + 2);
    const updatedAt = daysAgo(plan.daysBack);

    const exchange = await prisma.exchangeRequest.create({
      data: {
        requesterId: requester.id,
        ownerId: requestedUB.ownerId,
        requestedBookId: requestedUB.id,
        offeredBookId,
        offeredAmount: offeredBookId ? null : 25 + (i % 5) * 10,
        status: plan.status,
        message: 'Salut! Aș fi interesat de această carte, ai vrea să facem un schimb?',
        createdAt,
        updatedAt,
      },
    });
    exchanges.push({ ...exchange, bookTitle: requestedUB.bookTitle });

    if (plan.status === 'COMPLETED') {
      bump(requester.id);
      bump(requestedUB.ownerId);
      await prisma.userBook.update({ where: { id: requestedUB.id }, data: { availableForSwap: false } });
      if (offeredBookId) await prisma.userBook.update({ where: { id: offeredBookId }, data: { availableForSwap: false } });
    } else if (plan.status === 'ACCEPTED') {
      await prisma.userBook.update({ where: { id: requestedUB.id }, data: { availableForSwap: false } });
      if (offeredBookId) await prisma.userBook.update({ where: { id: offeredBookId }, data: { availableForSwap: false } });
    }

    // conversație asociată schimbului (pentru cele acceptate/completate/pending avansate)
    if (plan.status !== 'CANCELLED') {
      const [userAId, userBId] = [requester.id, requestedUB.ownerId].sort();
      const key = `${userAId}:${userBId}`;
      if (!conversationsMap.has(key)) {
        const conv = await prisma.conversation.create({
          data: { userAId, userBId, createdAt, updatedAt },
        });
        conversationsMap.set(key, { id: conv.id, a: userAId, b: userBId });
      }
    }
  }

  console.log('Setez rating și contor de schimburi pe profiluri...');
  for (const user of users) {
    const count = exchangeCount.get(user.id) ?? 0;
    const rating = count === 0 ? 0 : Math.min(5, 3.4 + ((user.name ?? '').length % 7) * 0.23);
    await prisma.user.update({
      where: { id: user.id },
      data: { booksExchangedCount: count, rating: Math.round(rating * 10) / 10 },
    });
  }

  console.log('Adaug mesaje în conversații...');
  const sampleMessages = [
    'Salut! Am văzut cererea ta, cartea e încă disponibilă.',
    'Perfect, unde ne-am putea întâlni pentru schimb?',
    'Pot veni în centru, sâmbătă după-amiază?',
    'Sună bine, ne vedem atunci!',
    'Mulțumesc mult, cartea era exact ce căutam!',
    'Cu plăcere, spor la citit!',
    'Cartea e în stare foarte bună, are doar câteva însemnări pe margini.',
    'Nicio problemă, nu mă deranjează.',
    'Mai ai și alte cărți disponibile la schimb?',
    'Da, am actualizat biblioteca, mai uită-te.',
  ];
  let msgIdx = 0;
  for (const conv of conversationsMap.values()) {
    const msgCount = 2 + (msgIdx % 4);
    let lastCreated = daysAgo(30 - msgIdx);
    for (let m = 0; m < msgCount; m++) {
      const sender = m % 2 === 0 ? conv.a : conv.b;
      lastCreated = new Date(lastCreated.getTime() + 1000 * 60 * 60 * (m + 1));
      await prisma.message.create({
        data: {
          conversationId: conv.id,
          senderId: sender,
          content: pickSeeded(sampleMessages, msgIdx + m),
          isRead: m < msgCount - 1,
          createdAt: lastCreated,
        },
      });
    }
    await prisma.conversation.update({ where: { id: conv.id }, data: { updatedAt: lastCreated } });
    msgIdx++;
  }

  console.log('Adaug wishlist...');
  for (let i = 0; i < 14; i++) {
    const user = pickSeeded(users, i * 3 + 5);
    const book = pickSeeded(books, i * 5 + 1);
    await prisma.wishlistItem
      .create({ data: { userId: user.id, bookId: book.id, createdAt: daysAgo(40 - i) } })
      .catch(() => undefined); // ignora duplicate (constraint unique)
  }

  console.log('Adaug notificări...');
  for (const ex of exchanges) {
    if (ex.status === 'PENDING') {
      await prisma.notification.create({
        data: {
          userId: ex.ownerId,
          type: 'EXCHANGE_REQUEST_RECEIVED',
          message: `Ai primit o cerere de schimb pentru "${ex.bookTitle}"`,
          data: { exchangeRequestId: ex.id },
          isRead: false,
          createdAt: ex.createdAt,
        },
      });
    } else if (ex.status === 'ACCEPTED' || ex.status === 'COMPLETED') {
      await prisma.notification.create({
        data: {
          userId: ex.requesterId,
          type: 'EXCHANGE_REQUEST_ACCEPTED',
          message: `Cererea ta de schimb pentru "${ex.bookTitle}" a fost acceptată`,
          data: { exchangeRequestId: ex.id },
          isRead: true,
          createdAt: ex.updatedAt,
        },
      });
    } else if (ex.status === 'REJECTED') {
      await prisma.notification.create({
        data: {
          userId: ex.requesterId,
          type: 'EXCHANGE_REQUEST_REJECTED',
          message: `Cererea ta de schimb pentru "${ex.bookTitle}" a fost refuzată`,
          data: { exchangeRequestId: ex.id },
          isRead: true,
          createdAt: ex.updatedAt,
        },
      });
    }
  }
  for (const conv of conversationsMap.values()) {
    await prisma.notification.create({
      data: {
        userId: conv.a,
        type: 'NEW_MESSAGE',
        message: 'Ai un mesaj nou într-o conversație',
        data: { conversationId: conv.id },
        isRead: Math.random() > 0.5,
        createdAt: daysAgo(2),
      },
    });
  }

  console.log('\nGata! Cont de test pentru login: oricare email de mai jos + parola "Parola123!"');
  console.log(users.slice(0, 5).map((u) => u.email).join('\n'));
}

main()
  .catch((e) => {
    console.error(e);
    process.exit(1);
  })
  .finally(async () => {
    await prisma.$disconnect();
  });
