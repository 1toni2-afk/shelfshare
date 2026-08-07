import { Injectable, NotFoundException } from '@nestjs/common';
import { PrismaService } from '../prisma/prisma.service';
import { FeedbackService } from '../feedback/feedback.service';
import { SupportService } from '../support/support.service';
import { ROMANIAN_CITY_COORDINATES } from '../common/constants/romanian-city-coordinates';
import { RomanianCity } from '../common/constants/romanian-cities';

@Injectable()
export class AdminService {
  constructor(
    private prisma: PrismaService,
    private feedback: FeedbackService,
    private support: SupportService,
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

  getUserReports() {
    return this.prisma.report.findMany({
      include: {
        reporter: { select: { id: true, email: true, name: true } },
        reportedUser: { select: { id: true, email: true, name: true } },
        userBook: { include: { book: { select: { title: true } } } },
      },
      orderBy: { createdAt: 'desc' },
      take: 100,
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
