/**
 * Prefixează cu "TEST_" numele TUTUROR userilor din producție, cu excepția
 * contului proprietarului (dat prin email). Rulare unică, dar idempotentă -
 * un nume care deja începe cu "TEST_" e sărit, deci poate fi rulat de mai
 * multe ori fără să dubleze prefixul.
 *
 * Versiune .js (nu .ts): imaginea de producție nu are pnpm/ts-node - doar
 * `node dist/main`. @prisma/client, @prisma/adapter-pg și dotenv rămân în
 * node_modules după `pnpm prune --prod` (sunt dependencies, nu devDependencies),
 * deci scriptul rulează direct cu `node`, fără compilare.
 *
 * Rulează în interiorul containerului backend (DATABASE_URL rezolvă "postgres"
 * ca host doar acolo):
 *   docker compose -f docker-compose.prod.yml exec backend \
 *     node prisma/rename-non-owner-users.js
 */
require('dotenv/config');
const { PrismaClient } = require('@prisma/client');
const { PrismaPg } = require('@prisma/adapter-pg');

const adapter = new PrismaPg({ connectionString: process.env.DATABASE_URL });
const prisma = new PrismaClient({ adapter });

const OWNER_EMAIL = 'dtoniyi@yahoo.com';
/** Conturi de sistem (Google Play review, ChatGPT plugin review) - nu sunt
 * ale userilor reali/de test, deci rămân neatinse la fel ca OWNER_EMAIL. */
const EXCLUDED_EMAILS = ['google.review@shelfshare.ro', 'test.chatgpt@shelfshare.ro'];
const PREFIX = 'TEST_';

async function main() {
  const users = await prisma.user.findMany({
    where: {
      email: {
        notIn: [OWNER_EMAIL.toLowerCase(), ...EXCLUDED_EMAILS.map((e) => e.toLowerCase())],
      },
    },
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

  console.log(
    `\nGata. ${renamed} useri redenumiți, ${skipped} deja aveau prefixul, ${[OWNER_EMAIL, ...EXCLUDED_EMAILS].join(', ')} neatinse.`,
  );
}

main()
  .catch((error) => {
    console.error(error);
    process.exitCode = 1;
  })
  .finally(() => prisma.$disconnect());
