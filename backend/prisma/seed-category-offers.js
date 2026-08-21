/**
 * Creează 16 oferte de test (4 din fiecare categorie - Swap / Vânzare /
 * Donație / Licitație) între cele 6 conturi de test (dtoniyi@yahoo.com +
 * test1..test5@yahoo.com), ca fluxul complet de oferte (accept/refuz/
 * contra-ofertă/finalizare, plus licitațiile) să poată fi testat manual
 * între aceste conturi, în toate categoriile de anunț.
 *
 * Mecanismul diferă pe categorie:
 *   - swap / donation -> ExchangeRequest simplă (donația e listată cu
 *     availableForSwap:true, vezi seed-test-accounts.js, deci cererea de
 *     donație funcționează la fel ca o cerere de schimb).
 *   - sale             -> PriceOffer (85% din prețul cerut).
 *   - auction          -> Bid (licitant nou, +10% peste prețul curent).
 *
 * NU creează useri sau anunțuri noi - referă doar UserBook-uri deja
 * existente, create de seed-test-accounts.js (source: 'test-accounts-seed').
 * Rulează seed-test-accounts.js ÎNAINTE de acest script.
 *
 * Idempotent: sare o pereche dacă există deja o ofertă/cerere PENDING
 * identică, sau dacă cel vizat a licitat deja pe acea licitație.
 *
 * Rulează în interiorul containerului backend:
 *   docker compose -f docker-compose.prod.yml exec backend \
 *     node prisma/seed-category-offers.js
 */
require('dotenv/config');
const { PrismaClient } = require('@prisma/client');
const { PrismaPg } = require('@prisma/adapter-pg');

const adapter = new PrismaPg({ connectionString: process.env.DATABASE_URL });
const prisma = new PrismaClient({ adapter });

const EMAILS = [
  'dtoniyi@yahoo.com',
  'test1@yahoo.com',
  'test2@yahoo.com',
  'test3@yahoo.com',
  'test4@yahoo.com',
  'test5@yahoo.com',
];
const SOURCE = 'test-accounts-seed';
const OFFER_EXPIRY_DAYS = 7;
const OFFERS_PER_CATEGORY = 4;

function expiresAt() {
  return new Date(Date.now() + OFFER_EXPIRY_DAYS * 86_400_000);
}

function categoryOf(ub) {
  if (ub.isAuction) return 'auction';
  if (ub.isForSale) return ub.salePrice == null || Number(ub.salePrice) === 0 ? 'donation' : 'sale';
  return 'swap';
}

async function findOrCreateConversation(userAId, userBId) {
  const [a, b] = [userAId, userBId].sort();
  const existing = await prisma.conversation.findUnique({
    where: { userAId_userBId: { userAId: a, userBId: b } },
  });
  return existing ?? prisma.conversation.create({ data: { userAId: a, userBId: b } });
}

async function postMessage(conversationId, senderId, content, ids) {
  await prisma.message.create({ data: { conversationId, senderId, content, ...ids } });
  await prisma.conversation.update({ where: { id: conversationId }, data: { updatedAt: new Date() } });
}

async function ensurePriceOffer(buyer, owner, userBook) {
  const existing = await prisma.priceOffer.findFirst({
    where: { buyerId: buyer.id, ownerId: owner.id, userBookId: userBook.id, status: 'PENDING' },
  });
  if (existing) {
    console.log(`  [sale] există deja: ${buyer.email} -> ${owner.email} ("${userBook.book.title}")`);
    return false;
  }
  const amount = userBook.salePrice ? Math.max(1, Math.round(Number(userBook.salePrice) * 0.85)) : 20;
  const offer = await prisma.priceOffer.create({
    data: {
      buyerId: buyer.id,
      ownerId: owner.id,
      userBookId: userBook.id,
      amount,
      message: 'Ofertă de test (seed-category-offers.js) - salut, ești de acord cu acest preț?',
      expiresAt: expiresAt(),
    },
  });
  const conversation = await findOrCreateConversation(buyer.id, owner.id);
  await postMessage(conversation.id, buyer.id, `Ofertă: ${amount} lei pentru "${userBook.book.title}"`, {
    priceOfferId: offer.id,
  });
  console.log(`  [sale] creat: ${buyer.email} -> ${owner.email} (${amount} lei, "${userBook.book.title}")`);
  return true;
}

async function ensureExchangeRequest(requester, owner, requestedBook, categoryLabel) {
  const existing = await prisma.exchangeRequest.findFirst({
    where: { requesterId: requester.id, ownerId: owner.id, requestedBookId: requestedBook.id, status: 'PENDING' },
  });
  if (existing) {
    console.log(`  [${categoryLabel}] există deja: ${requester.email} -> ${owner.email} ("${requestedBook.book.title}")`);
    return false;
  }
  const message =
    categoryLabel === 'donation'
      ? 'Cerere de donație de test (seed-category-offers.js) - mi-ar plăcea mult cartea asta!'
      : 'Cerere de schimb de test (seed-category-offers.js) - te-ar interesa?';
  const request = await prisma.exchangeRequest.create({
    data: { requesterId: requester.id, ownerId: owner.id, requestedBookId: requestedBook.id, message, expiresAt: expiresAt() },
  });
  const conversation = await findOrCreateConversation(requester.id, owner.id);
  await postMessage(conversation.id, requester.id, `Cerere pentru „${requestedBook.book.title}"`, {
    exchangeRequestId: request.id,
  });
  console.log(`  [${categoryLabel}] creat: ${requester.email} -> ${owner.email} ("${requestedBook.book.title}")`);
  return true;
}

async function ensureBid(bidder, owner, userBook) {
  const auction = await prisma.auction.findUnique({ where: { userBookId: userBook.id } });
  if (!auction) {
    console.log(`  [auction] sărit: ${owner.email} nu are licitație activă pe "${userBook.book.title}"`);
    return false;
  }
  const existing = await prisma.bid.findFirst({ where: { auctionId: auction.id, bidderId: bidder.id } });
  if (existing) {
    console.log(`  [auction] există deja: bid ${bidder.email} pe "${userBook.book.title}"`);
    return false;
  }
  const amount = Math.round(Number(auction.currentPrice) * 1.1 * 100) / 100;
  await prisma.$transaction([
    prisma.bid.create({ data: { auctionId: auction.id, bidderId: bidder.id, amount } }),
    prisma.auction.update({
      where: { id: auction.id },
      data: { currentPrice: amount, highestBidderId: bidder.id },
    }),
  ]);
  const conversation = await findOrCreateConversation(bidder.id, owner.id);
  await postMessage(conversation.id, bidder.id, `Bid: ${amount} lei la licitația pentru "${userBook.book.title}"`, {});
  console.log(`  [auction] creat: bid ${bidder.email} -> ${owner.email} (${amount} lei, "${userBook.book.title}")`);
  return true;
}

async function main() {
  const users = await prisma.user.findMany({ where: { email: { in: EMAILS } } });
  const byEmail = new Map(users.map((u) => [u.email, u]));
  const missing = EMAILS.filter((e) => !byEmail.has(e));
  if (missing.length > 0) {
    throw new Error(`Conturi negăsite: ${missing.join(', ')} - rulează seed-test-accounts.js întâi.`);
  }

  const listings = await prisma.userBook.findMany({
    where: { user: { email: { in: EMAILS } }, book: { source: SOURCE }, deletedAt: null },
    include: { book: true, user: true },
    orderBy: { createdAt: 'asc' },
  });

  const byUserAndCategory = new Map(); // email -> category -> [UserBook]
  for (const email of EMAILS) byUserAndCategory.set(email, { swap: [], sale: [], donation: [], auction: [] });
  for (const ub of listings) {
    byUserAndCategory.get(ub.user.email)[categoryOf(ub)].push(ub);
  }

  const roundRobin = new Map(); // "email:category" -> next index
  function nextListing(email, category) {
    const pool = byUserAndCategory.get(email)[category];
    if (pool.length === 0) return null;
    const key = `${email}:${category}`;
    const idx = (roundRobin.get(key) ?? 0) % pool.length;
    roundRobin.set(key, idx + 1);
    return pool[idx];
  }

  let created = 0;
  let skipped = 0;
  let existed = 0;

  for (const category of ['swap', 'sale', 'donation', 'auction']) {
    console.log(`\n== ${category} ==`);
    for (let k = 0; k < OFFERS_PER_CATEGORY; k++) {
      // Perechi (from -> to) diferite pentru fiecare categorie, ca aceleași
      // două conturi să nu se repete de fiecare dată - offset-ul categoriei
      // rotește punctul de start prin cele 6 conturi (from != to mereu,
      // fiindcă decalajul e între 1 și 4 din 6 conturi).
      const catOffset = ['swap', 'sale', 'donation', 'auction'].indexOf(category);
      const fromIdx = k % EMAILS.length;
      const toIdx = (fromIdx + 1 + catOffset) % EMAILS.length;
      const fromEmail = EMAILS[fromIdx];
      const toEmail = EMAILS[toIdx];

      const from = byEmail.get(fromEmail);
      const to = byEmail.get(toEmail);
      const userBook = nextListing(toEmail, category);

      if (!userBook) {
        console.log(`  sărit: ${fromEmail} -> ${toEmail} (${toEmail} nu are anunț de tip ${category})`);
        skipped++;
        continue;
      }

      let didCreate;
      if (category === 'sale') {
        didCreate = await ensurePriceOffer(from, to, userBook);
      } else if (category === 'auction') {
        didCreate = await ensureBid(from, to, userBook);
      } else {
        didCreate = await ensureExchangeRequest(from, to, userBook, category);
      }

      if (didCreate) created++;
      else if (didCreate === false) existed++;
    }
  }

  console.log(`\nGata. ${created} create, ${existed} deja existau/sărite, ${skipped} fără anunț eligibil (din ${OFFERS_PER_CATEGORY * 4} perechi vizate).`);
}

main()
  .catch((error) => {
    console.error(error);
    process.exitCode = 1;
  })
  .finally(() => prisma.$disconnect());
