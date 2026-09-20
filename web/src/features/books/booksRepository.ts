import { api } from '@/lib/api/client';
import type { UserBook } from '@/types/models';

export interface BrowseResult {
  items: UserBook[];
  total: number;
}

export interface BrowseParams {
  title?: string;
  author?: string;
  genre?: string;
  language?: string;
  city?: string;
  condition?: string;
  sort?: string;
  fromCity?: string;
  maxDistanceKm?: number;
  excludeUserId?: string;
  listingType?: string;
  limit?: number;
  offset?: number;
}

export const booksRepository = {
  browse(params: BrowseParams = {}, signal?: AbortSignal): Promise<BrowseResult> {
    const { limit = 20, offset = 0, ...filters } = params;
    // Parametrii goi nu se trimit deloc: backendul tratează `genre=""` drept
    // filtru pe genul gol, nu drept "fără filtru", și întoarce zero rezultate.
    const query: Record<string, string | number> = { limit, offset };
    for (const [key, value] of Object.entries(filters)) {
      if (value !== undefined && value !== null && value !== '') query[key] = value;
    }
    return api.get<BrowseResult>('/books/browse', { query, signal });
  },

  getById(userBookId: string, signal?: AbortSignal): Promise<UserBook> {
    return api.get<UserBook>(`/books/${userBookId}`, { signal });
  },

  getRecommended(signal?: AbortSignal): Promise<UserBook[]> {
    return api.get<UserBook[]>('/books/recommended', { signal });
  },

  getSimilar(userBookId: string, signal?: AbortSignal): Promise<UserBook[]> {
    return api.get<UserBook[]>(`/books/${userBookId}/similar`, { signal });
  },

  // --- secțiunile din Descoperă ---
  // Fiecare e un GET separat, invalidabil individual, exact ca providerii din
  // discover_screen.dart. Nu le unim într-un singur endpoint: o secțiune lentă
  // (recomandările, care fac muncă reală pe backend) ar ține în loc tot ecranul.

  getTrendingListings(signal?: AbortSignal): Promise<UserBook[]> {
    return api.get<UserBook[]>('/books/trending-listings', { signal });
  },

  getMostWished(signal?: AbortSignal): Promise<UserBook[]> {
    return api.get<UserBook[]>('/books/most-wished', { signal });
  },

  getHiddenGems(signal?: AbortSignal): Promise<UserBook[]> {
    return api.get<UserBook[]>('/books/hidden-gems', { signal });
  },

  getNearbyToday(city: string, signal?: AbortSignal): Promise<UserBook[]> {
    return api.get<UserBook[]>('/books/nearby-today', { query: { city }, signal });
  },

  getPopularSearches(signal?: AbortSignal): Promise<SearchStat[]> {
    return api.get<SearchStat[]>('/books/popular-searches', { signal });
  },

  getPopularAuthors(signal?: AbortSignal): Promise<AuthorStat[]> {
    return api.get<AuthorStat[]>('/books/popular-authors', { signal });
  },

  getGenres(signal?: AbortSignal): Promise<GenreStat[]> {
    return api.get<GenreStat[]>('/books/genres', { signal });
  },

  getMyLibrary(signal?: AbortSignal): Promise<UserBook[]> {
    return api.get<UserBook[]>('/books/my-library', { signal });
  },

  /** Caută în catalog + surse externe, pentru precompletarea formularului. */
  search(query: string, signal?: AbortSignal): Promise<ExternalBookResult[]> {
    return api.get<ExternalBookResult[]>('/books/search', { query: { q: query }, signal });
  },

  lookupIsbn(isbn: string, signal?: AbortSignal): Promise<ExternalBookResult | null> {
    return api.get<ExternalBookResult | null>('/books/lookup-isbn', {
      query: { isbn },
      signal,
    });
  },

  suggestCovers(input: { title: string; author?: string }, signal?: AbortSignal) {
    return api.get<string[]>('/books/covers', {
      query: { title: input.title, ...(input.author ? { author: input.author } : {}) },
      signal,
    });
  },

  /**
   * Câmpurile goale NU se trimit deloc. Backendul le-ar salva literal ca "",
   * iar cartea ar apărea cu o editură goală în loc să n-o afișeze.
   */
  addToLibrary(input: AddBookInput): Promise<UserBook> {
    const payload: Record<string, unknown> = { isHardcover: input.isHardcover ?? false };
    for (const [key, value] of Object.entries(input)) {
      if (key === 'isHardcover') continue;
      if (value === undefined || value === null || value === '') continue;
      if (Array.isArray(value) && value.length === 0) continue;
      payload[key] = value;
    }
    return api.post<UserBook>('/books', payload);
  },

  update(userBookId: string, input: Record<string, unknown>): Promise<UserBook> {
    return api.patch<UserBook>(`/books/${userBookId}`, input);
  },

  markForSale(userBookId: string, salePrice: number, isNegotiable: boolean): Promise<UserBook> {
    return api.patch<UserBook>(`/books/${userBookId}`, {
      isForSale: true,
      salePrice,
      isNegotiable,
    });
  },

  async addPhoto(userBookId: string, file: File): Promise<{ photoUrl?: string }> {
    const form = new FormData();
    form.append('photo', file);
    return api.request<{ photoUrl?: string }>(`/books/${userBookId}/photos`, {
      method: 'POST',
      formData: form,
    });
  },

  addPhotoFromUrl(userBookId: string, url: string): Promise<void> {
    return api.post(`/books/${userBookId}/photos/from-url`, { url });
  },

  /**
   * Poza principală a anunțului - cea care apare în feed. URL-ul poate fi o
   * poză urcată sau o copertă externă; `null` revine la fallback.
   */
  setMainPhoto(userBookId: string, mainPhotoUrl: string | null): Promise<void> {
    return api.patch(`/books/${userBookId}`, { mainPhotoUrl });
  },

  /**
   * Scorurile de anunt, pentru badge-ul vizibil DOAR adminilor.
   *
   * E un POST cu o lista, nu un GET per card: o grila de discover are 20-30 de
   * carduri, iar cate o cerere de fiecare ar insemna 30 de dus-intors la
   * fiecare derulare. Backendul limiteaza la 100 de id-uri per cerere.
   */
  getListingScores(userBookIds: string[]): Promise<Record<string, number>> {
    if (userBookIds.length === 0) return Promise.resolve({});
    return api.post<Record<string, number>>('/books/scores', { userBookIds });
  },
};

/** Rezultat de căutare, din catalog sau dintr-o sursă externă. */
export interface ExternalBookResult {
  id?: string;
  isbn?: string | null;
  title: string;
  author?: string | null;
  coverUrl?: string | null;
  publisher?: string | null;
  publishedYear?: number | null;
  pageCount?: number | null;
  description?: string | null;
  genre?: string | null;
  language?: string | null;
}

export interface AddBookInput {
  bookId?: string;
  isbn?: string;
  title?: string;
  author?: string;
  language?: string;
  edition?: string;
  isHardcover?: boolean;
  condition?: string;
  genre?: string;
  series?: string;
  seriesNumber?: number;
  publisher?: string;
  publishedYear?: number;
  editionYear?: number;
  pageCount?: number;
  description?: string;
  tags?: string[];
  city?: string;
  mainPhotoUrl?: string;
}

export interface SearchStat {
  query: string;
  count: number;
}

export interface AuthorStat {
  author: string;
  count: number;
}

export interface GenreStat {
  genre: string;
  count: number;
}

/**
 * Cheile de cache. Grupate într-un singur loc ca invalidarea după o mutație să
 * nu fie o ghicitoare - un string scris ușor diferit în două fișiere înseamnă
 * două intrări separate în cache, iar ecranul rămâne pe datele vechi fără
 * nicio eroare vizibilă.
 */
export const booksKeys = {
  all: ['books'] as const,
  browse: (params: BrowseParams) => ['books', 'browse', params] as const,
  detail: (id: string) => ['books', 'detail', id] as const,
  recommended: () => ['books', 'recommended'] as const,
  similar: (id: string) => ['books', 'similar', id] as const,
  trending: () => ['books', 'trending-listings'] as const,
  mostWished: () => ['books', 'most-wished'] as const,
  hiddenGems: () => ['books', 'hidden-gems'] as const,
  nearby: (city: string) => ['books', 'nearby-today', city] as const,
  popularSearches: () => ['books', 'popular-searches'] as const,
  popularAuthors: () => ['books', 'popular-authors'] as const,
  genres: () => ['books', 'genres'] as const,
  myLibrary: () => ['books', 'my-library'] as const,
};
