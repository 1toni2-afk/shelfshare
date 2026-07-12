import {
  BadRequestException,
  ForbiddenException,
  Injectable,
  NotFoundException,
} from '@nestjs/common';
import { PrismaService } from '../prisma/prisma.service';
import { CreateExchangeRequestDto } from './dto/create-exchange-request.dto';

const INCLUDE_FULL = {
  requestedBook: { include: { book: true } },
  offeredBook: { include: { book: true } },
  requester: {
    select: {
      id: true,
      name: true,
      city: true,
      rating: true,
      profileImage: true,
    },
  },
  owner: {
    select: {
      id: true,
      name: true,
      city: true,
      rating: true,
      profileImage: true,
    },
  },
} as const;

@Injectable()
export class ExchangesService {
  constructor(private prisma: PrismaService) {}

  async createRequest(requesterId: string, dto: CreateExchangeRequestDto) {
    const requestedBook = await this.prisma.userBook.findUnique({
      where: { id: dto.requestedBookId },
    });
    if (!requestedBook) {
      throw new NotFoundException('Cartea cerută nu a fost găsită');
    }
    if (requestedBook.userId === requesterId) {
      throw new BadRequestException('Nu poți cere propria carte la schimb');
    }
    if (!requestedBook.availableForSwap) {
      throw new BadRequestException(
        'Această carte nu mai este disponibilă la schimb',
      );
    }

    if (dto.offeredBookId) {
      const offeredBook = await this.prisma.userBook.findUnique({
        where: { id: dto.offeredBookId },
      });
      if (!offeredBook) {
        throw new NotFoundException('Cartea oferită nu a fost găsită');
      }
      if (offeredBook.userId !== requesterId) {
        throw new BadRequestException(
          'Poți oferi la schimb doar cărți din biblioteca ta',
        );
      }
      if (!offeredBook.availableForSwap) {
        throw new BadRequestException(
          'Cartea pe care vrei s-o oferi nu este disponibilă',
        );
      }
    }

    return this.prisma.exchangeRequest.create({
      data: {
        requesterId,
        ownerId: requestedBook.userId,
        requestedBookId: dto.requestedBookId,
        offeredBookId: dto.offeredBookId,
        offeredAmount: dto.offeredAmount,
        message: dto.message,
      },
      include: INCLUDE_FULL,
    });
  }

  getSentRequests(userId: string) {
    return this.prisma.exchangeRequest.findMany({
      where: { requesterId: userId },
      include: INCLUDE_FULL,
      orderBy: { createdAt: 'desc' },
    });
  }

  getReceivedRequests(userId: string) {
    return this.prisma.exchangeRequest.findMany({
      where: { ownerId: userId },
      include: INCLUDE_FULL,
      orderBy: { createdAt: 'desc' },
    });
  }

  async getRequest(id: string, userId: string) {
    const request = await this.findOwnedRequest(id, userId);
    return request;
  }

  /**
   * Owner-ul acceptă cererea. Ambele cărți implicate devin indisponibile,
   * cât timp schimbul e în desfășurare (nu mai apar în alte căutări).
   */
  async accept(id: string, userId: string) {
    const request = await this.findRequestForAction(id);
    this.assertIsOwner(request, userId);
    this.assertStatus(request, 'PENDING');

    return this.prisma.$transaction(async (tx) => {
      await tx.userBook.update({
        where: { id: request.requestedBookId },
        data: { availableForSwap: false },
      });
      if (request.offeredBookId) {
        await tx.userBook.update({
          where: { id: request.offeredBookId },
          data: { availableForSwap: false },
        });
      }

      return tx.exchangeRequest.update({
        where: { id },
        data: { status: 'ACCEPTED' },
        include: INCLUDE_FULL,
      });
    });
  }

  async reject(id: string, userId: string) {
    const request = await this.findRequestForAction(id);
    this.assertIsOwner(request, userId);
    this.assertStatus(request, 'PENDING');

    return this.prisma.exchangeRequest.update({
      where: { id },
      data: { status: 'REJECTED' },
      include: INCLUDE_FULL,
    });
  }

  async cancel(id: string, userId: string) {
    const request = await this.findRequestForAction(id);
    this.assertIsRequester(request, userId);
    this.assertStatus(request, 'PENDING');

    return this.prisma.exchangeRequest.update({
      where: { id },
      data: { status: 'CANCELLED' },
      include: INCLUDE_FULL,
    });
  }

  /**
   * Oricare dintre cei doi participanți poate marca schimbul ca finalizat.
   * Incrementăm contorul de cărți schimbate pentru amândoi - folosit
   * pentru rating și statistici pe profil.
   */
  async complete(id: string, userId: string) {
    const request = await this.findRequestForAction(id);
    if (request.requesterId !== userId && request.ownerId !== userId) {
      throw new ForbiddenException('Nu ești parte în acest schimb');
    }
    this.assertStatus(request, 'ACCEPTED');

    return this.prisma.$transaction(async (tx) => {
      await tx.user.update({
        where: { id: request.requesterId },
        data: { booksExchangedCount: { increment: 1 } },
      });
      await tx.user.update({
        where: { id: request.ownerId },
        data: { booksExchangedCount: { increment: 1 } },
      });

      return tx.exchangeRequest.update({
        where: { id },
        data: { status: 'COMPLETED' },
        include: INCLUDE_FULL,
      });
    });
  }

  // ---------- Helpers ----------

  private async findRequestForAction(id: string) {
    const request = await this.prisma.exchangeRequest.findUnique({
      where: { id },
    });
    if (!request) {
      throw new NotFoundException('Cererea de schimb nu a fost găsită');
    }
    return request;
  }

  private async findOwnedRequest(id: string, userId: string) {
    const request = await this.prisma.exchangeRequest.findUnique({
      where: { id },
      include: INCLUDE_FULL,
    });
    if (!request) {
      throw new NotFoundException('Cererea de schimb nu a fost găsită');
    }
    if (request.requesterId !== userId && request.ownerId !== userId) {
      throw new ForbiddenException('Nu ești parte în acest schimb');
    }
    return request;
  }

  private assertIsOwner(request: { ownerId: string }, userId: string) {
    if (request.ownerId !== userId) {
      throw new ForbiddenException('Doar proprietarul cărții poate face asta');
    }
  }

  private assertIsRequester(request: { requesterId: string }, userId: string) {
    if (request.requesterId !== userId) {
      throw new ForbiddenException('Doar solicitantul poate face asta');
    }
  }

  private assertStatus(request: { status: string }, expected: string) {
    if (request.status !== expected) {
      throw new BadRequestException(
        `Acțiunea nu este permisă - cererea are statusul "${request.status}"`,
      );
    }
  }
}
