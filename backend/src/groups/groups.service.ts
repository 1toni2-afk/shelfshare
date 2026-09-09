import { BadRequestException, ForbiddenException, Injectable, NotFoundException } from '@nestjs/common';
import { PrismaService } from '../prisma/prisma.service';
import { CreateGroupDto } from './dto/create-group.dto';
import { CreatePostDto } from './dto/create-post.dto';
import { CreateEventDto } from './dto/create-event.dto';
import { ReportPostDto } from './dto/report-post.dto';
import { publicName } from '../common/utils/user-visibility';
import { ReportsService } from '../reports/reports.service';
import { NotificationsService } from '../notifications/notifications.service';

const MEMBER_SELECT = {
  id: true,
  name: true,
  username: true,
  nameVisible: true,
  profileImage: true,
} as const;

const WITH_DETAIL = {
  members: { include: { user: { select: MEMBER_SELECT } }, orderBy: { joinedAt: 'asc' as const } },
  posts: {
    // Postările ascunse automat de moderare (vezi ReportsService.applyAutoHide)
    // ies din grup, dar rămân în baza de date pentru moderatorul care judecă
    // raportul - și pot fi repuse dacă raportul nu stă în picioare.
    where: { hiddenAt: null },
    include: { author: { select: MEMBER_SELECT } },
    orderBy: { createdAt: 'desc' as const },
    take: 50,
  },
  events: { orderBy: { eventAt: 'asc' as const } },
  _count: { select: { members: true } },
};

/// "Groups" (Milestone 5) - unifică Book Clubs, Reading Groups și Community
/// Events într-o singură entitate: membri + discuții + evenimente opționale.
@Injectable()
export class GroupsService {
  constructor(
    private prisma: PrismaService,
    private reports: ReportsService,
    private notifications: NotificationsService,
  ) {}

  private sanitizeMembers<T extends { user: { name: string | null; nameVisible: boolean } }>(
    members: T[],
  ): T[] {
    return members.map((m) => ({ ...m, user: { ...m.user, name: publicName(m.user) } }));
  }

  async createGroup(userId: string, dto: CreateGroupDto) {
    const group = await this.prisma.$transaction(async (tx) => {
      const created = await tx.group.create({
        data: { name: dto.name, description: dto.description, creatorId: userId, isPublic: dto.isPublic ?? true },
      });
      await tx.groupMember.create({ data: { groupId: created.id, userId, role: 'ADMIN' } });
      return created;
    });
    return this.getGroup(group.id, userId);
  }

  async getPublicGroups() {
    return this.prisma.group.findMany({
      where: { isPublic: true },
      include: { _count: { select: { members: true } } },
      orderBy: { updatedAt: 'desc' },
    });
  }

  async getMyGroups(userId: string) {
    const memberships = await this.prisma.groupMember.findMany({
      where: { userId },
      include: { group: { include: { _count: { select: { members: true } } } } },
      orderBy: { joinedAt: 'desc' },
    });
    return memberships.map((m) => m.group);
  }

  async getGroup(id: string, requestingUserId?: string) {
    const group = await this.prisma.group.findUnique({ where: { id }, include: WITH_DETAIL });
    if (!group) {
      throw new NotFoundException('Grupul nu a fost găsit');
    }
    const isMember = requestingUserId
      ? group.members.some((m) => m.userId === requestingUserId)
      : false;
    if (!group.isPublic && !isMember) {
      throw new NotFoundException('Grupul nu a fost găsit');
    }
    return {
      ...group,
      members: this.sanitizeMembers(group.members),
      posts: group.posts.map((p) => ({ ...p, author: { ...p.author, name: publicName(p.author) } })),
      isMember,
      isAdmin: group.members.some((m) => m.userId === requestingUserId && m.role === 'ADMIN'),
    };
  }

  async joinGroup(id: string, userId: string) {
    const group = await this.prisma.group.findUnique({ where: { id } });
    if (!group) {
      throw new NotFoundException('Grupul nu a fost găsit');
    }
    if (!group.isPublic) {
      throw new ForbiddenException('Acest grup este privat');
    }
    await this.prisma.groupMember.upsert({
      where: { groupId_userId: { groupId: id, userId } },
      create: { groupId: id, userId, role: 'MEMBER' },
      update: {},
    });
    return this.getGroup(id, userId);
  }

  async leaveGroup(id: string, userId: string) {
    const group = await this.prisma.group.findUnique({ where: { id } });
    if (!group) {
      throw new NotFoundException('Grupul nu a fost găsit');
    }
    if (group.creatorId === userId) {
      throw new BadRequestException(
        'Creatorul grupului nu poate pleca - șterge grupul dacă nu mai vrei să existe',
      );
    }
    await this.prisma.groupMember.deleteMany({ where: { groupId: id, userId } });
    return { message: 'Ai părăsit grupul' };
  }

  async deleteGroup(id: string, userId: string) {
    const group = await this.prisma.group.findUnique({ where: { id } });
    if (!group) {
      throw new NotFoundException('Grupul nu a fost găsit');
    }
    if (group.creatorId !== userId) {
      throw new ForbiddenException('Doar creatorul poate șterge grupul');
    }
    await this.prisma.group.delete({ where: { id } });
    return { message: 'Grup șters' };
  }

  async createPost(groupId: string, userId: string, dto: CreatePostDto) {
    await this.assertMember(groupId, userId);
    await this.prisma.groupPost.create({ data: { groupId, authorId: userId, content: dto.content } });
    // Best-effort, ca la restul notificărilor: o postare reușită nu trebuie
    // să cadă fiindcă n-am putut anunța pe cineva.
    this.notifyGroupMembers(groupId, userId).catch(() => {});
    return this.getGroup(groupId, userId);
  }

  /**
   * Anunță ceilalți membri că s-a postat în grup. Notificarea e per GRUP, nu
   * per postare (`upsertUnread` cu `groupId` drept cheie de dedup): într-o
   * discuție aprinsă, zece replici într-un minut ar fi însemnat zece
   * notificări pentru fiecare membru.
   */
  private async notifyGroupMembers(groupId: string, authorId: string) {
    const group = await this.prisma.group.findUnique({
      where: { id: groupId },
      select: {
        name: true,
        members: {
          where: { userId: { not: authorId } },
          select: { userId: true },
          // Plasă de siguranță pentru un grup foarte mare - la fel ca la
          // notificarea pe oraș din books.service.ts.
          take: 500,
        },
      },
    });
    if (!group) return;

    const author = await this.prisma.user.findUnique({
      where: { id: authorId },
      select: { name: true, username: true, nameVisible: true },
    });
    // publicName întoarce null pentru cine și-a ascuns numele real -
    // username-ul rămâne mereu vizibil, deci e treapta următoare.
    const authorLabel =
      (author && (publicName(author) ?? author.username)) ?? 'Cineva';
    const message = `${authorLabel} a postat în „${group.name}"`;

    await Promise.all(
      group.members.map((m) =>
        this.notifications
          .upsertUnread(m.userId, 'GROUP_POST', message, { groupId }, 'groupId')
          .catch(() => {}),
      ),
    );
  }

  async reportPost(groupId: string, postId: string, reporterId: string, dto: ReportPostDto) {
    const post = await this.prisma.groupPost.findUnique({ where: { id: postId } });
    if (!post || post.groupId !== groupId) {
      throw new NotFoundException('Postarea nu a fost găsită');
    }
    if (post.authorId === reporterId) {
      throw new BadRequestException('Nu îți poți raporta propria postare');
    }
    return this.reports.create({
      reporterId,
      reportedUserId: post.authorId,
      targetType: 'GROUP_POST',
      targetId: postId,
      reason: dto.reason,
      details: dto.details,
      extra: { groupPostId: postId },
    });
  }

  async createEvent(groupId: string, userId: string, dto: CreateEventDto) {
    await this.assertMember(groupId, userId);
    await this.prisma.groupEvent.create({
      data: {
        groupId,
        title: dto.title,
        description: dto.description,
        eventAt: new Date(dto.eventAt),
        location: dto.location,
      },
    });
    return this.getGroup(groupId, userId);
  }

  private async assertMember(groupId: string, userId: string) {
    const membership = await this.prisma.groupMember.findUnique({
      where: { groupId_userId: { groupId, userId } },
    });
    if (!membership) {
      throw new ForbiddenException('Trebuie să fii membru al grupului pentru asta');
    }
  }
}
