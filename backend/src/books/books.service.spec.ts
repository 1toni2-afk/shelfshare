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
import { ROMANIAN_CITY_COORDINATES } from '../common/constants/romanian-city-coordinates';

describe('BooksService', () => {
  let service: BooksService;
  let prisma: {
    userBook: Record<string, jest.Mock>;
    priceOffer: Record<string, jest.Mock>;
    exchangeRequest: Record<string, jest.Mock>;
  };
  let listingScore: { scoresFor: jest.Mock };

  beforeEach(async () => {
    prisma = {
      userBook: {
        findMany: jest.fn(),
        findUnique: jest.fn(),
        findFirst: jest.fn(),
        update: jest.fn(),
      },
      priceOffer: { findFirst: jest.fn().mockResolvedValue(null) },
      exchangeRequest: { findFirst: jest.fn().mockResolvedValue(null) },
    };
    listingScore = { scoresFor: jest.fn() };

    const module: TestingModule = await Test.createTestingModule({
      providers: [
        BooksService,
        { provide: PrismaService, useValue: prisma },
        {
          provide: StorageService,
          useValue: { getPublicUrl: (p: string) => `https://cdn.test/${p}` },
        },
        {
          provide: WishlistService,
          useValue: {
            notifyPriceChanged: jest.fn().mockResolvedValue(undefined),
            notifyWishlistedUsers: jest.fn().mockResolvedValue(undefined),
          },
        },
        { provide: FollowService, useValue: {} },
        { provide: NotificationsService, useValue: {} },
        { provide: BookLookupService, useValue: {} },
        { provide: ListingScoreService, useValue: listingScore },
        {
          provide: SavedSearchesService,
          useValue: {
            notifyOnNewListing: jest.fn().mockResolvedValue(undefined),
            notifyOnPriceSet: jest.fn().mockResolvedValue(undefined),
          },
        },
      ],
    }).compile();

    service = module.get(BooksService);
  });

  describe('updateUserBook - pretul redus si cooldown-ul de 72h', () => {
    const HOUR = 60 * 60 * 1000;
    /** Anunț la vânzare cu 50 lei, cu ultima modificare de preț acum `agoMs`. */
    const listing = (agoMs: number | null, salePrice = 50) => ({
      id: 'ub-1',
      userId: 'user-1',
      isForSale: true,
      salePrice,
      photos: ['p.jpg'],
      permanentlyTransferred: false,
      priceUpdatedAt: agoMs == null ? null : new Date(Date.now() - agoMs),
      book: {},
      user: { id: 'user-1', name: 'Ana', nameVisible: true },
    });

    it('retine pretul vechi cand pretul scade', async () => {
      prisma.userBook.findUnique.mockResolvedValue(listing(null));
      prisma.userBook.update.mockResolvedValue({ ...listing(null), book: {} });

      await service.updateUserBook('user-1', 'ub-1', { salePrice: 35 });

      const data = prisma.userBook.update.mock.calls[0][0].data;
      expect(data.previousSalePrice).toBe(50);
      expect(data.priceUpdatedAt).toBeInstanceOf(Date);
    });

    it('sterge pretul vechi cand pretul creste - nu mai e o reducere', async () => {
      prisma.userBook.findUnique.mockResolvedValue(listing(null));
      prisma.userBook.update.mockResolvedValue({ ...listing(null), book: {} });

      await service.updateUserBook('user-1', 'ub-1', { salePrice: 70 });

      expect(prisma.userBook.update.mock.calls[0][0].data.previousSalePrice).toBeNull();
    });

    it('respinge o a doua modificare in mai putin de 72h', async () => {
      prisma.userBook.findUnique.mockResolvedValue(listing(10 * HOUR));

      await expect(
        service.updateUserBook('user-1', 'ub-1', { salePrice: 35 }),
      ).rejects.toThrow(/62 de ore/);
      expect(prisma.userBook.update).not.toHaveBeenCalled();
    });

    it('permite modificarea dupa ce trec 72h', async () => {
      prisma.userBook.findUnique.mockResolvedValue(listing(73 * HOUR));
      prisma.userBook.update.mockResolvedValue({ ...listing(null), book: {} });

      await service.updateUserBook('user-1', 'ub-1', { salePrice: 35 });

      expect(prisma.userBook.update).toHaveBeenCalled();
    });

    it('nu declanseaza cooldown-ul cand pretul trimis e acelasi', async () => {
      // Sheet-ul de editare trimite mereu salePrice, chiar daca userul a
      // schimbat doar starea cartii - asta nu trebuie sa consume cooldown-ul.
      prisma.userBook.findUnique.mockResolvedValue(listing(HOUR));
      prisma.userBook.update.mockResolvedValue({ ...listing(null), book: {} });

      await service.updateUserBook('user-1', 'ub-1', { salePrice: 50 });

      const data = prisma.userBook.update.mock.calls[0][0].data;
      expect(data.priceUpdatedAt).toBeUndefined();
      expect(data.previousSalePrice).toBeUndefined();
    });
  });

  describe('getMapCities', () => {
    it('agrega numarul de carti disponibile per oras', async () => {
      prisma.userBook.findMany.mockResolvedValue([
        { user: { city: 'Cluj-Napoca' } },
        { user: { city: 'Cluj-Napoca' } },
        { user: { city: 'București' } },
      ]);

      const result = await service.getMapCities();

      // Coordonatele vin din tabelul generat, nu scrise de mână aici: fișierul
      // se regenerează din Wikidata, iar testul verifică agregarea per oraș,
      // nu valorile exacte ale coordonatelor.
      expect(result).toEqual(
        expect.arrayContaining([
          {
            city: 'Cluj-Napoca',
            ...ROMANIAN_CITY_COORDINATES['Cluj-Napoca'],
            count: 2,
          },
          {
            city: 'București',
            ...ROMANIAN_CITY_COORDINATES['București'],
            count: 1,
          },
        ]),
      );
      expect(result).toHaveLength(2);
    });

    it('ignora anunturile fara oras sau cu oras necunoscut', async () => {
      prisma.userBook.findMany.mockResolvedValue([
        { user: { city: null } },
        { user: { city: 'Oraș Inexistent' } },
      ]);

      const result = await service.getMapCities();

      expect(result).toEqual([]);
    });

    it('interogheaza doar cartile disponibile la schimb', async () => {
      prisma.userBook.findMany.mockResolvedValue([]);

      await service.getMapCities();

      expect(prisma.userBook.findMany).toHaveBeenCalledWith({
        where: { availableForSwap: true },
        select: { user: { select: { city: true } } },
      });
    });
  });

  describe('searchLibrary - sortare implicită (popularity)', () => {
    it('sortează după scor descrescător, promovate primele, fallback pe cele mai noi', async () => {
      const now = new Date('2026-08-18T00:00:00Z');
      const older = new Date('2026-08-01T00:00:00Z');
      // Candidați: b are cel mai mare scor; c e promovat, deci trece înaintea
      // lui b deși are scor mai mic; a și d n-au scor (rămân după b/c,
      // ordonați între ei după createdAt desc).
      const candidates = [
        { id: 'a', isPromoted: false, createdAt: older },
        { id: 'b', isPromoted: false, createdAt: older },
        { id: 'c', isPromoted: true, createdAt: older },
        { id: 'd', isPromoted: false, createdAt: now },
      ];
      prisma.userBook.findMany.mockImplementation(
        (args: { select?: unknown }) => {
          if (args.select) return Promise.resolve(candidates);
          return Promise.resolve(
            candidates.map((c) => ({
              ...c,
              book: {},
              user: { name: 'Test', nameVisible: true },
              photos: [],
            })),
          );
        },
      );
      listingScore.scoresFor.mockResolvedValue(
        new Map([
          ['b', 42],
          ['c', 10],
        ]),
      );

      const result = await service.searchLibrary({ limit: 20, offset: 0 });

      expect(result.items.map((i: { id: string }) => i.id)).toEqual([
        'c',
        'b',
        'd',
        'a',
      ]);
    });
  });
  // Regresie de confidentialitate: `hideSaleListingsPublic` etc. inseamna
  // „nu-mi arata acest tip de anunt in cautare/discover public". searchLibrary
  // trebuie sa ceara Prisma-ei sa excluda anunturile ale caror tipuri sunt
  // toate ascunse de proprietar - vezi comentariul din searchLibrary.
  describe('confidentialitatea anunturilor pe tip (searchLibrary)', () => {
    it('cere Prisma un OR care exclude fiecare tip cand proprietarul l-a ascuns', async () => {
      prisma.userBook.findMany.mockResolvedValue([]);

      await service.searchLibrary({ limit: 20, offset: 0 });

      expect(prisma.userBook.findMany).toHaveBeenCalledWith(
        expect.objectContaining({
          where: expect.objectContaining({
            OR: [
              {
                availableForSwap: true,
                user: { hideSwapListingsPublic: false },
              },
              {
                isForSale: true,
                salePrice: { gt: 0 },
                user: { hideSaleListingsPublic: false },
              },
              {
                isForSale: true,
                salePrice: { equals: 0 },
                user: { hideDonationListingsPublic: false },
              },
              { isAuction: true, user: { hideAuctionListingsPublic: false } },
            ],
          }),
        }),
      );
    });
  });

  // Regresie de confidentialitate: `nameVisible: false` inseamna „nu-mi arata
  // numele altora". Ambele endpointuri de mai jos sunt PUBLICE (fara
  // autentificare) si sareau peste `publicName()`, deci expuneau numele
  // tocmai userilor care il ascunsesera.
  describe('respectarea setarii nameVisible pe endpointurile publice', () => {
    it('getSimilarBooks nu intoarce numele unui proprietar care l-a ascuns', async () => {
      prisma.userBook.findUnique.mockResolvedValue({
        id: 'ub-1',
        book: { genre: 'SF', author: 'Autor' },
      });
      prisma.userBook.findMany.mockResolvedValue([
        {
          id: 'ub-2',
          photos: [],
          book: { title: 'Alta carte' },
          user: { id: 'u-ascuns', name: 'Ion Popescu', nameVisible: false },
        },
        {
          id: 'ub-3',
          photos: [],
          book: { title: 'A treia' },
          user: { id: 'u-vizibil', name: 'Maria Ionescu', nameVisible: true },
        },
      ]);

      const result = await service.getSimilarBooks('ub-1');

      expect(result[0].user.name).toBeNull();
      expect(result[1].user.name).toBe('Maria Ionescu');
    });

    it('getListingHistory nu intoarce numele proprietarilor anteriori care l-au ascuns', async () => {
      // Lant cu un singur anunt: radacina e chiar anuntul cerut.
      prisma.userBook.findUnique.mockResolvedValue({
        id: 'ub-1',
        previousListingId: null,
      });
      prisma.userBook.findFirst.mockResolvedValue(null);
      prisma.userBook.findMany.mockResolvedValue([
        {
          id: 'ub-1',
          condition: 'GOOD',
          photos: [],
          createdAt: new Date('2026-01-01T00:00:00.000Z'),
          user: { id: 'u-ascuns', name: 'Ion Popescu', nameVisible: false },
        },
      ]);

      const result = await service.getListingHistory('ub-1');

      expect(result).toHaveLength(1);
      expect(result[0].ownerId).toBe('u-ascuns');
      expect(result[0].ownerName).toBeNull();
    });
  });
});
