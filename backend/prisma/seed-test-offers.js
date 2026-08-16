/**
 * Creează 5 oferte/cereri de schimb (PriceOffer / ExchangeRequest) între
 * contul de admin (isAdmin: true) și 5 useri de test diferiți din setul
 * generat de seed-40-test-users.js (@shelfshare.test), pe cărți/categorii
 * diferite - ca fluxul de schimb complet (accept/refuz/contra-ofertă/
 * finalizare) să poată fi testat manual, de pe telefon, logat ca admin.
 *
 * NU creează useri sau anunțuri noi - referă doar UserBook-uri deja
 * existente (create de seed-40-test-users.js). Dacă adminul are și el
 * anunțuri proprii, o parte din cele 5 vor avea adminul ca owner
 * (test user -> admin), ca să poți testa și partea de "am primit o cerere".
 * Altfel toate 5 pleacă de la admin către useri de test (admin -> user).
 *
 * Fiecare mesaj din chat generat de flow-ul real (offers.service.ts /
 * exchanges.service.ts) e replicat aici direct prin Prisma, ca oferta să
 * apară și în conversație, exact ca la un request real din aplicație.
 *
 * Idempotent: la a doua rulare, verifică dacă există deja o ofertă/cerere
 * PENDING între aceiași doi useri pentru același UserBook și o sare, nu
 * duplică (vezi console.log "există deja").
 *
 * Rulează în interiorul containerului backend (DATABASE_URL rezolvă
 * "postgres" ca host doar acolo):
 *   docker compose -f docker-compose.prod.yml exec backend \
 *     node prisma/seed-test-offers.js
 */
require('dotenv/config');
const { PrismaClient } = require('@prisma/client');
const { PrismaPg } = require('@prisma/adapter-pg');

const adapter = new PrismaPg({ connectionString: process.env.DATABASE_URL });
const prisma = new PrismaClient({ adapter });

const EMAIL_DOMAIN = 'shelfshare.test';
const OFFER_EXPIRY_DAYS = 7;
const RECORD_COUNT = 5;

function expiresAt() {
  return new Date(Date.now() + OFFER_EXPIRY_DAYS * 86_400_000);
}

async function findOrCreateConversation(userAId, userBId) {
  const [a, b] = [userAId, userBId].sort();
  const existing = await prisma.conversation.findUnique({
    where: { userAId_userBId: { userAId: a, userBId: b } },
  });
  return existing ?? prisma.conversation.create({ data: { userAId: a, userBId: b } });
}

async function postMessage(conversationId, senderId, content, ids) {
  await prisma.message.create({
    data: { conversationId, senderId, content, ...ids },
  });
  await prisma.conversation.update({
    where: { id: conversationId },
    data: { updatedAt: new Date() },
  });
}

/** Creează o ofertă de preț admin<->user pentru un UserBook de vânzare,
 * negociabil. `buyer`/`owner` sunt useri (obiecte User), `userBook` are
 * .book inclus. Sare dacă există deja o ofertă PENDING pt aceeași pereche. */
async function ensurePriceOffer(buyer, owner, userBook) {
  const existing = await prisma.priceOffer.findFirst({
    where: { buyerId: buyer.id, ownerId: owner.id, userBookId: userBook.id, status: 'PENDING' },
  });
  if (existing) {
    console.log(`  există deja: PriceOffer ${buyer.email} -> ${owner.email} ("${userBook.book.title}")`);
    return false;
  }

  const amount = userBook.salePrice
    ? Math.max(1, Math.round(Number(userBook.salePrice) * 0.85))
    : 20;

  const offer = await prisma.priceOffer.create({
    data: {
      buyerId: buyer.id,
      ownerId: owner.id,
      userBookId: userBook.id,
      amount,
      message: 'Ofertă de test (seed-test-offers.js) - salut, ești de acord cu acest preț?',
      expiresAt: expiresAt(),
    },
  });

  const conversation = await findOrCreateConversation(buyer.id, owner.id);
  await postMessage(
    conversation.id,
    buyer.id,
    `Ofertă: ${amount} lei pentru "${userBook.book.title}"`,
    { priceOfferId: offer.id },
  );

  console.log(`  creat: PriceOffer ${buyer.email} -> ${owner.email} (${amount} lei, "${userBook.book.title}")`);
  return true;
}

/** Creează o cerere de schimb admin<->user (fără carte oferită în schimb,
 * doar cerere simplă) pentru un UserBook disponibil la swap. */
async function ensureExchangeRequest(requester, owner, requestedBook) {
  const existing = await prisma.exchangeRequest.findFirst({
    where: {
      requesterId: requester.id,
      ownerId: owner.id,
      requestedBookId: requestedBook.id,
      status: 'PENDING',
    },
  });
  if (existing) {
    console.log(`  există deja: ExchangeRequest ${requester.email} -> ${owner.email} ("${requestedBook.book.title}")`);
    return false;
  }

  const request = await prisma.exchangeRequest.create({
    data: {
      requesterId: requester.id,
      ownerId: owner.id,
      requestedBookId: requestedBook.id,
      message: 'Cerere de schimb de test (seed-test-offers.js) - te-ar interesa?',
      expiresAt: expiresAt(),
    },
  });

  const conversation = await findOrCreateConversation(requester.id, owner.id);
  await postMessage(
    conversation.id,
    requester.id,
    `Cerere de schimb pentru „${requestedBook.book.title}"`,
    { exchangeRequestId: request.id },
  );

  console.log(`  creat: ExchangeRequest ${requester.email} -> ${owner.email} ("${requestedBook.book.title}")`);
  return true;
}

async function main() {
  const admin = await prisma.user.findFirst({ where: { isAdmin: true } });
  if (!admin) {
    throw new Error('Niciun cont cu isAdmin: true găsit - rulează întâi setup-ul de admin.');
  }
  console.log(`Admin folosit: ${admin.email}`);

  // Anunțuri de vânzare (negociabile) ale userilor de test - pt PriceOffer.
  const saleListings = await prisma.userBook.findMany({
    where: {
      user: { email: { endsWith: `@${EMAIL_DOMAIN}` } },
      isForSale: true,
      isNegotiable: true,
      isAuction: false,
    },
    include: { book: true, user: true },
    orderBy: { createdAt: 'asc' },
  });

  // Anunțuri de swap ale userilor de test - pt ExchangeRequest.
  const swapListings = await prisma.userBook.findMany({
    where: {
      user: { email: { endsWith: `@${EMAIL_DOMAIN}` } },
      availableForSwap: true,
      isForSale: false,
      isAuction: false,
    },
    include: { book: true, user: true },
    orderBy: { createdAt: 'asc' },
  });

  if (saleListings.length === 0 && swapListings.length === 0) {
    throw new Error('Niciun anunț de test găsit - rulează întâi seed-40-test-users.js.');
  }

  // Anunțurile adminului însuși (dacă are), ca o parte din cele 5 să fie
  // "primite" de admin (test user -> admin), nu doar trimise de el.
  const adminSaleListings = await prisma.userBook.findMany({
    where: { userId: admin.id, isForSale: true, isNegotiable: true, isAuction: false },
    include: { book: true, user: true },
  });
  const adminSwapListings = await prisma.userBook.findMany({
    where: { userId: admin.id, availableForSwap: true, isForSale: false, isAuction: false },
    include: { book: true, user: true },
  });

  if (adminSaleListings.length === 0 && adminSwapListings.length === 0) {
    console.log(
      'Adminul nu are anunțuri proprii - toate cele 5 vor fi trimise DE admin CĂTRE useri de test ' +
        '(pt. testarea "am primit o cerere" ca admin, listează manual o carte pe contul de admin întâi).',
    );
  }

  // Câte un UserBook per user de test distinct, ca "diferite cărți" să
  // însemne și "diferiți useri", nu doar titluri diferite ale aceluiași user.
  function distinctByUser(listings, count) {
    const seenUsers = new Set();
    const seenBooks = new Set();
    const picked = [];
    for (const ub of listings) {
      if (seenUsers.has(ub.userId) || seenBooks.has(ub.bookId)) continue;
      seenUsers.add(ub.userId);
      seenBooks.add(ub.bookId);
      picked.push(ub);
      if (picked.length === count) break;
    }
    return picked;
  }

  const plan = []; // { kind: 'price' | 'exchange', buyer/requester, owner, userBook }

  // 1-2: PriceOffer, admin cumpără de la useri de test (dacă există anunțuri de vânzare).
  const salePicks = distinctByUser(saleListings, 2);
  for (const ub of salePicks) {
    plan.push({ kind: 'price', buyer: admin, owner: ub.user, userBook: ub });
  }

  // 3: dacă adminul are un anunț de vânzare, un test user îi face o ofertă lui.
  if (adminSaleListings.length > 0 && plan.length < RECORD_COUNT) {
    const buyerCandidate = swapListings.find((ub) => ub.userId !== admin.id)?.user
      ?? saleListings.find((ub) => ub.userId !== admin.id)?.user;
    if (buyerCandidate) {
      plan.push({ kind: 'price', buyer: buyerCandidate, owner: admin, userBook: adminSaleListings[0] });
    }
  }

  // Restul până la 5: ExchangeRequest, admin cere useri de test (sau invers,
  // dacă adminul are un anunț de swap și mai e loc).
  const usedUserIds = new Set(plan.map((p) => (p.buyer === admin ? p.owner.id : p.buyer.id)));
  const swapPicks = distinctByUser(
    swapListings.filter((ub) => !usedUserIds.has(ub.userId)),
    RECORD_COUNT,
  );

  if (adminSwapListings.length > 0 && plan.length < RECORD_COUNT) {
    const requesterCandidate = swapPicks.find((ub) => ub.userId !== admin.id)?.user;
    if (requesterCandidate) {
      plan.push({ kind: 'exchange', requester: requesterCandidate, owner: admin, requestedBook: adminSwapListings[0] });
    }
  }

  for (const ub of swapPicks) {
    if (plan.length >= RECORD_COUNT) break;
    plan.push({ kind: 'exchange', requester: admin, owner: ub.user, requestedBook: ub });
  }

  if (plan.length === 0) {
    throw new Error('Nu s-a putut construi niciun plan de oferte - verifică anunțurile din DB.');
  }
  if (plan.length < RECORD_COUNT) {
    console.log(`Notă: doar ${plan.length}/${RECORD_COUNT} perechi distincte disponibile (nu destule anunțuri variate).`);
  }

  let createdCount = 0;
  for (const item of plan) {
    const didCreate =
      item.kind === 'price'
        ? await ensurePriceOffer(item.buyer, item.owner, item.userBook)
        : await ensureExchangeRequest(item.requester, item.owner, item.requestedBook);
    if (didCreate) createdCount++;
  }

  console.log(`\nGata. ${createdCount} create, ${plan.length - createdCount} deja existau (idempotent).`);
}

main()
  .catch((error) => {
    console.error(error);
    process.exitCode = 1;
  })
  .finally(() => prisma.$disconnect());
