/**
 * Conturi de demo pentru capturile de ecran din secțiunea „Ce poți face în
 * ShelfShare" de pe pagina vizitatorilor (web/src/features/public/
 * LandingFeatures.tsx, butoanele „See Demo").
 *
 * Creează un cont principal (Maria) și 5 vecini de raft, cu TOATE funcțiile
 * populate, ca fiecare ecran să aibă ce arăta:
 *
 *   1. Collections       - 3 colecții cu câte 4-6 cărți
 *   2. Smart matches     - vecinii au cărți de pe lista Mariei și vor cărți
 *                          de pe raftul ei (reciproc, deci apar potriviri)
 *   3. Nearby books      - vecinii sunt în același oraș (Cluj-Napoca)
 *   4. Groups            - 2 grupuri cu membri, postări și un eveniment
 *   5. Leaderboard       - contoare de schimburi, XP și rating
 *   6. Global statistics - vin din anunțurile/schimburile de mai sus
 *   7. Book history      - o carte trecută prin 3 mâini (lanț previousListingId)
 *   8. My shelf          - citite / în curs (cu progres pe pagini) / de citit
 *   9. Trade system      - schimb finalizat cu recenzii, schimb acceptat cu
 *                          întâlnire și telefoane partajate, cerere în așteptare,
 *                          ofertă de preț, toate cu mesaje în chat
 *  10. Feed              - Maria îi urmărește pe vecini, care au activitate
 *
 * Idempotent: la fiecare rulare ȘTERGE conturile de demo de mai jos (cascadă
 * pe tot ce le aparține) și le recreează. Nu atinge niciun alt cont. Cărțile
 * se iau din catalogul existent (cele cu copertă, cele mai populare întâi),
 * deci nu se adaugă nimic în `books`.
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

const adapter = new PrismaPg({ connectionString: process.env.DATABASE_URL });
const prisma = new PrismaClient({ adapter });

const PASSWORD = process.env.DEMO_PASSWORD || 'ShelfDemo2026!';
const CITY = 'Cluj-Napoca';

const MAIN = {
  email: 'demo@shelfshare.demo',
  name: 'Maria Ionescu',
  username: 'maria.citeste',
  bio: 'Citesc seara, cu ceai. Fantasy, clasici și orice are o hartă la început.',
  profileImage: 'https://i.pravatar.cc/300?img=47',
  booksExchangedCount: 14,
  booksSharedCount: 9,
  booksReceivedCount: 5,
  xp: 1840,
  rating: 4.9,
};

const NEIGHBOURS = [
  { email: 'demo.andrei@shelfshare.demo', name: 'Andrei Pop', username: 'andrei.pop', img: 12, exchanged: 22, xp: 2600, rating: 4.8 },
  { email: 'demo.ioana@shelfshare.demo', name: 'Ioana Mureșan', username: 'ioana.m', img: 45, exchanged: 17, xp: 2100, rating: 5 },
  { email: 'demo.radu@shelfshare.demo', name: 'Radu Stan', username: 'radu.stan', img: 15, exchanged: 9, xp: 1200, rating: 4.7 },
  { email: 'demo.elena@shelfshare.demo', name: 'Elena Dragomir', username: 'elena.reads', img: 32, exchanged: 6, xp: 900, rating: 4.9 },
  { email: 'demo.mihai@shelfshare.demo', name: 'Mihai Rusu', username: 'mihai.rusu', img: 53, exchanged: 3, xp: 450, rating: 4.6 },
];

const ALL_EMAILS = [MAIN.email, ...NEIGHBOURS.map((n) => n.email)];

const daysAgo = (d) => new Date(Date.now() - d * 24 * 60 * 60 * 1000);
const daysFromNow = (d) => new Date(Date.now() + d * 24 * 60 * 60 * 1000);

async function main() {
  // 1. Curățenie: conturile vechi de demo, cu tot ce le aparține (cascadă).
  const removed = await prisma.user.deleteMany({ where: { email: { in: ALL_EMAILS } } });
  console.log(`Conturi demo vechi șterse: ${removed.count}`);

  // 2. Cărțile: cele mai populare din catalog, cu copertă și număr de pagini.
  const books = await prisma.book.findMany({
    where: { coverUrl: { not: null }, pageCount: { gt: 0 } },
    orderBy: [{ popularityScore: { sort: 'desc', nulls: 'last' } }, { createdAt: 'asc' }],
    take: 70,
  });
  if (books.length < 55) {
    throw new Error(`Catalogul are doar ${books.length} cărți cu copertă - trebuie cel puțin 55.`);
  }
  const take = (() => {
    let i = 0;
    return (n) => {
      const slice = books.slice(i, i + n);
      i += n;
      return slice;
    };
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
  };

  const maria = await prisma.user.create({
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
  const [andrei, ioana, radu, elena, mihai] = neighbours;
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

  // 4. Raftul Mariei: anunțuri (schimb + vânzare).
  const mariaListedBooks = take(8);
  const mariaListings = [];
  for (const [i, book] of mariaListedBooks.entries()) {
    mariaListings.push(
      await listing(maria.id, book, {
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
    for (const book of take(5)) own.push(await listing(n.id, book, { isForSale: Math.random() > 0.5, salePrice: 30 }));
    neighbourListings.set(n.id, own);
  }

  // 6. Potriviri de schimb: Maria vrea câte o carte de la 3 vecini, iar ei vor
  //    câte una de pe raftul ei.
  for (const [i, n] of [andrei, ioana, radu].entries()) {
    const theirs = neighbourListings.get(n.id)[0];
    await prisma.wishlistItem.create({ data: { userId: maria.id, bookId: theirs.bookId, userBookId: theirs.id } });
    await prisma.wishlistItem.create({ data: { userId: n.id, bookId: mariaListings[i].bookId } });
  }
  // Plus câteva dorințe fără potrivire, ca lista să nu fie doar de 3.
  for (const book of take(3)) {
    await prisma.wishlistItem.create({ data: { userId: maria.id, bookId: book.id, source: 'BOOK_MATCH' } });
  }

  // 7. Raftul de lectură, cu progres.
  const reading = take(3);
  const finished = take(6);
  const wantToRead = take(5);
  for (const [i, book] of reading.entries()) {
    await prisma.bookshelfEntry.create({ data: { userId: maria.id, bookId: book.id, status: 'READING' } });
    const total = book.pageCount;
    await prisma.readingProgress.create({
      data: { userId: maria.id, bookId: book.id, currentPage: Math.round(total * [0.18, 0.52, 0.86][i]), totalPages: total },
    });
  }
  for (const [i, book] of finished.entries()) {
    await prisma.bookshelfEntry.create({
      data: { userId: maria.id, bookId: book.id, status: 'FINISHED', owned: i < 3, updatedAt: daysAgo(i * 9 + 2) },
    });
    await prisma.review.create({
      data: {
        userId: maria.id,
        bookId: book.id,
        rating: [5, 4, 5, 3, 5, 4][i],
        text: ['Nu am putut s-o las din mână.', 'Frumoasă, deși spre final se lungește.', 'O recitesc în fiecare an.', null, 'Cea mai bună carte citită anul ăsta.', null][i],
      },
    });
  }
  for (const book of wantToRead) {
    await prisma.bookshelfEntry.create({ data: { userId: maria.id, bookId: book.id, status: 'WANT_TO_READ' } });
  }
  // Vecinii citesc și ei - ca feedul să aibă „a terminat de citit".
  for (const [i, n] of neighbours.entries()) {
    const book = finished[i % finished.length];
    await prisma.bookshelfEntry.create({ data: { userId: n.id, bookId: book.id, status: 'FINISHED', updatedAt: daysAgo(i + 1) } });
    const current = reading[i % reading.length];
    await prisma.bookshelfEntry.create({ data: { userId: n.id, bookId: current.id, status: 'READING' } });
    await prisma.readingProgress.create({
      data: { userId: n.id, bookId: current.id, currentPage: Math.round(current.pageCount * 0.4), totalPages: current.pageCount, updatedAt: daysAgo(i) },
    });
  }

  // 8. Colecții.
  const collections = [
    { name: 'De citit vara asta', description: 'Pentru concediu și serile lungi.', books: wantToRead },
    { name: 'Preferatele mele', description: 'Cărțile pe care le recomand oricui.', books: finished.slice(0, 5) },
    { name: 'De dat mai departe', description: 'Le-am citit, merită alt cititor.', books: mariaListedBooks.slice(0, 4) },
  ];
  for (const c of collections) {
    await prisma.collection.create({
      data: {
        userId: maria.id,
        name: c.name,
        description: c.description,
        isPublic: true,
        items: { create: c.books.map((b) => ({ bookId: b.id })) },
      },
    });
  }

  // 9. Urmăriri (feed) și urmăritori.
  for (const n of neighbours) {
    await prisma.follow.create({ data: { followerId: maria.id, followingId: n.id } });
  }
  for (const n of [andrei, ioana, elena]) {
    await prisma.follow.create({ data: { followerId: n.id, followingId: maria.id } });
  }

  // 10. Grupuri.
  const club = await prisma.group.create({
    data: {
      name: 'Clubul de lectură Cluj',
      description: 'Ne vedem o dată pe lună la o cafenea din centru și discutăm cartea lunii.',
      creatorId: maria.id,
      isPublic: true,
      createdAt: daysAgo(120),
      members: {
        create: [
          { userId: maria.id, role: 'ADMIN' },
          ...neighbours.map((n) => ({ userId: n.id, role: 'MEMBER' })),
        ],
      },
      posts: {
        create: [
          { authorId: maria.id, content: 'Cartea lunii octombrie e aleasă! Ne vedem pe 18 la Joben.', createdAt: daysAgo(3) },
          { authorId: ioana.id, content: 'Am terminat-o aseară - finalul m-a dat peste cap. Abia aștept discuția!', createdAt: daysAgo(2) },
          { authorId: andrei.id, content: 'Aduce cineva un exemplar în plus? Aș vrea să i-l dau colegului meu.', createdAt: daysAgo(1) },
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
      creatorId: andrei.id,
      isPublic: true,
      createdAt: daysAgo(200),
      members: {
        create: [
          { userId: andrei.id, role: 'ADMIN' },
          { userId: maria.id, role: 'MEMBER' },
          { userId: radu.id, role: 'MEMBER' },
        ],
      },
      posts: {
        create: [
          { authorId: andrei.id, content: 'Ce serie fantasy ați recomanda cuiva care n-a citit niciodată genul?', createdAt: daysAgo(4) },
          { authorId: maria.id, content: 'Stăpânul Inelelor, fără discuție. Și dacă îi place, Earthsea.', createdAt: daysAgo(4) },
        ],
      },
    },
  });
  console.log(`Grupuri create (principal: ${club.name})`);

  // 11. Istoria unei cărți: Mihai -> Elena -> Maria (lanț de re-listări).
  const historyBook = take(1)[0];
  const h1 = await listing(mihai.id, historyBook, { permanentlyTransferred: true, deletedAt: daysAgo(300), createdAt: daysAgo(420), city: 'Brașov' });
  const h2 = await listing(elena.id, historyBook, { permanentlyTransferred: true, deletedAt: daysAgo(90), createdAt: daysAgo(290), city: 'Sibiu', previousListingId: h1.id });
  const h3 = await listing(maria.id, historyBook, { createdAt: daysAgo(80), previousListingId: h2.id });
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
  await completedExchange(elena.id, mihai.id, h1.id, 300);
  await completedExchange(maria.id, elena.id, h2.id, 90);
  console.log(`Istoric creat pentru „${historyBook.title}" (${h3.id})`);

  // 12. Sistemul de schimb: toate stările, cu chat.
  const conversation = async (a, b) => {
    const [userAId, userBId] = [a.id, b.id].sort();
    return prisma.conversation.create({ data: { userAId, userBId } });
  };

  // a) Schimb acceptat, cu întâlnire stabilită și telefoane partajate.
  const andreiBook = neighbourListings.get(andrei.id)[1];
  const accepted = await prisma.exchangeRequest.create({
    data: {
      requesterId: maria.id,
      ownerId: andrei.id,
      requestedBookId: andreiBook.id,
      offeredBookId: mariaListings[3].id,
      status: 'ACCEPTED',
      message: 'Salut! Ți-aș da la schimb cartea mea, e ca nouă.',
      createdAt: daysAgo(3),
      acceptedAt: daysAgo(2),
      meetingTime: daysFromNow(2),
      meetingLocation: 'Iulius Mall, intrarea principală',
      meetingProposedBy: andrei.id,
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
    where: { id: { in: [andreiBook.id, mariaListings[3].id] } },
    data: { reservedForExchangeId: accepted.id },
  });
  const convAndrei = await conversation(maria, andrei);
  await prisma.message.createMany({
    data: [
      { conversationId: convAndrei.id, senderId: maria.id, exchangeRequestId: accepted.id, content: 'Salut! Ți-aș da la schimb cartea mea, e ca nouă.', createdAt: daysAgo(3), isRead: true },
      { conversationId: convAndrei.id, senderId: andrei.id, content: 'Sună bine, accept! Când ți-ar veni bine?', createdAt: daysAgo(2), isRead: true },
      { conversationId: convAndrei.id, senderId: andrei.id, content: 'Propun joi la 18:00, la Iulius Mall.', meetingAt: daysFromNow(2), location: 'Iulius Mall, intrarea principală', createdAt: daysAgo(2), isRead: true },
      { conversationId: convAndrei.id, senderId: maria.id, content: 'Perfect, ne vedem acolo!', createdAt: daysAgo(1), isRead: true },
      { conversationId: convAndrei.id, senderId: andrei.id, content: 'Ți-am lăsat și numărul, în caz că întârzii.', createdAt: daysAgo(1), isRead: false },
    ],
  });

  // b) Cerere primită, în așteptare.
  const pending = await prisma.exchangeRequest.create({
    data: {
      requesterId: ioana.id,
      ownerId: maria.id,
      requestedBookId: mariaListings[1].id,
      offeredBookId: neighbourListings.get(ioana.id)[1].id,
      status: 'PENDING',
      message: 'Bună! Te-ar interesa un schimb? Am și eu câteva care ți-ar plăcea.',
      expiresAt: daysFromNow(5),
      createdAt: daysAgo(1),
    },
  });
  const convIoana = await conversation(maria, ioana);
  await prisma.message.create({
    data: { conversationId: convIoana.id, senderId: ioana.id, exchangeRequestId: pending.id, content: pending.message, createdAt: daysAgo(1) },
  });

  // c) Ofertă de preț în așteptare, cu negociere.
  const offer = await prisma.priceOffer.create({
    data: {
      buyerId: radu.id,
      ownerId: maria.id,
      userBookId: mariaListings[0].id,
      amount: 20,
      message: 'Ai lua 20 de lei pe ea? Pot veni s-o iau mâine.',
      status: 'PENDING',
      expiresAt: daysFromNow(3),
      createdAt: daysAgo(0.2),
    },
  });
  const convRadu = await conversation(maria, radu);
  await prisma.message.create({
    data: { conversationId: convRadu.id, senderId: radu.id, priceOfferId: offer.id, content: offer.message, createdAt: daysAgo(0.2) },
  });

  // d) Încă un schimb finalizat, cu recenzii (pe profilul Mariei).
  await completedExchange(elena.id, maria.id, (await listing(maria.id, take(1)[0], { permanentlyTransferred: true, deletedAt: daysAgo(30) })).id, 30);

  // 13. Notificări, ca clopoțelul să nu fie gol.
  await prisma.notification.createMany({
    data: [
      { userId: maria.id, type: 'EXCHANGE_REQUEST_RECEIVED', message: 'Ioana Mureșan vrea să facă un schimb cu tine.', createdAt: daysAgo(1) },
      { userId: maria.id, type: 'PRICE_OFFER_RECEIVED', message: 'Radu Stan ți-a făcut o ofertă de 20 lei.', createdAt: daysAgo(0.2) },
      { userId: maria.id, type: 'EXCHANGE_MEETING_ACCEPTED', message: 'Andrei Pop a confirmat întâlnirea de joi.', createdAt: daysAgo(1), isRead: true },
      { userId: maria.id, type: 'WISHLIST_BOOK_AVAILABLE', message: 'O carte de pe lista ta de dorințe e disponibilă în Cluj-Napoca.', createdAt: daysAgo(2) },
      { userId: maria.id, type: 'GROUP_POST', message: 'Postare nouă în Clubul de lectură Cluj.', createdAt: daysAgo(1), isRead: true },
    ],
  });

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
