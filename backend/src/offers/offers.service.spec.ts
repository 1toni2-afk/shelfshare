import { Test, TestingModule } from '@nestjs/testing';
import { BadRequestException } from '@nestjs/common';
import { OffersService } from './offers.service';
import { PrismaService } from '../prisma/prisma.service';
import { NotificationsService } from '../notifications/notifications.service';
import { ConversationsService } from '../chat/conversations.service';
import { ListingScoreService } from '../books/listing-score.service';
import { ActivityLogService } from '../activity-log/activity-log.service';

/**
 * Anunțul de tip Schimb cu „sau vinde cu X lei" (UserBook.swapSalePrice)
 * acceptă oferte în bani, dar `isForSale` rămâne false - vezi createOffer.
 * Testele de aici păzesc exact ruptura care rezulta din asta: ofertele se
 * puteau face, dar acceptarea lor pica mereu.
 */
describe('OffersService - anunț de Schimb cu preț de vânzare', () => {
  let service: OffersService;
  let prisma: {
    priceOffer: Record<string, jest.Mock>;
    userBook: Record<string, jest.Mock>;
    user: Record<string, jest.Mock>;
    message: Record<string, jest.Mock>;
    $transaction: jest.Mock;
  };
  let userBookUpdateMany: jest.Mock;

  const offer = {
    id: 'offer-1',
    status: 'PENDING',
    buyerId: 'buyer-1',
    ownerId: 'owner-1',
    userBookId: 'ub-1',
    expiresAt: null,
    amount: { toString: () => '55' },
  };

  const fullOffer = {
    ...offer,
    owner: { name: 'Owner', nameVisible: true },
    buyer: { name: 'Buyer', nameVisible: true },
    userBook: { book: { title: 'Carte' } },
  };

  beforeEach(async () => {
    userBookUpdateMany = jest.fn().mockResolvedValue({ count: 1 });
    prisma = {
      priceOffer: {
        findUnique: jest.fn().mockResolvedValue(offer),
        findUniqueOrThrow: jest.fn().mockResolvedValue(fullOffer),
        findFirst: jest.fn().mockResolvedValue(null),
        // Ofertele „surori" (ceilalți cumpărători în așteptare pe aceeași
        // carte) - anunțate la acceptare/anulare, vezi notifyOtherPendingBuyers.
        findMany: jest.fn().mockResolvedValue([]),
        updateMany: jest.fn().mockResolvedValue({ count: 1 }),
        update: jest.fn().mockResolvedValue(fullOffer),
      },
      userBook: {
        updateMany: userBookUpdateMany,
        findUnique: jest.fn().mockResolvedValue({ salePrice: null }),
      },
      user: { findUnique: jest.fn().mockResolvedValue({ name: 'Owner' }) },
      message: { findFirst: jest.fn().mockResolvedValue(null) },
      $transaction: jest.fn(),
    };
    // Tranzacția primește exact aceleași mock-uri ca prisma - ce ne interesează
    // sunt argumentele cu care se cheamă `userBook.updateMany` înăuntru.
    prisma.$transaction.mockImplementation((callback: (tx: unknown) => unknown) =>
      callback(prisma),
    );

    const module: TestingModule = await Test.createTestingModule({
      providers: [
        OffersService,
        { provide: PrismaService, useValue: prisma },
        { provide: NotificationsService, useValue: { create: jest.fn() } },
        {
          provide: ConversationsService,
          useValue: {
            broadcastPriceOfferUpdate: jest.fn(),
            findOrCreateConversation: jest.fn().mockResolvedValue({ id: 'c1' }),
          },
        },
        { provide: ListingScoreService, useValue: { recordOffer: jest.fn() } },
        { provide: ActivityLogService, useValue: { record: jest.fn() } },
      ],
    }).compile();

    service = module.get(OffersService);
  });

  it('acceptă oferta pe un anunț de Schimb cu preț, nu doar pe unul de vânzare', async () => {
    await service.accept('offer-1', 'owner-1');

    // Revendicarea trebuie să accepte AMBELE forme, altfel un anunț de Schimb
    // cu preț (isForSale = false) n-ar putea fi acceptat niciodată.
    expect(userBookUpdateMany).toHaveBeenCalledWith(
      expect.objectContaining({
        where: expect.objectContaining({
          id: 'ub-1',
          OR: [
            { isForSale: true },
            { availableForSwap: true, swapSalePrice: { not: null } },
          ],
        }),
        data: { isForSale: false, availableForSwap: false },
      }),
    );
  });

  it('rămâne o revendicare atomică: fără rând potrivit, acceptarea pică', async () => {
    userBookUpdateMany.mockResolvedValue({ count: 0 });

    await expect(service.accept('offer-1', 'owner-1')).rejects.toThrow(
      BadRequestException,
    );
  });

  it('la anulare NU transformă un anunț de Schimb într-unul de vânzare', async () => {
    prisma.priceOffer.findUnique.mockResolvedValue({
      ...offer,
      status: 'ACCEPTED',
    });
    // Anunț fără preț de vânzare = era un Schimb.
    prisma.userBook.findUnique.mockResolvedValue({ salePrice: null });

    await service.cancel('offer-1', 'owner-1', {
      reason: 'OTHER',
      details: 'test',
    } as never);

    expect(userBookUpdateMany).toHaveBeenCalledWith(
      expect.objectContaining({
        data: { isForSale: false, availableForSwap: true },
      }),
    );
  });

  it('la anulare readuce la vânzare un anunț care chiar avea preț de vânzare', async () => {
    prisma.priceOffer.findUnique.mockResolvedValue({
      ...offer,
      status: 'ACCEPTED',
    });
    prisma.userBook.findUnique.mockResolvedValue({ salePrice: '40' });

    await service.cancel('offer-1', 'owner-1', {
      reason: 'OTHER',
      details: 'test',
    } as never);

    expect(userBookUpdateMany).toHaveBeenCalledWith(
      expect.objectContaining({
        data: { isForSale: true, availableForSwap: true },
      }),
    );
  });
});
