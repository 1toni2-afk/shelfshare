import { api } from '@/lib/api/client';
import type { Book, PublicUser } from '@/types/models';

export interface Group {
  id: string;
  name: string;
  description: string | null;
  isPublic: boolean;
  memberCount: number;
  isMember?: boolean;
  createdAt: string;
}

export interface GroupPost {
  id: string;
  content: string;
  author: PublicUser;
  createdAt: string;
}

export interface GroupEvent {
  id: string;
  title: string;
  description: string | null;
  location: string | null;
  /** `eventAt` în API (GroupEvent din schema.prisma), nu `startsAt`. */
  eventAt: string;
}

export interface GroupDetail extends Group {
  posts: GroupPost[];
  events: GroupEvent[];
  members?: PublicUser[];
}

/**
 * Un exemplar dintr-o potrivire. Backendul întoarce o proiecție plată
 * (`userBookId`, `title`, `coverUrl`), NU un `UserBook` întreg - vezi
 * getSmartMatches din backend/src/books/books.service.ts.
 */
export interface SmartMatchBook {
  /** Id-ul anunțului, nu al cărții din catalog: cu el se deschide /books/:id. */
  userBookId: string;
  title: string;
  /** Opțional: backendul de producție îl trimite abia după redeploy. */
  author?: string | null;
  coverUrl: string | null;
}

export interface SmartMatch {
  /** Numele câmpului vine din API (`owner`), nu `user`. */
  owner: PublicUser;
  /** Cărți pe care le are el și le vreau eu. */
  theirBooks: SmartMatchBook[];
  /** Cărți pe care le am eu și le vrea el. */
  myBooksTheyWant: SmartMatchBook[];
}

/**
 * Un card de Book Match. Backendul întoarce câmpurile cărții APLATIZATE (titlu,
 * autor, copertă direct pe card), nu un obiect `book` imbricat - vezi
 * BookMatchCard.fromJson din book_match_repository.dart.
 */
export interface BookMatchCard {
  /** `bookId`, nu `id`: cardul e o proiecție a cărții, nu cartea însăși. */
  bookId: string;
  title: string;
  author: string | null;
  coverUrl: string | null;
  genre: string | null;
  publishedYear: number | null;
  description: string | null;
  /** Carte scoasă din zona de descoperire, nu din preferințele userului. */
  isDiscovery: boolean;
}

export interface BookMatchQueue {
  /**
   * Backendul LEAGĂ coada de sesiune: același `sessionId` trebuie trimis și la
   * fiecare swipe, altfel serverul nu poate corela răspunsurile cu teancul pe
   * care l-a servit. Îl generăm noi și îl păstrăm cât ține ecranul.
   */
  sessionId: string;
  cards: BookMatchCard[];
}

export interface BookMatchSwipeResult {
  recorded: boolean;
  addedToWishlist: boolean;
  onboardingSwipesCount: number;
  discoveryBoostSwipesRemaining: number;
}

/**
 * Grupul așa cum vine din API: numărul de membri e în `_count.members`
 * (include-ul Prisma din groups.service.ts), nu într-un `memberCount` plat.
 * Tipul promitea `memberCount`, TypeScript n-avea cum să prindă diferența, iar
 * pe ecran apărea „undefined membri".
 */
type RawGroup<T extends Group = Group> = Omit<T, 'memberCount'> & {
  _count?: { members?: number };
};

function withMemberCount<T extends Group>(group: RawGroup<T>): T {
  return { ...group, memberCount: group._count?.members ?? 0 } as T;
}

export const groupsRepository = {
  async mine(signal?: AbortSignal): Promise<Group[]> {
    return (await api.get<RawGroup[]>('/groups/mine', { signal })).map(withMemberCount);
  },

  async discover(signal?: AbortSignal): Promise<Group[]> {
    return (await api.get<RawGroup[]>('/groups/public', { signal })).map(withMemberCount);
  },

  async detail(id: string, signal?: AbortSignal): Promise<GroupDetail> {
    return withMemberCount(await api.get<RawGroup<GroupDetail>>(`/groups/${id}`, { signal }));
  },

  async create(input: { name: string; description?: string; isPublic: boolean }): Promise<Group> {
    return withMemberCount(await api.post<RawGroup>('/groups', input));
  },

  join(id: string): Promise<void> {
    return api.post(`/groups/${id}/join`);
  },

  leave(id: string): Promise<void> {
    return api.post(`/groups/${id}/leave`);
  },

  remove(id: string): Promise<void> {
    return api.delete(`/groups/${id}`);
  },

  post(id: string, content: string): Promise<GroupPost> {
    return api.post<GroupPost>(`/groups/${id}/posts`, { content });
  },

  addEvent(id: string, input: { title: string; location?: string; eventAt: string }) {
    return api.post<GroupEvent>(`/groups/${id}/events`, input);
  },

  reportPost(groupId: string, postId: string, reason: string): Promise<void> {
    return api.post(`/groups/${groupId}/posts/${postId}/report`, { reason });
  },
};

export const bookMatchRepository = {
  queue(sessionId: string, size = 20, signal?: AbortSignal): Promise<BookMatchQueue> {
    return api.get<BookMatchQueue>('/book-match/queue', {
      // `size` e limitat de backend la 1-50; cerem 20, ca în Flutter.
      query: { sessionId, size },
      signal,
    });
  },

  /**
   * `YES` adaugă cartea în lista de dorințe (sursa BOOK_MATCH), `NO` o exclude,
   * `SKIP` o amână fără să exprime o preferință - de aceea sunt trei valori,
   * nu un boolean.
   */
  swipe(input: {
    bookId: string;
    action: 'YES' | 'NO' | 'SKIP';
    sessionId: string;
    isDiscovery?: boolean;
  }): Promise<BookMatchSwipeResult> {
    return api.post<BookMatchSwipeResult>('/book-match/swipe', input);
  },

  recalibrate(): Promise<void> {
    return api.post('/book-match/recalibrate');
  },

  status(signal?: AbortSignal): Promise<{ canRecalibrate: boolean; nextAt?: string }> {
    return api.get('/book-match/status', { signal });
  },
};

export const statsRepository = {
  smartMatches(signal?: AbortSignal): Promise<SmartMatch[]> {
    return api.get<SmartMatch[]>('/books/smart-matches', { signal });
  },

  mostShared(signal?: AbortSignal): Promise<Array<{ book: Book; count: number }>> {
    return api.get('/books/most-shared', { signal });
  },

  trending(signal?: AbortSignal): Promise<Array<{ book: Book; count: number }>> {
    return api.get('/books/trending', { signal });
  },
};

export const socialKeys = {
  groupsMine: () => ['groups', 'mine'] as const,
  groupsDiscover: () => ['groups', 'public'] as const,
  group: (id: string) => ['groups', id] as const,
  bookMatchQueue: () => ['book-match', 'queue'] as const,
  bookMatchStatus: () => ['book-match', 'status'] as const,
  smartMatches: () => ['books', 'smart-matches'] as const,
  mostShared: () => ['books', 'most-shared'] as const,
  trending: () => ['books', 'trending'] as const,
};
