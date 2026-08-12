/**
 * Prefixează cu "TEST_" numele TUTUROR userilor din producție, cu excepția
 * contului proprietarului (dat prin email). Rulare unică, dar idempotentă -
 * un nume care deja începe cu "TEST_" e sărit, deci poate fi rulat de mai
 * multe ori fără să dubleze prefixul.
 *
 * Rulează în interiorul containerului backend (DATABASE_URL rezolvă "postgres"
 * ca host doar acolo):
 *   docker compose -f docker-compose.prod.yml exec backend \
 *     pnpm exec ts-node prisma/rename-non-owner-users.ts
 */
import 'dotenv/config';
import { PrismaClient } from '@prisma/client';
import { PrismaPg } from '@prisma/adapter-pg';

const adapter = new PrismaPg({ connectionString: process.env.DATABASE_URL });
const prisma = new PrismaClient({ adapter });

const OWNER_EMAIL = 'dtoniyi@yahoo.com';
const PREFIX = 'TEST_';

async function main() {
  const users = await prisma.user.findMany({
    where: { email: { not: OWNER_EMAIL.toLowerCase() } },
    select: { id: true, email: true, name: true },
  });

  let renamed = 0;
  let skipped = 0;

  for (const user of users) {
    const currentName = user.name?.trim() ?? '';
    if (currentName.startsWith(PREFIX)) {
      skipped++;
      continue;
    }
    const newName = currentName.length > 0 ? `${PREFIX}${currentName}` : PREFIX.slice(0, -1);
    await prisma.user.update({ where: { id: user.id }, data: { name: newName } });
    console.log(`${user.email}: "${currentName}" -> "${newName}"`);
    renamed++;
  }

  console.log(`\nGata. ${renamed} useri redenumiți, ${skipped} deja aveau prefixul, contul ${OWNER_EMAIL} neatins.`);
}

main()
  .catch((error) => {
    console.error(error);
    process.exitCode = 1;
  })
  .finally(() => prisma.$disconnect());
