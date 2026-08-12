/**
 * Verifică rezultatul lui seed-40-test-users.js: exact 40 de useri cu
 * domeniul @shelfshare.test, fiecare cu exact 3 anunțuri din fiecare
 * categorie (Swap / Vânzare / Licitație / Donație) = 12 total.
 *
 * Categoria e derivată din UserBook exact ca în frontend (_categoryOf din
 * my_library_screen.dart): isAuction -> auction; isForSale && salePrice
 * gol/0 -> donation; isForSale && salePrice > 0 -> sale; altfel -> swap.
 *
 * Rulează în interiorul containerului backend:
 *   docker compose -f docker-compose.prod.yml exec backend \
 *     node prisma/verify-40-test-users.js
 */
require('dotenv/config');
const { PrismaClient } = require('@prisma/client');
const { PrismaPg } = require('@prisma/adapter-pg');

const adapter = new PrismaPg({ connectionString: process.env.DATABASE_URL });
const prisma = new PrismaClient({ adapter });

const EMAIL_DOMAIN = 'shelfshare.test';

function categoryOf(userBook) {
  if (userBook.isAuction) return 'auction';
  if (userBook.isForSale) {
    return userBook.salePrice == null || Number(userBook.salePrice) === 0 ? 'donation' : 'sale';
  }
  return 'swap';
}

async function main() {
  const users = await prisma.user.findMany({
    where: { email: { endsWith: `@${EMAIL_DOMAIN}` } },
    select: {
      email: true,
      name: true,
      userBooks: {
        select: { isAuction: true, isForSale: true, salePrice: true },
      },
    },
    orderBy: { email: 'asc' },
  });

  console.log(`Useri „- TEST" găsiți (email @${EMAIL_DOMAIN}): ${users.length} (așteptat: 40)\n`);

  let allGood = true;
  const totals = { swap: 0, sale: 0, auction: 0, donation: 0 };

  for (const user of users) {
    const counts = { swap: 0, sale: 0, auction: 0, donation: 0 };
    for (const ub of user.userBooks) {
      counts[categoryOf(ub)]++;
    }
    for (const key of Object.keys(totals)) totals[key] += counts[key];

    const total = user.userBooks.length;
    const isGood = counts.swap === 3 && counts.sale === 3 && counts.auction === 3 && counts.donation === 3 && total === 12;
    if (!isGood) {
      allGood = false;
      console.log(
        `✗ ${user.email} (${user.name}): swap=${counts.swap} sale=${counts.sale} auction=${counts.auction} donation=${counts.donation} total=${total}`,
      );
    }
  }

  console.log(`\nTotaluri pe toți userii: swap=${totals.swap} sale=${totals.sale} auction=${totals.auction} donation=${totals.donation} (fiecare așteptat: 120)`);

  if (users.length === 40 && allGood) {
    console.log('\n✓ Totul corect: 40 useri, câte 3 anunțuri din fiecare categorie.');
  } else {
    console.log('\n✗ Sunt abateri de la ce era de așteptat - vezi detaliile de mai sus.');
  }
}

main()
  .catch((error) => {
    console.error(error);
    process.exitCode = 1;
  })
  .finally(() => prisma.$disconnect());
