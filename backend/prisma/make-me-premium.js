/**
 * Setează isPremium = true pe un singur cont, dat prin email. Rulare unică.
 *
 * Versiune .js (nu .ts): imaginea de producție nu are pnpm/ts-node - doar
 * `node dist/main`. @prisma/client, @prisma/adapter-pg și dotenv rămân în
 * node_modules după `pnpm prune --prod` (sunt dependencies, nu devDependencies),
 * deci scriptul rulează direct cu `node`, fără compilare.
 *
 * Rulează în interiorul containerului backend (DATABASE_URL rezolvă "postgres"
 * ca host doar acolo):
 *   docker compose -f docker-compose.prod.yml exec backend \
 *     node prisma/make-me-premium.js
 */
require('dotenv/config');
const { PrismaClient } = require('@prisma/client');
const { PrismaPg } = require('@prisma/adapter-pg');

const adapter = new PrismaPg({ connectionString: process.env.DATABASE_URL });
const prisma = new PrismaClient({ adapter });

const EMAIL = 'dtoniyi@yahoo.com';

async function main() {
  const user = await prisma.user.update({
    where: { email: EMAIL.toLowerCase() },
    data: { isPremium: true },
  });
  console.log(`${user.email} este acum premium (isPremium = true).`);
}

main()
  .catch((error) => {
    console.error(error);
    process.exitCode = 1;
  })
  .finally(() => prisma.$disconnect());
