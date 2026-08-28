import { Test, TestingModule } from '@nestjs/testing';
import { ConflictException, NotFoundException } from '@nestjs/common';
import { WishlistService } from './wishlist.service';
import { PrismaService } from '../prisma/prisma.service';
import { NotificationsService } from '../notifications/notifications.service';
import { ListingScoreService } from '../books/listing-score.service';

describe('WishlistService', () => {
  let service: WishlistService;
  let prisma: {
    book: Record<string, jest.Mock>;
    userBook: Record<string, jest.Mock>;
    wishlistItem: Record<string, jest.Mock>;
    user: Record<string, jest.Mock>;
    auctionWatch: Record<string, jest.Mock>;
  };
  let notifications: jest.Mocked<NotificationsService>;

  beforeEach(async () => {
    prisma = {
      book: { findUnique: jest.fn() },
      // Implicit: userul NU are un anunț pentru titlu (nu e cartea lui).
      userBook: { findFirst: jest.fn().mockResolvedValue(null) },
      wishlistItem: {
        findFirst: jest.fn().mockResolvedValue(null),
        create: jest.fn(),
        deleteMany: jest.fn(),
        findMany: jest.fn(),
        count: jest.fn().mockResolvedValue(0),
      },
      user: { findUnique: jest.fn().mockResolvedValue({ isPremium: false }) },
      auctionWatch: { count: jest.fn().mockResolvedValue(0) },
    };

    const module: TestingModule = await Test.createTestingModule({
      providers: [
        WishlistService,
        { provide: PrismaService, useValue: prisma },
        { provide: NotificationsService, useValue: { create: jest.fn() } },
        {
          provide: ListingScoreService,
          useValue: {
            recordWishlistAdd: jest.fn().mockResolvedValue(undefined),
          },
        },
      ],
    }).compile();

    service = module.get(WishlistService);
    notifications = module.get(NotificationsService);
  });

  describe('add', () => {
    it('respinge daca cartea nu exista', async () => {
      prisma.book.findUnique.mockResolvedValue(null);

      await expect(service.add('user-1', 'book-1')).rejects.toThrow(
        NotFoundException,
      );
    });

    it('respinge daca e deja pe wishlist', async () => {
      prisma.book.findUnique.mockResolvedValue({ id: 'book-1' });
      prisma.wishlistItem.findFirst.mockResolvedValue({ id: 'wl-1' });

      await expect(service.add('user-1', 'book-1')).rejects.toThrow(
        ConflictException,
      );
    });

    it('respinge daca e propria carte (userul are deja un anunt activ)', async () => {
      prisma.book.findUnique.mockResolvedValue({ id: 'book-1' });
      prisma.userBook.findFirst.mockResolvedValue({ id: 'ub-1' });

      await expect(service.add('user-1', 'book-1')).rejects.toThrow(
        ConflictException,
      );
      expect(prisma.wishlistItem.create).not.toHaveBeenCalled();
    });

    it('permite wishlist daca singurul anunt al userului pentru titlu a fost deja dat la schimb', async () => {
      // userBook.findFirst e chemat cu permanentlyTransferred: false in
      // where, deci mock-ul care simuleaza filtrarea Prisma intoarce null.
      prisma.book.findUnique.mockResolvedValue({ id: 'book-1' });
      prisma.userBook.findFirst.mockResolvedValue(null);
      prisma.wishlistItem.findFirst.mockResolvedValue(null);
      prisma.wishlistItem.create.mockResolvedValue({ id: 'wl-new' });

      await expect(service.add('user-1', 'book-1')).resolves.toEqual({ id: 'wl-new' });
      expect(prisma.userBook.findFirst).toHaveBeenCalledWith({
        where: { userId: 'user-1', bookId: 'book-1', deletedAt: null, permanentlyTransferred: false },
        select: { id: true },
      });
    });

    it('adauga cartea pe wishlist', async () => {
      prisma.book.findUnique.mockResolvedValue({ id: 'book-1' });
      prisma.wishlistItem.findFirst.mockResolvedValue(null);
      prisma.wishlistItem.create.mockResolvedValue({ id: 'wl-new' });

      const result = await service.add('user-1', 'book-1');

      expect(result).toEqual({ id: 'wl-new' });
    });

    it('leaga favoritul de anuntul de pe care s-a apasat inima', async () => {
      prisma.book.findUnique.mockResolvedValue({ id: 'book-1' });
      // Primul findFirst (validarea anuntului) intoarce anuntul, restul null.
      prisma.userBook.findFirst
        .mockResolvedValueOnce({ id: 'ub-1' })
        .mockResolvedValue(null);
      prisma.wishlistItem.findFirst.mockResolvedValue(null);
      prisma.wishlistItem.create.mockResolvedValue({ id: 'wl-new' });

      await service.add('user-1', 'book-1', 'ub-1');

      expect(prisma.wishlistItem.create).toHaveBeenCalledWith({
        data: { userId: 'user-1', bookId: 'book-1', userBookId: 'ub-1' },
        include: { book: true },
      });
    });

    it('respinge un anunt care nu e al titlului cerut', async () => {
      prisma.book.findUnique.mockResolvedValue({ id: 'book-1' });
      prisma.userBook.findFirst.mockResolvedValue(null);

      await expect(service.add('user-1', 'book-1', 'ub-altul')).rejects.toThrow(
        NotFoundException,
      );
      expect(prisma.wishlistItem.create).not.toHaveBeenCalled();
    });

    it('scoate de la favorite doar anuntul cerut', async () => {
      await service.removeListing('user-1', 'ub-1');

      expect(prisma.wishlistItem.deleteMany).toHaveBeenCalledWith({
        where: { userId: 'user-1', userBookId: 'ub-1' },
      });
    });
  });

  describe('notifyWishlistedUsers', () => {
    it('notifica pe toti cei care au cartea pe wishlist, exceptand userul curent', async () => {
      prisma.wishlistItem.findMany.mockResolvedValue([
        { userId: 'user-2', book: { title: 'Cartea X' } },
        { userId: 'user-3', book: { title: 'Cartea X' } },
      ]);

      await service.notifyWishlistedUsers('book-1', 'user-1');

      expect(prisma.wishlistItem.findMany).toHaveBeenCalledWith({
        where: { bookId: 'book-1', userId: { not: 'user-1' } },
        include: { book: true },
        distinct: ['userId'],
      });
      expect(notifications.create).toHaveBeenCalledTimes(2);
      expect(notifications.create).toHaveBeenCalledWith(
        'user-2',
        'WISHLIST_BOOK_AVAILABLE',
        expect.stringContaining('Cartea X'),
        { bookId: 'book-1' },
      );
    });
  });
});
