import {
  BadRequestException,
  Injectable,
  Logger,
  NotFoundException,
} from '@nestjs/common';
import { PrismaService } from '../prisma/prisma.service';
import { NotificationsService } from '../notifications/notifications.service';
import { publicName } from '../common/utils/user-visibility';

@Injectable()
export class FollowService {
  private readonly logger = new Logger(FollowService.name);

  constructor(
    private prisma: PrismaService,
    private notifications: NotificationsService,
  ) {}

  async followUser(followerId: string, followingId: string) {
    if (followerId === followingId) {
      throw new BadRequestException('Nu te poți urmări pe tine însuți');
    }
    const user = await this.prisma.user.findUnique({
      where: { id: followingId },
    });
    if (!user) {
      throw new NotFoundException('Utilizatorul nu a fost găsit');
    }

    await this.prisma.follow.upsert({
      where: { followerId_followingId: { followerId, followingId } },
      create: { followerId, followingId },
      update: {},
    });
    return { message: 'Urmărești acest utilizator' };
  }

  async unfollowUser(followerId: string, followingId: string) {
    await this.prisma.follow
      .delete({
        where: { followerId_followingId: { followerId, followingId } },
      })
      .catch(() => {});
    return { message: 'Nu mai urmărești acest utilizator' };
  }

  async getFollowStatus(currentUserId: string, profileUserId: string) {
    const [isFollowing, followersCount, followingCount] = await Promise.all([
      this.prisma.follow.findUnique({
        where: {
          followerId_followingId: {
            followerId: currentUserId,
            followingId: profileUserId,
          },
        },
      }),
      this.prisma.follow.count({ where: { followingId: profileUserId } }),
      this.prisma.follow.count({ where: { followerId: profileUserId } }),
    ]);
    return {
      isFollowing: isFollowing !== null,
      followersCount,
      followingCount,
    };
  }

  /**
   * "Vânzători/schimbători favoriți" - userii pe care îi urmărește userul
   * curent, ca să îi poată regăsi rapid dintr-o listă dedicată, nu doar din
   * badge-ul de follow de pe fiecare profil vizitat în parte.
   */
  async getFollowing(userId: string) {
    const follows = await this.prisma.follow.findMany({
      where: { followerId: userId },
      include: {
        following: {
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
        },
      },
      orderBy: { createdAt: 'desc' },
    });
    return follows.map((f) => ({
      ...f.following,
      name: publicName(f.following),
    }));
  }

  /**
   * Membri "activi" - cei cu cele mai recente anunțuri noi, ca punct de
   * plecare simplu pentru descoperirea altor utilizatori (fără un scor de
   * activitate complex).
   */
  async getActiveMembers() {
    const recentListings = await this.prisma.userBook.findMany({
      orderBy: { createdAt: 'desc' },
      take: 100,
      select: { userId: true },
    });

    const orderedUserIds: string[] = [];
    const seen = new Set<string>();
    for (const listing of recentListings) {
      if (!seen.has(listing.userId)) {
        seen.add(listing.userId);
        orderedUserIds.push(listing.userId);
      }
      if (orderedUserIds.length >= 10) break;
    }

    const users = await this.prisma.user.findMany({
      where: { id: { in: orderedUserIds } },
      select: {
        id: true,
        name: true,
        city: true,
        profileImage: true,
        rating: true,
        booksExchangedCount: true,
      },
    });
    const byId = new Map(users.map((u) => [u.id, u]));
    return orderedUserIds
      .map((id) => byId.get(id))
      .filter((u) => u !== undefined);
  }

  /**
   * Notifică followerii unui user când acesta adaugă o carte nouă -
   * best-effort, nu trebuie să blocheze adăugarea cărții dacă eșuează.
   */
  async notifyFollowersOfNewBook(userId: string, bookTitle: string) {
    try {
      const follows = await this.prisma.follow.findMany({
        where: { followingId: userId },
        select: { followerId: true },
      });
      const author = await this.prisma.user.findUnique({
        where: { id: userId },
      });
      await Promise.all(
        follows.map((f) =>
          this.notifications.create(
            f.followerId,
            'FOLLOWED_USER_NEW_BOOK',
            `${author?.name ?? 'Un utilizator pe care îl urmărești'} a adăugat o carte nouă: "${bookTitle}"`,
            { userId },
          ),
        ),
      );
    } catch (error) {
      this.logger.warn(
        `Nu am putut notifica followerii lui ${userId}: ${error}`,
      );
    }
  }
}
