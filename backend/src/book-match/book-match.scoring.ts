/**
 * Matematica Book Match, izolată de Prisma ca să fie testabilă direct.
 *
 * Trei dimensiuni independente (gen, autor, epocă), fiecare cu propriul scor
 * per user. Un swipe atinge exact o valoare din fiecare dimensiune (genul
 * cărții, autorul ei, bucket-ul de an) și contribuie cu puncte diferite:
 * autorul e semnalul cel mai tare ("nu vreau nimic de X" e o preferință mult
 * mai clară decât "nu vreau fantasy"), epoca cel mai slab.
 */

export type BookMatchAction = 'YES' | 'NO' | 'SKIP';
export type ScoreDimension = 'genre' | 'author' | 'era';

/// Puncte per swipe, pe acțiune și dimensiune. „Skip" penalizează doar genul,
/// și foarte puțin: un skip înseamnă „nu acum", nu „nu-mi place autorul".
export const SWIPE_POINTS: Record<
  BookMatchAction,
  Record<ScoreDimension, number>
> = {
  YES: { genre: 1.0, author: 1.5, era: 0.5 },
  NO: { genre: -0.5, author: -0.7, era: -0.2 },
  SKIP: { genre: -0.1, author: 0, era: 0 },
};

/// Jumătate de pondere la fiecare 180 de zile. Gusturile se schimbă, dar lent -
/// un „da" de acum un an încă spune ceva, doar că mai puțin decât cel de ieri.
export const DECAY_HALF_LIFE_DAYS = 180;

/// Sub acest prag de swipe-uri, userul e în cold start.
export const ONBOARDING_SWIPES_TARGET = 50;

/// Multiplicatorul de cold start folosește popularitatea cărții; cărțile
/// necurate primesc o valoare mică, uniformă, deci multiplicator 1.3.
export const BOOK_MATCH_DEFAULT_POPULARITY = 0.3;

/// Ponderile compunerii scorului per carte pentru ordonarea cozii.
export const COMPOSITE_WEIGHTS = { genre: 0.5, author: 0.35, era: 0.15 };

/// Cât de mult se comprimă scorurile la recalibrare (nu se șterg rândurile:
/// vrem să rămână urma preferințelor, doar mult slăbită).
export const RECALIBRATION_FACTOR = 0.4;

/// Cooldown între două recalibrări.
export const RECALIBRATION_COOLDOWN_DAYS = 30;

/// Câte swipe-uri primesc discovery crescut după o recalibrare.
export const DISCOVERY_BOOST_SWIPES = 20;

/// Din cota de discovery, ce parte rămâne serendipity pură (complet random,
/// orice gen cunoscut, nerespins) - restul e „distanță controlată": genuri
/// adiacente celor din top, nu tot catalogul la întâmplare (vezi
/// GENRE_ADJACENCY din book-genres.ts).
export const DISCOVERY_SERENDIPITY_RATIO = 0.15;

/// Sub acest scor un gen e considerat respins - nu mai apare nici măcar ca
/// discovery (dar vezi MIN_SWIPES_FOR_GENRE_REJECTION și MIN_ALLOWED_GENRES din
/// book-match.service.ts: respingerea cere și destule voturi, și nu poate goli
/// catalogul). Scorul e o MEDIE ponderată a punctelor, deci pragul se citește
/// în raportul „nu"/„da" din acel gen: -0.3 înseamnă ~6-7 „Nu" la fiecare „Da".
/// Era -0.15 (~3 „Nu" la un „Da"), adică nivelul normal de swipe al oricui -
/// ajungeau să fie respinse toate genurile și coada rămânea goală.
export const NEGATIVE_GENRE_THRESHOLD = -0.3;

/// Cât de aproape de 0 trebuie să stea scorul unui gen ca genul să treacă drept
/// „neutru" și să poată alimenta cardurile de discovery. Separat de pragul de
/// respingere: un gen poate fi prea slab ca să fie discovery fără să fie respins.
export const NEUTRAL_GENRE_BAND = 0.15;

const MS_PER_DAY = 24 * 60 * 60 * 1000;

/**
 * Bucket-ul de epocă pentru un an de apariție. Granițele sunt alese ca fiecare
 * bucket să însemne ceva pentru un cititor, nu doar un interval egal:
 *   - `pre-1950`  - tot ce e „clasic" fără distincții mai fine (nu avem destule
 *                   cărți vechi ca să merite decenii separate);
 *   - `1950s` … `2020s` - câte un deceniu, etichetat după prima lui zi
 *                   (2020s = 2020-2029, deci acoperă și viitorul apropiat);
 *   - `null`      - anul lipsește (publishedYear e opțional și des gol la
 *                   cărțile introduse manual). Un swipe fără an nu atinge
 *                   nicio valoare de epocă, nu inventăm un bucket „unknown"
 *                   care ar amesteca cărți din secole diferite.
 * Anii absurzi (≤ 0 sau mai mari decât anul curent + 2) sunt tratați ca lipsă.
 */
export function eraForYear(year: number | null | undefined): string | null {
  if (year == null || !Number.isFinite(year)) return null;
  const y = Math.trunc(year);
  if (y <= 0 || y > new Date().getFullYear() + 2) return null;
  if (y < 1950) return 'pre-1950';
  const decade = Math.floor(y / 10) * 10;
  return `${decade}s`;
}

/**
 * Inversul lui `eraForYear`: intervalul de ani [from, to) al unui bucket.
 * Necesar fiindcă epoca e derivată, nu stocată pe carte - ca să re-agregăm
 * swipe-urile unei epoci trebuie să filtrăm după publishedYear în SQL.
 * Întoarce null pentru etichete necunoscute.
 */
export function yearRangeForEra(
  era: string,
): { from: number | null; to: number } | null {
  if (era === 'pre-1950') return { from: null, to: 1950 };
  const match = /^(\d{4})s$/.exec(era);
  if (!match) return null;
  const decade = Number(match[1]);
  if (decade < 1950 || decade % 10 !== 0) return null;
  return { from: decade, to: decade + 10 };
}

/// Ponderea de vechime a unui swipe la momentul `now`.
export function decayWeight(swipedAt: Date, now: Date = new Date()): number {
  const days = (now.getTime() - swipedAt.getTime()) / MS_PER_DAY;
  // Swipe-urile „din viitor" (clock skew) primesc pondere 1, nu peste 1.
  const safeDays = days > 0 ? days : 0;
  return Math.pow(0.5, safeDays / DECAY_HALF_LIFE_DAYS);
}

export interface ScoredSwipe {
  action: BookMatchAction;
  createdAt: Date;
  /// Multiplicatorul aplicat la momentul swipe-ului (cold start), 1 după.
  multiplier?: number;
}

/**
 * Media ponderată a punctelor pentru o dimensiune, peste toate swipe-urile care
 * ating acea valoare: Σ(puncte * pondere) / Σ(pondere).
 *
 * E o medie, nu o sumă: altfel un gen pe care userul l-a văzut de 40 de ori ar
 * bate orice gen văzut de 3 ori, indiferent de răspunsuri. Scorul rămâne astfel
 * comparabil între dimensiuni și mărginit de punctajele din SWIPE_POINTS.
 */
export function aggregateScore(
  swipes: ScoredSwipe[],
  dimension: ScoreDimension,
  now: Date = new Date(),
): number {
  let weighted = 0;
  let totalWeight = 0;
  for (const swipe of swipes) {
    const weight = decayWeight(swipe.createdAt, now);
    const points =
      SWIPE_POINTS[swipe.action][dimension] * (swipe.multiplier ?? 1);
    weighted += points * weight;
    totalWeight += weight;
  }
  if (totalWeight === 0) return 0;
  return weighted / totalWeight;
}

/// Multiplicatorul de cold start pentru un swipe. Peste pragul de onboarding
/// nu se mai amplifică nimic - userul are deja destul semnal propriu.
export function coldStartMultiplier(
  onboardingSwipesCount: number,
  popularityScore: number | null | undefined,
): number {
  if (onboardingSwipesCount >= ONBOARDING_SWIPES_TARGET) return 1;
  return 1 + (popularityScore ?? BOOK_MATCH_DEFAULT_POPULARITY);
}

export interface UserScoreMaps {
  genre: Map<string, number>;
  author: Map<string, number>;
  era: Map<string, number>;
}

/// Scorul compus al unei cărți față de profilul curent. Valorile necunoscute
/// (gen nou, autor nou) contează 0, adică neutru - nu penalizate.
export function compositeBookScore(
  book: {
    genre?: string | null;
    author?: string | null;
    publishedYear?: number | null;
  },
  scores: UserScoreMaps,
): number {
  const genre = book.genre ? (scores.genre.get(book.genre) ?? 0) : 0;
  const author = book.author ? (scores.author.get(book.author) ?? 0) : 0;
  const era = scores.era.get(eraForYear(book.publishedYear) ?? '') ?? 0;
  return (
    genre * COMPOSITE_WEIGHTS.genre +
    author * COMPOSITE_WEIGHTS.author +
    era * COMPOSITE_WEIGHTS.era
  );
}

/**
 * Câte cărți de discovery intră într-un batch de `size`. Normal 2 din 5; după o
 * recalibrare (cât timp mai sunt swipe-uri de boost) 3 din 5, ca profilul să se
 * re-formeze din material nou, nu din ce știa deja.
 */
export function discoveryCountFor(size: number, boosted: boolean): number {
  const ratio = boosted ? 3 / 5 : 2 / 5;
  return Math.min(size, Math.round(size * ratio));
}

/**
 * Eșantionare aleatoare ponderată fără repetiție (Efraimidis-Spirakis): fiecare
 * candidat primește cheia `random^(1/greutate)` și luăm cele mai mari `count`.
 * Folosită ca să nu servim mereu aceleași „cele mai bune" cărți la fiecare
 * apel - cărțile bune ies des, dar nu determinist.
 */
export function weightedSample<T>(
  candidates: { item: T; weight: number }[],
  count: number,
  random: () => number = Math.random,
): T[] {
  if (count <= 0) return [];
  return candidates
    .map(({ item, weight }) => {
      // Greutatea 0 ar da cheie 0 și ar fi mereu ultima; ținem un minim.
      const w = weight > 0 ? weight : 1e-6;
      return { item, key: Math.pow(random(), 1 / w) };
    })
    .sort((a, b) => b.key - a.key)
    .slice(0, count)
    .map((entry) => entry.item);
}
