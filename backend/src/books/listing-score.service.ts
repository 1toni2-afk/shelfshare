import { Injectable } from '@nestjs/common';
import { PrismaService } from '../prisma/prisma.service';

/// Cât valorează fiecare tip de interes. Un view unic e semnalul tare, un
/// refresh contează aproape deloc (altfel un singur user cu F5 ar putea urca
/// orice anunț în „Cele mai căutate"), iar un favorite e undeva la mijloc.
export const SCORE_UNIQUE_VIEW = 3;
export const SCORE_REVIEW = 0.1;
export const SCORE_WISHLIST_ADD = 1;

/// Fiecare punct expiră individual la 14 zile după ce a fost câștigat.
export const SCORE_WINDOW_DAYS = 14;

/// Fereastra în care re-deschiderea aceluiași anunț de către același viewer
/// e considerată „refresh", nu view unic.
const UNIQUE_VIEW_DEDUPE_HOURS = 24;

/**
 * Scorul de interes al anunțurilor - baza secțiunii „Cele mai căutate" din
 * Discover (Milestone 20). Scorul NU e vizibil userilor normali: nu apare pe
 * card, nu e returnat de endpointurile publice; determină doar ordinea
 * secțiunii. Adminii îl primesc explicit (vezi BooksService.getTrendingListings).
 *
 * Serviciu separat de BooksService fiindcă și WishlistService trebuie să
 * înregistreze evenimente, iar BooksService deja depinde de WishlistService
 * (dependența inversă ar fi ciclică).
 */
@Injectable()
export class ListingScoreService {
  constructor(private prisma: PrismaService) {}

  private since(): Date {
    return new Date(Date.now() - SCORE_WINDOW_DAYS * 24 * 60 * 60 * 1000);
  }

  /**
   * Înregistrează deschiderea unui anunț. Prima deschidere a viewerului în
   * ultimele 24h = view unic (3p); orice re-deschidere în acel interval =
   * refresh (0.1p). Viewerii ne-autentificați sunt tratați ca o singură
   * entitate (userId null), la fel ca la BookView, ca un tab incognito să nu
   * poată genera view-uri „unice" la infinit.
   *
   * Fire-and-forget la apelant: o scriere pierdută nu trebuie să blocheze
   * afișarea anunțului.
   */
  async recordView(userBookId: string, userId?: string): Promise<void> {
    const dedupeSince = new Date(
      Date.now() - UNIQUE_VIEW_DEDUPE_HOURS * 60 * 60 * 1000,
    );
    const recent = await this.prisma.listingScoreEvent.findFirst({
      where: {
        userBookId,
        userId: userId ?? null,
        kind: 'UNIQUE_VIEW',
        createdAt: { gte: dedupeSince },
      },
      select: { id: true },
    });

    await this.prisma.listingScoreEvent.create({
      data: {
        userBookId,
        userId: userId ?? null,
        kind: recent ? 'REVIEW' : 'UNIQUE_VIEW',
        points: recent ? SCORE_REVIEW : SCORE_UNIQUE_VIEW,
      },
    });
  }

  /**
   * Un titlu pus la favorite = +1p pentru fiecare anunț activ al titlului.
   * Wishlist-ul e per carte (Book), nu per exemplar, deci nu avem cum să
   * atribuim punctul unui singur anunț - iar interesul e real pentru toate.
   */
  async recordWishlistAdd(bookId: string, userId: string): Promise<void> {
    const listings = await this.prisma.userBook.findMany({
      where: { bookId, deletedAt: null, availableForSwap: true },
      select: { id: true },
      take: 50,
    });
    if (listings.length === 0) return;
    await this.prisma.listingScoreEvent.createMany({
      data: listings.map((l) => ({
        userBookId: l.id,
        userId,
        kind: 'WISHLIST_ADD' as const,
        points: SCORE_WISHLIST_ADD,
      })),
    });
  }

  /**
   * Scorul curent (suma punctelor ne-expirate) pentru anunțurile date.
   * Anunțurile fără niciun eveniment în fereastră lipsesc din Map.
   */
  async scoresFor(userBookIds: string[]): Promise<Map<string, number>> {
    if (userBookIds.length === 0) return new Map();
    const grouped = await this.prisma.listingScoreEvent.groupBy({
      by: ['userBookId'],
      where: {
        userBookId: { in: userBookIds },
        createdAt: { gte: this.since() },
      },
      _sum: { points: true },
    });
    return new Map(
      grouped.map((g) => [g.userBookId, round1(g._sum.points ?? 0)]),
    );
  }

  /**
   * Top anunțuri după scor, ordonat descrescător. Întoarce doar anunțuri cu
   * cel puțin un eveniment ne-expirat - apelantul decide ce face când lista e
   * mai scurtă decât `take` (vezi fallback-ul din getTrendingListings).
   */
  async topScoringListingIds(
    take: number,
  ): Promise<{ userBookId: string; score: number }[]> {
    const grouped = await this.prisma.listingScoreEvent.groupBy({
      by: ['userBookId'],
      where: { createdAt: { gte: this.since() } },
      _sum: { points: true },
      orderBy: { _sum: { points: 'desc' } },
      take,
    });
    return grouped.map((g) => ({
      userBookId: g.userBookId,
      score: round1(g._sum.points ?? 0),
    }));
  }
}

/// Punctele sunt fracționare (0.1 per refresh) - fără rotunjire, sumele ies
/// cu coada de floating point (3.0000000000000004) în răspunsul de admin.
function round1(value: number): number {
  return Math.round(value * 10) / 10;
}
