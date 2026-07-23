import {
  ConflictException,
  ForbiddenException,
  Injectable,
  NotFoundException,
} from '@nestjs/common';
import { Prisma, User } from '@prisma/client';
import { PrismaService } from '../prisma/prisma.service';
import { UsersService } from '../users/users.service';
import { BookshelfService } from '../bookshelf/bookshelf.service';
import { UpdateProfileDto } from './dto/update-profile.dto';
import { publicName } from '../common/utils/user-visibility';

@Injectable()
export class ProfileService {
  constructor(
    private users: UsersService,
    private prisma: PrismaService,
    private bookshelf: BookshelfService,
  ) {}

  async getMyProfile(userId: string) {
    const user = await this.users.findById(userId);
    if (!user) {
      throw new NotFoundException('Utilizator negăsit');
    }

    const referralCount = await this.prisma.user.count({
      where: { invitedById: user.id },
    });

    return {
      id: user.id,
      email: user.email,
      name: user.name,
      username: user.username,
      nameVisible: user.nameVisible,
      city: user.city,
      bio: user.bio,
      profileImage: user.profileImage,
      rating: user.rating,
      booksExchangedCount: user.booksExchangedCount,
      booksSharedCount: user.booksSharedCount,
      booksReceivedCount: user.booksReceivedCount,
      isEmailVerified: user.isEmailVerified,
      isAdmin: user.isAdmin,
      isPremium: user.isPremium,
      showAcquisitionHistory: user.showAcquisitionHistory,
      referralCode: user.referralCode,
      referralCount,
      createdAt: user.createdAt,
      trustScore: await this.computeTrustScore(user),
      achievements: await this.getAchievements(user),
      impactStats: await this.getImpactStats(userId),
      gamification: this.getGamificationStats(user),
    };
  }

  async updateMyProfile(userId: string, dto: UpdateProfileDto) {
    let user: User;
    try {
      user = await this.users.update(userId, dto);
    } catch (error) {
      if (
        error instanceof Prisma.PrismaClientKnownRequestError &&
        error.code === 'P2002' &&
        (error.meta?.target as string[] | undefined)?.includes('username')
      ) {
        throw new ConflictException('Acest username este deja folosit');
      }
      throw error;
    }

    return {
      id: user.id,
      email: user.email,
      name: user.name,
      username: user.username,
      nameVisible: user.nameVisible,
      city: user.city,
      bio: user.bio,
      profileImage: user.profileImage,
      rating: user.rating,
      booksExchangedCount: user.booksExchangedCount,
      showAcquisitionHistory: user.showAcquisitionHistory,
    };
  }

  async getPublicProfile(userId: string) {
    const user = await this.users.findById(userId);
    if (!user) {
      throw new NotFoundException('Utilizator negăsit');
    }

    const [listedBooks, listingsCount] = await Promise.all([
      this.prisma.userBook.findMany({
        where: { userId, availableForSwap: true },
        include: { book: true },
        orderBy: { createdAt: 'desc' },
        take: 20,
      }),
      this.prisma.userBook.count({ where: { userId } }),
    ]);

    const acquisitionHistory = user.showAcquisitionHistory
      ? await this.getAcquisitionHistory(userId)
      : null;

    const [reviews, readingStats, achievements, impactStats, bookshelf] = await Promise.all([
      this.getReviews(userId),
      this.getReadingStats(userId),
      this.getAchievements(user),
      this.getImpactStats(userId),
      this.bookshelf.getPublicShelf(userId),
    ]);

    return {
      id: user.id,
      name: publicName(user),
      username: user.username,
      city: user.city,
      bio: user.bio,
      profileImage: user.profileImage,
      isPremium: user.isPremium,
      rating: user.rating,
      booksExchangedCount: user.booksExchangedCount,
      booksSharedCount: user.booksSharedCount,
      booksReceivedCount: user.booksReceivedCount,
      memberSince: user.createdAt,
      listedBooks,
      listingsCount,
      acquisitionHistory,
      trustScore: await this.computeTrustScore(user),
      reviews,
      readingStats,
      achievements,
      impactStats,
      bookshelf,
      gamification: this.getGamificationStats(user),
    };
  }

  /**
   * Recenziile text primite de un user, din ambele roluri posibile
   * (proprietar sau solicitant) ale unui schimb finalizat.
   */
  private async getReviews(userId: string) {
    const [asOwner, asRequester] = await Promise.all([
      this.prisma.exchangeRequest.findMany({
        where: { ownerId: userId, requesterReviewForOwner: { not: null } },
        include: {
          requester: { select: { id: true, name: true, profileImage: true } },
        },
        orderBy: { updatedAt: 'desc' },
      }),
      this.prisma.exchangeRequest.findMany({
        where: { requesterId: userId, ownerReviewForRequester: { not: null } },
        include: {
          owner: { select: { id: true, name: true, profileImage: true } },
        },
        orderBy: { updatedAt: 'desc' },
      }),
    ]);

    const fromOwnerRole = asOwner.map((e) => ({
      reviewerId: e.requester.id,
      reviewerName: e.requester.name,
      reviewerImage: e.requester.profileImage,
      rating: e.requesterRatingForOwner,
      comment: e.requesterReviewForOwner,
      date: e.updatedAt,
    }));
    const fromRequesterRole = asRequester.map((e) => ({
      reviewerId: e.owner.id,
      reviewerName: e.owner.name,
      reviewerImage: e.owner.profileImage,
      rating: e.ownerRatingForRequester,
      comment: e.ownerReviewForRequester,
      date: e.updatedAt,
    }));

    return [...fromOwnerRole, ...fromRequesterRole].sort(
      (a, b) => b.date.getTime() - a.date.getTime(),
    );
  }

  /**
   * Statistici simple de citit, calculate din cărțile listate de user -
   * nu urmărește cărți citite efectiv, doar activitatea din aplicație.
   */
  private async getReadingStats(userId: string) {
    const listings = await this.prisma.userBook.findMany({
      where: { userId },
      include: { book: { select: { title: true, genre: true, pageCount: true } } },
    });

    const genreCounts = new Map<string, number>();
    let totalPages = 0;
    let longestBookTitle: string | null = null;
    let longestBookPages = 0;
    for (const listing of listings) {
      if (listing.book.genre) {
        genreCounts.set(
          listing.book.genre,
          (genreCounts.get(listing.book.genre) ?? 0) + 1,
        );
      }
      if (listing.book.pageCount) {
        totalPages += listing.book.pageCount;
        if (listing.book.pageCount > longestBookPages) {
          longestBookPages = listing.book.pageCount;
          longestBookTitle = listing.book.title;
        }
      }
    }

    const topGenres = Array.from(genreCounts.entries())
      .map(([genre, count]) => ({ genre, count }))
      .sort((a, b) => b.count - a.count)
      .slice(0, 5);

    return {
      totalListed: listings.length,
      totalPages,
      favoriteGenre: topGenres[0]?.genre ?? null,
      longestBookTitle,
      longestBookPages: longestBookPages || null,
      topGenres,
    };
  }

  // Estimare aproximativă, nu o măsurătoare certificată - o medie des
  // citată pentru amprenta de CO2 a producției unei cărți tipărite noi.
  private static readonly CO2_KG_PER_BOOK = 2.5;

  /**
   * "Money Saved" / "Total Value of Books Exchanged" / "Estimated CO2
   * Saved" - calculate din `Book.referencePrice` (prețul de listă preluat
   * de la Google Books, vezi book-lookup.service.ts), acolo unde există.
   * Definiție: pentru fiecare carte primită (schimb sau cumpărare), userul
   * "economisește" diferența dintre prețul de referință și ce a plătit
   * efectiv (0 la schimb pur, suma oferită la schimb cu bani, prețul plătit
   * la o vânzare) - iar la un schimb carte-contra-carte, ambele părți
   * economisesc valoarea cărții primite. Cărțile fără preț de referință
   * (multe intrări manuale) nu pot contribui la Money Saved, dar tot intră
   * în Total Value dacă știm măcar suma plătită.
   */
  private async getImpactStats(userId: string) {
    const [asRequester, asOwnerWithOfferedBook, acceptedOffersAsBuyer, user] =
      await Promise.all([
        this.prisma.exchangeRequest.findMany({
          where: { requesterId: userId, status: 'COMPLETED' },
          select: {
            offeredAmount: true,
            requestedBook: { select: { book: { select: { referencePrice: true } } } },
          },
        }),
        this.prisma.exchangeRequest.findMany({
          where: {
            ownerId: userId,
            status: 'COMPLETED',
            offeredBookId: { not: null },
          },
          select: {
            offeredBook: { select: { book: { select: { referencePrice: true } } } },
          },
        }),
        this.prisma.priceOffer.findMany({
          where: { buyerId: userId, status: 'ACCEPTED' },
          select: {
            amount: true,
            userBook: { select: { book: { select: { referencePrice: true } } } },
          },
        }),
        this.prisma.user.findUnique({
          where: { id: userId },
          select: { booksReceivedCount: true },
        }),
      ]);

    let totalValueExchanged = 0;
    let moneySaved = 0;

    for (const exchange of asRequester) {
      const price = exchange.requestedBook.book.referencePrice?.toNumber();
      if (price == null) continue;
      totalValueExchanged += price;
      const paid = exchange.offeredAmount?.toNumber() ?? 0;
      moneySaved += Math.max(0, price - paid);
    }

    for (const exchange of asOwnerWithOfferedBook) {
      const price = exchange.offeredBook?.book.referencePrice?.toNumber();
      if (price == null) continue;
      totalValueExchanged += price;
      moneySaved += price;
    }

    for (const offer of acceptedOffersAsBuyer) {
      const price = offer.userBook.book.referencePrice?.toNumber();
      const paid = offer.amount.toNumber();
      if (price != null) {
        totalValueExchanged += price;
        moneySaved += Math.max(0, price - paid);
      } else {
        totalValueExchanged += paid;
      }
    }

    return {
      totalValueExchanged: Math.round(totalValueExchanged * 100) / 100,
      moneySaved: Math.round(moneySaved * 100) / 100,
      co2SavedKg:
        Math.round(
          (user?.booksReceivedCount ?? 0) * ProfileService.CO2_KG_PER_BOOK * 10,
        ) / 10,
    };
  }

  /**
   * "Advanced Analytics" (Premium, Milestone 5) - statistici de vânzător
   * calculate din date deja existente (UserBook.viewCount, PriceOffer),
   * fără infrastructură nouă de tracking.
   */
  async getSellerAnalytics(userId: string) {
    const user = await this.prisma.user.findUnique({ where: { id: userId }, select: { isPremium: true } });
    if (!user?.isPremium) {
      throw new ForbiddenException('Statisticile avansate sunt o funcție Premium');
    }

    const [listings, offersReceived, acceptedOffers] = await Promise.all([
      this.prisma.userBook.findMany({
        where: { userId },
        select: { viewCount: true, book: { select: { title: true } } },
        orderBy: { viewCount: 'desc' },
      }),
      this.prisma.priceOffer.count({ where: { ownerId: userId } }),
      this.prisma.priceOffer.findMany({
        where: { ownerId: userId, status: 'ACCEPTED' },
        select: { amount: true },
      }),
    ]);

    const totalViews = listings.reduce((sum, l) => sum + l.viewCount, 0);
    const totalRevenue = acceptedOffers.reduce((sum, o) => sum + o.amount.toNumber(), 0);

    return {
      totalListings: listings.length,
      totalViews,
      totalOffersReceived: offersReceived,
      acceptedOffersCount: acceptedOffers.length,
      conversionRate: offersReceived > 0 ? acceptedOffers.length / offersReceived : 0,
      totalRevenue: Math.round(totalRevenue * 100) / 100,
      topListingsByViews: listings.slice(0, 5).map((l) => ({ title: l.book.title, views: l.viewCount })),
    };
  }

  /**
   * Indicator simplu de încredere (0-100), calculat doar din date deja
   * existente în aplicație - NU e o verificare certificată de identitate.
   * Componente și ponderi (suma = 100 la scor maxim):
   *  - vechimea contului (până la 1 an)           → max 15
   *  - email verificat                             → 10
   *  - volum de schimburi finalizate (până la 20)  → max 20
   *  - rating primit                                → max 20 (neutru 10 dacă nu are încă schimburi)
   *  - % schimburi finalizate din totalul închise   → max 20 (neutru 10 dacă nu are istoric)
   *  - % din cererile proprii NEanulate              → max 15 (neutru 8 dacă nu are istoric)
   * Userii noi pornesc cu scor moderat (nu 0) ca să nu fie penalizați doar
   * pentru lipsă de istoric - scorul crește pe măsură ce se construiește
   * un istoric real de comportament.
   */
  private async computeTrustScore(user: User) {
    const [ownerResponses, terminalExchanges, pendingReceivedCount] =
      await Promise.all([
        this.prisma.exchangeRequest.findMany({
          where: {
            ownerId: user.id,
            status: { in: ['ACCEPTED', 'REJECTED', 'COMPLETED'] },
          },
          select: { createdAt: true, updatedAt: true },
        }),
        this.prisma.exchangeRequest.findMany({
          where: {
            OR: [{ ownerId: user.id }, { requesterId: user.id }],
            status: { in: ['COMPLETED', 'REJECTED', 'CANCELLED'] },
          },
          select: {
            status: true,
            requesterId: true,
            createdAt: true,
            updatedAt: true,
          },
        }),
        this.prisma.exchangeRequest.count({
          where: { ownerId: user.id, status: 'PENDING' },
        }),
      ]);

    const accountAgeDays = Math.floor(
      (Date.now() - user.createdAt.getTime()) / 86_400_000,
    );

    const averageResponseHours = ownerResponses.length
      ? ownerResponses.reduce(
          (sum, r) =>
            sum + (r.updatedAt.getTime() - r.createdAt.getTime()) / 3_600_000,
          0,
        ) / ownerResponses.length
      : null;

    const completedCount = terminalExchanges.filter(
      (e) => e.status === 'COMPLETED',
    ).length;
    const completedExchangeRate = terminalExchanges.length
      ? completedCount / terminalExchanges.length
      : null;

    const asRequester = terminalExchanges.filter(
      (e) => e.requesterId === user.id,
    );
    const cancelledByUser = asRequester.filter(
      (e) => e.status === 'CANCELLED',
    ).length;
    const cancellationRate = asRequester.length
      ? cancelledByUser / asRequester.length
      : null;

    // Rata de răspuns - din cererile primite ca proprietar, cât % au primit
    // deja un răspuns (acceptat/respins), excluzând cele anulate de
    // solicitant (nu e vina proprietarului) - restul rămân "pending" (nu
    // le numărăm ca "răspuns", dar nici nu penalizăm nejustificat cererile
    // foarte proaspete care abia au ajuns).
    const respondedCount = ownerResponses.length;
    const responseRate =
      respondedCount + pendingReceivedCount > 0
        ? respondedCount / (respondedCount + pendingReceivedCount)
        : null;

    // Timpul mediu de finalizare a unui schimb (de la cerere la finalizare
    // efectivă) - aceeași aproximare ca la averageResponseHours, folosind
    // updatedAt ca proxy pentru "momentul finalizării".
    const completedWithTimestamps = terminalExchanges.filter(
      (e) => e.status === 'COMPLETED',
    );
    const averageSwapTimeHours = completedWithTimestamps.length
      ? completedWithTimestamps.reduce(
          (sum, e) =>
            sum + (e.updatedAt.getTime() - e.createdAt.getTime()) / 3_600_000,
          0,
        ) / completedWithTimestamps.length
      : null;

    const ageScore = Math.min(accountAgeDays / 365, 1) * 15;
    const emailScore = user.isEmailVerified ? 10 : 0;
    const volumeScore = Math.min(user.booksExchangedCount / 20, 1) * 20;
    const ratingScore =
      user.booksExchangedCount > 0 ? (user.rating / 5) * 20 : 10;
    const completionScore =
      completedExchangeRate !== null ? completedExchangeRate * 20 : 10;
    const cancellationScore =
      cancellationRate !== null ? (1 - cancellationRate) * 15 : 8;

    const score = Math.round(
      ageScore +
        emailScore +
        volumeScore +
        ratingScore +
        completionScore +
        cancellationScore,
    );

    return {
      score,
      accountAgeDays,
      isEmailVerified: user.isEmailVerified,
      completedExchanges: user.booksExchangedCount,
      rating: user.rating,
      completedExchangeRate,
      averageResponseHours,
      cancellationRate,
      lastActiveAt: user.lastActiveAt,
      responseRate,
      averageSwapTimeHours,
      avgCommunicationRating: user.avgCommunicationRating || null,
      avgPunctualityRating: user.avgPunctualityRating || null,
      avgConditionRating: user.avgConditionRating || null,
    };
  }

  /**
   * Clasament pe orașe - cel mai activ utilizator (după schimburi finalizate)
   * din fiecare oraș care are măcar un utilizator cu activitate.
   */
  async getCityLeaderboard() {
    const users = await this.prisma.user.findMany({
      where: { booksExchangedCount: { gt: 0 }, city: { not: null } },
      select: {
        id: true,
        name: true,
        username: true,
        nameVisible: true,
        city: true,
        profileImage: true,
        rating: true,
        booksExchangedCount: true,
      },
      orderBy: { booksExchangedCount: 'desc' },
    });

    const byCity = new Map<string, (typeof users)[number]>();
    for (const user of users) {
      if (!byCity.has(user.city!)) {
        byCity.set(user.city!, user);
      }
    }

    return Array.from(byCity.values())
      .sort((a, b) => b.booksExchangedCount - a.booksExchangedCount)
      .slice(0, 15)
      .map((user) => ({ ...user, name: publicName(user) }));
  }

  /**
   * Clasament național - top useri după schimburi finalizate, indiferent de
   * oraș (spre deosebire de getCityLeaderboard, care ia un singur user per
   * oraș).
   */
  async getNationalLeaderboard() {
    const users = await this.prisma.user.findMany({
      where: { booksExchangedCount: { gt: 0 } },
      select: {
        id: true,
        name: true,
        username: true,
        nameVisible: true,
        city: true,
        profileImage: true,
        rating: true,
        booksExchangedCount: true,
      },
      orderBy: { booksExchangedCount: 'desc' },
      take: 20,
    });
    return users.map((user) => ({ ...user, name: publicName(user) }));
  }

  /**
   * "Top Readers" - clasament după totalul de pagini din cărțile listate,
   * ca proxy pentru activitatea de citit (nu urmărim cărți citite efectiv,
   * vezi getReadingStats de mai jos pentru același compromis pe profil).
   */
  async getTopReaders() {
    const rows = await this.prisma.userBook.findMany({
      where: { book: { pageCount: { not: null } } },
      select: {
        userId: true,
        book: { select: { pageCount: true } },
        user: {
          select: {
            id: true,
            name: true,
            username: true,
            nameVisible: true,
            city: true,
            profileImage: true,
          },
        },
      },
    });

    const totals = new Map<string, { pages: number; user: (typeof rows)[number]['user'] }>();
    for (const row of rows) {
      const entry = totals.get(row.userId) ?? { pages: 0, user: row.user };
      entry.pages += row.book.pageCount ?? 0;
      totals.set(row.userId, entry);
    }

    return Array.from(totals.values())
      .sort((a, b) => b.pages - a.pages)
      .slice(0, 15)
      .map((entry) => ({
        ...entry.user,
        name: publicName(entry.user),
        totalPages: entry.pages,
      }));
  }

  /**
   * Insigne calculate din activitatea deja existentă - fără un sistem de
   * puncte separat, doar praguri simple pe date pe care le avem oricum.
   */
  private async getAchievements(user: User) {
    const [
      listingsCount,
      genreRows,
      reviewsWritten,
      earlierUsersCount,
      exchangePartnerRows,
      higherRankedCount,
    ] = await Promise.all([
      this.prisma.userBook.count({ where: { userId: user.id } }),
      this.prisma.userBook.findMany({
        where: { userId: user.id },
        select: { language: true, book: { select: { genre: true } } },
      }),
      this.prisma.exchangeRequest.count({
        where: {
          OR: [
            { requesterId: user.id, requesterReviewForOwner: { not: null } },
            { ownerId: user.id, ownerReviewForRequester: { not: null } },
          ],
        },
      }),
      this.prisma.user.count({
        where: { createdAt: { lt: user.createdAt } },
      }),
      this.prisma.exchangeRequest.findMany({
        where: {
          status: 'COMPLETED',
          OR: [{ requesterId: user.id }, { ownerId: user.id }],
        },
        select: { requesterId: true, ownerId: true },
      }),
      this.prisma.user.count({
        where: { booksExchangedCount: { gt: user.booksExchangedCount } },
      }),
    ]);

    const distinctGenres = new Set(
      genreRows.map((r) => r.book.genre).filter((g): g is string => g !== null),
    ).size;
    const distinctLanguages = new Set(
      genreRows.map((r) => r.language).filter((l): l is string => l !== null),
    ).size;
    const fantasyBooksCount = genreRows.filter((r) =>
      r.book.genre?.toLowerCase().includes('fantas'),
    ).length;
    const distinctExchangePartners = new Set(
      exchangePartnerRows.map((r) =>
        r.requesterId === user.id ? r.ownerId : r.requesterId,
      ),
    ).size;
    const trustScore = await this.computeTrustScore(user);

    const badges = [
      {
        key: 'first_swap',
        label: 'Primul schimb',
        description: 'Ai finalizat primul schimb prin aplicație.',
        achieved: user.booksExchangedCount >= 1,
      },
      {
        key: 'ten_swaps',
        label: '10 schimburi',
        description: 'Ai finalizat 10 schimburi.',
        achieved: user.booksExchangedCount >= 10,
      },
      {
        key: 'fifty_swaps',
        label: '50 de schimburi',
        description: 'Ai finalizat 50 de schimburi.',
        achieved: user.booksExchangedCount >= 50,
      },
      {
        key: 'collector',
        label: 'Colecționar',
        description: 'Ai listat cel puțin 10 cărți.',
        achieved: listingsCount >= 10,
      },
      {
        key: 'trusted_member',
        label: 'Membru de încredere',
        description: 'Ai un scor de încredere de cel puțin 70.',
        achieved: trustScore.score >= 70,
      },
      {
        key: 'early_adopter',
        label: 'Early Adopter',
        description: 'Printre primii 50 de utilizatori înregistrați.',
        achieved: earlierUsersCount < 50,
      },
      {
        key: 'genre_master',
        label: 'Genre Master',
        description: 'Ai listat cărți din cel puțin 5 genuri diferite.',
        achieved: distinctGenres >= 5,
      },
      {
        key: 'community_helper',
        label: 'Community Helper',
        description: 'Ai scris cel puțin 3 recenzii pentru alți utilizatori.',
        achieved: reviewsWritten >= 3,
      },
      {
        key: 'explorer',
        label: 'Explorer',
        description: 'Ai făcut schimburi cu cel puțin 5 utilizatori diferiți.',
        achieved: distinctExchangePartners >= 5,
      },
      {
        key: 'fantasy_collector',
        label: 'Fantasy Collector',
        description: 'Ai listat cel puțin 3 cărți din genul fantasy.',
        achieved: fantasyBooksCount >= 3,
      },
      {
        key: 'top_swapper',
        label: 'Top Swapper',
        description: 'Ești în top 10 la nivel național după schimburi finalizate.',
        achieved: user.booksExchangedCount > 0 && higherRankedCount < 10,
      },
      {
        key: 'book_explorer',
        label: 'Book Explorer',
        description: 'Ai listat cărți în cel puțin 3 limbi diferite.',
        achieved: distinctLanguages >= 3,
      },
    ];

    return badges;
  }

  /**
   * Cărțile primite prin aplicație - din oferte de preț acceptate (ca
   * cumpărător) și schimburi finalizate (ca solicitant). Afișat pe profil
   * doar dacă userul a activat explicit showAcquisitionHistory.
   */
  private async getAcquisitionHistory(userId: string) {
    const [acceptedOffers, completedExchanges] = await Promise.all([
      this.prisma.priceOffer.findMany({
        where: { buyerId: userId, status: 'ACCEPTED' },
        include: { userBook: { include: { book: true } } },
        orderBy: { updatedAt: 'desc' },
      }),
      this.prisma.exchangeRequest.findMany({
        where: { requesterId: userId, status: 'COMPLETED' },
        include: { requestedBook: { include: { book: true } } },
        orderBy: { updatedAt: 'desc' },
      }),
    ]);

    const fromOffers = acceptedOffers.map((offer) => ({
      bookTitle: offer.userBook.book.title,
      bookCoverUrl: offer.userBook.book.coverUrl,
      date: offer.updatedAt,
      type: 'sale' as const,
    }));
    const fromExchanges = completedExchanges.map((exchange) => ({
      bookTitle: exchange.requestedBook.book.title,
      bookCoverUrl: exchange.requestedBook.book.coverUrl,
      date: exchange.updatedAt,
      type: 'exchange' as const,
    }));

    return [...fromOffers, ...fromExchanges].sort(
      (a, b) => b.date.getTime() - a.date.getTime(),
    );
  }

  /**
   * XP & Levels - nivelul se calculează din xp total, nu se stochează
   * (curbă simplă, liniară: 100 xp/nivel). Streak-ul (zile consecutive cu
   * activitate) e actualizat din JwtAuthGuard, aici doar îl expunem.
   */
  private getGamificationStats(user: User) {
    return {
      xp: user.xp,
      level: Math.floor(user.xp / 100) + 1,
      xpToNextLevel: 100 - (user.xp % 100),
      currentStreakDays: user.currentStreakDays,
      longestStreakDays: user.longestStreakDays,
    };
  }

  /**
   * Monthly Challenges - fără un sistem separat de misiuni/premii, doar 3
   * praguri simple recalculate live din activitatea lunii calendaristice
   * curente (fără tabelă dedicată - la fel ca achievements/badges).
   */
  async getMonthlyChallenges(userId: string) {
    const monthStart = new Date(Date.UTC(new Date().getUTCFullYear(), new Date().getUTCMonth(), 1));

    const [booksListed, exchangesCompleted, reviewsWritten] = await Promise.all([
      this.prisma.userBook.count({
        where: { userId, createdAt: { gte: monthStart } },
      }),
      this.prisma.exchangeRequest.count({
        where: {
          status: 'COMPLETED',
          updatedAt: { gte: monthStart },
          OR: [{ requesterId: userId }, { ownerId: userId }],
        },
      }),
      this.prisma.exchangeRequest.count({
        where: {
          updatedAt: { gte: monthStart },
          OR: [
            { requesterId: userId, requesterRatingForOwner: { not: null } },
            { ownerId: userId, ownerRatingForRequester: { not: null } },
          ],
        },
      }),
    ]);

    return [
      { key: 'list_books', label: 'Listează 3 cărți luna asta', progress: booksListed, goal: 3 },
      { key: 'complete_swaps', label: 'Finalizează 2 schimburi luna asta', progress: exchangesCompleted, goal: 2 },
      { key: 'write_reviews', label: 'Scrie 1 recenzie luna asta', progress: reviewsWritten, goal: 1 },
    ].map((c) => ({ ...c, completed: c.progress >= c.goal }));
  }

  /**
   * Reading Challenge - obiectiv anual opțional (ca la Goodreads), setat
   * de user; progresul se calculează din BookshelfEntry cu status FINISHED
   * marcate în anul calendaristic curent.
   */
  async getReadingChallenge(userId: string) {
    const user = await this.users.findById(userId);
    if (!user) {
      throw new NotFoundException('Utilizator negăsit');
    }

    const yearStart = new Date(Date.UTC(new Date().getUTCFullYear(), 0, 1));
    const finishedThisYear = await this.prisma.bookshelfEntry.count({
      where: { userId, status: 'FINISHED', updatedAt: { gte: yearStart } },
    });

    return {
      year: new Date().getUTCFullYear(),
      goal: user.readingChallengeGoal,
      progress: finishedThisYear,
    };
  }

  async setReadingChallengeGoal(userId: string, goal: number | null) {
    await this.prisma.user.update({
      where: { id: userId },
      data: { readingChallengeGoal: goal },
    });
    return this.getReadingChallenge(userId);
  }

  /**
   * Reading Activity Feed - evenimente recente din activitatea userilor
   * URMĂRIȚI (vezi Follow), nu globale - altfel ar fi zgomot pe o platformă
   * cu mulți useri necunoscuți între ei. Fără o tabelă de evenimente
   * dedicată - recompunem feed-ul din datele deja existente (listări noi,
   * cărți terminate, schimburi finalizate), la fel ca restul statisticilor
   * "derivate" din aplicație.
   */
  async getActivityFeed(userId: string) {
    const follows = await this.prisma.follow.findMany({
      where: { followerId: userId },
      select: { followingId: true },
    });
    const followingIds = follows.map((f) => f.followingId);
    if (followingIds.length === 0) return [];

    const [newListings, finishedBooks, completedExchanges] = await Promise.all([
      this.prisma.userBook.findMany({
        where: { userId: { in: followingIds } },
        select: {
          userId: true,
          createdAt: true,
          book: { select: { title: true, coverUrl: true } },
          user: { select: { name: true, nameVisible: true } },
        },
        orderBy: { createdAt: 'desc' },
        take: 20,
      }),
      this.prisma.bookshelfEntry.findMany({
        where: { userId: { in: followingIds }, status: 'FINISHED' },
        select: {
          userId: true,
          updatedAt: true,
          book: { select: { title: true, coverUrl: true } },
          user: { select: { name: true, nameVisible: true } },
        },
        orderBy: { updatedAt: 'desc' },
        take: 20,
      }),
      this.prisma.exchangeRequest.findMany({
        where: { status: 'COMPLETED', OR: [{ requesterId: { in: followingIds } }, { ownerId: { in: followingIds } }] },
        select: {
          requesterId: true,
          ownerId: true,
          updatedAt: true,
          requestedBook: { select: { book: { select: { title: true, coverUrl: true } } } },
          requester: { select: { name: true, nameVisible: true } },
          owner: { select: { name: true, nameVisible: true } },
        },
        orderBy: { updatedAt: 'desc' },
        take: 20,
      }),
    ]);

    const events = [
      ...newListings.map((l) => ({
        type: 'new_listing' as const,
        userId: l.userId,
        userName: publicName(l.user),
        bookTitle: l.book.title,
        bookCoverUrl: l.book.coverUrl,
        date: l.createdAt,
      })),
      ...finishedBooks.map((f) => ({
        type: 'finished_book' as const,
        userId: f.userId,
        userName: publicName(f.user),
        bookTitle: f.book.title,
        bookCoverUrl: f.book.coverUrl,
        date: f.updatedAt,
      })),
      ...completedExchanges.flatMap((exchange) => {
        // Evenimentul apare o singură dată, atribuit userului urmărit
        // implicat (dacă amândoi sunt urmăriți, apare pentru requester -
        // simplificare acceptabilă, nu dublăm evenimentul).
        const isRequesterFollowed = followingIds.includes(exchange.requesterId);
        const actor = isRequesterFollowed ? exchange.requester : exchange.owner;
        const actorId = isRequesterFollowed ? exchange.requesterId : exchange.ownerId;
        return [
          {
            type: 'completed_exchange' as const,
            userId: actorId,
            userName: publicName(actor),
            bookTitle: exchange.requestedBook.book.title,
            bookCoverUrl: exchange.requestedBook.book.coverUrl,
            date: exchange.updatedAt,
          },
        ];
      }),
    ];

    return events.sort((a, b) => b.date.getTime() - a.date.getTime()).slice(0, 30);
  }
}
