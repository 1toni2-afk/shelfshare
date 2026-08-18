import { Injectable } from '@nestjs/common';
import { PrismaService } from '../prisma/prisma.service';
import { ListingScoreEventKind } from '@prisma/client';

/// Cât valorează fiecare tip de interes pentru scorul de popularitate. Un
/// view unic e semnalul cel mai slab, o cerere de schimb/ofertă de preț
/// (intenție reală de tranzacție) e semnalul cel mai tare.
export const POPULARITY_WEIGHTS: Record<ListingScoreEventKind, number> = {
  UNIQUE_VIEW: 1,
  // Deprecated, nu se mai scrie (vezi enum-ul din schema) - păstrat doar ca
  // evenimentele vechi din DB să continue să conteze puțin până expiră.
  REVIEW: 0.1,
  RETURN_VISIT: 0.5,
  WISHLIST_ADD: 7,
  EXCHANGE_REQUEST: 10,
  BUY_OFFER: 12,
};

/// Scorul de "potențial de schimb" - cât de probabil e ca anunțul să ducă
/// efectiv la o tranzacție. Ignoră deliberat view-urile: 5.000 de vizualizări
/// fără nicio cerere de schimb valorează mai puțin, pentru ShelfShare, decât
/// 300 de vizualizări cu 15 cereri de schimb.
export const EXCHANGE_POTENTIAL_WEIGHTS: Record<ListingScoreEventKind, number> =
  {
    UNIQUE_VIEW: 0,
    REVIEW: 0,
    RETURN_VISIT: 0,
    WISHLIST_ADD: 3,
    EXCHANGE_REQUEST: 10,
    BUY_OFFER: 12,
  };

/// Fiecare punct expiră individual la 30 de zile după ce a fost câștigat.
export const SCORE_WINDOW_DAYS = 30;

/// Fereastra sub care re-deschiderea aceluiași anunț de către același viewer
/// e considerată „refresh" și nu contează deloc (nici măcar ca revenire).
const RETURN_VISIT_DEDUPE_HOURS = 6;

/// Câte reveniri ale aceluiași viewer contează, cel mult, per anunț și per
/// fereastră de scor - altfel un singur user care revine obsesiv ar putea
/// urca artificial un anunț.
const MAX_RETURN_VISITS_PER_WINDOW = 3;

/// Cardul de carte arată badge de scor doar pentru primele N anunțuri din
/// clasament (implicit) - vezi scoresForCards.
export const MAX_CARD_BADGE_LISTINGS = 256;

export interface ListingScoreBreakdown {
  userBookId: string;
  counts: Partial<Record<ListingScoreEventKind, number>>;
  popularityScore: number;
  exchangePotentialScore: number;
  manualScoreOverride: number | null;
}

/**
 * Scorul de interes al anunțurilor - baza secțiunii „Cele mai căutate" din
 * Discover (Milestone 20), extinsă cu un al doilea scor („potențial de
 * schimb") și cu suprascriere manuală din consola de admin. Scorul NU e
 * vizibil userilor normali: nu apare pe card, nu e returnat de endpointurile
 * publice; determină doar ordinea. Adminii îl primesc explicit (vezi
 * BooksService.getTrendingListings și AdminService.getListingScore).
 *
 * Serviciu separat de BooksService fiindcă și WishlistService/ExchangesService/
 * OffersService trebuie să înregistreze evenimente, iar BooksService deja
 * depinde de WishlistService (dependența inversă ar fi ciclică).
 */
@Injectable()
export class ListingScoreService {
  constructor(private prisma: PrismaService) {}

  private since(): Date {
    return new Date(Date.now() - SCORE_WINDOW_DAYS * 24 * 60 * 60 * 1000);
  }

  /**
   * Înregistrează deschiderea unui anunț. Prima deschidere a viewerului în
   * fereastra de scor = view unic; o re-deschidere la ≥6h de la ultima
   * vizită = revenire reală (max 3/user/fereastră); orice altceva (refresh
   * sub 6h) nu se scrie deloc - altfel un singur user cu F5 ar putea urca
   * orice anunț. Viewerii ne-autentificați sunt tratați ca o singură
   * entitate (userId null), la fel ca la BookView, ca un tab incognito să nu
   * poată genera view-uri „unice" la infinit.
   *
   * Fire-and-forget la apelant: o scriere pierdută nu trebuie să blocheze
   * afișarea anunțului.
   */
  async recordView(userBookId: string, userId?: string): Promise<void> {
    const key = userId ?? null;

    const lastVisit = await this.prisma.listingScoreEvent.findFirst({
      where: {
        userBookId,
        userId: key,
        kind: { in: ['UNIQUE_VIEW', 'RETURN_VISIT'] },
      },
      orderBy: { createdAt: 'desc' },
      select: { createdAt: true },
    });

    if (!lastVisit) {
      await this.prisma.listingScoreEvent.create({
        data: {
          userBookId,
          userId: key,
          kind: 'UNIQUE_VIEW',
          points: POPULARITY_WEIGHTS.UNIQUE_VIEW,
        },
      });
      return;
    }

    const dedupeSince = new Date(
      Date.now() - RETURN_VISIT_DEDUPE_HOURS * 60 * 60 * 1000,
    );
    if (lastVisit.createdAt >= dedupeSince) {
      return; // refresh - nu contează
    }

    const returnVisitsInWindow = await this.prisma.listingScoreEvent.count({
      where: {
        userBookId,
        userId: key,
        kind: 'RETURN_VISIT',
        createdAt: { gte: this.since() },
      },
    });
    if (returnVisitsInWindow >= MAX_RETURN_VISITS_PER_WINDOW) {
      return; // a atins deja capul de reveniri pentru fereastra curentă
    }

    await this.prisma.listingScoreEvent.create({
      data: {
        userBookId,
        userId: key,
        kind: 'RETURN_VISIT',
        points: POPULARITY_WEIGHTS.RETURN_VISIT,
      },
    });
  }

  /**
   * Un titlu pus la favorite = eveniment pentru fiecare anunț activ al
   * titlului. Wishlist-ul e per carte (Book), nu per exemplar, deci nu avem
   * cum să atribuim punctul unui singur anunț - iar interesul e real pentru
   * toate.
   */
  async recordWishlistAdd(bookId: string, userId: string): Promise<void> {
    await this.recordForActiveListings(bookId, userId, 'WISHLIST_ADD');
  }

  /** O cerere de schimb trimisă pentru anunțul cerut - semnal puternic de intenție. */
  async recordExchangeRequest(
    userBookId: string,
    userId: string,
  ): Promise<void> {
    await this.prisma.listingScoreEvent.create({
      data: {
        userBookId,
        userId,
        kind: 'EXCHANGE_REQUEST',
        points: POPULARITY_WEIGHTS.EXCHANGE_REQUEST,
      },
    });
  }

  /** O ofertă de preț trimisă pentru anunțul cerut - cel mai puternic semnal. */
  async recordBuyOffer(userBookId: string, userId: string): Promise<void> {
    await this.prisma.listingScoreEvent.create({
      data: {
        userBookId,
        userId,
        kind: 'BUY_OFFER',
        points: POPULARITY_WEIGHTS.BUY_OFFER,
      },
    });
  }

  private async recordForActiveListings(
    bookId: string,
    userId: string,
    kind: ListingScoreEventKind,
  ): Promise<void> {
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
        kind,
        points: POPULARITY_WEIGHTS[kind],
      })),
    });
  }

  /**
   * Scorul de popularitate curent (suma punctelor ne-expirate, sau
   * suprascrierea manuală de admin dacă există) pentru anunțurile date.
   * Anunțurile fără niciun eveniment în fereastră și fără override lipsesc
   * din Map.
   */
  async scoresFor(userBookIds: string[]): Promise<Map<string, number>> {
    if (userBookIds.length === 0) return new Map();

    const [grouped, overridden] = await Promise.all([
      this.prisma.listingScoreEvent.groupBy({
        by: ['userBookId'],
        where: {
          userBookId: { in: userBookIds },
          createdAt: { gte: this.since() },
        },
        _sum: { points: true },
      }),
      this.prisma.userBook.findMany({
        where: { id: { in: userBookIds }, manualScoreOverride: { not: null } },
        select: { id: true, manualScoreOverride: true },
      }),
    ]);

    const scores = new Map(
      grouped.map((g) => [g.userBookId, round1(g._sum.points ?? 0)]),
    );
    for (const o of overridden) {
      scores.set(o.id, o.manualScoreOverride!);
    }
    return scores;
  }

  /**
   * Scorurile de afișat ca badge pe cardurile de carte (colțul stânga-sus),
   * pentru admini. `showAll=false` (implicit) restrânge badge-ul la anunțurile
   * din top [MAX_CARD_BADGE_LISTINGS] la nivel de platformă, ca „Cele mai
   * căutate" din Discover - restul cărților rămân fără badge, chiar dacă au
   * un scor mic. `showAll=true` întoarce scorul pentru orice anunț din
   * `userBookIds` care are unul.
   */
  async scoresForCards(
    userBookIds: string[],
    showAll: boolean,
  ): Promise<Map<string, number>> {
    const all = await this.scoresFor(userBookIds);
    if (showAll) return all;

    const top = await this.topScoringListingIds(MAX_CARD_BADGE_LISTINGS);
    const topIds = new Set(top.map((t) => t.userBookId));
    for (const id of all.keys()) {
      if (!topIds.has(id)) all.delete(id);
    }
    return all;
  }

  /**
   * Top anunțuri după scorul de popularitate, ordonat descrescător.
   * Include anunțurile cu override manual chiar dacă nu au evenimente
   * ne-expirate. Apelantul decide ce face când lista e mai scurtă decât
   * `take` (vezi fallback-ul din getTrendingListings).
   */
  async topScoringListingIds(
    take: number,
  ): Promise<{ userBookId: string; score: number }[]> {
    const [grouped, overridden] = await Promise.all([
      this.prisma.listingScoreEvent.groupBy({
        by: ['userBookId'],
        where: { createdAt: { gte: this.since() } },
        _sum: { points: true },
      }),
      this.prisma.userBook.findMany({
        where: { manualScoreOverride: { not: null } },
        select: { id: true, manualScoreOverride: true },
      }),
    ]);

    const scores = new Map(
      grouped.map((g) => [g.userBookId, round1(g._sum.points ?? 0)]),
    );
    for (const o of overridden) {
      scores.set(o.id, o.manualScoreOverride!);
    }

    return [...scores.entries()]
      .map(([userBookId, score]) => ({ userBookId, score }))
      .sort((a, b) => b.score - a.score)
      .slice(0, take);
  }

  /**
   * Breakdown complet pentru panoul de admin: counts brute per tip de
   * eveniment (ne-expirate), scorul de popularitate, scorul de potențial de
   * schimb și overrideul manual curent. Popularitatea folosește overrideul
   * dacă există; potențialul de schimb rămâne mereu calculat (overrideul nu
   * îl afectează - vezi comentariul de pe UserBook.manualScoreOverride).
   */
  async getBreakdown(userBookId: string): Promise<ListingScoreBreakdown> {
    const [grouped, userBook] = await Promise.all([
      this.prisma.listingScoreEvent.groupBy({
        by: ['kind'],
        where: { userBookId, createdAt: { gte: this.since() } },
        _count: { _all: true },
      }),
      this.prisma.userBook.findUnique({
        where: { id: userBookId },
        select: { manualScoreOverride: true },
      }),
    ]);

    const counts: Partial<Record<ListingScoreEventKind, number>> = {};
    let rawPopularity = 0;
    let exchangePotential = 0;
    for (const g of grouped) {
      counts[g.kind] = g._count._all;
      rawPopularity += g._count._all * POPULARITY_WEIGHTS[g.kind];
      exchangePotential += g._count._all * EXCHANGE_POTENTIAL_WEIGHTS[g.kind];
    }

    return {
      userBookId,
      counts,
      popularityScore: round1(userBook?.manualScoreOverride ?? rawPopularity),
      exchangePotentialScore: round1(exchangePotential),
      manualScoreOverride: userBook?.manualScoreOverride ?? null,
    };
  }
}

/// Punctele sunt fracționare (0.5 per revenire) - fără rotunjire, sumele ies
/// cu coada de floating point (3.0000000000000004) în răspunsul de admin.
function round1(value: number): number {
  return Math.round(value * 10) / 10;
}
