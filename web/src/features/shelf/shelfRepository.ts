import { api } from '@/lib/api/client';
import type { Book } from '@/types/models';

/** Statusul unei cărți pe raftul personal. */
export type ShelfStatus = 'READING' | 'WANT_TO_READ' | 'FINISHED';

export interface ShelfEntry {
  book: Book;
  status: ShelfStatus;
  currentPage: number;
  totalPages: number | null;
  /** True dacă userul are și un anunț activ pentru cartea asta. */
  listed: boolean;
}

/**
 * Raftul grupat pe statusuri, exact cum îl întoarce `/bookshelf/me`: liste de
 * CĂRȚI, nu de intrări cu progres (vezi `groupByStatus` din
 * bookshelf.service.ts, care face `.map((e) => e.book)`).
 *
 * Tipul spunea `ShelfEntry[]`, adică obiecte cu `book` înăuntru. Nimic nu
 * semnala diferența la compilare, dar ecranul citea `entry.book.id` pe un Book
 * simplu și crăpa cu „Cannot read properties of undefined" de îndată ce
 * apărea prima carte pe raft - deci raftul era rupt pentru oricine îl
 * folosea, și arăta bine doar cât era gol.
 *
 * Progresul la citit NU vine de aici; se ia din `/bookshelf/me/owned`
 * (`OwnedBook`) și se lipește pe cărți după id.
 */
export interface Bookshelf {
  reading: Book[];
  wantToRead: Book[];
  finished: Book[];
}

/**
 * O carte pe care userul o DEȚINE, cu progresul la citit. `listed` spune dacă
 * are și un anunț activ; `relistSourceId` e exemplarul primit printr-un schimb
 * finalizat, care se RE-listează, nu se duplică.
 */
export interface OwnedBook {
  book: Book;
  status: ShelfStatus;
  currentPage: number;
  totalPages: number | null;
  listed: boolean;
  relistSourceId: string | null;
}

/**
 * Fracție 0..1 pentru bara de progres. `null` când nu știm totalul - atunci se
 * afișează doar „Pagina X", fără bară: n-avem de unde inventa un procent.
 */
export function ownedProgress(owned: OwnedBook): number | null {
  if (!owned.totalPages || owned.totalPages <= 0) return null;
  return Math.min(1, Math.max(0, owned.currentPage / owned.totalPages));
}

/**
 * Terminată de citit: fie marcată explicit FINISHED, fie progresul a ajuns la
 * ultima pagină. Doar atunci se oferă „scoate-o la schimb".
 */
export function ownedIsFinished(owned: OwnedBook): boolean {
  if (owned.status === 'FINISHED') return true;
  return !!owned.totalPages && owned.totalPages > 0 && owned.currentPage >= owned.totalPages;
}

export type BookRequestStatus = 'PENDING' | 'FULFILLED' | 'NOT_FOUND' | 'CANCELLED';

export interface BookRequest {
  id: string;
  title: string;
  author: string | null;
  status: BookRequestStatus;
  attempts: number;
  foundBookId: string | null;
  createdAt: string;
}

export const shelfRepository = {
  /**
   * Adaugă o carte DEȚINUTĂ în raft, fără să creeze un anunț.
   *
   * Deliberat mai sărac decât listarea (vezi AddOwnedBookDto pe backend): fără
   * poze, preț, stare sau oraș - exemplarul nu-l vede nimeni în afară de
   * proprietar, deci nu are ce negocia cu el.
   */
  addOwned(input: {
    /** Cartea din catalog aleasă din autocomplete - vezi AddOwnedBookDto. */
    bookId?: string;
    title: string;
    author?: string;
    isbn?: string;
    coverUrl?: string;
    genre?: string;
    publisher?: string;
    publishedYear?: number;
    status?: ShelfStatus;
    totalPages?: number;
  }): Promise<Book> {
    return api.post<Book>('/bookshelf/own', input);
  },

  mine(signal?: AbortSignal): Promise<Bookshelf> {
    return api.get<Bookshelf>('/bookshelf/me', { signal });
  },

  setStatus(
    bookId: string,
    input: { status: ShelfStatus; currentPage?: number; owned?: boolean },
  ) {
    return api.put(`/bookshelf/${bookId}`, input);
  },

  remove(bookId: string): Promise<void> {
    return api.delete(`/bookshelf/${bookId}`);
  },

  /** Cărțile deținute dar nelistate, afișate în prim-planul din „Raftul meu". */
  owned(signal?: AbortSignal): Promise<OwnedBook[]> {
    return api.get<OwnedBook[]>('/bookshelf/me/owned', { signal });
  },

  /**
   * Progresul la citit. `totalPages` suprascrie numărul din catalog cu cel al
   * ediției pe care o are userul în mână - are propriul endpoint, separat de
   * raft (vezi reading_progress_repository.dart).
   */
  saveProgress(bookId: string, input: { currentPage: number; totalPages?: number }) {
    return api.put(`/reading-progress/${bookId}`, input);
  },
};

export const bookRequestsRepository = {
  mine(signal?: AbortSignal): Promise<BookRequest[]> {
    return api.get<BookRequest[]>('/book-requests/mine', { signal });
  },

  create(input: { title: string; author?: string }): Promise<BookRequest> {
    return api.post<BookRequest>('/book-requests', input);
  },

  cancel(id: string): Promise<void> {
    return api.delete(`/book-requests/${id}`);
  },
};

export const feedbackRepository = {
  /**
   * Feedbackul merge ca `multipart`, nu JSON: poate include o captură de ecran,
   * iar backendul citește ambele câmpuri din același formular.
   */
  send(message: string, photo?: File): Promise<void> {
    const form = new FormData();
    form.append('message', message);
    if (photo) form.append('photo', photo);
    return api.request('/feedback', { method: 'POST', formData: form });
  },
};

export const shelfKeys = {
  /** Prefixul tuturor listelor de raft - pentru invalidare în bloc. */
  all: ['bookshelf'] as const,
  bookshelf: () => ['bookshelf', 'me'] as const,
  owned: () => ['bookshelf', 'me', 'owned'] as const,
  bookRequests: () => ['book-requests', 'mine'] as const,
};
