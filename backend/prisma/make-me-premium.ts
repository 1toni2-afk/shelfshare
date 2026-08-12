/**
 * Setează isPremium = true pe un singur cont, dat prin email. Rulare unică.
 *
 * Rulează în interiorul containerului backend (DATABASE_URL rezolvă "postgres"
 * ca host doar acolo):
 *   docker compose -f docker-compose.prod.yml exec backend \
 *     pnpm exec ts-node prisma/make-me-premium.ts
 */
import 'dotenv/config';
import { PrismaClient } from '@prisma/client';
import { PrismaPg } from '@prisma/adapter-pg';

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
