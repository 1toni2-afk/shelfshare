import { Injectable, NotFoundException } from '@nestjs/common';
import { Cron, CronExpression } from '@nestjs/schedule';
import { ReportStatus, ReportTargetType } from '@prisma/client';
import { ReportsService } from '../reports/reports.service';
import { PrismaService } from '../prisma/prisma.service';
import { FeedbackService } from '../feedback/feedback.service';
import { SupportService } from '../support/support.service';
import { ROMANIAN_CITY_COORDINATES } from '../common/constants/romanian-city-coordinates';
import { RomanianCity } from '../common/constants/romanian-cities';
import {
  FEATURE_FLAG_KEYS,
  isFeatureFlagKey,
} from '../common/constants/feature-flags';
import { FeatureFlagValueDto } from './dto/set-feature-flags.dto';
import { ListingScoreService } from '../books/listing-score.service';

@Injectable()
export class AdminService {
  constructor(
    private prisma: PrismaService,
    private feedback: FeedbackService,
    private support: SupportService,
    private listingScore: ListingScoreService,
    private reports: ReportsService,
  ) {}

  async getStats() {
    const [
      totalUsers,
      verifiedUsers,
      totalBooks,
      totalUserBooks,
      totalExchanges,
      completedExchanges,
      pendingExchanges,
    ] = await Promise.all([
      this.prisma.user.count(),
      this.prisma.user.count({ where: { isEmailVerified: true } }),
      this.prisma.book.count(),
      this.prisma.userBook.count(),
      this.prisma.exchangeRequest.count(),
      this.prisma.exchangeRequest.count({ where: { status: 'COMPLETED' } }),
      this.prisma.exchangeRequest.count({ where: { status: 'PENDING' } }),
    ]);

    return {
      users: { total: totalUsers, verified: verifiedUsers },
      books: { totalInCatalog: totalBooks, totalListings: totalUserBooks },
      exchanges: {
        total: totalExchanges,
        completed: completedExchanges,
        pending: pendingExchanges,
      },
    };
  }

  /**
   * "Growth over time" (feature backlog #10) - un rând pe zi, ca panoul de
   * admin să poată arăta creșterea, nu doar starea curentă. Upsert pe
   * `date`, deci o rulare re-declanșată manual în aceeași zi actualizează
   * rândul zilei, nu creează duplicate.
   */
  @Cron(CronExpression.EVERY_DAY_AT_4AM)
  async snapshotDailyStats(): Promise<void> {
    const stats = await this.getStats();
    const today = new Date();
    today.setUTCHours(0, 0, 0, 0);

    const data = {
      totalUsers: stats.users.total,
      verifiedUsers: stats.users.verified,
      totalBooks: stats.books.totalInCatalog,
      totalListings: stats.books.totalListings,
      totalExchanges: stats.exchanges.total,
      completedExchanges: stats.exchanges.completed,
    };

    await this.prisma.statsSnapshot.upsert({
      where: { date: today },
      create: { date: today, ...data },
      update: data,
    });
  }

  /**
   * Feature backlog #19: conversion funnel - pre-înscriere -> onboarding ->
   * primul anunț -> primul schimb finalizat. Nu ține pasul cu userii care
   * intră din reclame vs. organic etc. - doar numărul brut la fiecare treaptă,
   * construit din date deja existente (fără model nou).
   */
  async getConversionFunnel() {
    const [
      preRegistrations,
      registeredUsers,
      onboardedUsers,
      listedUsers,
      completedRequesters,
      completedOwners,
    ] = await Promise.all([
      this.prisma.preRegistration.count(),
      this.prisma.user.count(),
      this.prisma.user.count({ where: { onboardingPurpose: { not: null } } }),
      this.prisma.userBook.findMany({
        distinct: ['userId'],
        select: { userId: true },
      }),
      this.prisma.exchangeRequest.findMany({
        where: { status: 'COMPLETED' },
        distinct: ['requesterId'],
        select: { requesterId: true },
      }),
      this.prisma.exchangeRequest.findMany({
        where: { status: 'COMPLETED' },
        distinct: ['ownerId'],
        select: { ownerId: true },
      }),
    ]);

    const exchangedUserIds = new Set([
      ...completedRequesters.map((r) => r.requesterId),
      ...completedOwners.map((r) => r.ownerId),
    ]);

    return {
      preRegistrations,
      registeredUsers,
      onboardedUsers,
      listedUsers: listedUsers.length,
      exchangedUsers: exchangedUserIds.size,
    };
  }

  async getStatsHistory(days?: number) {
    const bounded = Math.min(Math.max(days ?? 30, 1), 365);
    const since = new Date();
    since.setUTCHours(0, 0, 0, 0);
    since.setUTCDate(since.getUTCDate() - bounded);

    return this.prisma.statsSnapshot.findMany({
      where: { date: { gte: since } },
      orderBy: { date: 'asc' },
    });
  }

  // Numărul total de utilizatori vine deja din getStats() - nu-l mai
  // numărăm o a doua oară aici doar ca să-l afișăm într-un titlu.
  async getUsers(limit = 50, offset = 0) {
    const items = await this.prisma.user.findMany({
      select: {
        id: true,
        email: true,
        name: true,
        city: true,
        isEmailVerified: true,
        isBanned: true,
        isAdmin: true,
        isPremium: true,
        rating: true,
        booksExchangedCount: true,
        createdAt: true,
      },
      orderBy: { createdAt: 'desc' },
      take: limit,
      skip: offset,
    });

    return { items, limit, offset };
  }

  /**
   * Căutare de useri pentru panoul de acces la funcții - după email, nume sau
   * username. Aceleași câmpuri ca getUsers(), ca frontend-ul să refolosească
   * modelul AdminUser.
   */
  async searchUsers(query: string, limit = 20) {
    const q = query.trim();
    if (q.length < 2) return [];

    return this.prisma.user.findMany({
      where: {
        OR: [
          { email: { contains: q, mode: 'insensitive' } },
          { name: { contains: q, mode: 'insensitive' } },
          { username: { contains: q, mode: 'insensitive' } },
        ],
      },
      select: {
        id: true,
        email: true,
        name: true,
        city: true,
        isEmailVerified: true,
        isBanned: true,
        isAdmin: true,
        isPremium: true,
        rating: true,
        booksExchangedCount: true,
        createdAt: true,
      },
      orderBy: { createdAt: 'desc' },
      take: Math.min(limit, 50),
    });
  }

  /**
   * Starea checkbox-urilor pentru un user: toate cheile cunoscute, cu
   * enabled=false pentru cele fără rând în DB. Rândurile cu chei scoase din
   * FEATURE_FLAG_KEYS sunt ignorate (vezi comentariul de pe constantă).
   */
  async getUserFeatureFlags(userId: string) {
    const user = await this.prisma.user.findUnique({
      where: { id: userId },
      select: { id: true, email: true, name: true },
    });
    if (!user) {
      throw new NotFoundException('Utilizator negăsit');
    }

    const rows = await this.prisma.userFeatureFlag.findMany({
      where: { userId },
      select: { flagKey: true, enabled: true },
    });
    const enabledByKey = new Map(rows.map((r) => [r.flagKey, r.enabled]));

    return {
      user,
      flags: FEATURE_FLAG_KEYS.map((key) => ({
        key,
        enabled: enabledByKey.get(key) ?? false,
      })),
    };
  }

  /** „Aplică" din ecranul de admin - upsert pe fiecare checkbox trimis. */
  async setUserFeatureFlags(userId: string, flags: FeatureFlagValueDto[]) {
    const user = await this.prisma.user.findUnique({ where: { id: userId } });
    if (!user) {
      throw new NotFoundException('Utilizator negăsit');
    }

    await this.prisma.$transaction(
      flags
        .filter((f) => isFeatureFlagKey(f.key))
        .map((f) =>
          this.prisma.userFeatureFlag.upsert({
            where: { userId_flagKey: { userId, flagKey: f.key } },
            create: { userId, flagKey: f.key, enabled: f.enabled },
            update: { enabled: f.enabled },
          }),
        ),
    );

    return this.getUserFeatureFlags(userId);
  }

  async banUser(userId: string) {
    const user = await this.prisma.user.findUnique({ where: { id: userId } });
    if (!user) {
      throw new NotFoundException('Utilizator negăsit');
    }

    return this.prisma.user.update({
      where: { id: userId },
      data: { isBanned: true, refreshTokenHash: null },
      select: { id: true, email: true, isBanned: true },
    });
  }

  async unbanUser(userId: string) {
    const user = await this.prisma.user.findUnique({ where: { id: userId } });
    if (!user) {
      throw new NotFoundException('Utilizator negăsit');
    }

    return this.prisma.user.update({
      where: { id: userId },
      data: { isBanned: false },
      select: { id: true, email: true, isBanned: true },
    });
  }

  /** Premium e doar un flag acordat manual - nicio procesare de plăți reale, vezi comentariul de pe User.isPremium. */
  async togglePremium(userId: string) {
    const user = await this.prisma.user.findUnique({ where: { id: userId } });
    if (!user) {
      throw new NotFoundException('Utilizator negăsit');
    }

    return this.prisma.user.update({
      where: { id: userId },
      data: { isPremium: !user.isPremium },
      select: { id: true, email: true, isPremium: true },
    });
  }

  /**
   * Insigna „Supporter" - acordată manual până există integrarea de plăți
   * (Google Play Billing pe Android, PayPal pe web). Când aceasta va exista,
   * webhook-ul de plată va seta `supporterSince`, iar acest endpoint rămâne
   * doar pentru corecții manuale.
   */
  async toggleSupporter(userId: string) {
    const user = await this.prisma.user.findUnique({ where: { id: userId } });
    if (!user) {
      throw new NotFoundException('Utilizator negăsit');
    }

    return this.prisma.user.update({
      where: { id: userId },
      data: { supporterSince: user.supporterSince ? null : new Date() },
      select: { id: true, email: true, supporterSince: true },
    });
  }

  async deleteUser(userId: string) {
    const user = await this.prisma.user.findUnique({ where: { id: userId } });
    if (!user) {
      throw new NotFoundException('Utilizator negăsit');
    }

    await this.prisma.user.delete({ where: { id: userId } });
    return { message: 'Utilizator șters' };
  }

  async deleteBook(bookId: string) {
    const book = await this.prisma.book.findUnique({ where: { id: bookId } });
    if (!book) {
      throw new NotFoundException('Cartea nu a fost găsită');
    }

    await this.prisma.book.delete({ where: { id: bookId } });
    return { message: 'Carte ștearsă din catalog' };
  }

  async deleteUserBook(userBookId: string) {
    const userBook = await this.prisma.userBook.findUnique({
      where: { id: userBookId },
    });
    if (!userBook) {
      throw new NotFoundException('Anunțul nu a fost găsit');
    }

    await this.prisma.userBook.delete({ where: { id: userBookId } });
    return { message: 'Anunț șters' };
  }

  /**
   * Breakdown-ul scorului de interes al unui anunț (Milestone 20, extins) -
   * counts brute per tip de eveniment, popularityScore, exchangePotentialScore
   * și overrideul manual curent, pentru panoul de admin.
   */
  async getListingScore(userBookId: string) {
    const userBook = await this.prisma.userBook.findUnique({
      where: { id: userBookId },
      select: { id: true, book: { select: { title: true, author: true } } },
    });
    if (!userBook) {
      throw new NotFoundException('Anunțul nu a fost găsit');
    }

    const breakdown = await this.listingScore.getBreakdown(userBookId);
    return { ...breakdown, book: userBook.book };
  }

  /**
   * Suprascrie manual scorul de popularitate al unui anunț (promovare/
   * corecție arbitrară din consola de admin). `score: null` elimină
   * overrideul și revine la scorul calculat din evenimente.
   */
  async setListingScoreOverride(userBookId: string, score: number | null) {
    const userBook = await this.prisma.userBook.findUnique({
      where: { id: userBookId },
    });
    if (!userBook) {
      throw new NotFoundException('Anunțul nu a fost găsit');
    }

    await this.prisma.userBook.update({
      where: { id: userBookId },
      data: { manualScoreOverride: score ?? null },
    });

    return this.getListingScore(userBookId);
  }

  getInactiveListingsReport() {
    return this.prisma.userBook.findMany({
      where: {
        exchangeRequestsReceived: { none: {} },
      },
      include: {
        book: { select: { title: true, author: true } },
        user: { select: { email: true, name: true } },
      },
      orderBy: { createdAt: 'asc' },
      take: 100,
    });
  }

  /**
   * Coada de moderare, filtrabilă după tipul țintei și după status - un
   * singur panou pentru toate tipurile de raport, nu câte unul per tip.
   *
   * `hiddenAt` vine cu fiecare țintă ascunzibilă: moderatorul trebuie să vadă
   * dacă auto-hide-ul a apucat deja să acționeze (vezi ReportsService), altfel
   * n-ar ști dacă mai are ceva de făcut.
   */
  getUserReports(filters?: {
    targetType?: ReportTargetType;
    status?: ReportStatus;
  }) {
    return this.prisma.report.findMany({
      where: {
        targetType: filters?.targetType,
        status: filters?.status,
      },
      include: {
        reporter: { select: { id: true, email: true, name: true } },
        reportedUser: { select: { id: true, email: true, name: true } },
        userBook: {
          include: { book: { select: { title: true } } },
        },
        assignedTo: { select: { id: true, email: true, name: true } },
        // Feature backlog #18: reports pot viza acum și o postare de grup
        // sau o recenzie, nu doar user/anunț/conversație.
        groupPost: {
          select: { id: true, content: true, groupId: true, hiddenAt: true },
        },
        review: {
          select: {
            id: true,
            text: true,
            rating: true,
            bookId: true,
            hiddenAt: true,
          },
        },
      },
      // OPEN/IN_PROGRESS întâi, ca un moderator să vadă coada de lucru
      // înaintea raportelor deja închise.
      orderBy: [{ status: 'asc' }, { createdAt: 'desc' }],
      take: 100,
    });
  }

  /**
   * Câte rapoarte deschise are fiecare tip de țintă - alimentează contoarele
   * de pe filtrele panoului, ca moderatorul să vadă unde s-a strâns treabă
   * fără să deschidă fiecare filtru pe rând.
   */
  async getReportCounts() {
    const grouped = await this.prisma.report.groupBy({
      by: ['targetType', 'status'],
      _count: { _all: true },
    });
    return grouped.map((row) => ({
      targetType: row.targetType,
      status: row.status,
      count: row._count._all,
    }));
  }

  /**
   * Repune conținutul ascuns automat - „raportul nu stă în picioare".
   * Ascunderea automată e provizorie prin definiție, deci drumul invers
   * trebuie să existe în panou, nu doar în baza de date.
   *
   * Ia id-ul RAPORTULUI, nu perechea (tip, id): panoul are în mână rândul de
   * raport, iar ținta se citește de pe el - un parametru mai puțin de pus
   * corect în interfață.
   */
  async unhideReportById(reportId: string) {
    const report = await this.prisma.report.findUnique({
      where: { id: reportId },
      select: { targetType: true, targetId: true },
    });
    if (!report) {
      throw new NotFoundException('Raportul nu a fost găsit');
    }
    return this.reports.unhideTarget(report.targetType, report.targetId);
  }

  async deleteGroupPost(groupPostId: string) {
    const post = await this.prisma.groupPost.findUnique({ where: { id: groupPostId } });
    if (!post) {
      throw new NotFoundException('Postarea nu a fost găsită');
    }
    await this.prisma.groupPost.delete({ where: { id: groupPostId } });
    return { message: 'Postare ștearsă' };
  }

  async deleteReview(reviewId: string) {
    const review = await this.prisma.review.findUnique({ where: { id: reviewId } });
    if (!review) {
      throw new NotFoundException('Recenzia nu a fost găsită');
    }
    await this.prisma.review.delete({ where: { id: reviewId } });
    return { message: 'Recenzie ștearsă' };
  }

  /**
   * Se ia mereu ca actor administratorul care face schimbarea - ca la un
   * raport rezolvat/respins să rămână o urmă a cui l-a tratat, nu doar a
   * cui l-a raportat prima dată (vezi feature backlog #4).
   */
  async updateReportStatus(
    reportId: string,
    adminUserId: string,
    status: ReportStatus,
    resolutionNote?: string,
  ) {
    const report = await this.prisma.report.findUnique({
      where: { id: reportId },
    });
    if (!report) {
      throw new NotFoundException('Raportul nu a fost găsit');
    }

    const isTerminal = status === 'RESOLVED' || status === 'DISMISSED';
    return this.prisma.report.update({
      where: { id: reportId },
      data: {
        status,
        assignedToId: adminUserId,
        resolutionNote: resolutionNote ?? report.resolutionNote,
        resolvedAt: isTerminal ? new Date() : null,
      },
      include: {
        reporter: { select: { id: true, email: true, name: true } },
        reportedUser: { select: { id: true, email: true, name: true } },
        userBook: { include: { book: { select: { title: true } } } },
        assignedTo: { select: { id: true, email: true, name: true } },
        groupPost: {
          select: { id: true, content: true, groupId: true, hiddenAt: true },
        },
        review: {
          select: {
            id: true,
            text: true,
            rating: true,
            bookId: true,
            hiddenAt: true,
          },
        },
      },
    });
  }

  getFeedback() {
    return this.feedback.getAll();
  }

  getSupportRequests() {
    return this.support.getAll();
  }

  /**
   * Monitorizare minimă (Milestone 17): agregă SecurityEvent pe ultimele
   * 24h/7 zile, plus IP-urile cu cele mai multe login-uri eșuate - un punct
   * de plecare ca să vezi un atac de brute-force sau un abuz de cont fără
   * să sapi în loguri brute.
   */
  async getSecurityStats() {
    const now = new Date();
    const since24h = new Date(now.getTime() - 24 * 60 * 60 * 1000);
    const since7d = new Date(now.getTime() - 7 * 24 * 60 * 60 * 1000);

    const [countsByType24h, countsByType7d, topFailedLoginIps, recentLockouts] =
      await Promise.all([
        this.prisma.securityEvent.groupBy({
          by: ['type'],
          where: { createdAt: { gte: since24h } },
          _count: { _all: true },
        }),
        this.prisma.securityEvent.groupBy({
          by: ['type'],
          where: { createdAt: { gte: since7d } },
          _count: { _all: true },
        }),
        this.prisma.securityEvent.groupBy({
          by: ['ip'],
          where: {
            type: 'LOGIN_FAILED',
            createdAt: { gte: since24h },
            ip: { not: null },
          },
          _count: { ip: true },
          orderBy: { _count: { ip: 'desc' } },
          take: 10,
        }),
        this.prisma.securityEvent.findMany({
          where: { type: 'ACCOUNT_LOCKED', createdAt: { gte: since7d } },
          orderBy: { createdAt: 'desc' },
          take: 20,
          select: { userId: true, ip: true, createdAt: true },
        }),
      ]);

    return {
      since24h: Object.fromEntries(
        countsByType24h.map((c) => [c.type, c._count._all]),
      ),
      since7d: Object.fromEntries(
        countsByType7d.map((c) => [c.type, c._count._all]),
      ),
      topFailedLoginIps24h: topFailedLoginIps.map((r) => ({
        ip: r.ip,
        count: r._count.ip,
      })),
      recentLockouts,
    };
  }

  /**
   * Statistici de marketplace (Milestone 5) - separate de getStats(), care e
   * mai degrabă un raport de sănătate a platformei (useri/cărți/schimburi).
   * GMV = suma ofertelor de preț acceptate + licitațiilor încheiate cu
   * câștigător + schimburilor finalizate unde s-a oferit bani în loc de
   * carte (offeredAmount) - cele 3 căi prin care circulă bani în aplicație.
   */
  async getMarketplaceStats() {
    const [
      acceptedOffers,
      wonAuctions,
      cashExchanges,
      completedSalesCount,
      completedAuctionsCount,
    ] = await Promise.all([
      this.prisma.priceOffer.aggregate({
        where: { status: 'ACCEPTED' },
        _sum: { amount: true },
        _avg: { amount: true },
      }),
      this.prisma.auction.aggregate({
        where: { status: 'ENDED', highestBidderId: { not: null } },
        _sum: { currentPrice: true },
      }),
      this.prisma.exchangeRequest.aggregate({
        where: { status: 'COMPLETED', offeredAmount: { not: null } },
        _sum: { offeredAmount: true },
      }),
      this.prisma.priceOffer.count({ where: { status: 'ACCEPTED' } }),
      this.prisma.auction.count({
        where: { status: 'ENDED', highestBidderId: { not: null } },
      }),
    ]);

    const gmv =
      Number(acceptedOffers._sum.amount ?? 0) +
      Number(wonAuctions._sum.currentPrice ?? 0) +
      Number(cashExchanges._sum.offeredAmount ?? 0);

    const topGenres = await this.prisma.userBook.groupBy({
      by: ['bookId'],
      where: {
        OR: [
          { isForSale: true },
          { isAuction: true },
          { availableForSwap: true },
        ],
      },
      _count: true,
    });
    const bookGenres = await this.prisma.book.findMany({
      where: { id: { in: topGenres.map((g) => g.bookId) } },
      select: { id: true, genre: true },
    });
    const genreCounts = new Map<string, number>();
    for (const entry of topGenres) {
      const genre = bookGenres.find((b) => b.id === entry.bookId)?.genre;
      if (!genre) continue;
      genreCounts.set(genre, (genreCounts.get(genre) ?? 0) + entry._count);
    }
    const topGenresByListings = [...genreCounts.entries()]
      .map(([genre, count]) => ({ genre, count }))
      .sort((a, b) => b.count - a.count)
      .slice(0, 10);

    return {
      gmv,
      completedSalesCount,
      completedAuctionsCount,
      averageSalePrice: acceptedOffers._avg.amount ?? 0,
      topGenresByListings,
    };
  }

  /**
   * Densitatea activității pe oraș (anunțuri active - schimb/vânzare/
   * licitație) - agregăm din UserBook.user.city fiindcă nu există o
   * coordonată per user, doar per oraș (vezi ROMANIAN_CITY_COORDINATES,
   * aceleași coordonate aproximative folosite și la calculul de distanță).
   */
  async getActiveZones() {
    const grouped = await this.prisma.userBook.groupBy({
      by: ['userId'],
      where: {
        OR: [
          { isForSale: true },
          { isAuction: true },
          { availableForSwap: true },
        ],
      },
      _count: true,
    });
    const users = await this.prisma.user.findMany({
      where: { id: { in: grouped.map((g) => g.userId) } },
      select: { id: true, city: true },
    });

    const perCity = new Map<string, number>();
    for (const entry of grouped) {
      const city = users.find((u) => u.id === entry.userId)?.city;
      if (!city) continue;
      perCity.set(city, (perCity.get(city) ?? 0) + entry._count);
    }

    return [...perCity.entries()]
      .map(([city, count]) => {
        const coords = ROMANIAN_CITY_COORDINATES[city as RomanianCity];
        return coords
          ? { city, count, lat: coords.lat, lng: coords.lng }
          : null;
      })
      .filter((z) => z !== null)
      .sort((a, b) => b.count - a.count);
  }
}
