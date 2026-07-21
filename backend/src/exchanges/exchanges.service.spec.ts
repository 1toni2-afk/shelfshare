import { Test, TestingModule } from '@nestjs/testing';
import { BadRequestException, ForbiddenException } from '@nestjs/common';
import { ExchangesService } from './exchanges.service';
import { PrismaService } from '../prisma/prisma.service';
import { NotificationsService } from '../notifications/notifications.service';

describe('ExchangesService', () => {
  let service: ExchangesService;
  let prisma: {
    userBook: Record<string, jest.Mock>;
    exchangeRequest: Record<string, jest.Mock>;
    user: Record<string, jest.Mock>;
    $transaction: jest.Mock;
  };
  let notifications: jest.Mocked<NotificationsService>;

  const requestedUserBook = {
    id: 'ub-requested',
    userId: 'owner-1',
    availableForSwap: true,
    book: { title: 'Cartea Cerută' },
  };

  const pendingRequest = {
    id: 'ex-1',
    requesterId: 'requester-1',
    ownerId: 'owner-1',
    requestedBookId: 'ub-requested',
    offeredBookId: null,
    status: 'PENDING',
  };

  beforeEach(async () => {
    prisma = {
      userBook: { findUnique: jest.fn(), update: jest.fn() },
      exchangeRequest: {
        create: jest.fn(),
        findMany: jest.fn(),
        findUnique: jest.fn(),
        update: jest.fn(),
      },
      user: { update: jest.fn() },
      $transaction: jest.fn((cb: (tx: unknown) => unknown) => cb(prisma)),
    };

    const module: TestingModule = await Test.createTestingModule({
      providers: [
        ExchangesService,
        { provide: PrismaService, useValue: prisma },
        {
          provide: NotificationsService,
          useValue: { create: jest.fn() },
        },
      ],
    }).compile();

    service = module.get(ExchangesService);
    notifications = module.get(NotificationsService);
  });

  describe('createRequest', () => {
    it('respinge daca solicitantul incearca sa isi ceara propria carte', async () => {
      prisma.userBook.findUnique.mockResolvedValue({
        ...requestedUserBook,
        userId: 'requester-1',
      });

      await expect(
        service.createRequest('requester-1', {
          requestedBookId: 'ub-requested',
        }),
      ).rejects.toThrow(BadRequestException);
    });

    it('respinge daca cartea nu mai e disponibila', async () => {
      prisma.userBook.findUnique.mockResolvedValue({
        ...requestedUserBook,
        availableForSwap: false,
      });

      await expect(
        service.createRequest('requester-1', {
          requestedBookId: 'ub-requested',
        }),
      ).rejects.toThrow('nu mai este disponibilă');
    });

    it('creeaza cererea si notifica proprietarul', async () => {
      prisma.userBook.findUnique.mockResolvedValue(requestedUserBook);
      prisma.exchangeRequest.create.mockResolvedValue({ id: 'ex-new' });

      const result = await service.createRequest('requester-1', {
        requestedBookId: 'ub-requested',
      });

      expect(result).toEqual({ id: 'ex-new' });
      expect(notifications.create).toHaveBeenCalledWith(
        'owner-1',
        'EXCHANGE_REQUEST_RECEIVED',
        expect.stringContaining('Cartea Cerută'),
        { exchangeRequestId: 'ex-new' },
      );
    });

    it('nu esueaza daca trimiterea notificarii pica - cererea deja s-a salvat', async () => {
      prisma.userBook.findUnique.mockResolvedValue(requestedUserBook);
      prisma.exchangeRequest.create.mockResolvedValue({ id: 'ex-new' });
      notifications.create.mockRejectedValue(new Error('notif service down'));

      const result = await service.createRequest('requester-1', {
        requestedBookId: 'ub-requested',
      });

      expect(result).toEqual({ id: 'ex-new' });
    });
  });

  describe('accept', () => {
    it('respinge daca nu esti proprietarul', async () => {
      prisma.exchangeRequest.findUnique.mockResolvedValue(pendingRequest);

      await expect(service.accept('ex-1', 'altcineva')).rejects.toThrow(
        ForbiddenException,
      );
    });

    it('respinge daca cererea nu mai e PENDING', async () => {
      prisma.exchangeRequest.findUnique.mockResolvedValue({
        ...pendingRequest,
        status: 'ACCEPTED',
      });

      await expect(service.accept('ex-1', 'owner-1')).rejects.toThrow(
        BadRequestException,
      );
    });

    it('accepta, marcheaza cartea indisponibila si notifica solicitantul', async () => {
      prisma.exchangeRequest.findUnique.mockResolvedValue(pendingRequest);
      prisma.exchangeRequest.update.mockResolvedValue({
        ...pendingRequest,
        status: 'ACCEPTED',
        requestedBook: { book: { title: 'Cartea Cerută' } },
      });

      const result = await service.accept('ex-1', 'owner-1');

      expect(prisma.userBook.update).toHaveBeenCalledWith({
        where: { id: 'ub-requested' },
        data: { availableForSwap: false },
      });
      expect(notifications.create).toHaveBeenCalledWith(
        'requester-1',
        'EXCHANGE_REQUEST_ACCEPTED',
        expect.stringContaining('Cartea Cerută'),
        { exchangeRequestId: 'ex-1' },
      );
      expect((result as { status: string }).status).toBe('ACCEPTED');
    });
  });

  describe('reject', () => {
    it('respinge daca cererea nu mai e PENDING', async () => {
      prisma.exchangeRequest.findUnique.mockResolvedValue({
        ...pendingRequest,
        status: 'REJECTED',
      });

      await expect(service.reject('ex-1', 'owner-1')).rejects.toThrow(
        BadRequestException,
      );
    });

    it('respinge cererea si notifica solicitantul', async () => {
      prisma.exchangeRequest.findUnique.mockResolvedValue(pendingRequest);
      prisma.exchangeRequest.update.mockResolvedValue({
        ...pendingRequest,
        status: 'REJECTED',
        requestedBook: { book: { title: 'Cartea Cerută' } },
      });

      await service.reject('ex-1', 'owner-1');

      expect(notifications.create).toHaveBeenCalledWith(
        'requester-1',
        'EXCHANGE_REQUEST_REJECTED',
        expect.stringContaining('Cartea Cerută'),
        { exchangeRequestId: 'ex-1' },
      );
    });
  });

  describe('complete', () => {
    it('respinge daca nu esti parte in schimb', async () => {
      prisma.exchangeRequest.findUnique.mockResolvedValue({
        ...pendingRequest,
        status: 'ACCEPTED',
      });

      await expect(service.complete('ex-1', 'strain')).rejects.toThrow(
        ForbiddenException,
      );
    });

    it('respinge daca schimbul nu e ACCEPTED', async () => {
      prisma.exchangeRequest.findUnique.mockResolvedValue(pendingRequest);

      await expect(service.complete('ex-1', 'owner-1')).rejects.toThrow(
        BadRequestException,
      );
    });

    it('finalizeaza si incrementeaza contorul ambilor participanti', async () => {
      prisma.exchangeRequest.findUnique.mockResolvedValue({
        ...pendingRequest,
        status: 'ACCEPTED',
      });
      prisma.exchangeRequest.update.mockResolvedValue({
        ...pendingRequest,
        status: 'COMPLETED',
      });

      await service.complete('ex-1', 'owner-1');

      expect(prisma.user.update).toHaveBeenCalledWith({
        where: { id: 'requester-1' },
        data: { booksExchangedCount: { increment: 1 } },
      });
      expect(prisma.user.update).toHaveBeenCalledWith({
        where: { id: 'owner-1' },
        data: { booksExchangedCount: { increment: 1 } },
      });
    });
  });

  describe('rate', () => {
    const completedRequest = {
      ...pendingRequest,
      status: 'COMPLETED',
      requesterRatingForOwner: null,
      ownerRatingForRequester: null,
    };

    it('respinge daca schimbul nu e COMPLETED', async () => {
      prisma.exchangeRequest.findUnique.mockResolvedValue(pendingRequest);

      await expect(service.rate('ex-1', 'owner-1', 5)).rejects.toThrow(
        BadRequestException,
      );
    });

    it('respinge a doua evaluare a aceluiasi schimb', async () => {
      prisma.exchangeRequest.findUnique.mockResolvedValue({
        ...completedRequest,
        requesterRatingForOwner: 4,
      });

      await expect(service.rate('ex-1', 'requester-1', 5)).rejects.toThrow(
        'Ai evaluat deja',
      );
    });

    it('salveaza rating-ul si recalculeaza media utilizatorului evaluat', async () => {
      // requester-1 evaluează pe owner-1 (proprietarul cărții) cu 5 stele
      prisma.exchangeRequest.findUnique
        .mockResolvedValueOnce(completedRequest) // findRequestForAction in rate()
        .mockResolvedValueOnce(completedRequest); // findOwnedRequest la final
      prisma.exchangeRequest.update.mockResolvedValue(completedRequest);
      prisma.exchangeRequest.findMany.mockResolvedValue([
        { requesterRatingForOwner: 5, ownerRatingForRequester: null },
      ]);
      prisma.user.update.mockResolvedValue({});

      await service.rate('ex-1', 'requester-1', 5);

      expect(prisma.exchangeRequest.update).toHaveBeenCalledWith({
        where: { id: 'ex-1' },
        data: { requesterRatingForOwner: 5 },
      });
      expect(prisma.user.update).toHaveBeenCalledWith({
        where: { id: 'owner-1' },
        data: { rating: 5 },
      });
      // o singura interogare (OR), nu doua findMany separate
      expect(prisma.exchangeRequest.findMany).toHaveBeenCalledTimes(1);
    });
  });
});
