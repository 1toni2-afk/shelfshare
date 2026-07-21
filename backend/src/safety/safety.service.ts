import {
  BadRequestException,
  ForbiddenException,
  Injectable,
  NotFoundException,
} from '@nestjs/common';
import { PrismaService } from '../prisma/prisma.service';
import { ReportUserDto } from './dto/report-user.dto';

@Injectable()
export class SafetyService {
  constructor(private prisma: PrismaService) {}

  async blockUser(blockerId: string, blockedId: string) {
    if (blockerId === blockedId) {
      throw new BadRequestException('Nu te poți bloca pe tine însuți');
    }
    await this.assertUserExists(blockedId);

    await this.prisma.block.upsert({
      where: { blockerId_blockedId: { blockerId, blockedId } },
      create: { blockerId, blockedId },
      update: {},
    });
    return { message: 'Utilizator blocat' };
  }

  async unblockUser(blockerId: string, blockedId: string) {
    await this.prisma.block
      .delete({ where: { blockerId_blockedId: { blockerId, blockedId } } })
      .catch(() => {});
    return { message: 'Utilizator deblocat' };
  }

  async getBlockStatus(userId: string, otherUserId: string) {
    const [blockedByMe, blockedByThem] = await Promise.all([
      this.prisma.block.findUnique({
        where: {
          blockerId_blockedId: { blockerId: userId, blockedId: otherUserId },
        },
      }),
      this.prisma.block.findUnique({
        where: {
          blockerId_blockedId: { blockerId: otherUserId, blockedId: userId },
        },
      }),
    ]);
    return {
      blockedByMe: blockedByMe !== null,
      blockedByThem: blockedByThem !== null,
    };
  }

  async isBlocked(userAId: string, userBId: string): Promise<boolean> {
    const block = await this.prisma.block.findFirst({
      where: {
        OR: [
          { blockerId: userAId, blockedId: userBId },
          { blockerId: userBId, blockedId: userAId },
        ],
      },
    });
    return block !== null;
  }

  async assertNotBlocked(userAId: string, userBId: string) {
    if (await this.isBlocked(userAId, userBId)) {
      throw new ForbiddenException(
        'Nu poți comunica cu acest utilizator - unul dintre voi a blocat conversația',
      );
    }
  }

  async reportUser(
    reporterId: string,
    reportedUserId: string,
    dto: ReportUserDto,
  ) {
    if (reporterId === reportedUserId) {
      throw new BadRequestException('Nu te poți raporta pe tine însuți');
    }
    await this.assertUserExists(reportedUserId);

    return this.prisma.report.create({
      data: {
        reporterId,
        reportedUserId,
        reason: dto.reason,
        details: dto.details,
        userBookId: dto.userBookId,
      },
    });
  }

  private async assertUserExists(userId: string) {
    const user = await this.prisma.user.findUnique({ where: { id: userId } });
    if (!user) {
      throw new NotFoundException('Utilizatorul nu a fost găsit');
    }
  }
}
