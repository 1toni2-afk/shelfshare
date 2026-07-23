import { ForbiddenException } from '@nestjs/common';
import { PrismaService } from '../../prisma/prisma.service';

/**
 * "Unlimited Watchlist" (Premium, Milestone 5) - userii gratuiți au o limită
 * combinată wishlist + licitații urmărite; userii isPremium nu au limită.
 * Combinată fiindcă ambele sunt conceptual "cărți care mă interesează", nu
 * are sens un plafon separat pentru fiecare.
 */
export const FREE_WATCHLIST_LIMIT = 15;

export async function assertUnderWatchlistLimit(prisma: PrismaService, userId: string) {
  const user = await prisma.user.findUnique({ where: { id: userId }, select: { isPremium: true } });
  if (user?.isPremium) return;

  const [wishlistCount, watchCount] = await Promise.all([
    prisma.wishlistItem.count({ where: { userId } }),
    prisma.auctionWatch.count({ where: { userId } }),
  ]);

  if (wishlistCount + watchCount >= FREE_WATCHLIST_LIMIT) {
    throw new ForbiddenException(
      `Ai atins limita gratuită de ${FREE_WATCHLIST_LIMIT} cărți/licitații urmărite - Premium elimină limita`,
    );
  }
}
