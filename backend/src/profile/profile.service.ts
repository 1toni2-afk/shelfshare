import {
  ConflictException,
  Injectable,
  NotFoundException,
} from '@nestjs/common';
import { Prisma, User } from '@prisma/client';
import { PrismaService } from '../prisma/prisma.service';
import { UsersService } from '../users/users.service';
import { UpdateProfileDto } from './dto/update-profile.dto';
import { publicName } from '../common/utils/user-visibility';

@Injectable()
export class ProfileService {
  constructor(
    private users: UsersService,
    private prisma: PrismaService,
  ) {}

  async getMyProfile(userId: string) {
    const user = await this.users.findById(userId);
    if (!user) {
      throw new NotFoundException('Utilizator negăsit');
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
      isEmailVerified: user.isEmailVerified,
      isAdmin: user.isAdmin,
      showAcquisitionHistory: user.showAcquisitionHistory,
      createdAt: user.createdAt,
      trustScore: await this.computeTrustScore(user),
      achievements: await this.getAchievements(user),
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

    const [reviews, readingStats, achievements] = await Promise.all([
      this.getReviews(userId),
      this.getReadingStats(userId),
      this.getAchievements(user),
    ]);

    return {
      id: user.id,
      name: publicName(user),
      username: user.username,
      city: user.city,
      bio: user.bio,
      profileImage: user.profileImage,
      rating: user.rating,
      booksExchangedCount: user.booksExchangedCount,
      memberSince: user.createdAt,
      listedBooks,
      listingsCount,
      acquisitionHistory,
      trustScore: await this.computeTrustScore(user),
      reviews,
      readingStats,
      achievements,
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
      include: { book: { select: { genre: true, pageCount: true } } },
    });

    const genreCounts = new Map<string, number>();
    let totalPages = 0;
    for (const listing of listings) {
      if (listing.book.genre) {
        genreCounts.set(
          listing.book.genre,
          (genreCounts.get(listing.book.genre) ?? 0) + 1,
        );
      }
      if (listing.book.pageCount) {
        totalPages += listing.book.pageCount;
      }
    }

    let favoriteGenre: string | null = null;
    let max = 0;
    for (const [genre, count] of genreCounts) {
      if (count > max) {
        max = count;
        favoriteGenre = genre;
      }
    }

    return {
      totalListed: listings.length,
      totalPages,
      favoriteGenre,
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
    const [ownerResponses, terminalExchanges] = await Promise.all([
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
        select: { status: true, requesterId: true },
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
   * Insigne calculate din activitatea deja existentă - fără un sistem de
   * puncte separat, doar praguri simple pe date pe care le avem oricum.
   */
  private async getAchievements(user: User) {
    const [listingsCount, genreRows, reviewsWritten, earlierUsersCount] =
      await Promise.all([
        this.prisma.userBook.count({ where: { userId: user.id } }),
        this.prisma.userBook.findMany({
          where: { userId: user.id },
          select: { book: { select: { genre: true } } },
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
      ]);

    const distinctGenres = new Set(
      genreRows.map((r) => r.book.genre).filter((g): g is string => g !== null),
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
}
