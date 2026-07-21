import { Test, TestingModule } from '@nestjs/testing';
import { NotFoundException } from '@nestjs/common';
import { AdminService } from './admin.service';
import { PrismaService } from '../prisma/prisma.service';
import { FeedbackService } from '../feedback/feedback.service';

describe('AdminService', () => {
  let service: AdminService;
  let prisma: {
    user: Record<string, jest.Mock>;
    book: Record<string, jest.Mock>;
    userBook: Record<string, jest.Mock>;
    exchangeRequest: Record<string, jest.Mock>;
  };

  beforeEach(async () => {
    prisma = {
      user: {
        count: jest.fn(),
        findMany: jest.fn(),
        findUnique: jest.fn(),
        update: jest.fn(),
        delete: jest.fn(),
      },
      book: { count: jest.fn(), findUnique: jest.fn(), delete: jest.fn() },
      userBook: {
        count: jest.fn(),
        findMany: jest.fn(),
        findUnique: jest.fn(),
        delete: jest.fn(),
      },
      exchangeRequest: { count: jest.fn() },
    };

    const module: TestingModule = await Test.createTestingModule({
      providers: [
        AdminService,
        { provide: PrismaService, useValue: prisma },
        { provide: FeedbackService, useValue: { getAll: jest.fn() } },
      ],
    }).compile();

    service = module.get(AdminService);
  });

  describe('getStats', () => {
    it('agregheaza statisticile din toate tabelele', async () => {
      prisma.user.count.mockResolvedValueOnce(10).mockResolvedValueOnce(8);
      prisma.book.count.mockResolvedValue(20);
      prisma.userBook.count.mockResolvedValue(25);
      prisma.exchangeRequest.count
        .mockResolvedValueOnce(15)
        .mockResolvedValueOnce(6)
        .mockResolvedValueOnce(4);

      const stats = await service.getStats();

      expect(stats).toEqual({
        users: { total: 10, verified: 8 },
        books: { totalInCatalog: 20, totalListings: 25 },
        exchanges: { total: 15, completed: 6, pending: 4 },
      });
    });
  });

  describe('banUser / unbanUser', () => {
    it('respinge daca userul nu exista', async () => {
      prisma.user.findUnique.mockResolvedValue(null);

      await expect(service.banUser('missing')).rejects.toThrow(
        NotFoundException,
      );
      await expect(service.unbanUser('missing')).rejects.toThrow(
        NotFoundException,
      );
    });

    it('blocheaza userul si ii invalideaza refresh token-ul', async () => {
      prisma.user.findUnique.mockResolvedValue({ id: 'u-1' });
      prisma.user.update.mockResolvedValue({
        id: 'u-1',
        email: 'a@b.com',
        isBanned: true,
      });

      await service.banUser('u-1');

      expect(prisma.user.update).toHaveBeenCalledWith({
        where: { id: 'u-1' },
        data: { isBanned: true, refreshTokenHash: null },
        select: { id: true, email: true, isBanned: true },
      });
    });

    it('deblocheaza userul', async () => {
      prisma.user.findUnique.mockResolvedValue({ id: 'u-1' });
      prisma.user.update.mockResolvedValue({
        id: 'u-1',
        email: 'a@b.com',
        isBanned: false,
      });

      await service.unbanUser('u-1');

      expect(prisma.user.update).toHaveBeenCalledWith({
        where: { id: 'u-1' },
        data: { isBanned: false },
        select: { id: true, email: true, isBanned: true },
      });
    });
  });

  describe('deleteUser / deleteBook / deleteUserBook', () => {
    it('arunca NotFound cand entitatea nu exista', async () => {
      prisma.user.findUnique.mockResolvedValue(null);
      prisma.book.findUnique.mockResolvedValue(null);
      prisma.userBook.findUnique.mockResolvedValue(null);

      await expect(service.deleteUser('x')).rejects.toThrow(NotFoundException);
      await expect(service.deleteBook('x')).rejects.toThrow(NotFoundException);
      await expect(service.deleteUserBook('x')).rejects.toThrow(
        NotFoundException,
      );
    });

    it('sterge entitatea cand exista', async () => {
      prisma.user.findUnique.mockResolvedValue({ id: 'u-1' });
      prisma.user.delete.mockResolvedValue({});

      const result = await service.deleteUser('u-1');

      expect(prisma.user.delete).toHaveBeenCalledWith({ where: { id: 'u-1' } });
      expect(result.message).toContain('șters');
    });
  });

  describe('getInactiveListingsReport', () => {
    it('cere anunturile fara nicio cerere de schimb, cele mai vechi primele', async () => {
      prisma.userBook.findMany.mockResolvedValue([]);

      await service.getInactiveListingsReport();

      expect(prisma.userBook.findMany).toHaveBeenCalledWith(
        expect.objectContaining({
          where: { exchangeRequestsReceived: { none: {} } },
          orderBy: { createdAt: 'asc' },
          take: 100,
        }),
      );
    });
  });
});
