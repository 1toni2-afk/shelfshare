import { Test, TestingModule } from '@nestjs/testing';
import { BadRequestException } from '@nestjs/common';
import { BookMatchService } from './book-match.service';
import { PrismaService } from '../prisma/prisma.service';
import {
  DISCOVERY_BOOST_SWIPES,
  ONBOARDING_SWIPES_TARGET,
  RECALIBRATION_FACTOR,
  discoveryCountFor,
} from './book-match.scoring';

type Book = {
  id: string;
  title: string;
  author: string | null;
  coverUrl: string | null;
  genre: string | null;
  publishedYear: number | null;
  description: string | null;
  popularityScore: number | null;
};

const book = (id: string, genre: string, author = `A-${id}`): Book => ({
  id,
  title: `Titlu ${id}`,
  author,
  coverUrl: null,
  genre,
  publishedYear: 2001,
  description: null,
  popularityScore: null,
});

/// Catalog de test: 6 genuri x 6 titluri, destul cât să existe candidați și
/// pentru profil, și pentru discovery.
const CATALOG: Book[] = [
  'Fantasy',
  'SF',
  'Thriller',
  'Poezie',
  'Istoric',
  'Copii',
].flatMap((genre, gi) =>
  Array.from({ length: 6 }, (_, i) => book(`b${gi}-${i}`, genre)),
);

type MockModel = Record<string, jest.Mock>;

interface PrismaMock {
  user: MockModel;
  book: MockModel;
  bookSwipe: MockModel;
  wishlistItem: MockModel;
  userBook: MockModel;
  userGenreScore: MockModel;
  userAuthorScore: MockModel;
  userEraScore: MockModel;
  recalibrationLog: MockModel;
  $transaction: jest.Mock;
  $queryRaw: jest.Mock;
}

describe('BookMatchService', () => {
  let service: BookMatchService;
  let prisma: PrismaMock;

  /// Ce id-uri a cerut serviciul să fie excluse din interogarea de candidați.
  const excludedIdsFromQuery = (): string[] => {
    const calls = prisma.book.findMany.mock.calls as unknown as [
      { where: { id: { notIn: string[] } } },
    ][];
    return calls[0][0].where.id.notIn;
  };

  /// Argumentul `data` al primului user.update - ce contoare s-au atins.
  const userUpdateData = (): Record<string, unknown> => {
    const calls = prisma.user.update.mock.calls as unknown as [
      { data: Record<string, unknown> },
    ][];
    return calls[0][0].data;
  };

  beforeEach(async () => {
    prisma = {
      user: {
        findUnique: jest.fn().mockResolvedValue({
          onboardingSwipesCount: ONBOARDING_SWIPES_TARGET,
          discoveryBoostSwipesRemaining: 0,
          favoriteGenres: [],
          lastRecalibrationAt: null,
        }),
        update: jest.fn().mockResolvedValue({
          onboardingSwipesCount: 1,
          discoveryBoostSwipesRemaining: 0,
        }),
      },
      book: {
        findMany: jest.fn().mockResolvedValue(CATALOG),
        findUnique: jest.fn(),
      },
      bookSwipe: {
        findMany: jest.fn().mockResolvedValue([]),
        create: jest.fn().mockResolvedValue({ id: 'sw-1' }),
      },
      wishlistItem: {
        findMany: jest.fn().mockResolvedValue([]),
        findFirst: jest.fn().mockResolvedValue(null),
        create: jest.fn().mockResolvedValue({ id: 'wl-1' }),
      },
      userBook: { findMany: jest.fn().mockResolvedValue([]) },
      userGenreScore: {
        findMany: jest.fn().mockResolvedValue([]),
        upsert: jest.fn().mockResolvedValue({}),
        update: jest.fn(),
      },
      userAuthorScore: {
        findMany: jest.fn().mockResolvedValue([]),
        upsert: jest.fn().mockResolvedValue({}),
        update: jest.fn(),
      },
      userEraScore: {
        findMany: jest.fn().mockResolvedValue([]),
        upsert: jest.fn().mockResolvedValue({}),
        update: jest.fn(),
      },
      recalibrationLog: { create: jest.fn() },
      $transaction: jest.fn().mockResolvedValue([]),
      // Estimarea de mărime a catalogului (pg_class.reltuples) - sub pragul
      // de eșantionare, ca `sampleCandidates` să ia calea `findMany` de mai
      // sus (comportamentul testat de restul fișierului), nu TABLESAMPLE.
      $queryRaw: jest.fn().mockResolvedValue([{ estimate: CATALOG.length }]),
    };

    const module: TestingModule = await Test.createTestingModule({
      providers: [
        BookMatchService,
        { provide: PrismaService, useValue: prisma },
      ],
    }).compile();

    service = module.get(BookMatchService);
  });

  describe('getQueue - unicitate in sesiune', () => {
    it('exclude din interogare cartile atinse in sesiunea curenta, orice actiune', async () => {
      prisma.bookSwipe.findMany.mockResolvedValue([
        { bookId: 'b0-0', action: 'NO', sessionId: 'sess-1' },
        { bookId: 'b0-1', action: 'SKIP', sessionId: 'sess-1' },
        { bookId: 'b0-2', action: 'YES', sessionId: 'sess-1' },
      ]);

      await service.getQueue('user-1', 'sess-1', 10);

      const excluded = excludedIdsFromQuery();
      expect(excluded).toEqual(
        expect.arrayContaining(['b0-0', 'b0-1', 'b0-2']),
      );
    });

    it('un YES vechi ramane exclus permanent, un NO vechi nu', async () => {
      prisma.bookSwipe.findMany.mockResolvedValue([
        { bookId: 'b0-0', action: 'YES', sessionId: 'sess-veche' },
        { bookId: 'b0-1', action: 'NO', sessionId: 'sess-veche' },
        { bookId: 'b0-2', action: 'SKIP', sessionId: 'sess-veche' },
      ]);

      await service.getQueue('user-1', 'sess-noua', 10);

      const excluded = excludedIdsFromQuery();
      expect(excluded).toContain('b0-0');
      expect(excluded).not.toContain('b0-1');
      expect(excluded).not.toContain('b0-2');
    });

    it('exclude si cartile deja pe wishlist si cele listate de user', async () => {
      prisma.wishlistItem.findMany.mockResolvedValue([{ bookId: 'b1-0' }]);
      prisma.userBook.findMany.mockResolvedValue([{ bookId: 'b1-1' }]);

      await service.getQueue('user-1', 'sess-1', 10);

      const excluded = excludedIdsFromQuery();
      expect(excluded).toEqual(expect.arrayContaining(['b1-0', 'b1-1']));
    });

    it('nu intoarce niciodata acelasi bookId de doua ori intr-un batch', async () => {
      const { cards } = await service.getQueue('user-1', 'sess-1', 20);
      expect(new Set(cards.map((c) => c.bookId)).size).toBe(cards.length);
    });

    it('catalog gol -> batch gol, nu eroare', async () => {
      prisma.book.findMany.mockResolvedValue([]);
      await expect(service.getQueue('user-1', 'sess-1', 20)).resolves.toEqual({
        sessionId: 'sess-1',
        cards: [],
      });
    });
  });

  describe('getQueue - raportul de discovery', () => {
    const scoredUser = () => {
      prisma.user.findUnique.mockResolvedValue({
        onboardingSwipesCount: ONBOARDING_SWIPES_TARGET,
        discoveryBoostSwipesRemaining: 0,
        favoriteGenres: [],
        lastRecalibrationAt: null,
      });
      // Doua genuri „bune", restul necunoscute -> candidati si de profil,
      // si de discovery.
      prisma.userGenreScore.findMany.mockResolvedValue([
        { genre: 'Fantasy', score: 1.2 },
        { genre: 'SF', score: 0.8 },
      ]);
    };

    it('2 din 5 carduri sunt discovery in regim normal', async () => {
      scoredUser();
      const { cards } = await service.getQueue('user-1', 'sess-1', 20);
      expect(cards).toHaveLength(20);
      expect(cards.filter((c) => c.isDiscovery)).toHaveLength(
        discoveryCountFor(20, false),
      );
    });

    it('3 din 5 carduri sunt discovery cat timp boost-ul e activ', async () => {
      scoredUser();
      prisma.user.findUnique.mockResolvedValue({
        onboardingSwipesCount: ONBOARDING_SWIPES_TARGET,
        discoveryBoostSwipesRemaining: 7,
        favoriteGenres: [],
        lastRecalibrationAt: null,
      });

      const { cards } = await service.getQueue('user-1', 'sess-1', 20);
      expect(cards.filter((c) => c.isDiscovery)).toHaveLength(
        discoveryCountFor(20, true),
      );
    });

    it('nu serveste niciodata un gen clar respins, nici ca discovery', async () => {
      scoredUser();
      prisma.userGenreScore.findMany.mockResolvedValue([
        { genre: 'Fantasy', score: 1.2 },
        { genre: 'Thriller', score: -0.9 },
      ]);

      const { cards } = await service.getQueue('user-1', 'sess-1', 20);
      expect(cards.some((c) => c.genre === 'Thriller')).toBe(false);
    });

    it('cardurile de discovery vin din genuri neutre, nu din topul userului', async () => {
      scoredUser();
      const { cards } = await service.getQueue('user-1', 'sess-1', 20);
      const discoveryGenres = cards
        .filter((c) => c.isDiscovery)
        .map((c) => c.genre);
      expect(discoveryGenres.length).toBeGreaterThan(0);
      for (const genre of discoveryGenres) {
        expect(['Fantasy', 'SF']).not.toContain(genre);
      }
    });

    it('doua apeluri consecutive nu dau exact aceeasi coada (esantionare aleatoare)', async () => {
      scoredUser();
      const runs = await Promise.all(
        Array.from({ length: 6 }, () =>
          service.getQueue('user-1', 'sess-1', 10),
        ),
      );
      const signatures = runs.map((r) =>
        r.cards.map((c) => c.bookId).join(','),
      );
      expect(new Set(signatures).size).toBeGreaterThan(1);
    });
  });

  describe('getQueue - cold start', () => {
    it('sub 50 de swipe-uri intinde batch-ul pe cat mai multe genuri', async () => {
      prisma.user.findUnique.mockResolvedValue({
        onboardingSwipesCount: 3,
        discoveryBoostSwipesRemaining: 0,
        favoriteGenres: [],
        lastRecalibrationAt: null,
      });

      const { cards } = await service.getQueue('user-1', 'sess-1', 12);

      expect(cards).toHaveLength(12);
      // Cu 6 genuri in catalog si max 4 titluri per gen, un batch de 12
      // trebuie sa atinga cel putin 3 genuri distincte.
      expect(new Set(cards.map((c) => c.genre)).size).toBeGreaterThanOrEqual(3);
      // La cold start nu marcam nimic drept discovery - inca nu exista profil
      // fata de care ceva sa fie „in afara".
      expect(cards.every((c) => !c.isDiscovery)).toBe(true);
      // Nu s-au citit scorurile: la cold start nu exista inca.
      expect(prisma.userGenreScore.findMany).not.toHaveBeenCalled();
    });
  });

  describe('recordSwipe', () => {
    beforeEach(() => {
      prisma.book.findUnique.mockResolvedValue({
        id: 'b0-0',
        genre: 'Fantasy',
        author: 'Tolkien',
        publishedYear: 1954,
      });
    });

    it('logheaza swipe-ul cu sesiunea si flagul de discovery', async () => {
      await service.recordSwipe('user-1', {
        bookId: 'b0-0',
        action: 'NO',
        sessionId: 'sess-1',
        isDiscovery: true,
      });

      expect(prisma.bookSwipe.create).toHaveBeenCalledWith({
        data: {
          userId: 'user-1',
          bookId: 'b0-0',
          action: 'NO',
          sessionId: 'sess-1',
          isDiscovery: true,
        },
      });
      expect(prisma.wishlistItem.create).not.toHaveBeenCalled();
    });

    it('YES pune cartea pe wishlist cu source BOOK_MATCH', async () => {
      const result = await service.recordSwipe('user-1', {
        bookId: 'b0-0',
        action: 'YES',
        sessionId: 'sess-1',
        isDiscovery: false,
      });

      // Rand „de titlu" (fara userBookId): un YES vrea cartea, nu exemplarul
      // unui anumit anunt - vezi WishlistItem.userBookId din schema.
      expect(prisma.wishlistItem.create).toHaveBeenCalledWith({
        data: { userId: 'user-1', bookId: 'b0-0', source: 'BOOK_MATCH' },
      });
      expect(result.addedToWishlist).toBe(true);
    });

    it('nu suprascrie source-ul unui rand adaugat manual (PERSONAL)', async () => {
      prisma.wishlistItem.findFirst.mockResolvedValue({ id: 'wl-existent' });

      const result = await service.recordSwipe('user-1', {
        bookId: 'b0-0',
        action: 'YES',
        sessionId: 'sess-1',
      });

      // Randul existent ramane neatins, inclusiv source-ul.
      expect(prisma.wishlistItem.create).not.toHaveBeenCalled();
      expect(result.addedToWishlist).toBe(false);
    });

    it('incrementeaza contorul de onboarding cat timp e sub prag', async () => {
      prisma.user.findUnique.mockResolvedValue({
        onboardingSwipesCount: 10,
        discoveryBoostSwipesRemaining: 0,
      });

      await service.recordSwipe('user-1', {
        bookId: 'b0-0',
        action: 'YES',
        sessionId: 'sess-1',
      });

      expect(userUpdateData()).toEqual({
        onboardingSwipesCount: { increment: 1 },
      });
    });

    it('nu mai incrementeaza dupa prag si decrementeaza boost-ul de discovery', async () => {
      prisma.user.findUnique.mockResolvedValue({
        onboardingSwipesCount: ONBOARDING_SWIPES_TARGET,
        discoveryBoostSwipesRemaining: 5,
      });

      await service.recordSwipe('user-1', {
        bookId: 'b0-0',
        action: 'SKIP',
        sessionId: 'sess-1',
      });

      expect(userUpdateData()).toEqual({
        discoveryBoostSwipesRemaining: { decrement: 1 },
      });
    });

    it('nu duce boost-ul sub zero', async () => {
      prisma.user.findUnique.mockResolvedValue({
        onboardingSwipesCount: ONBOARDING_SWIPES_TARGET,
        discoveryBoostSwipesRemaining: 0,
      });

      await service.recordSwipe('user-1', {
        bookId: 'b0-0',
        action: 'SKIP',
        sessionId: 'sess-1',
      });

      expect(userUpdateData()).toEqual({});
    });

    it('recalculeaza exact cele 3 scoruri atinse de carte', async () => {
      const now = new Date();
      prisma.bookSwipe.findMany.mockResolvedValue([
        { action: 'YES', createdAt: now, book: { popularityScore: null } },
      ]);

      const result = await service.recordSwipe('user-1', {
        bookId: 'b0-0',
        action: 'YES',
        sessionId: 'sess-1',
      });

      expect(result.scores.genre?.value).toBe('Fantasy');
      expect(result.scores.author?.value).toBe('Tolkien');
      expect(result.scores.era?.value).toBe('1950s');
      // Sub prag userul e in cold start -> multiplicator 1.3 (popularitate
      // implicita 0.3) peste punctajul de baza.
      expect(result.scores.genre?.score).toBeCloseTo(1.0 * 1.3, 6);
      expect(result.scores.author?.score).toBeCloseTo(1.5 * 1.3, 6);
      expect(result.scores.era?.score).toBeCloseTo(0.5 * 1.3, 6);
      expect(prisma.userGenreScore.upsert).toHaveBeenCalledTimes(1);
      expect(prisma.userAuthorScore.upsert).toHaveBeenCalledTimes(1);
      expect(prisma.userEraScore.upsert).toHaveBeenCalledTimes(1);
    });

    it('cartea fara autor/an atinge doar scorul de gen', async () => {
      prisma.book.findUnique.mockResolvedValue({
        id: 'b0-0',
        genre: 'Fantasy',
        author: null,
        publishedYear: null,
      });

      const result = await service.recordSwipe('user-1', {
        bookId: 'b0-0',
        action: 'NO',
        sessionId: 'sess-1',
      });

      expect(result.scores.author).toBeNull();
      expect(result.scores.era).toBeNull();
      expect(prisma.userAuthorScore.upsert).not.toHaveBeenCalled();
      expect(prisma.userEraScore.upsert).not.toHaveBeenCalled();
    });
  });

  describe('recalibrate', () => {
    it('respinge in cooldown si spune cate zile mai sunt', async () => {
      const daysAgo10 = new Date(Date.now() - 10 * 24 * 60 * 60 * 1000);
      prisma.user.findUnique.mockResolvedValue({
        lastRecalibrationAt: daysAgo10,
      });

      await expect(service.recalibrate('user-1')).rejects.toThrow(
        BadRequestException,
      );
      try {
        await service.recalibrate('user-1');
      } catch (e) {
        const payload = (e as BadRequestException).getResponse() as {
          error: string;
          daysRemaining: number;
          message: string;
        };
        expect(payload.error).toBe('RECALIBRATION_COOLDOWN');
        expect(payload.daysRemaining).toBe(20);
        expect(typeof payload.message).toBe('string');
      }
      expect(prisma.$transaction).not.toHaveBeenCalled();
    });

    it('trece dupa 30 de zile si comprima scorurile la 40%, fara sa stearga randuri', async () => {
      prisma.user.findUnique.mockResolvedValue({
        lastRecalibrationAt: new Date(Date.now() - 31 * 24 * 60 * 60 * 1000),
      });
      prisma.userGenreScore.findMany.mockResolvedValue([
        { genre: 'Fantasy', score: 1.5 },
        { genre: 'Thriller', score: -0.8 },
      ]);
      prisma.userAuthorScore.findMany.mockResolvedValue([
        { author: 'Tolkien', score: 2.0 },
      ]);
      prisma.userEraScore.findMany.mockResolvedValue([
        { era: '1950s', score: 0.5 },
      ]);

      const result = await service.recalibrate('user-1');

      expect(result.scoresBefore.genre).toEqual({
        Fantasy: 1.5,
        Thriller: -0.8,
      });
      expect(result.scoresAfter.genre.Fantasy).toBeCloseTo(
        1.5 * RECALIBRATION_FACTOR,
        10,
      );
      // Semnul negativ se pastreaza, doar se apropie de zero.
      expect(result.scoresAfter.genre.Thriller).toBeCloseTo(-0.32, 10);
      expect(result.scoresAfter.author.Tolkien).toBeCloseTo(0.8, 10);
      expect(result.scoresAfter.era['1950s']).toBeCloseTo(0.2, 10);
      expect(result.discoveryBoostSwipesRemaining).toBe(DISCOVERY_BOOST_SWIPES);
      // update, nu delete: rândurile rămân.
      expect(prisma.userGenreScore.update).toHaveBeenCalledTimes(2);
      expect(prisma.recalibrationLog.create).toHaveBeenCalledTimes(1);
      expect(prisma.$transaction).toHaveBeenCalledTimes(1);
    });

    it('prima recalibrare (fara istoric) e permisa', async () => {
      prisma.user.findUnique.mockResolvedValue({ lastRecalibrationAt: null });
      await expect(service.recalibrate('user-1')).resolves.toBeDefined();
    });
  });

  describe('getStatus', () => {
    it('intoarce progresul, cooldown-ul si topul de genuri', async () => {
      const last = new Date(Date.now() - 5 * 24 * 60 * 60 * 1000);
      prisma.user.findUnique.mockResolvedValue({
        onboardingSwipesCount: 12,
        lastRecalibrationAt: last,
        discoveryBoostSwipesRemaining: 3,
      });
      prisma.userGenreScore.findMany.mockResolvedValue([
        { genre: 'Fantasy', score: 1.2 },
      ]);

      const status = await service.getStatus('user-1');

      expect(status.onboardingSwipesCount).toBe(12);
      expect(status.isOnboarding).toBe(true);
      expect(status.canRecalibrate).toBe(false);
      expect(status.cooldownEndsAt).not.toBeNull();
      expect(status.discoveryBoostSwipesRemaining).toBe(3);
      expect(status.topGenres).toEqual([{ genre: 'Fantasy', score: 1.2 }]);
    });

    it('fara recalibrare anterioara nu exista cooldown', async () => {
      prisma.user.findUnique.mockResolvedValue({
        onboardingSwipesCount: 80,
        lastRecalibrationAt: null,
        discoveryBoostSwipesRemaining: 0,
      });

      const status = await service.getStatus('user-1');

      expect(status.cooldownEndsAt).toBeNull();
      expect(status.canRecalibrate).toBe(true);
      expect(status.isOnboarding).toBe(false);
    });
  });
});
