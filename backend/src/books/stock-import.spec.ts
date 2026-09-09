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
 * Importul de stoc al conturilor de magazin (anticariate).
 *
 * Toate rândurile de aici au un `sku` care EXISTĂ deja, deci se testează exact
 * calea de actualizare - cea care face importul idempotent și pe care se
 * sprijină o sincronizare zilnică. Crearea trece prin addToLibrary, acoperit
 * separat.
 */
describe('BooksService - import de stoc (sku/price/qty)', () => {
  let service: BooksService;
  let prisma: {
    user: { findUnique: jest.Mock };
    userBook: Record<string, jest.Mock>;
    searchLog: Record<string, jest.Mock>;
  };
  let stores: { assertActiveStore: jest.Mock };

  /** Anunțul deja existent pentru sku-ul din CSV. */
  const existingListing = (
    overrides: Partial<{
      id: string;
      salePrice: number | null;
      permanentlyTransferred: boolean;
    }> = {},
  ) => ({
    id: overrides.id ?? 'ub-1',
    salePrice: overrides.salePrice === undefined ? null : overrides.salePrice,
    permanentlyTransferred: overrides.permanentlyTransferred ?? false,
  });

  /** Ultimul `data` trimis către userBook.update. */
  const lastUpdate = () =>
    prisma.userBook.update.mock.calls.at(-1)?.[0] as {
      where: { id: string };
      data: Record<string, unknown>;
    };

  const csv = (body: string) => Buffer.from(body, 'utf-8');

  const setup = async (isStore: boolean) => {
    prisma = {
      user: { findUnique: jest.fn().mockResolvedValue({ isStore }) },
      userBook: {
        findFirst: jest.fn().mockResolvedValue({ id: 'ub-1' }),
        findUnique: jest.fn().mockResolvedValue(existingListing()),
        update: jest.fn().mockResolvedValue({}),
      },
      searchLog: { create: jest.fn().mockResolvedValue(null) },
    };
    stores = { assertActiveStore: jest.fn() };

    const module: TestingModule = await Test.createTestingModule({
      providers: [
        BooksService,
        { provide: PrismaService, useValue: prisma },
        { provide: StorageService, useValue: {} },
        { provide: WishlistService, useValue: {} },
        { provide: FollowService, useValue: {} },
        { provide: ReviewsService, useValue: {} },
        { provide: NotificationsService, useValue: {} },
        { provide: BookLookupService, useValue: {} },
        { provide: ListingScoreService, useValue: {} },
        { provide: SavedSearchesService, useValue: {} },
        { provide: StoresService, useValue: stores },
      ],
    }).compile();

    service = module.get(BooksService);
  };

  describe('cont de magazin', () => {
    beforeEach(() => setup(true));

    it('actualizeaza anuntul existent in loc sa creeze inca unul (idempotenta pe sku)', async () => {
      const result = await service.importListingsCsv(
        'store-1',
        csv('sku,title,price,qty\nA-100,Dune,42.50,3\n'),
      );

      expect(prisma.userBook.findFirst).toHaveBeenCalledWith({
        where: { userId: 'store-1', sku: 'A-100' },
      });
      expect(result.created).toHaveLength(0);
      expect(result.updated).toEqual([{ title: 'Dune', userBookId: 'ub-1' }]);
      expect(lastUpdate().data).toMatchObject({
        stockQuantity: 3,
        availableForSwap: true,
        isForSale: true,
      });
      expect(Number(lastUpdate().data.salePrice)).toBe(42.5);
    });

    it('qty 0 scoate anuntul din piata fara sa il stearga', async () => {
      const result = await service.importListingsCsv(
        'store-1',
        csv('sku,title,qty\nA-100,Dune,0\n'),
      );

      expect(result.delisted).toEqual([{ title: 'Dune', userBookId: 'ub-1' }]);
      expect(lastUpdate().data).toMatchObject({
        stockQuantity: 0,
        availableForSwap: false,
        isForSale: false,
      });
      // Nicio stergere: rândul asteapta urmatoarea sincronizare.
      expect(lastUpdate().data.deletedAt).toBeUndefined();
    });

    it('un rand intors in stoc scoate anuntul din cosul de gunoi', async () => {
      await service.importListingsCsv(
        'store-1',
        csv('sku,title,qty\nA-100,Dune,2\n'),
      );

      expect(lastUpdate().data.deletedAt).toBeNull();
    });

    it('pretul scazut lasa in urma pretul vechi taiat, cel crescut il sterge', async () => {
      prisma.userBook.findUnique.mockResolvedValue(
        existingListing({ salePrice: 50 }),
      );
      await service.importListingsCsv(
        'store-1',
        csv('sku,title,price,qty\nA-100,Dune,40,1\n'),
      );
      expect(lastUpdate().data.previousSalePrice).toBe(50);

      await service.importListingsCsv(
        'store-1',
        csv('sku,title,price,qty\nA-100,Dune,60,1\n'),
      );
      expect(lastUpdate().data.previousSalePrice).toBeNull();
    });

    it('acelasi pret nu atinge priceUpdatedAt - o resincronizare zilnica nu e o schimbare de pret', async () => {
      prisma.userBook.findUnique.mockResolvedValue(
        existingListing({ salePrice: 50 }),
      );
      await service.importListingsCsv(
        'store-1',
        csv('sku,title,price,qty\nA-100,Dune,50,1\n'),
      );
      expect(lastUpdate().data.priceUpdatedAt).toBeUndefined();
    });

    it('accepta virgula zecimala - exporturile romanesti o folosesc', async () => {
      await service.importListingsCsv(
        'store-1',
        csv('sku,title,price\nA-100,Dune,"12,90"\n'),
      );
      expect(Number(lastUpdate().data.salePrice)).toBe(12.9);
    });

    it('citeste antetul indiferent de majuscule si spatii', async () => {
      await service.importListingsCsv(
        'store-1',
        csv(' SKU , Title , QTY \nA-100,Dune,4\n'),
      );
      expect(lastUpdate().data.stockQuantity).toBe(4);
    });

    it('raporteaza un sku repetat in acelasi fisier in loc sa il suprascrie in tacere', async () => {
      const result = await service.importListingsCsv(
        'store-1',
        csv('sku,title,qty\nA-100,Dune,1\nA-100,Dune,9\n'),
      );

      expect(result.updated).toHaveLength(1);
      expect(result.failed).toEqual([
        { title: 'Dune', reason: 'SKU duplicat în fișier: A-100' },
      ]);
      expect(prisma.userBook.update).toHaveBeenCalledTimes(1);
    });

    it('respinge randul cu stoc sau pret invalid, fara sa opreasca restul', async () => {
      const result = await service.importListingsCsv(
        'store-1',
        csv(
          'sku,title,price,qty\n' +
            'A-1,Dune,10,-2\n' +
            'A-2,Solaris,abc,1\n' +
            'A-3,Sapiens,15,1\n',
        ),
      );

      expect(result.failed.map((f) => f.title)).toEqual(['Dune', 'Solaris']);
      expect(result.updated.map((u) => u.title)).toEqual(['Sapiens']);
    });

    it('nu repune in stoc un exemplar deja transferat', async () => {
      prisma.userBook.findUnique.mockResolvedValue(
        existingListing({ permanentlyTransferred: true }),
      );
      const result = await service.importListingsCsv(
        'store-1',
        csv('sku,title,qty\nA-100,Dune,1\n'),
      );

      expect(result.updated).toHaveLength(0);
      expect(result.failed[0].reason).toContain('transferat');
    });
  });

  describe('cont obisnuit', () => {
    beforeEach(() => setup(false));

    it('retine pretul dar NU pune anuntul la vanzare - regula „cel putin o poza" ramane', async () => {
      await service.importListingsCsv(
        'user-1',
        csv('sku,title,price,qty\nA-100,Dune,30,1\n'),
      );

      expect(Number(lastUpdate().data.salePrice)).toBe(30);
      expect(lastUpdate().data.isForSale).toBe(false);
    });
  });

  describe('import in numele unui magazin', () => {
    beforeEach(() => setup(true));

    it('refuza un actor care nu e super-admin', async () => {
      // isSuperAdmin citeste tot prin user.findUnique - fara rol de admin.
      prisma.user.findUnique.mockResolvedValue({ adminRole: null });

      await expect(
        service.importListingsCsv(
          'user-1',
          csv('sku,title,qty\nA-100,Dune,1\n'),
          'store-1',
        ),
      ).rejects.toThrow('super-admin');
      expect(stores.assertActiveStore).not.toHaveBeenCalled();
    });

    it('un super-admin importa pe contul magazinului, nu pe al lui', async () => {
      prisma.user.findUnique
        .mockResolvedValueOnce({ adminRole: { name: 'SUPER_ADMIN' } })
        .mockResolvedValueOnce({ isStore: true });
      stores.assertActiveStore.mockResolvedValue('store-1');

      await service.importListingsCsv(
        'admin-1',
        csv('sku,title,qty\nA-100,Dune,1\n'),
        'store-1',
      );

      expect(stores.assertActiveStore).toHaveBeenCalledWith('store-1');
      expect(prisma.userBook.findFirst).toHaveBeenCalledWith({
        where: { userId: 'store-1', sku: 'A-100' },
      });
    });
  });
});
