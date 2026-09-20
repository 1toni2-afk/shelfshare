/**
 * Formele de date întoarse de backend.
 *
 * Portate din frontend/lib/data/models/. Diferența de abordare: în Dart
 * fiecare model avea `fromJson` care valida și converta; aici tipurile sunt
 * doar contracte de compilare, iar conversiile care chiar au nevoie de lucru
 * (date ISO -> Date, Decimal -> number) se fac explicit la locul lor.
 *
 * Atenție la `salePrice` și la orice câmp care vine dintr-un Decimal Prisma:
 * se serializează ca STRING în JSON, nu ca number. Tipul de mai jos îl
 * declară ca atare dinadins - un `number` aici ar fi o minciună care trece de
 * compilator și cade abia în UI, la prima înmulțire.
 */

export type DecimalString = string;

export interface PublicUser {
  id: string;
  name: string | null;
  username: string | null;
  profileImage: string | null;
  city: string | null;
  rating: number;
  isPremium?: boolean;
  isStore?: boolean;
}

export interface AppUser {
  id: string;
  email: string;
  name: string | null;
  username: string | null;
  nameVisible: boolean;
  city: string | null;
  bio: string | null;
  birthdayDay: number | null;
  birthdayMonth: number | null;
  languages: string[];
  profileImage: string | null;
  rating: number;
  booksExchangedCount: number;
  booksSharedCount: number;
  booksReceivedCount: number;
  isEmailVerified: boolean;
  isAdmin: boolean;
  /** Rolul SUPER_ADMIN, nu doar "e admin" - uneltele de operare depind de el. */
  isSuperAdmin: boolean;
  isPremium: boolean;
  isStore: boolean;
  canAccessAdvancedStats: boolean;
  showAcquisitionHistory: boolean;
  showAllListingScores: boolean;
  hideSwapListingsPublic: boolean;
  hideSaleListingsPublic: boolean;
  hideDonationListingsPublic: boolean;
  hideAuctionListingsPublic: boolean;
  referralCode: string | null;
  referralCount: number;
  createdAt: string | null;
  /**
   * Când a terminat userul chestionarul de cititor, adică pasul final al
   * onboardingului. `null` = wizardul nu e dus până la capăt.
   *
   * API-ul îl întorcea de la bun început (vezi `/profile/me`), doar tipul de
   * aici nu-l avea - iar routerul nu avea cum să știe pe cine să trimită la
   * onboarding.
   */
  readingSurveyCompletedAt: string | null;
  /**
   * Setat dacă userul a cerut ștergerea contului - contul se șterge efectiv
   * la data asta dacă nu anulează între timp.
   */
  deletionScheduledAt?: string | null;
  /** Scorul de încredere calculat pe backend. Lipsește pe conturile noi. */
  trustScore?: TrustScore | null;
  /** Statistici derivate din biblioteca proprie - alimentează „Top genuri". */
  readingStats?: ReadingStats | null;
}

export interface TrustScore {
  score: number;
  accountAgeDays: number;
  isEmailVerified: boolean;
  completedExchanges: number;
  rating: number;
}

export interface GenreCount {
  genre: string;
  count: number;
}

export interface ReadingStats {
  totalListed: number;
  totalPages: number;
  favoriteGenre: string | null;
  topGenres: GenreCount[];
  longestBookTitle: string | null;
  longestBookPages: number | null;
}

/** Obiectivul anual de lectură. `goal` lipsă = userul nu l-a setat. */
export interface ReadingChallenge {
  year: number;
  goal: number | null;
  progress: number;
}

export interface Book {
  id: string;
  isbn: string | null;
  title: string;
  author: string | null;
  description: string | null;
  coverUrl: string | null;
  publisher: string | null;
  publishedYear: number | null;
  pageCount: number | null;
  language: string | null;
  genre: string | null;
  series: string | null;
  seriesNumber: number | null;
  referencePrice: DecimalString | null;
  referencePriceCurrency: string | null;
}

/** Valorile enumului BookCondition din schema Prisma - în română, ca acolo. */
export type BookCondition = 'NOUA' | 'FOARTE_BUNA' | 'BUNA' | 'ACCEPTABILA';

export interface AuctionCardSummary {
  id: string;
  currentPrice: DecimalString;
  endsAt: string;
  status: string;
  buyNowPrice: DecimalString | null;
}

export interface UserBook {
  id: string;
  userId: string;
  book: Book;
  /**
   * Proprietarul anunțului. Se numește `user`, nu `owner`, fiindcă așa îl
   * întoarce API-ul peste tot unde e inclus (`user: { select: OWNER_SELECT }`
   * în books.service.ts).
   *
   * Numele greșit nu dădea nicio eroare, doar făcea câmpul `undefined`: pe
   * pagina unei cărți listate, butoanele „Propune schimb" și „Fă o ofertă"
   * sunt condiționate de el, deci pur și simplu nu se desenau, iar cartea
   * părea că nu se poate cere de nicăieri.
   *
   * Poate lipsi: listele proprii nu includ proprietarul, fiind evident cine e.
   */
  user?: PublicUser | null;
  condition: BookCondition | null;
  language: string | null;
  edition: string | null;
  isHardcover: boolean;
  availableForSwap: boolean;
  isForSale: boolean;
  salePrice: DecimalString | null;
  previousSalePrice: DecimalString | null;
  isNegotiable: boolean;
  swapSalePrice: DecimalString | null;
  isAuction: boolean;
  auction: AuctionCardSummary | null;
  isPromoted: boolean;
  viewCount: number;
  stockQuantity: number;
  distanceKm: number | null;
  photos: string[];
  mainPhotoUrl: string | null;
  createdAt: string;
  permanentlyTransferred: boolean;
  isReservedForExchange: boolean;
  deletedAt: string | null;
  description: string | null;
  tags: string[];
  city: string | null;
  favoriteCount: number | null;
  isWishlisted: boolean | null;
  searchScore: number | null;
}

export interface AuthTokens {
  accessToken: string;
  refreshToken: string;
}

/** Provocarea aritmetică cerută după prea multe încercări eșuate de login. */
export interface CaptchaChallenge {
  token: string;
  question: string;
}

/**
 * Un Decimal Prisma ajunge aici ca string. Conversia e centralizată ca să nu
 * apară `Number(x)` împrăștiat prin ecrane - un `undefined` strecurat acolo
 * dă `NaN` afișat direct userului, fără nicio eroare.
 */
export function toNumber(value: DecimalString | number | null | undefined): number | null {
  if (value === null || value === undefined || value === '') return null;
  const parsed = typeof value === 'number' ? value : Number(value);
  return Number.isFinite(parsed) ? parsed : null;
}
