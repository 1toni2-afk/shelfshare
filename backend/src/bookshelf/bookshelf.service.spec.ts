import { Test, TestingModule } from '@nestjs/testing';
import { BookshelfService } from './bookshelf.service';
import { PrismaService } from '../prisma/prisma.service';
import { BookDescriptionService } from '../books/book-description.service';
import { FollowService } from '../follow/follow.service';
import { CatalogMatchService } from '../books/catalog-match.service';

/**
 * My Shelf pe categorii care se suprapun (Deținute / Citite / De citit /
 * Listate). Bugurile acoperite: cărțile citite din Goodreads apăreau „gata de
 * listat" și „Pagina 0 din 230 · 0%" deși erau terminate.
 */
describe('BookshelfService - My Shelf', () => {
  let service: BookshelfService;
  let prisma: {
    book: Record<string, jest.Mock>;
    bookshelfEntry: Record<string, jest.Mock>;
    userBook: Record<string, jest.Mock>;
    readingProgress: Record<string, jest.Mock>;
  };
  let follow: { notifyFollowersOfFinishedBook: jest.Mock };

  const book = (id: string, pageCount: number | null = 230) => ({
    id,
    title: `Carte ${id}`,
    description: 'descriere',
    pageCount,
  });

  beforeEach(async () => {
    prisma = {
      book: { findUnique: jest.fn().mockResolvedValue(book('b1')) },
      bookshelfEntry: {
        findMany: jest.fn().mockResolvedValue([]),
        findUnique: jest.fn().mockResolvedValue(null),
        upsert: jest.fn().mockResolvedValue({}),
        deleteMany: jest.fn().mockResolvedValue({ count: 1 }),
      },
      userBook: { findMany: jest.fn().mockResolvedValue([]) },
      readingProgress: { findMany: jest.fn().mockResolvedValue([]) },
    };
    follow = { notifyFollowersOfFinishedBook: jest.fn().mockResolvedValue(undefined) };

    const module: TestingModule = await Test.createTestingModule({
      providers: [
        BookshelfService,
        { provide: PrismaService, useValue: prisma },
        { provide: BookDescriptionService, useValue: { scheduleBackfill: jest.fn() } },
        { provide: FollowService, useValue: follow },
        { provide: CatalogMatchService, useValue: { findByTitle: jest.fn() } },
      ],
    }).compile();

    service = module.get(BookshelfService);
  });

  describe('getLibrary', () => {
    it('o carte citită apare citită până la capăt, fără progres salvat', async () => {
      prisma.bookshelfEntry.findMany.mockResolvedValue([
        { bookId: 'b1', book: book('b1'), status: 'FINISHED', owned: false, updatedAt: new Date() },
      ]);

      const [item] = await service.getLibrary('u1');

      expect(item).toMatchObject({ currentPage: 230, totalPages: 230, owned: false, listed: false });
    });

    it('un anunț face cartea deținută și listată, chiar fără rând pe raft', async () => {
      prisma.userBook.findMany.mockResolvedValue([
        {
          id: 'ub1',
          bookId: 'b2',
          previousListingId: null,
          availableForSwap: true,
          isForSale: false,
          isAuction: false,
          updatedAt: new Date(),
          book: book('b2'),
        },
      ]);

      const [item] = await service.getLibrary('u1');

      expect(item).toMatchObject({
        bookId: 'b2',
        status: null,
        owned: true,
        listed: true,
        listingId: 'ub1',
      });
    });

    it('cartea primită la schimb și nescoasă în piață e deținută, dar nu listată', async () => {
      prisma.bookshelfEntry.findMany.mockResolvedValue([
        { bookId: 'b3', book: book('b3'), status: 'FINISHED', owned: false, updatedAt: new Date() },
      ]);
      prisma.userBook.findMany.mockResolvedValue([
        {
          id: 'ub3',
          bookId: 'b3',
          previousListingId: 'orig',
          availableForSwap: false,
          isForSale: false,
          isAuction: false,
          updatedAt: new Date(),
          book: book('b3'),
        },
      ]);

      const [item] = await service.getLibrary('u1');

      expect(item).toMatchObject({ owned: true, listed: false, relistSourceId: 'orig' });
    });
  });

  describe('updateEntry', () => {
    it('„deținută" se schimbă fără să atingă statusul de lectură', async () => {
      prisma.bookshelfEntry.findUnique.mockResolvedValue({ status: 'FINISHED', owned: false });

      await service.updateEntry('u1', 'b1', { owned: true });

      expect(prisma.bookshelfEntry.upsert).toHaveBeenCalledWith(
        expect.objectContaining({ update: { status: 'FINISHED', owned: true } }),
      );
      expect(follow.notifyFollowersOfFinishedBook).not.toHaveBeenCalled();
    });

    it('scoasă din Citite dar deținută, cartea rămâne pe raft fără status', async () => {
      prisma.bookshelfEntry.findUnique.mockResolvedValue({ status: 'FINISHED', owned: true });

      await service.updateEntry('u1', 'b1', { status: null });

      expect(prisma.bookshelfEntry.upsert).toHaveBeenCalledWith(
        expect.objectContaining({ update: { status: null, owned: true } }),
      );
      expect(prisma.bookshelfEntry.deleteMany).not.toHaveBeenCalled();
    });

    it('fără status și nedeținută, intrarea se șterge', async () => {
      prisma.bookshelfEntry.findUnique.mockResolvedValue({ status: 'WANT_TO_READ', owned: false });

      await service.updateEntry('u1', 'b1', { status: null });

      expect(prisma.bookshelfEntry.deleteMany).toHaveBeenCalledWith({
        where: { userId: 'u1', bookId: 'b1' },
      });
      expect(prisma.bookshelfEntry.upsert).not.toHaveBeenCalled();
    });

    it('trecerea în „Citită" anunță urmăritorii o singură dată', async () => {
      prisma.bookshelfEntry.findUnique.mockResolvedValue({ status: 'READING', owned: false });

      await service.updateEntry('u1', 'b1', { status: 'FINISHED' });

      expect(follow.notifyFollowersOfFinishedBook).toHaveBeenCalledWith('u1', 'Carte b1', 'b1');
    });
  });
});
