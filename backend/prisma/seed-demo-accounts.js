/**
 * Conturi de demo pentru capturile de ecran din secțiunea „Ce poți face în
 * ShelfShare" de pe pagina vizitatorilor (web/src/features/public/
 * LandingFeatures.tsx, butoanele „See Demo").
 *
 * Creează un cont principal (Toni) și 3 vecini de raft (Andrada, Mina, Matei), cu TOATE funcțiile
 * populate, ca fiecare ecran să aibă ce arăta:
 *
 *   1. Collections       - 3 colecții cu câte 4-6 cărți
 *   2. Smart matches     - vecinii au cărți de pe lista lui Toni și vor cărți
 *                          de pe raftul lui (reciproc, deci apar potriviri)
 *   3. Nearby books      - vecinii sunt în același oraș (Cluj-Napoca)
 *   4. Groups            - 2 grupuri cu membri, postări și un eveniment
 *   5. Leaderboard       - contoare de schimburi, XP și rating
 *   6. Global statistics - vin din anunțurile/schimburile de mai sus
 *   7. Book history      - Silo, trecută prin 4 mâini (3 foști proprietari),
 *                          plus o carte cu 3 (lanț previousListingId)
 *   8. My shelf          - citite / în curs (cu progres pe pagini) / de citit
 *   9. Trade system      - schimb finalizat cu recenzii, schimb acceptat cu
 *                          întâlnire și telefoane partajate, cerere în așteptare,
 *                          ofertă de preț, toate cu mesaje în chat
 *  10. Feed              - Toni îi urmărește pe vecini, care au activitate
 *
 * Idempotent: la fiecare rulare ȘTERGE conturile de demo de mai jos (cascadă
 * pe tot ce le aparține) și le recreează. Nu atinge niciun alt cont. Cărțile
 * se iau din catalogul existent (cele cu copertă, cele mai populare întâi);
 * singura carte adăugată, dacă lipsește, e Silo (Hugh Howey), pentru istoric.
 *
 * Parola implicită e DEMO_PASSWORD din env, altfel cea de mai jos.
 *
 * Versiune .js (nu .ts): imaginea de producție nu are pnpm/ts-node.
 *
 * Rulare - pe backendul de TEST (api-beta.shelfshare.ro, cel folosit de beta),
 * nu pe producție: conturile ar apărea altfel în clasamentul, harta și
 * statisticile userilor reali. Containerul de test montează ./backend, deci
 * scriptul e deja acolo după checkout, fără `docker cp`:
 *   docker compose -f docker-compose.test.yml --env-file .env.test \
 *     exec backend node prisma/seed-demo-accounts.js
 */
require('dotenv/config');
const { PrismaClient } = require('@prisma/client');
const { PrismaPg } = require('@prisma/adapter-pg');
const bcrypt = require('bcrypt');
const { seedFeed } = require('./seed-demo-feed');

const adapter = new PrismaPg({ connectionString: process.env.DATABASE_URL });
const prisma = new PrismaClient({ adapter });

const PASSWORD = process.env.DEMO_PASSWORD || 'pass123';
const CITY = 'Cluj-Napoca';

const MAIN = {
  email: 'toni@ss.com',
  name: 'Toni Muresan',
  username: 'oboseus',
  bio: 'Citesc seara, cu ceai. Fantasy, clasici și orice are o hartă la început.',
  profileImage: 'https://i.pravatar.cc/300?img=12',
  booksExchangedCount: 14,
  booksSharedCount: 9,
  booksReceivedCount: 5,
  xp: 1840,
  rating: 4.9,
};

const NEIGHBOURS = [
  { email: 'andrada@ss.com', name: 'Andrada', username: 'andrada', img: 45, exchanged: 22, xp: 2600, rating: 4.8 },
  { email: 'mina@ss.com', name: 'Mina', username: 'mina', img: 32, exchanged: 17, xp: 2100, rating: 5 },
  { email: 'matei@ss.com', name: 'Matei', username: 'matei', img: 15, exchanged: 9, xp: 1200, rating: 4.7 },
];

const ALL_EMAILS = [MAIN.email, ...NEIGHBOURS.map((n) => n.email)];

/** Conturile demo din versiunile anterioare ale scriptului - se șterg și ele. */
const LEGACY_EMAILS = [
  'demo@shelfshare.demo',
  'demo.andrei@shelfshare.demo',
  'demo.ioana@shelfshare.demo',
  'demo.radu@shelfshare.demo',
  'demo.elena@shelfshare.demo',
  'demo.mihai@shelfshare.demo',
];

const daysAgo = (d) => new Date(Date.now() - d * 24 * 60 * 60 * 1000);
const daysFromNow = (d) => new Date(Date.now() + d * 24 * 60 * 60 * 1000);

async function main() {
  // 1. Curățenie: conturile vechi de demo, cu tot ce le aparține (cascadă).
  const removed = await prisma.user.deleteMany({
    where: { email: { in: [...ALL_EMAILS, ...LEGACY_EMAILS] } },
  });
  console.log(`Conturi demo vechi șterse: ${removed.count}`);

  // Username-urile sunt unice: dacă un cont real (nu de demo) are deja unul
  // din ele, ne oprim cu un mesaj clar în loc de o eroare Prisma.
  const usernames = [MAIN.username, ...NEIGHBOURS.map((n) => n.username)];
  const taken = await prisma.user.findMany({
    where: { username: { in: usernames } },
    select: { username: true, email: true },
  });
  if (taken.length > 0) {
    throw new Error(
      `Username deja folosit de alt cont: ${taken.map((u) => `${u.username} (${u.email})`).join(', ')}`,
    );
  }

  // 2. Cărțile: cele mai populare din catalog, cu copertă.
  //
  // Contul lui Toni are nevoie de MAIN_BOOKS titluri distincte (raftul,
  // colecțiile și lista de dorințe nu acceptă aceeași carte de două ori),
  // plus câte una distinctă pentru fiecare potrivire de schimb. Vecinii pot
  // repeta titlurile lui - pe baza de test catalogul e mic (~40 de cărți).
  const MAIN_BOOKS = 27;
  const MATCHES = 3;
  const books = await prisma.book.findMany({
    where: {
      coverUrl: { not: null },
      // Silo e adăugată de scriptul ăsta doar pentru istoric (vezi 11b) - nu
      // trebuie să apară și ca anunț obișnuit al vreunui vecin.
      OR: [{ source: null }, { source: { not: 'demo-seed' } }],
    },
    orderBy: [{ popularityScore: { sort: 'desc', nulls: 'last' } }, { createdAt: 'asc' }],
    take: 80,
  });
  if (books.length < MAIN_BOOKS + MATCHES) {
    throw new Error(
      `Catalogul are doar ${books.length} cărți cu copertă - trebuie cel puțin ${MAIN_BOOKS + MATCHES}.`,
    );
  }
  // Fără număr de pagini, progresul lecturii n-ar avea din ce să se calculeze.
  const pagesOf = (book) => book.pageCount || 320;
  const take = (() => {
    let i = 0;
    return (n) => {
      const slice = books.slice(i, i + n);
      i += n;
      return slice;
    };
  })();
  // Vecinii încep după cărțile lui Toni și reiau catalogul de la capăt dacă se
  // termină - primele lor anunțuri (cele din potriviri) rămân distincte.
  const takeForNeighbour = (() => {
    let i = MAIN_BOOKS;
    return (n) => Array.from({ length: n }, () => books[i++ % books.length]);
  })();

  // 3. Conturile.
  const passwordHash = await bcrypt.hash(PASSWORD, 10);
  const baseUser = {
    password: passwordHash,
    isEmailVerified: true,
    city: CITY,
    readingSurveyCompletedAt: daysAgo(200),
    onboardingTodoDismissed: true,
    lastActiveAt: new Date(),
    lastSeenAt: new Date(),
    // Cronul de bun venit (welcome-email.service.ts) ar scrie altfel pe
    // adrese care nu sunt ale noastre.
    welcomeEmailSentAt: new Date(),
  };

  const toni = await prisma.user.create({
    data: {
      ...baseUser,
      email: MAIN.email,
      name: MAIN.name,
      username: MAIN.username,
      bio: MAIN.bio,
      profileImage: MAIN.profileImage,
      booksExchangedCount: MAIN.booksExchangedCount,
      booksSharedCount: MAIN.booksSharedCount,
      booksReceivedCount: MAIN.booksReceivedCount,
      xp: MAIN.xp,
      rating: MAIN.rating,
      avgCommunicationRating: 5,
      avgPunctualityRating: 4.8,
      avgConditionRating: 4.9,
      currentStreakDays: 12,
      longestStreakDays: 41,
      readingChallengeGoal: 30,
      favoriteGenres: ['Fantasy', 'Clasici', 'SF'],
      favoriteAuthors: ['J.R.R. Tolkien', 'Mihail Bulgakov'],
      createdAt: daysAgo(400),
    },
  });

  const neighbours = [];
  for (const n of NEIGHBOURS) {
    neighbours.push(
      await prisma.user.create({
        data: {
          ...baseUser,
          email: n.email,
          name: n.name,
          username: n.username,
          profileImage: `https://i.pravatar.cc/300?img=${n.img}`,
          booksExchangedCount: n.exchanged,
          booksSharedCount: Math.ceil(n.exchanged / 2),
          booksReceivedCount: Math.floor(n.exchanged / 2),
          xp: n.xp,
          rating: n.rating,
          avgCommunicationRating: n.rating,
          avgPunctualityRating: n.rating,
          avgConditionRating: n.rating,
          createdAt: daysAgo(300),
        },
      }),
    );
  }
  const [andrada, mina, matei] = neighbours;
  console.log(`Conturi create: ${1 + neighbours.length}`);

  const listing = (userId, book, extra = {}) =>
    prisma.userBook.create({
      data: {
        userId,
        bookId: book.id,
        condition: 'FOARTE_BUNA',
        availableForSwap: true,
        city: CITY,
        createdAt: daysAgo(Math.floor(Math.random() * 20) + 1),
        ...extra,
      },
    });

  // 4. Raftul lui Toni: anunțuri (schimb + vânzare).
  const toniListedBooks = take(8);
  const toniListings = [];
  for (const [i, book] of toniListedBooks.entries()) {
    toniListings.push(
      await listing(toni.id, book, {
        isForSale: i % 2 === 0,
        salePrice: i % 2 === 0 ? 25 + i * 5 : null,
        condition: i % 3 === 0 ? 'NOUA' : 'FOARTE_BUNA',
      }),
    );
  }

  // 5. Anunțurile vecinilor (toți în Cluj, deci „în apropiere").
  const neighbourListings = new Map();
  for (const n of neighbours) {
    const own = [];
    for (const book of takeForNeighbour(5)) own.push(await listing(n.id, book, { isForSale: Math.random() > 0.5, salePrice: 30 }));
    neighbourListings.set(n.id, own);
  }

  // 6. Potriviri de schimb: Toni vrea câte o carte de la 3 vecini, iar ei vor
  //    câte una de pe raftul lui.
  for (const [i, n] of [andrada, mina, matei].entries()) {
    const theirs = neighbourListings.get(n.id)[0];
    await prisma.wishlistItem.create({ data: { userId: toni.id, bookId: theirs.bookId, userBookId: theirs.id } });
    await prisma.wishlistItem.create({ data: { userId: n.id, bookId: toniListings[i].bookId } });
  }
  // Plus câteva dorințe fără potrivire, ca lista să nu fie doar de 3.
  for (const book of take(3)) {
    await prisma.wishlistItem.create({ data: { userId: toni.id, bookId: book.id, source: 'BOOK_MATCH' } });
  }

  // 7. Raftul de lectură, cu progres.
  const reading = take(3);
  const finished = take(6);
  const wantToRead = take(5);
  for (const [i, book] of reading.entries()) {
    await prisma.bookshelfEntry.create({ data: { userId: toni.id, bookId: book.id, status: 'READING' } });
    const total = pagesOf(book);
    await prisma.readingProgress.create({
      data: { userId: toni.id, bookId: book.id, currentPage: Math.round(total * [0.18, 0.52, 0.86][i]), totalPages: total },
    });
  }
  for (const [i, book] of finished.entries()) {
    await prisma.bookshelfEntry.create({
      data: { userId: toni.id, bookId: book.id, status: 'FINISHED', owned: i < 3, updatedAt: daysAgo(i * 9 + 2) },
    });
    await prisma.review.create({
      data: {
        userId: toni.id,
        bookId: book.id,
        rating: [5, 4, 5, 3, 5, 4][i],
        text: ['Nu am putut s-o las din mână.', 'Frumoasă, deși spre final se lungește.', 'O recitesc în fiecare an.', null, 'Cea mai bună carte citită anul ăsta.', null][i],
      },
    });
  }
  for (const book of wantToRead) {
    await prisma.bookshelfEntry.create({ data: { userId: toni.id, bookId: book.id, status: 'WANT_TO_READ' } });
  }
  // Vecinii citesc și ei - ca feedul să aibă „a terminat de citit".
  for (const [i, n] of neighbours.entries()) {
    const book = finished[i % finished.length];
    await prisma.bookshelfEntry.create({ data: { userId: n.id, bookId: book.id, status: 'FINISHED', updatedAt: daysAgo(i + 1) } });
    const current = reading[i % reading.length];
    await prisma.bookshelfEntry.create({ data: { userId: n.id, bookId: current.id, status: 'READING' } });
    await prisma.readingProgress.create({
      data: { userId: n.id, bookId: current.id, currentPage: Math.round(pagesOf(current) * 0.4), totalPages: pagesOf(current), updatedAt: daysAgo(i) },
    });
  }

  // 8. Colecții.
  const collections = [
    { name: 'De citit vara asta', description: 'Pentru concediu și serile lungi.', books: wantToRead },
    { name: 'Preferatele mele', description: 'Cărțile pe care le recomand oricui.', books: finished.slice(0, 5) },
    { name: 'De dat mai departe', description: 'Le-am citit, merită alt cititor.', books: toniListedBooks.slice(0, 4) },
  ];
  for (const c of collections) {
    await prisma.collection.create({
      data: {
        userId: toni.id,
        name: c.name,
        description: c.description,
        isPublic: true,
        items: { create: c.books.map((b) => ({ bookId: b.id })) },
      },
    });
  }

  // 9. Urmăriri (feed) și urmăritori.
  for (const n of neighbours) {
    await prisma.follow.create({ data: { followerId: toni.id, followingId: n.id } });
  }
  for (const n of [andrada, mina]) {
    await prisma.follow.create({ data: { followerId: n.id, followingId: toni.id } });
  }

  // 10. Grupuri.
  const club = await prisma.group.create({
    data: {
      name: 'Clubul de lectură Cluj',
      description: 'Ne vedem o dată pe lună la o cafenea din centru și discutăm cartea lunii.',
      creatorId: toni.id,
      isPublic: true,
      createdAt: daysAgo(120),
      members: {
        create: [
          { userId: toni.id, role: 'ADMIN' },
          ...neighbours.map((n) => ({ userId: n.id, role: 'MEMBER' })),
        ],
      },
      posts: {
        create: [
          { authorId: toni.id, content: 'Cartea lunii octombrie e aleasă! Ne vedem pe 18 la Joben.', createdAt: daysAgo(3) },
          { authorId: mina.id, content: 'Am terminat-o aseară - finalul m-a dat peste cap. Abia aștept discuția!', createdAt: daysAgo(2) },
          { authorId: andrada.id, content: 'Aduce cineva un exemplar în plus? Aș vrea să i-l dau colegului meu.', createdAt: daysAgo(1) },
        ],
      },
      events: {
        create: [
          { title: 'Întâlnirea lunară', description: 'Discutăm cartea lunii.', eventAt: daysFromNow(9), location: 'Joben Bistro, Cluj-Napoca' },
        ],
      },
    },
  });
  await prisma.group.create({
    data: {
      name: 'Fantasy & SF România',
      description: 'Recomandări, serii noi și schimburi între fanii genului.',
      creatorId: andrada.id,
      isPublic: true,
      createdAt: daysAgo(200),
      members: {
        create: [
          { userId: andrada.id, role: 'ADMIN' },
          { userId: toni.id, role: 'MEMBER' },
          { userId: matei.id, role: 'MEMBER' },
        ],
      },
      posts: {
        create: [
          { authorId: andrada.id, content: 'Ce serie fantasy ați recomanda cuiva care n-a citit niciodată genul?', createdAt: daysAgo(4) },
          { authorId: toni.id, content: 'Stăpânul Inelelor, fără discuție. Și dacă îi place, Earthsea.', createdAt: daysAgo(4) },
        ],
      },
    },
  });
  console.log(`Grupuri create (principal: ${club.name})`);

  // 11. Istoria unei cărți: Matei -> Mina -> Toni (lanț de re-listări).
  const historyBook = take(1)[0];
  const h1 = await listing(matei.id, historyBook, { permanentlyTransferred: true, deletedAt: daysAgo(300), createdAt: daysAgo(420), city: 'Brașov' });
  const h2 = await listing(mina.id, historyBook, { permanentlyTransferred: true, deletedAt: daysAgo(90), createdAt: daysAgo(290), city: 'Sibiu', previousListingId: h1.id });
  const h3 = await listing(toni.id, historyBook, { createdAt: daysAgo(80), previousListingId: h2.id });
  const completedExchange = async (requesterId, ownerId, requestedBookId, at) =>
    prisma.exchangeRequest.create({
      data: {
        requesterId,
        ownerId,
        requestedBookId,
        status: 'COMPLETED',
        createdAt: daysAgo(at + 5),
        acceptedAt: daysAgo(at + 3),
        meetingTime: daysAgo(at),
        meetingLocation: 'Piața Unirii',
        meetingAcceptedAt: daysAgo(at + 2),
        requesterDoneAt: daysAgo(at),
        ownerDoneAt: daysAgo(at),
        // Istoricul cărții afișează `updatedAt` ca dată a transferului.
        updatedAt: daysAgo(at),
        requesterRatingForOwner: 5,
        ownerRatingForRequester: 5,
        requesterReviewForOwner: 'Cartea exact ca în descriere, predare rapidă. Mulțumesc!',
        ownerReviewForRequester: 'Punctual și foarte de treabă. Recomand!',
        requesterCommunicationForOwner: 5,
        requesterPunctualityForOwner: 5,
        requesterConditionForOwner: 5,
        ownerCommunicationForRequester: 5,
        ownerPunctualityForRequester: 5,
        ownerConditionForRequester: 5,
      },
    });
  await completedExchange(mina.id, matei.id, h1.id, 300);
  await completedExchange(toni.id, mina.id, h2.id, 90);
  console.log(`Istoric creat pentru „${historyBook.title}" (${h3.id})`);

  // 11b. Silo (Hugh Howey) - exemplarul cu cel mai lung istoric: trei foști
  //      proprietari, din trei orașe, cu un schimb, o vânzare și încă un schimb.
  //      Matei (Brașov) -> Andrada (Sibiu) -> Mina (Cluj) -> Toni.
  let silo = await prisma.book.findFirst({
    where: { title: { equals: 'Silo', mode: 'insensitive' }, author: { contains: 'Howey', mode: 'insensitive' } },
  });
  if (!silo) {
    silo = await prisma.book.create({
      data: {
        title: 'Silo',
        author: 'Hugh Howey',
        coverUrl: 'https://covers.openlibrary.org/b/id/11297214-L.jpg',
        publishedYear: 2011,
        pageCount: 560,
        genre: 'Science-fiction',
        description:
          'Într-o lume ruinată și toxică, o comunitate trăiește într-un siloz uriaș, adânc în pământ. Cine cere să iasă afară primește exact ce și-a dorit - și nimeni nu se mai întoarce.',
        source: 'demo-seed',
      },
    });
  }
  const s1 = await listing(matei.id, silo, {
    permanentlyTransferred: true, deletedAt: daysAgo(600), createdAt: daysAgo(720), city: 'Brașov',
  });
  const s2 = await listing(andrada.id, silo, {
    permanentlyTransferred: true, deletedAt: daysAgo(400), createdAt: daysAgo(590), city: 'Sibiu', previousListingId: s1.id,
  });
  const s3 = await listing(mina.id, silo, {
    permanentlyTransferred: true, deletedAt: daysAgo(60), createdAt: daysAgo(390), condition: 'BUNA', previousListingId: s2.id,
  });
  const s4 = await listing(toni.id, silo, { createdAt: daysAgo(50), condition: 'BUNA', previousListingId: s3.id });
  await completedExchange(andrada.id, matei.id, s1.id, 600);
  // Andrada -> Mina e o vânzare: istoricul o recunoaște după oferta ACCEPTED.
  await prisma.priceOffer.create({
    data: {
      buyerId: mina.id,
      ownerId: andrada.id,
      userBookId: s2.id,
      amount: 35,
      status: 'ACCEPTED',
      acceptedAt: daysAgo(402),
      buyerDoneAt: daysAgo(400),
      ownerDoneAt: daysAgo(400),
      createdAt: daysAgo(405),
      updatedAt: daysAgo(400),
    },
  });
  await completedExchange(toni.id, mina.id, s3.id, 60);
  console.log(`Istoric creat pentru „Silo" (${s4.id}) - 3 foști proprietari`);

  // 12. Sistemul de schimb: toate stările, cu chat.
  const conversation = async (a, b) => {
    const [userAId, userBId] = [a.id, b.id].sort();
    return prisma.conversation.create({ data: { userAId, userBId } });
  };

  // a) Schimb acceptat, cu întâlnire stabilită și telefoane partajate.
  const andradaBook = neighbourListings.get(andrada.id)[1];
  const accepted = await prisma.exchangeRequest.create({
    data: {
      requesterId: toni.id,
      ownerId: andrada.id,
      requestedBookId: andradaBook.id,
      offeredBookId: toniListings[3].id,
      status: 'ACCEPTED',
      message: 'Salut! Ți-aș da la schimb cartea mea, e ca nouă.',
      createdAt: daysAgo(3),
      acceptedAt: daysAgo(2),
      meetingTime: daysFromNow(2),
      meetingLocation: 'Iulius Mall, intrarea principală',
      meetingProposedBy: andrada.id,
      meetingAcceptedAt: daysAgo(1),
      requesterContactPhone: '+40 744 123 456',
      ownerContactPhone: '+40 755 987 654',
      requesterContactSharedAt: daysAgo(1),
      ownerContactSharedAt: daysAgo(1),
      requesterSafetyAckAt: daysAgo(1),
      ownerSafetyAckAt: daysAgo(1),
    },
  });
  await prisma.userBook.updateMany({
    where: { id: { in: [andradaBook.id, toniListings[3].id] } },
    data: { reservedForExchangeId: accepted.id },
  });
  const convAndrada = await conversation(toni, andrada);
  await prisma.message.createMany({
    data: [
      { conversationId: convAndrada.id, senderId: toni.id, exchangeRequestId: accepted.id, content: 'Salut! Ți-aș da la schimb cartea mea, e ca nouă.', createdAt: daysAgo(3), isRead: true },
      { conversationId: convAndrada.id, senderId: andrada.id, content: 'Sună bine, accept! Când ți-ar veni bine?', createdAt: daysAgo(2), isRead: true },
      { conversationId: convAndrada.id, senderId: andrada.id, content: 'Propun joi la 18:00, la Iulius Mall.', meetingAt: daysFromNow(2), location: 'Iulius Mall, intrarea principală', createdAt: daysAgo(2), isRead: true },
      { conversationId: convAndrada.id, senderId: toni.id, content: 'Perfect, ne vedem acolo!', createdAt: daysAgo(1), isRead: true },
      { conversationId: convAndrada.id, senderId: andrada.id, content: 'Ți-am lăsat și numărul, în caz că întârzii.', createdAt: daysAgo(1), isRead: false },
    ],
  });

  // b) Cerere primită, în așteptare.
  const pending = await prisma.exchangeRequest.create({
    data: {
      requesterId: mina.id,
      ownerId: toni.id,
      requestedBookId: toniListings[1].id,
      offeredBookId: neighbourListings.get(mina.id)[1].id,
      status: 'PENDING',
      message: 'Bună! Te-ar interesa un schimb? Am și eu câteva care ți-ar plăcea.',
      expiresAt: daysFromNow(5),
      createdAt: daysAgo(1),
    },
  });
  const convMina = await conversation(toni, mina);
  await prisma.message.create({
    data: { conversationId: convMina.id, senderId: mina.id, exchangeRequestId: pending.id, content: pending.message, createdAt: daysAgo(1) },
  });

  // c) Ofertă de preț în așteptare, cu negociere.
  const offer = await prisma.priceOffer.create({
    data: {
      buyerId: matei.id,
      ownerId: toni.id,
      userBookId: toniListings[0].id,
      amount: 20,
      message: 'Ai lua 20 de lei pe ea? Pot veni s-o iau mâine.',
      status: 'PENDING',
      expiresAt: daysFromNow(3),
      createdAt: daysAgo(0.2),
    },
  });
  const convMatei = await conversation(toni, matei);
  await prisma.message.create({
    data: { conversationId: convMatei.id, senderId: matei.id, priceOfferId: offer.id, content: offer.message, createdAt: daysAgo(0.2) },
  });

  // d) Încă un schimb finalizat, cu recenzii (pe profilul lui Toni).
  await completedExchange(mina.id, toni.id, (await listing(toni.id, take(1)[0], { permanentlyTransferred: true, deletedAt: daysAgo(30) })).id, 30);

  // 13. Notificări, ca clopoțelul să nu fie gol.
  await prisma.notification.createMany({
    data: [
      { userId: toni.id, type: 'EXCHANGE_REQUEST_RECEIVED', message: 'Mina vrea să facă un schimb cu tine.', createdAt: daysAgo(1) },
      { userId: toni.id, type: 'PRICE_OFFER_RECEIVED', message: 'Matei ți-a făcut o ofertă de 20 lei.', createdAt: daysAgo(0.2) },
      { userId: toni.id, type: 'EXCHANGE_MEETING_ACCEPTED', message: 'Andrada a confirmat întâlnirea de joi.', createdAt: daysAgo(1), isRead: true },
      { userId: toni.id, type: 'WISHLIST_BOOK_AVAILABLE', message: 'O carte de pe lista ta de dorințe e disponibilă în Cluj-Napoca.', createdAt: daysAgo(2) },
      { userId: toni.id, type: 'GROUP_POST', message: 'Postare nouă în Clubul de lectură Cluj.', createdAt: daysAgo(1), isRead: true },
    ],
  });

  // 14. Activitate din ultimele zile în feed (schimburi, cărți noi, progres).
  await seedFeed(prisma);

  console.log('\nGata. Conturi de demo:');
  for (const email of ALL_EMAILS) console.log(`  ${email}`);
  console.log(`Parola: ${process.env.DEMO_PASSWORD ? '(din DEMO_PASSWORD)' : PASSWORD}`);
  console.log(`Contul pentru capturi: ${MAIN.email}`);
}

main()
  .catch((error) => {
    console.error(error);
    process.exitCode = 1;
  })
  .finally(() => prisma.$disconnect());
