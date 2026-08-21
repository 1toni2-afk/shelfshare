/**
 * Șterge conturile orfane rămase dintr-o versiune veche a
 * `seed-40-test-users.js` (username-uri fără prefixul `test_`, ex.
 * `andrei_voicu_01@shelfshare.test`, în loc de actualul
 * `test_andrei_voicu_01@shelfshare.test`). Versiunea veche a scriptului
 * folosea array-uri de nume mai scurte (20 în loc de 40), deci username-urile
 * se repetau la fiecare 20 de conturi - de asta apar perechi cu același nume
 * (ex. „andrei_voicu_01" și „andrei_voicu_21").
 *
 * Șterge DOAR userii @shelfshare.test care (a) NU au username cu prefixul
 * `test_` ȘI (b) nu au niciun UserBook activ - o măsură dublă de siguranță,
 * ca să nu atingă din greșeală un cont real sau cu date.
 *
 * Rulează în interiorul containerului backend:
 *   docker compose -f docker-compose.prod.yml exec backend \
 *     node prisma/cleanup-old-test-users.js
 */
require('dotenv/config');
const { PrismaClient } = require('@prisma/client');
const { PrismaPg } = require('@prisma/adapter-pg');

const adapter = new PrismaPg({ connectionString: process.env.DATABASE_URL });
const prisma = new PrismaClient({ adapter });

const EMAIL_DOMAIN = 'shelfshare.test';

async function main() {
  const candidates = await prisma.user.findMany({
    where: {
      email: { endsWith: `@${EMAIL_DOMAIN}` },
      NOT: { username: { startsWith: 'test_' } },
    },
    select: { id: true, email: true, username: true, _count: { select: { userBooks: true } } },
  });

  const toDelete = candidates.filter((u) => u._count.userBooks === 0);
  const skipped = candidates.filter((u) => u._count.userBooks > 0);

  if (skipped.length > 0) {
    console.log(`Sar peste ${skipped.length} conturi vechi care încă au anunțuri (nu par orfane):`);
    for (const u of skipped) console.log(`  - ${u.email} (${u.username}): ${u._count.userBooks} anunțuri`);
  }

  if (toDelete.length === 0) {
    console.log('Niciun cont orfan de șters.');
    return;
  }

  console.log(`Șterg ${toDelete.length} conturi orfane fără anunțuri:`);
  for (const u of toDelete) console.log(`  - ${u.email} (${u.username})`);

  const ids = toDelete.map((u) => u.id);
  const result = await prisma.user.deleteMany({ where: { id: { in: ids } } });

  console.log(`\nGata. ${result.count} conturi șterse.`);
}

main()
  .catch((error) => {
    console.error(error);
    process.exitCode = 1;
  })
  .finally(() => prisma.$disconnect());
