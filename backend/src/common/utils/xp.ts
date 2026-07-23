import { PrismaService } from '../../prisma/prisma.service';

/**
 * XP & Levels - puncte acordate la acțiuni cheie deja existente în
 * aplicație (nu e un sistem separat de misiuni). Nivelul se calculează
 * din xp total, nu se stochează - vezi levelForXp în profile.service.ts.
 * Valorile sunt alese să reflecte "greutatea" acțiunii, nu o formulă
 * riguroasă: un schimb finalizat contează mai mult decât o simplă listare.
 */
export const XP_BOOK_LISTED = 10;
export const XP_EXCHANGE_COMPLETED = 30;
export const XP_SALE_COMPLETED = 20;
export const XP_REVIEW_WRITTEN = 5;

export async function awardXp(prisma: PrismaService, userId: string, amount: number) {
  await prisma.user
    .update({ where: { id: userId }, data: { xp: { increment: amount } } })
    .catch(() => {});
}
