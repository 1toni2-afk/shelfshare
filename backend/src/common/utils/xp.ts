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

/** Cât XP costă un nivel. Curbă liniară, fără nivel maxim. */
export const XP_PER_LEVEL = 100;

/**
 * Tabelul de recompense trimis către client, ca ecranul de profil să poată
 * explica userului de unde vine XP-ul fără să dublăm valorile în Dart.
 */
export const XP_REWARDS = {
  bookListed: XP_BOOK_LISTED,
  exchangeCompleted: XP_EXCHANGE_COMPLETED,
  saleCompleted: XP_SALE_COMPLETED,
  reviewWritten: XP_REVIEW_WRITTEN,
};

export async function awardXp(prisma: PrismaService, userId: string, amount: number) {
  await prisma.user
    .update({ where: { id: userId }, data: { xp: { increment: amount } } })
    .catch(() => {});
}
