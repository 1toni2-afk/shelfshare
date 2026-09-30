import { BadRequestException } from '@nestjs/common';
import { Test, TestingModule } from '@nestjs/testing';
import { BooksService } from './books.service';
import { PrismaService } from '../prisma/prisma.service';
import { StorageService } from '../storage/storage.service';
import { WishlistService } from '../wishlist/wishlist.service';
import { FollowService } from '../follow/follow.service';
import { NotificationsService } from '../notifications/notifications.service';
import { BookLookupService } from './book-lookup.service';
import { ListingScoreService } from './listing-score.service';
import { SavedSearchesService } from '../saved-searches/saved-searches.service';
import { ReviewsService } from '../reviews/reviews.service';
import { StoresService } from '../stores/stores.service';
import { CatalogMatchService } from './catalog-match.service';
import { isAllowedImageUrl } from '../common/utils/image-url';

/**
 * Catalogul e comun: un rând creat din ce a scris un user nu trebuie să poată
 * ocupa un ISBN real cu un titlu inventat, nici să pună pe paginile altora o
 * imagine de pe un server oarecare.
 */
describe('BooksService - încrederea în datele din catalog', () => {
  const STORAGE = 'https://storage.shelfshare.ro/shelfshare';
  const ISBN = '9780441013593';

  let service: BooksService;
  let prisma: {
    book: Record<string, jest.Mock>;
    userBook: Record<string, jest.Mock>;
    $queryRaw: jest.Mock;
  };
  let lookup: Record<string, jest.Mock>;

  const external = {
    isbn: ISBN,
    title: 'Dune',
    author: 'Frank Herbert',
    description: 'Pe Arrakis...',
    coverUrl: 'https://books.google.com/books/content?id=dune',
    publisher: 'Ace',
    publishedYear: 2005,
    pageCount: 528,
    language: 'en',
    genre: 'Fiction',
    subjects: [],
    source: 'google_books' as const,
  };

  const catalogBook = (overrides: Record<string, unknown> = {}) => ({
    id: 'book-1',
    isbn: ISBN,
    title: 'CÂȘTIGĂ BANI PE evil.test',
    author: 'Spam',
    description: null,
    coverUrl: null,
    publisher: null,
    publishedYear: null,
    pageCount: null,
    language: null,
    genre: null,
    source: 'shelf-import',
    curatedAt: null,
    updatedAt: new Date(),
    ...overrides,
  });

  beforeEach(async () => {
    lookup = {
      lookupByIsbn: jest.fn().mockResolvedValue(null),
      lookupPrice: jest.fn().mockResolvedValue(null),
      lookupCoverByTitle: jest.fn().mockResolvedValue(null),
    };
    prisma = {
      book: {
        findUnique: jest.fn().mockResolvedValue(null),
        create: jest.fn(async ({ data }) => ({ id: 'book-new', ...data })),
        update: jest.fn(async ({ data }) => ({ ...catalogBook(), ...data })),
      },
      userBook: {
        create: jest.fn(async ({ data }) => ({ id: 'ub-1', ...data, book: { title: 'x' } })),
        findUnique: jest.fn(),
        update: jest.fn().mockResolvedValue({}),
      },
      $queryRaw: jest.fn().mockResolvedValue([]),
    };

    const module: TestingModule = await Test.createTestingModule({
      providers: [
        BooksService,
        { provide: PrismaService, useValue: prisma },
        {
          provide: StorageService,
          useValue: {
            isAllowedImageUrl: (url: string) => isAllowedImageUrl(url, STORAGE),
            getPublicUrl: (p: string) => (p.startsWith('http') ? p : `${STORAGE}/${p}`),
          },
        },
        { provide: WishlistService, useValue: { notifyWishlistedUsers: jest.fn().mockResolvedValue(undefined) } },
        { provide: FollowService, useValue: {} },
        { provide: ReviewsService, useValue: {} },
        { provide: NotificationsService, useValue: {} },
        { provide: BookLookupService, useValue: lookup },
        { provide: ListingScoreService, useValue: {} },
        { provide: SavedSearchesService, useValue: { notifyOnNewListing: jest.fn().mockResolvedValue(undefined) } },
        { provide: StoresService, useValue: {} },
        { provide: CatalogMatchService, useValue: { findByTitle: jest.fn().mockResolvedValue(null) } },
      ],
    }).compile();

    service = module.get(BooksService);
  });

  const list = (dto: Record<string, unknown>) =>
    service.addToLibrary('user-1', { isbn: ISBN, ...dto }, { silent: true });

  describe('un ISBN ocupat dintr-un import', () => {
    it('e verificat la listare: datele externe le înlocuiesc pe cele ale userului', async () => {
      prisma.book.findUnique.mockResolvedValue(catalogBook());
      lookup.lookupByIsbn.mockResolvedValue(external);

      await list({});

      expect(lookup.lookupByIsbn).toHaveBeenCalledWith(ISBN);
      expect(prisma.book.update).toHaveBeenCalledWith({
        where: { id: 'book-1' },
        data: expect.objectContaining({
          title: 'Dune',
          author: 'Frank Herbert',
          source: 'google_books',
        }),
      });
    });

    it('negăsit extern: devine „manual", ca să nu fie căutat la fiecare listare', async () => {
      prisma.book.findUnique.mockResolvedValue(catalogBook());

      await list({});

      expect(prisma.book.update).toHaveBeenCalledWith({
        where: { id: 'book-1' },
        data: { source: 'manual' },
      });
    });

    it('un „manual" recent nu mai e căutat; unul vechi de o zi, da', async () => {
      prisma.book.findUnique.mockResolvedValue(
        catalogBook({ source: 'manual', updatedAt: new Date(Date.now() - 60_000) }),
      );
      await list({});
      expect(lookup.lookupByIsbn).not.toHaveBeenCalled();

      prisma.book.findUnique.mockResolvedValue(
        catalogBook({
          source: 'manual',
          updatedAt: new Date(Date.now() - 2 * 24 * 60 * 60 * 1000),
        }),
      );
      await list({});
      expect(lookup.lookupByIsbn).toHaveBeenCalledTimes(1);
    });

    it('cărțile din surse externe sau din catalogul curat nu sunt atinse', async () => {
      prisma.book.findUnique.mockResolvedValue(catalogBook({ source: 'google_books' }));
      await list({});
      prisma.book.findUnique.mockResolvedValue(
        catalogBook({ source: 'shelf-import', curatedAt: new Date() }),
      );
      await list({});

      expect(lookup.lookupByIsbn).not.toHaveBeenCalled();
      expect(prisma.book.update).not.toHaveBeenCalled();
    });
  });

  describe('resolveWork', () => {
    it('ignoră sursa și datele clientului când ISBN-ul e cunoscut extern', async () => {
      lookup.lookupByIsbn.mockResolvedValue(external);

      await service.resolveWork({
        title: 'Titlu fals',
        isbn: ISBN,
        coverUrl: 'https://evil.test/pixel.gif',
        source: 'google_books',
      });

      const data = prisma.book.create.mock.calls[0][0].data;
      expect(data).toMatchObject({ isbn: ISBN, title: 'Dune', source: 'google_books' });
      expect(data.coverUrl).toBe(external.coverUrl);
    });

    it('fără potrivire externă: datele clientului, dar marcate „manual", fără coperta străină', async () => {
      await service.resolveWork({
        title: 'Carte românească',
        isbn: ISBN,
        coverUrl: 'https://evil.test/pixel.gif',
        source: 'google_books',
      });

      const data = prisma.book.create.mock.calls[0][0].data;
      expect(data).toMatchObject({ title: 'Carte românească', source: 'manual' });
      expect(data.coverUrl).toBeUndefined();
    });

    it('un ISBN stricat nu ocupă nimic în catalog', async () => {
      await service.resolveWork({ title: 'X', isbn: '=HYPERLINK("x")' });

      expect(lookup.lookupByIsbn).not.toHaveBeenCalled();
      const data = prisma.book.create.mock.calls[0][0].data;
      expect(data).toMatchObject({ isbn: null, source: 'search' });
    });

    it('verifică și cartea deja existentă pe ISBN', async () => {
      prisma.book.findUnique.mockResolvedValue(catalogBook());
      lookup.lookupByIsbn.mockResolvedValue(external);

      const result = await service.resolveWork({ title: 'X', isbn: ISBN });

      expect(result).toEqual({ bookId: 'book-1' });
      expect(prisma.book.update).toHaveBeenCalled();
      expect(prisma.book.create).not.toHaveBeenCalled();
    });
  });

  describe('imagini date ca URL', () => {
    const ownListing = {
      id: 'ub-1',
      userId: 'user-1',
      photos: [] as string[],
      book: { title: 'Dune' },
      user: { name: 'Ana', nameVisible: true },
    };

    it('poza principală de pe o gazdă străină e aruncată la listare, nu refuzată', async () => {
      prisma.book.findUnique.mockResolvedValue(catalogBook({ source: 'google_books' }));

      await list({ mainPhotoUrl: 'https://evil.test/pixel.gif' });
      await list({ mainPhotoUrl: external.coverUrl });

      const created = prisma.userBook.create.mock.calls.map((c) => c[0].data.mainPhotoUrl);
      expect(created).toEqual([undefined, external.coverUrl]);
    });

    it('„poză din URL" refuză orice în afară de stocare și coperțile cunoscute', async () => {
      prisma.userBook.findUnique.mockResolvedValue(ownListing);
      prisma.userBook.update.mockResolvedValue({ ...ownListing, photos: [`${STORAGE}/a.webp`] });

      await expect(
        service.addPhotoUrl('user-1', 'ub-1', 'https://evil.test/pixel.gif'),
      ).rejects.toBeInstanceOf(BadRequestException);
      await expect(
        service.addPhotoUrl('user-1', 'ub-1', `${STORAGE}/user-books/a.webp`),
      ).resolves.toBeDefined();
    });

    it('schimbarea pozei principale spre o gazdă străină e refuzată', async () => {
      prisma.userBook.findUnique.mockResolvedValue(ownListing);

      await expect(
        service.updateUserBook('user-1', 'ub-1', {
          mainPhotoUrl: 'https://evil.test/pixel.gif',
        }),
      ).rejects.toBeInstanceOf(BadRequestException);
      expect(prisma.userBook.update).not.toHaveBeenCalled();
    });
  });
});
