import { Test, TestingModule } from '@nestjs/testing';
import { ConflictException, NotFoundException } from '@nestjs/common';
import { WishlistService } from './wishlist.service';
import { PrismaService } from '../prisma/prisma.service';
import { NotificationsService } from '../notifications/notifications.service';

describe('WishlistService', () => {
  let service: WishlistService;
  let prisma: {
    book: Record<string, jest.Mock>;
    wishlistItem: Record<string, jest.Mock>;
    user: Record<string, jest.Mock>;
    auctionWatch: Record<string, jest.Mock>;
  };
  let notifications: jest.Mocked<NotificationsService>;

  beforeEach(async () => {
    prisma = {
      book: { findUnique: jest.fn() },
      wishlistItem: {
        findUnique: jest.fn(),
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
      prisma.wishlistItem.findUnique.mockResolvedValue({ id: 'wl-1' });

      await expect(service.add('user-1', 'book-1')).rejects.toThrow(
        ConflictException,
      );
    });

    it('adauga cartea pe wishlist', async () => {
      prisma.book.findUnique.mockResolvedValue({ id: 'book-1' });
      prisma.wishlistItem.findUnique.mockResolvedValue(null);
      prisma.wishlistItem.create.mockResolvedValue({ id: 'wl-new' });

      const result = await service.add('user-1', 'book-1');

      expect(result).toEqual({ id: 'wl-new' });
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
