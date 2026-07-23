import { BadRequestException, ForbiddenException, Injectable, NotFoundException } from '@nestjs/common';
import { PrismaService } from '../prisma/prisma.service';
import { CreateGroupDto } from './dto/create-group.dto';
import { CreatePostDto } from './dto/create-post.dto';
import { CreateEventDto } from './dto/create-event.dto';
import { publicName } from '../common/utils/user-visibility';

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
  constructor(private prisma: PrismaService) {}

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
    return this.getGroup(groupId, userId);
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
