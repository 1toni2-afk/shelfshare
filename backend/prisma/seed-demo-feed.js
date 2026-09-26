/**
 * Activitate proaspătă în feedul contului demo (toni@ss.com), din ultimele
 * zile: schimburi finalizate ale vecinilor urmăriți (cu cine și ce carte a
 * dat / a primit), cărți noi puse pe raft și progres de citit.
 *
 * Se sprijină pe conturile din seed-demo-accounts.js (Toni, Andrada, Mina,
 * Matei) și, ca parteneri de schimb, pe conturile *.shelfshare.demo dacă
 * există - un feed în care vecinii fac schimb doar între ei arată artificial.
 *
 * Nu recreează nimic: doar ADAUGĂ, lângă ce e deja în baza de date. Anunțurile
 * create aici au `sku` = „demo-feed:…" (câmp folosit altfel doar de
 * anticariate), iar la rulare le ștergem întâi pe cele vechi; schimburile lor
 * pleacă odată cu ele (cascadă pe requestedBook). Progresul și raftul se
 * scriu cu upsert. Deci se poate rula oricât de des: datele rămân „de azi".
 *
 * Rulare, pe backendul de TEST:
 *   docker compose -f docker-compose.test.yml --env-file .env.test \
 *     exec backend node prisma/seed-demo-feed.js
 */
require('dotenv/config');
const { PrismaClient } = require('@prisma/client');
const { PrismaPg } = require('@prisma/adapter-pg');

const MARK = 'demo-feed:';
const CITY = 'Cluj-Napoca';

const hoursAgo = (h) => new Date(Date.now() - h * 3600 * 1000);

async function seedFeed(prisma) {
  const byEmail = async (email) => prisma.user.findUnique({ where: { email } });
  const [toni, andrada, mina, matei] = await Promise.all(
    ['toni@ss.com', 'andrada@ss.com', 'mina@ss.com', 'matei@ss.com'].map(byEmail),
  );
  if (!toni || !andrada || !mina || !matei) {
    throw new Error('Lipsesc conturile demo - rulează întâi prisma/seed-demo-accounts.js');
  }
  const others = await prisma.user.findMany({
    where: { email: { endsWith: '@shelfshare.demo' }, deletionScheduledAt: null },
    orderBy: { email: 'asc' },
    take: 4,
  });
  // Fără conturile *.shelfshare.demo, partenerii rămân vecinii între ei.
  const outsider = (i) => others[i] ?? [andrada, mina, matei][i % 3];

  // Curățenie: tot ce a creat o rulare anterioară.
  const removed = await prisma.userBook.deleteMany({ where: { sku: { startsWith: MARK } } });

  // Cărți cu copertă. Întâi cele pe care vecinii nu le au deja - ca „a
  // adăugat o carte nouă" să nu repete ce e deja în feed -, apoi restul:
  // catalogul bazei de test are doar câteva zeci de cărți.
  const neighbourIds = [andrada.id, mina.id, matei.id, toni.id];
  const alreadyOwned = new Set(
    (await prisma.userBook.findMany({ where: { userId: { in: neighbourIds } }, select: { bookId: true } })).map(
      (b) => b.bookId,
    ),
  );
  const withCover = await prisma.book.findMany({
    where: { coverUrl: { not: null } },
    orderBy: [{ curatedAt: { sort: 'desc', nulls: 'last' } }, { id: 'asc' }],
    take: 200,
  });
  const pool = [...withCover.filter((b) => !alreadyOwned.has(b.id)), ...withCover.filter((b) => alreadyOwned.has(b.id))];
  if (pool.length < 12) throw new Error(`Prea puține cărți cu copertă în catalog (${pool.length})`);
  let cursor = 0;
  const nextBook = () => pool[cursor++ % pool.length];
  const pagesOf = (book) => book.pageCount ?? 320;

  let skuSeq = 0;
  const listing = (user, book, at, extra = {}) =>
    prisma.userBook.create({
      data: {
        userId: user.id,
        bookId: book.id,
        condition: 'FOARTE_BUNA',
        availableForSwap: true,
        city: CITY,
        sku: `${MARK}${++skuSeq}`,
        createdAt: at,
        updatedAt: at,
        ...extra,
      },
    });

  // Un schimb finalizat, cu transferul făcut ca în transfer-listing.ts:
  // exemplarele vechi închise, noii proprietari primesc câte o copie
  // nelistată legată prin previousListingId.
  const exchange = async ({ requester, owner, swapBook = true, hours, review }) => {
    const requestedBook = nextBook();
    const offeredBook = swapBook ? nextBook() : null;
    const listedAt = hoursAgo(hours + 24 * 20);
    const requested = await listing(owner, requestedBook, listedAt);
    const offered = offeredBook ? await listing(requester, offeredBook, listedAt) : null;
    const doneAt = hoursAgo(hours);

    await prisma.exchangeRequest.create({
      data: {
        requesterId: requester.id,
        ownerId: owner.id,
        requestedBookId: requested.id,
        offeredBookId: offered?.id ?? null,
        status: 'COMPLETED',
        createdAt: hoursAgo(hours + 72),
        acceptedAt: hoursAgo(hours + 48),
        meetingTime: doneAt,
        meetingLocation: 'Piața Muzeului',
        meetingAcceptedAt: hoursAgo(hours + 40),
        requesterDoneAt: doneAt,
        ownerDoneAt: doneAt,
        updatedAt: doneAt,
        requesterRatingForOwner: 5,
        ownerRatingForRequester: 5,
        requesterReviewForOwner: review ?? null,
      },
    });

    const handOver = async (from, to) => {
      await prisma.userBook.update({
        where: { id: from.id },
        data: { permanentlyTransferred: true, availableForSwap: false, isForSale: false },
      });
      await listing(to, { id: from.bookId }, doneAt, {
        availableForSwap: false,
        previousListingId: from.id,
      });
    };
    await handOver(requested, requester);
    if (offered) await handOver(offered, owner);
  };

  // 1. Schimburi - cel mai recent sus.
  await exchange({ requester: andrada, owner: outsider(0), hours: 3, review: 'Exact cum era în poze, mersi!' });
  await exchange({ requester: outsider(1), owner: mina, hours: 20 });
  await exchange({ requester: matei, owner: andrada, hours: 30 });
  await exchange({ requester: matei, owner: outsider(2), swapBook: false, hours: 52 });
  await exchange({ requester: toni, owner: mina, hours: 75 });
  await exchange({ requester: outsider(3), owner: andrada, hours: 110 });

  // 2. Cărți noi pe raft, cu câte o notă a proprietarului.
  const newListings = [
    [mina, 2, 'Citită o singură dată, pagini impecabile.'],
    [matei, 7, 'O dau la schimb pe ceva SF.'],
    [andrada, 14, null],
    [mina, 26, 'Ediție cartonată, cu semn de carte inclus.'],
    [matei, 40, null],
    [andrada, 60, 'Mi-a plăcut enorm, merită dată mai departe.'],
  ];
  for (const [user, hours, description] of newListings) {
    await listing(user, nextBook(), hoursAgo(hours), { description, isForSale: hours % 2 === 0, salePrice: hours % 2 === 0 ? 30 : null });
  }

  // 3. Progres de citit - procente diferite, ca barele să arate diferit.
  const progress = [
    [andrada, 1, 0.12],
    [matei, 5, 0.47],
    [mina, 9, 0.81],
    [andrada, 18, 0.63],
    [matei, 33, 0.95],
    [mina, 46, 0.28],
  ];
  for (const [user, hours, share] of progress) {
    const book = nextBook();
    const at = hoursAgo(hours);
    await prisma.bookshelfEntry.upsert({
      where: { userId_bookId: { userId: user.id, bookId: book.id } },
      create: { userId: user.id, bookId: book.id, status: 'READING', updatedAt: at },
      update: { status: 'READING', updatedAt: at },
    });
    const currentPage = Math.max(5, Math.round(pagesOf(book) * share));
    await prisma.readingProgress.upsert({
      where: { userId_bookId: { userId: user.id, bookId: book.id } },
      create: { userId: user.id, bookId: book.id, currentPage, totalPages: book.pageCount ? null : pagesOf(book), updatedAt: at },
      update: { currentPage, totalPages: book.pageCount ? null : pagesOf(book), updatedAt: at },
    });
  }

  console.log(
    `Feed demo: ${removed.count} anunțuri vechi șterse; 6 schimburi, ${newListings.length} cărți noi, ${progress.length} progrese de citit.`,
  );
}

module.exports = { seedFeed };

if (require.main === module) {
  const prisma = new PrismaClient({ adapter: new PrismaPg({ connectionString: process.env.DATABASE_URL }) });
  seedFeed(prisma)
    .catch((err) => {
      console.error(err);
      process.exitCode = 1;
    })
    .finally(() => prisma.$disconnect());
}
