import { api } from '@/lib/api/client';
import type { Book, UserBook } from '@/types/models';

/** Sursa unei intrări din lista de dorințe: adăugată manual sau din Book Match. */
export type WishlistSource = 'MANUAL' | 'BOOK_MATCH' | string;

export interface WishlistItem {
  id: string;
  book: Book;
  source: WishlistSource;
  createdAt: string;
  /**
   * Anunțul de pe care s-a apăsat inima. `null` pentru intrările „de titlu"
   * (adăugate din Book Match sau de pe pagina operei), care nu sunt legate de
   * un exemplar anume.
   */
  userBookId?: string | null;
  /** Anunțurile disponibile acum pentru cartea dorită, dacă backendul le trimite. */
  availableListings?: UserBook[];
}

export interface Collection {
  id: string;
  name: string;
  isPublic: boolean;
  bookCount: number;
  createdAt: string;
}

export interface CollectionDetail extends Collection {
  books: Book[];
}

export interface SavedSearch {
  id: string;
  label: string | null;
  genre: string | null;
  city: string | null;
  maxPrice: string | null;
  createdAt: string;
}

export const wishlistRepository = {
  list(signal?: AbortSignal): Promise<WishlistItem[]> {
    return api.get<WishlistItem[]>('/wishlist', { signal });
  },

  /**
   * `userBookId` leagă favoritul de EXEMPLAR, nu de titlu: inima apăsată pe
   * anunțul unui user nu trebuie să se aprindă și pe celelalte anunțuri ale
   * aceleiași cărți. E opțional - adăugările care nu pleacă de pe un card
   * (Book Match, pagina operei) rămân la nivel de titlu.
   */
  add(bookId: string, userBookId?: string): Promise<WishlistItem> {
    return api.post<WishlistItem>('/wishlist', {
      bookId,
      ...(userBookId ? { userBookId } : {}),
    });
  },

  remove(bookId: string): Promise<void> {
    return api.delete(`/wishlist/${bookId}`);
  },

  /**
   * Scoate din listă pornind de la ANUNȚ, nu de la cartea din catalog.
   * Există separat fiindcă butonul de pe cardul unui anunț nu știe id-ul
   * cărții din catalog, doar pe al exemplarului.
   */
  removeByListing(userBookId: string): Promise<void> {
    return api.delete(`/wishlist/listing/${userBookId}`);
  },
};

export const collectionsRepository = {
  mine(signal?: AbortSignal): Promise<Collection[]> {
    return api.get<Collection[]>('/collections/mine', { signal });
  },

  ofUser(userId: string, signal?: AbortSignal): Promise<Collection[]> {
    return api.get<Collection[]>(`/collections/user/${userId}`, { signal });
  },

  detail(id: string, signal?: AbortSignal): Promise<CollectionDetail> {
    return api.get<CollectionDetail>(`/collections/${id}`, { signal });
  },

  create(input: { name: string; isPublic: boolean }): Promise<Collection> {
    return api.post<Collection>('/collections', input);
  },

  update(id: string, input: { name?: string; isPublic?: boolean }): Promise<Collection> {
    return api.patch<Collection>(`/collections/${id}`, input);
  },

  remove(id: string): Promise<void> {
    return api.delete(`/collections/${id}`);
  },

  addBook(id: string, bookId: string): Promise<void> {
    return api.post(`/collections/${id}/items`, { bookId });
  },

  removeBook(id: string, bookId: string): Promise<void> {
    return api.delete(`/collections/${id}/items/${bookId}`);
  },
};

export const savedSearchesRepository = {
  list(signal?: AbortSignal): Promise<SavedSearch[]> {
    return api.get<SavedSearch[]>('/saved-searches', { signal });
  },

  create(input: {
    label?: string;
    genre?: string;
    city?: string;
    maxPrice?: number;
  }): Promise<SavedSearch> {
    return api.post<SavedSearch>('/saved-searches', input);
  },

  remove(id: string): Promise<void> {
    return api.delete(`/saved-searches/${id}`);
  },
};

export const trashRepository = {
  list(signal?: AbortSignal): Promise<UserBook[]> {
    return api.get<UserBook[]>('/books/my-library/deleted', { signal });
  },

  restore(userBookId: string): Promise<void> {
    return api.post(`/books/${userBookId}/restore`);
  },
};

export const listsKeys = {
  wishlist: () => ['wishlist'] as const,
  collections: () => ['collections', 'mine'] as const,
  collection: (id: string) => ['collections', id] as const,
  savedSearches: () => ['saved-searches'] as const,
  trash: () => ['books', 'trash'] as const,
};
