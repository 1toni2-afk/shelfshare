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

/**
 * Importul CSV din „Cărțile mele" citește rafturile Goodreads/StoryGraph.
 *
 * Bugul acoperit aici: până acum ORICE rând devenea anunț, deci un export
 * Goodreads întreg - inclusiv titlurile „to-read" sau doar puse la favorite -
 * ajungea disponibil la schimb.
 */
describe('BooksService - import CSV cu rafturi (Goodreads/StoryGraph)', () => {
  let service: BooksService;
  let prisma: {
    user: { findUnique: jest.Mock };
    userBook: Record<string, jest.Mock>;
    book: Record<string, jest.Mock>;
    bookshelfEntry: Record<string, jest.Mock>;
    wishlistItem: Record<string, jest.Mock>;
    searchLog: Record<string, jest.Mock>;
  };

  let lookup: Record<string, jest.Mock>;

  const csv = (body: string) => Buffer.from(body, 'utf-8');

  beforeEach(async () => {
    lookup = {
      lookupByIsbn: jest.fn().mockResolvedValue(null),
      lookupPrice: jest.fn().mockResolvedValue(null),
      lookupCoverByTitle: jest.fn().mockResolvedValue(null),
    };
    prisma = {
      user: { findUnique: jest.fn().mockResolvedValue({ isStore: false }) },
      userBook: {
        findFirst: jest.fn().mockResolvedValue(null),
        findUnique: jest.fn().mockResolvedValue(null),
        create: jest
          .fn()
          .mockResolvedValue({ id: 'ub-1', book: { title: 'Dune' } }),
        update: jest.fn().mockResolvedValue({}),
        updateMany: jest.fn().mockResolvedValue({ count: 2 }),
      },
      book: {
        // Titlul e deja în catalog: calea fără ISBN îl refolosește, ca importul
        // să nu creeze un duplicat pentru fiecare rând.
        findFirst: jest.fn().mockResolvedValue({ id: 'book-1', title: 'Dune' }),
        findUnique: jest.fn().mockResolvedValue(null),
        create: jest
          .fn()
          .mockResolvedValue({ id: 'book-1', title: 'Dune' }),
      },
      bookshelfEntry: { upsert: jest.fn().mockResolvedValue({}) },
      wishlistItem: {
        findFirst: jest.fn().mockResolvedValue(null),
        create: jest.fn().mockResolvedValue({}),
      },
      searchLog: { create: jest.fn().mockResolvedValue(null) },
    };

    const module: TestingModule = await Test.createTestingModule({
      providers: [
        BooksService,
        { provide: PrismaService, useValue: prisma },
        { provide: StorageService, useValue: {} },
        { provide: WishlistService, useValue: { notifyWishlistedUsers: jest.fn().mockResolvedValue(undefined) } },
        { provide: FollowService, useValue: { notifyFollowersOfNewBook: jest.fn().mockResolvedValue(undefined) } },
        { provide: ReviewsService, useValue: {} },
        { provide: NotificationsService, useValue: {} },
        { provide: BookLookupService, useValue: lookup },
        { provide: ListingScoreService, useValue: {} },
        { provide: SavedSearchesService, useValue: {} },
        { provide: StoresService, useValue: {} },
      ],
    }).compile();

    service = module.get(BooksService);
  });

  it('„to-read" ajunge doar la favorite, fara anunt', async () => {
    const result = await service.importListingsCsv(
      'user-1',
      csv('Title,Author,Exclusive Shelf\nDune,Herbert,to-read\n'),
    );

    expect(result.favorited).toEqual([{ title: 'Dune' }]);
    expect(result.created).toHaveLength(0);
    expect(prisma.userBook.create).not.toHaveBeenCalled();
    expect(prisma.wishlistItem.create).toHaveBeenCalledWith({
      data: { userId: 'user-1', bookId: 'book-1' },
    });
  });

  it('„read" si „currently-reading" ajung pe raft, ca deținute, fara anunt', async () => {
    const result = await service.importListingsCsv(
      'user-1',
      csv('Title,Exclusive Shelf\nDune,read\nDune,currently-reading\n'),
    );

    expect(result.shelved.map((s) => s.status)).toEqual([
      'FINISHED',
      'READING',
    ]);
    expect(result.created).toHaveLength(0);
    expect(prisma.userBook.create).not.toHaveBeenCalled();
    expect(prisma.bookshelfEntry.upsert).toHaveBeenCalledWith(
      expect.objectContaining({
        create: {
          userId: 'user-1',
          bookId: 'book-1',
          status: 'FINISHED',
          owned: true,
        },
      }),
    );
  });

  it('titlul doar la „favorites" printre rafturile libere ramane doar la favorite', async () => {
    const result = await service.importListingsCsv(
      'user-1',
      csv('Title,Bookshelves\nDune,"sci-fi, favorites"\n'),
    );

    expect(result.favorited).toEqual([{ title: 'Dune' }]);
    expect(prisma.userBook.create).not.toHaveBeenCalled();
  });

  it('un rand de stoc (sku/qty/price) ramane anunt, oricare ar fi raftul', async () => {
    const result = await service.importListingsCsv(
      'user-1',
      csv('sku,title,qty,price,Exclusive Shelf\nA-1,Dune,2,30,to-read\n'),
    );

    // Nu ne intereseaza aici tot ciclul de creare (acoperit de addToLibrary),
    // ci doar ca randul a mers pe calea de anunt, nu pe raft.
    expect(result.favorited).toHaveLength(0);
    expect(result.shelved).toHaveLength(0);
    expect(prisma.userBook.create).toHaveBeenCalled();
  });

  it('un CSV fara coloane de raft se comporta exact ca inainte: anunturi', async () => {
    const result = await service.importListingsCsv(
      'user-1',
      csv('title,author\nDune,Herbert\n'),
    );

    expect(result.favorited).toHaveLength(0);
    expect(result.shelved).toHaveLength(0);
    expect(prisma.userBook.create).toHaveBeenCalled();
  });

  it('curata invelisul Excel al ISBN-ului Goodreads si ignora `=""`', async () => {
    prisma.book.findFirst.mockResolvedValue(null);
    prisma.book.findUnique.mockResolvedValue(null);

    await service.importListingsCsv(
      'user-1',
      csv(
        'Title,ISBN,Exclusive Shelf\n' +
          'Dune,"=""0143039954""",read\n' +
          'White Nights,"=""""",read\n',
      ),
    );

    // Primul rand: ISBN curatat de invelisul Excel, cautat ca atare.
    expect(prisma.book.findUnique).toHaveBeenCalledWith({
      where: { isbn: '0143039954' },
    });
    // Al doilea: `=""` nu e un ISBN, deci cautam pe titlu si NU scriem un
    // ISBN fals pe care s-ar dedubla toate cartile fara ISBN.
    expect(prisma.book.findFirst).toHaveBeenCalledWith(
      expect.objectContaining({
        where: expect.objectContaining({
          title: { equals: 'White Nights', mode: 'insensitive' },
        }),
      }),
    );
    const created = prisma.book.create.mock.calls.map(
      (c) => c[0].data as Record<string, unknown>,
    );
    expect(created[0]).toMatchObject({ isbn: '0143039954', title: 'Dune' });
    expect(created[1].isbn).toBeUndefined();
  });

  it('nu cauta extern pentru randurile de raft (fara timeout pe sute de randuri)', async () => {
    prisma.book.findFirst.mockResolvedValue(null);
    prisma.book.findUnique.mockResolvedValue(null);

    await service.importListingsCsv(
      'user-1',
      csv('Title,Exclusive Shelf\nDune,read\n'),
    );

    expect(lookup.lookupByIsbn).not.toHaveBeenCalled();
    expect(lookup.lookupCoverByTitle).not.toHaveBeenCalled();
  });

  it('stergerea in masa atinge doar anunturile proprii, nesterse', async () => {
    const result = await service.deleteUserBooks('user-1', ['ub-1', 'ub-2']);

    expect(prisma.userBook.updateMany).toHaveBeenCalledWith({
      where: { id: { in: ['ub-1', 'ub-2'] }, userId: 'user-1', deletedAt: null },
      data: { deletedAt: expect.any(Date), availableForSwap: false },
    });
    expect(result).toEqual({ deleted: 2, requested: 2 });
  });
});
