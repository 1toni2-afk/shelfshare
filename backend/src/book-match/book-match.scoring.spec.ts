import {
  DECAY_HALF_LIFE_DAYS,
  RECALIBRATION_FACTOR,
  SWIPE_POINTS,
  aggregateScore,
  coldStartMultiplier,
  compositeBookScore,
  decayWeight,
  discoveryCountFor,
  eraForYear,
  weightedSample,
  yearRangeForEra,
  type ScoredSwipe,
} from './book-match.scoring';

const DAY = 24 * 60 * 60 * 1000;
const NOW = new Date('2026-08-14T12:00:00.000Z');
const daysAgo = (n: number) => new Date(NOW.getTime() - n * DAY);

describe('book-match scoring', () => {
  describe('decayWeight', () => {
    it('un swipe de acum e ponderat 1', () => {
      expect(decayWeight(NOW, NOW)).toBeCloseTo(1, 10);
    });

    it('se injumatateste exact la 180 de zile', () => {
      expect(decayWeight(daysAgo(DECAY_HALF_LIFE_DAYS), NOW)).toBeCloseTo(
        0.5,
        10,
      );
      expect(decayWeight(daysAgo(2 * DECAY_HALF_LIFE_DAYS), NOW)).toBeCloseTo(
        0.25,
        10,
      );
      expect(decayWeight(daysAgo(90), NOW)).toBeCloseTo(Math.SQRT1_2, 10);
    });

    it('nu depaseste 1 pentru un swipe cu data in viitor (clock skew)', () => {
      expect(decayWeight(new Date(NOW.getTime() + 5 * DAY), NOW)).toBe(1);
    });
  });

  describe('SWIPE_POINTS', () => {
    it('Yes e pozitiv, No negativ, Skip penalizeaza doar genul', () => {
      expect(SWIPE_POINTS.YES).toEqual({ genre: 1.0, author: 1.5, era: 0.5 });
      expect(SWIPE_POINTS.NO).toEqual({ genre: -0.5, author: -0.7, era: -0.2 });
      expect(SWIPE_POINTS.SKIP).toEqual({ genre: -0.1, author: 0, era: 0 });
    });
  });

  describe('aggregateScore', () => {
    it('fara swipe-uri scorul e 0 (nu NaN din impartire la 0)', () => {
      expect(aggregateScore([], 'genre', NOW)).toBe(0);
    });

    it('un singur Yes de azi da exact punctajul dimensiunii', () => {
      const swipes: ScoredSwipe[] = [{ action: 'YES', createdAt: NOW }];
      expect(aggregateScore(swipes, 'genre', NOW)).toBeCloseTo(1.0, 10);
      expect(aggregateScore(swipes, 'author', NOW)).toBeCloseTo(1.5, 10);
      expect(aggregateScore(swipes, 'era', NOW)).toBeCloseTo(0.5, 10);
    });

    it('e o medie ponderata, nu o suma - 5 x Yes tot 1.0 dau la gen', () => {
      const swipes: ScoredSwipe[] = Array.from({ length: 5 }, () => ({
        action: 'YES' as const,
        createdAt: NOW,
      }));
      expect(aggregateScore(swipes, 'genre', NOW)).toBeCloseTo(1.0, 10);
    });

    it('Yes si No egale, aceeasi zi, se anuleaza spre media punctajelor', () => {
      const swipes: ScoredSwipe[] = [
        { action: 'YES', createdAt: NOW },
        { action: 'NO', createdAt: NOW },
      ];
      // (1.0 + (-0.5)) / 2
      expect(aggregateScore(swipes, 'genre', NOW)).toBeCloseTo(0.25, 10);
    });

    it('swipe-ul vechi cantareste mai putin decat cel recent', () => {
      // Yes acum 180 de zile (pondere 0.5) + No azi (pondere 1):
      // (1.0*0.5 + (-0.5)*1) / 1.5 = 0 / 1.5 = 0
      const swipes: ScoredSwipe[] = [
        { action: 'YES', createdAt: daysAgo(DECAY_HALF_LIFE_DAYS) },
        { action: 'NO', createdAt: NOW },
      ];
      expect(aggregateScore(swipes, 'genre', NOW)).toBeCloseTo(0, 10);
    });

    it('Skip nu misca deloc autorul si epoca, doar genul', () => {
      const swipes: ScoredSwipe[] = [{ action: 'SKIP', createdAt: NOW }];
      expect(aggregateScore(swipes, 'genre', NOW)).toBeCloseTo(-0.1, 10);
      expect(aggregateScore(swipes, 'author', NOW)).toBe(0);
      expect(aggregateScore(swipes, 'era', NOW)).toBe(0);
    });

    it('multiplicatorul de cold start amplifica doar punctele, nu ponderea', () => {
      const swipes: ScoredSwipe[] = [
        { action: 'YES', createdAt: NOW, multiplier: 1.3 },
      ];
      expect(aggregateScore(swipes, 'genre', NOW)).toBeCloseTo(1.3, 10);
    });

    it('semnul se pastreaza: numai No-uri dau scor negativ', () => {
      const swipes: ScoredSwipe[] = [
        { action: 'NO', createdAt: NOW },
        { action: 'NO', createdAt: daysAgo(30) },
      ];
      expect(aggregateScore(swipes, 'author', NOW)).toBeLessThan(0);
      expect(aggregateScore(swipes, 'author', NOW)).toBeCloseTo(-0.7, 10);
    });
  });

  describe('coldStartMultiplier', () => {
    it('sub 50 de swipe-uri amplifica cu (1 + popularitate)', () => {
      expect(coldStartMultiplier(0, 0.8)).toBeCloseTo(1.8, 10);
      expect(coldStartMultiplier(49, null)).toBeCloseTo(1.3, 10); // default 0.3
    });

    it('de la 50 in sus nu mai amplifica nimic', () => {
      expect(coldStartMultiplier(50, 0.9)).toBe(1);
      expect(coldStartMultiplier(500, 0.9)).toBe(1);
    });
  });

  describe('eraForYear / yearRangeForEra', () => {
    it('grupeaza tot ce e sub 1950 intr-un singur bucket', () => {
      expect(eraForYear(1949)).toBe('pre-1950');
      expect(eraForYear(1600)).toBe('pre-1950');
    });

    it('dupa 1950 grupeaza pe decenii', () => {
      expect(eraForYear(1950)).toBe('1950s');
      expect(eraForYear(1959)).toBe('1950s');
      expect(eraForYear(1960)).toBe('1960s');
      expect(eraForYear(2024)).toBe('2020s');
    });

    it('anul lipsa sau absurd nu produce bucket', () => {
      expect(eraForYear(null)).toBeNull();
      expect(eraForYear(undefined)).toBeNull();
      expect(eraForYear(0)).toBeNull();
      expect(eraForYear(-500)).toBeNull();
      expect(eraForYear(new Date().getFullYear() + 50)).toBeNull();
    });

    it('yearRangeForEra e inversul lui eraForYear', () => {
      expect(yearRangeForEra('pre-1950')).toEqual({ from: null, to: 1950 });
      expect(yearRangeForEra('1990s')).toEqual({ from: 1990, to: 2000 });
      expect(yearRangeForEra('nu-e-o-epoca')).toBeNull();
      expect(yearRangeForEra('1940s')).toBeNull(); // acoperit de pre-1950
    });
  });

  describe('compositeBookScore', () => {
    const scores = {
      genre: new Map([['Fantasy', 1.0]]),
      author: new Map([['Tolkien', 2.0]]),
      era: new Map([['1950s', 1.0]]),
    };

    it('combina dimensiunile cu 0.5 / 0.35 / 0.15', () => {
      const score = compositeBookScore(
        { genre: 'Fantasy', author: 'Tolkien', publishedYear: 1954 },
        scores,
      );
      expect(score).toBeCloseTo(1.0 * 0.5 + 2.0 * 0.35 + 1.0 * 0.15, 10);
    });

    it('valorile necunoscute conteaza 0, nu penalizeaza', () => {
      const score = compositeBookScore(
        { genre: 'Poezie', author: 'Cineva', publishedYear: 2001 },
        scores,
      );
      expect(score).toBe(0);
    });

    it('cartea fara an nu primeste contributie de epoca', () => {
      const score = compositeBookScore(
        { genre: 'Fantasy', author: null, publishedYear: null },
        scores,
      );
      expect(score).toBeCloseTo(0.5, 10);
    });
  });

  describe('discoveryCountFor', () => {
    it('normal 2 din 5', () => {
      expect(discoveryCountFor(20, false)).toBe(8);
      expect(discoveryCountFor(10, false)).toBe(4);
      expect(discoveryCountFor(5, false)).toBe(2);
    });

    it('cu boost dupa recalibrare 3 din 5', () => {
      expect(discoveryCountFor(20, true)).toBe(12);
      expect(discoveryCountFor(10, true)).toBe(6);
      expect(discoveryCountFor(5, true)).toBe(3);
    });

    it('nu depaseste marimea batch-ului', () => {
      expect(discoveryCountFor(1, true)).toBeLessThanOrEqual(1);
    });
  });

  describe('weightedSample', () => {
    it('nu intoarce duplicate si respecta numarul cerut', () => {
      const items = ['a', 'b', 'c', 'd', 'e'].map((item) => ({
        item,
        weight: 1,
      }));
      const picked = weightedSample(items, 3);
      expect(picked).toHaveLength(3);
      expect(new Set(picked).size).toBe(3);
    });

    it('cere mai mult decat exista - intoarce tot ce e', () => {
      expect(weightedSample([{ item: 'a', weight: 1 }], 5)).toEqual(['a']);
    });

    it('count 0 sau negativ intoarce lista goala', () => {
      expect(weightedSample([{ item: 'a', weight: 1 }], 0)).toEqual([]);
    });

    it('greutatea mare iese semnificativ mai des decat cea mica', () => {
      let heavy = 0;
      for (let i = 0; i < 400; i++) {
        const [pick] = weightedSample(
          [
            { item: 'heavy', weight: 20 },
            { item: 'light', weight: 0.5 },
          ],
          1,
        );
        if (pick === 'heavy') heavy++;
      }
      expect(heavy).toBeGreaterThan(300);
    });

    it('nu e determinist: doua apeluri pe acelasi pool difera macar uneori', () => {
      const pool = Array.from({ length: 20 }, (_, i) => ({
        item: `b${i}`,
        weight: 1,
      }));
      const runs = Array.from({ length: 10 }, () =>
        weightedSample(pool, 5).join(','),
      );
      expect(new Set(runs).size).toBeGreaterThan(1);
    });
  });

  describe('recalibrare', () => {
    it('comprima la 40% si pastreaza semnul', () => {
      expect(1.2 * RECALIBRATION_FACTOR).toBeCloseTo(0.48, 10);
      expect(-0.9 * RECALIBRATION_FACTOR).toBeCloseTo(-0.36, 10);
      expect(0 * RECALIBRATION_FACTOR).toBe(0);
    });
  });
});
