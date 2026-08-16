/**
 * Creează 30 de oferte/cereri de schimb (PriceOffer / ExchangeRequest) între
 * 6 conturi fixe: contul de admin (dtoniyi@yahoo.com) + 5 conturi de test
 * (test1..test5@yahoo.com). Fiecare din cele 6 conturi INIȚIAZĂ exact 5
 * oferte - câte una către fiecare din celelalte 5 conturi - deci fiecare
 * cont ajunge să aibă 5 trimise + un număr variabil de primite (media 5).
 *
 * Pentru fiecare pereche (from -> to), alege un anunț deținut de `to`:
 *   - dacă e de vânzare + negociabil -> PriceOffer (85% din preț)
 *   - altfel, dacă e disponibil la schimb -> ExchangeRequest simplă
 *   - dacă `to` nu are niciun anunț eligibil -> perechea e sărită (loggat)
 * Anunțurile deținute de `to` sunt distribuite round-robin ca sursele să
 * varieze (nu toate cele 5 oferte primite de un cont să țintească aceeași
 * carte).
 *
 * Idempotent: sare perechile pentru care există deja o ofertă/cerere
 * PENDING identică (aceiași doi useri, același UserBook).
 *
 * Rulează în interiorul containerului backend:
 *   docker compose -f docker-compose.prod.yml exec backend \
 *     node prisma/seed-pairwise-offers.js
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
const OFFER_EXPIRY_DAYS = 7;

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

async function ensurePriceOffer(buyer, owner, userBook) {
  const existing = await prisma.priceOffer.findFirst({
    where: { buyerId: buyer.id, ownerId: owner.id, userBookId: userBook.id, status: 'PENDING' },
  });
  if (existing) {
    console.log(`  există deja: PriceOffer ${buyer.email} -> ${owner.email} ("${userBook.book.title}")`);
    return false;
  }

  const amount = userBook.salePrice ? Math.max(1, Math.round(Number(userBook.salePrice) * 0.85)) : 20;

  const offer = await prisma.priceOffer.create({
    data: {
      buyerId: buyer.id,
      ownerId: owner.id,
      userBookId: userBook.id,
      amount,
      message: 'Ofertă de test (seed-pairwise-offers.js) - salut, ești de acord cu acest preț?',
      expiresAt: expiresAt(),
    },
  });

  const conversation = await findOrCreateConversation(buyer.id, owner.id);
  await postMessage(conversation.id, buyer.id, `Ofertă: ${amount} lei pentru "${userBook.book.title}"`, {
    priceOfferId: offer.id,
  });

  console.log(`  creat: PriceOffer ${buyer.email} -> ${owner.email} (${amount} lei, "${userBook.book.title}")`);
  return true;
}

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
      message: 'Cerere de schimb de test (seed-pairwise-offers.js) - te-ar interesa?',
      expiresAt: expiresAt(),
    },
  });

  const conversation = await findOrCreateConversation(requester.id, owner.id);
  await postMessage(conversation.id, requester.id, `Cerere de schimb pentru „${requestedBook.book.title}"`, {
    exchangeRequestId: request.id,
  });

  console.log(`  creat: ExchangeRequest ${requester.email} -> ${owner.email} ("${requestedBook.book.title}")`);
  return true;
}

async function main() {
  const users = await prisma.user.findMany({ where: { email: { in: EMAILS } } });
  const byEmail = new Map(users.map((u) => [u.email, u]));
  const missing = EMAILS.filter((e) => !byEmail.has(e));
  if (missing.length > 0) {
    throw new Error(`Conturi negăsite: ${missing.join(', ')}`);
  }

  // Anunțurile fiecărui user, ca listă (round-robin index per owner).
  const listingsByUser = new Map();
  for (const email of EMAILS) {
    const user = byEmail.get(email);
    const listings = await prisma.userBook.findMany({
      where: { userId: user.id, deletedAt: null, isAuction: false },
      include: { book: true, user: true },
      orderBy: { createdAt: 'asc' },
    });
    listingsByUser.set(email, listings);
  }

  const roundRobinIndex = new Map(EMAILS.map((e) => [e, 0]));

  function nextListingFor(ownerEmail) {
    const listings = listingsByUser.get(ownerEmail);
    if (!listings || listings.length === 0) return null;
    const idx = roundRobinIndex.get(ownerEmail) % listings.length;
    roundRobinIndex.set(ownerEmail, idx + 1);
    return listings[idx];
  }

  let createdCount = 0;
  let skippedCount = 0;
  let existedCount = 0;

  for (const fromEmail of EMAILS) {
    for (const toEmail of EMAILS) {
      if (fromEmail === toEmail) continue;

      const from = byEmail.get(fromEmail);
      const to = byEmail.get(toEmail);
      const userBook = nextListingFor(toEmail);

      if (!userBook) {
        console.log(`  sărit: ${fromEmail} -> ${toEmail} (nu are niciun anunț)`);
        skippedCount++;
        continue;
      }

      let didCreate;
      if (userBook.isForSale && userBook.isNegotiable) {
        didCreate = await ensurePriceOffer(from, to, userBook);
      } else if (userBook.availableForSwap) {
        didCreate = await ensureExchangeRequest(from, to, userBook);
      } else {
        // Anunț de vânzare fix-preț (sau altfel neeligibil) - încearcă
        // următorul anunț al aceluiași owner o singură dată.
        const fallback = nextListingFor(toEmail);
        if (fallback && fallback.availableForSwap) {
          didCreate = await ensureExchangeRequest(from, to, fallback);
        } else if (fallback && fallback.isForSale && fallback.isNegotiable) {
          didCreate = await ensurePriceOffer(from, to, fallback);
        } else {
          console.log(`  sărit: ${fromEmail} -> ${toEmail} (anunțurile disponibile nu sunt eligibile)`);
          skippedCount++;
          continue;
        }
      }

      if (didCreate) createdCount++;
      else existedCount++;
    }
  }

  console.log(`\nGata. ${createdCount} create, ${existedCount} deja existau, ${skippedCount} sărite (din 30 perechi).`);
}

main()
  .catch((error) => {
    console.error(error);
    process.exitCode = 1;
  })
  .finally(() => prisma.$disconnect());
