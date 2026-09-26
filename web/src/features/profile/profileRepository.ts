import { api } from '@/lib/api/client';
import type {
  AppUser,
  CurrentlyReading,
  PublicUser,
  ReadingChallenge,
  ReadingStats,
  TrustScore,
  UserBook,
} from '@/types/models';

export interface PublicProfile extends PublicUser {
  bio: string | null;
  booksExchangedCount: number;
  booksSharedCount: number;
  booksReceivedCount: number;
  languages: string[];
  /**
   * Data înscrierii. API-ul o trimite ca `memberSince`, nu `createdAt` - tipul
   * vechi citea `createdAt`, mereu undefined, deci „Membru din" nu apărea.
   */
  memberSince: string | null;
  /** Doar anunțurile de schimb - forma veche, păstrată pentru Flutter. */
  listedBooks?: UserBook[];
  /** Toate anunțurile publice: schimb, vânzare, donație, licitație. */
  availableBooks?: UserBook[];
  reviews?: PublicReview[];
  readingStats?: ReadingStats | null;
  trustScore?: TrustScore | null;
  currentlyReading?: CurrentlyReading | null;
  isFollowing?: boolean;
  followersCount?: number;
  followingCount?: number;
}

/** O recenzie text primită după un schimb finalizat (vezi getReviews). */
export interface PublicReview {
  reviewerId: string;
  reviewerName: string | null;
  reviewerImage: string | null;
  rating: number | null;
  comment: string | null;
  date: string;
}

/**
 * „Tu & X": anunțurile lui care îți sunt pe wishlist și anunțurile tale care îi
 * sunt lui pe wishlist. Potrivirea e pe operă, nu pe exemplar.
 */
export interface Compatibility {
  theirBooksYouWant: UserBook[];
  yourBooksTheyWant: UserBook[];
}

/**
 * O intrare din fluxul de activitate. Backendul întoarce o listă OMOGENĂ ca
 * formă (aceleași câmpuri de carte și de autor peste tot), cu `type` ca
 * discriminator și câteva câmpuri în plus per tip - vezi getActivityFeed din
 * profile.service.ts. Nu e o uniune de tipuri discriminată strict, fiindcă nu
 * e nici pe server.
 */
export interface ActivityEntry {
  type: 'new_listing' | 'finished_book' | 'completed_exchange' | 'sale' | 'reading_progress';
  /** Cheia stabilă `tip:idSursă` - ținta aprecierilor și comentariilor. */
  id: string;
  /** Cartea din catalog; la un schimb, cea primită de cel din feed. */
  bookId: string;
  /** doar `new_listing` - anunțul, pentru „Vezi cartea" */
  userBookId?: string;
  likeCount: number;
  likedByMe: boolean;
  commentCount: number;
  wishlistedByMe: boolean;
  readingByMe: boolean;
  /** doar `finished_book` - nota și părerea din recenzia lui, dacă a lăsat una */
  rating?: number | null;
  reviewText?: string | null;
  userId: string;
  userName: string | null;
  userAvatar: string | null;
  bookTitle: string;
  bookAuthor: string | null;
  bookCoverUrl: string | null;
  genre: string | null;
  date: string;
  /** doar `new_listing` */
  caption?: string | null;
  /** doar `completed_exchange` */
  offeredBookTitle?: string | null;
  offeredBookCoverUrl?: string | null;
  /** Cărțile văzute din partea celui urmărit: ce a primit, ce a dat. Oricare
   *  poate lipsi la un schimb care n-a fost carte-contra-carte. */
  receivedBookTitle?: string | null;
  receivedBookCoverUrl?: string | null;
  givenBookTitle?: string | null;
  givenBookCoverUrl?: string | null;
  counterpartyId?: string;
  counterpartyName?: string | null;
  counterpartyAvatar?: string | null;
  /** doar `sale` - convertit deja la number pe server */
  amount?: number;
  /** doar `reading_progress` */
  currentPage?: number;
  totalPages?: number | null;
}

/** Ale cui evenimente: urmăriți, din oraș, sau ambele. */
export type FeedScope = 'following' | 'nearby' | 'all';
/** Restrânge tipurile pe server: citit (progres + terminate) sau schimburi. */
export type FeedKind = 'reading' | 'exchanges';
export const FEED_PAGE_SIZE = 20;

export interface FeedComment {
  id: string;
  text: string;
  createdAt: string;
  user: { id: string; name: string | null; profileImage: string | null };
  isMine: boolean;
  canDelete: boolean;
}

export interface NotificationPreferences {
  [key: string]: boolean;
}

export interface UpdateProfileInput {
  name?: string | null;
  username?: string | null;
  nameVisible?: boolean;
  city?: string | null;
  bio?: string | null;
  languages?: string[];
  showAcquisitionHistory?: boolean;
  hideSwapListingsPublic?: boolean;
  hideSaleListingsPublic?: boolean;
  hideDonationListingsPublic?: boolean;
  hideAuctionListingsPublic?: boolean;
}

export const profileRepository = {
  me(signal?: AbortSignal): Promise<AppUser> {
    return api.get<AppUser>('/profile/me', { signal });
  },

  update(input: UpdateProfileInput): Promise<AppUser> {
    return api.patch<AppUser>('/profile/me', input);
  },

  /**
   * Chestionarul de cititor, pasul final al onboardingului.
   *
   * Întoarce DOAR câmpurile de chestionar, nu utilizatorul întreg - de aceea
   * apelantul trebuie să lipească `readingSurveyCompletedAt` peste userul din
   * sesiune. Atât timp cât rămâne `null`, routerul trimite omul înapoi la
   * onboarding (vezi RequireAuth).
   */
  saveReadingSurvey(input: {
    purpose?: string;
    readingPace?: string;
    favoriteGenres?: string[];
    favoriteAuthors?: string[];
  }): Promise<{ readingSurveyCompletedAt: string | null }> {
    return api.put<{ readingSurveyCompletedAt: string | null }>(
      '/profile/me/reading-survey',
      input,
    );
  },

  publicProfile(userId: string, signal?: AbortSignal): Promise<PublicProfile> {
    return api.get<PublicProfile>(`/profile/${userId}`, { signal });
  },

  compatibility(userId: string, signal?: AbortSignal): Promise<Compatibility> {
    return api.get<Compatibility>(`/profile/${userId}/compatibility`, { signal });
  },

  activityFeed(
    params: { scope: FeedScope; kind?: FeedKind; offset?: number; limit?: number },
    signal?: AbortSignal,
  ): Promise<ActivityEntry[]> {
    const query = new URLSearchParams({
      scope: params.scope,
      limit: String(params.limit ?? FEED_PAGE_SIZE),
      offset: String(params.offset ?? 0),
      ...(params.kind ? { kind: params.kind } : {}),
    });
    return api.get<ActivityEntry[]>(`/profile/activity-feed?${query}`, { signal });
  },

  likeFeedEvent(eventKey: string, like: boolean): Promise<{ likeCount: number; likedByMe: boolean }> {
    const path = `/profile/activity-feed/${encodeURIComponent(eventKey)}/like`;
    return like ? api.put(path, {}) : api.delete(path);
  },

  feedComments(eventKey: string, signal?: AbortSignal): Promise<FeedComment[]> {
    return api.get<FeedComment[]>(
      `/profile/activity-feed/${encodeURIComponent(eventKey)}/comments`,
      { signal },
    );
  },

  addFeedComment(eventKey: string, text: string): Promise<FeedComment> {
    return api.post<FeedComment>(
      `/profile/activity-feed/${encodeURIComponent(eventKey)}/comments`,
      { text },
    );
  },

  deleteFeedComment(commentId: string): Promise<void> {
    return api.delete(`/profile/activity-feed/comments/${commentId}`);
  },

  reportFeedComment(commentId: string, reason: string): Promise<void> {
    return api.post(`/profile/activity-feed/comments/${commentId}/report`, { reason });
  },

  async uploadPhoto(file: File): Promise<AppUser> {
    const form = new FormData();
    form.append('photo', file);
    return api.request<AppUser>('/profile/me/photo', { method: 'POST', formData: form });
  },

  removePhoto(): Promise<AppUser> {
    return api.delete<AppUser>('/profile/me/photo');
  },

  notificationPreferences(signal?: AbortSignal): Promise<NotificationPreferences> {
    return api.get<NotificationPreferences>('/notifications/preferences', { signal });
  },

  /**
   * Backendul așteaptă o LISTĂ `{type, enabled}`, nu harta plată pe care o
   * întoarce GET-ul. E un PUT parțial dinadins: ecranul comută o categorie
   * odată, iar restul preferințelor rămân neatinse - două tab-uri deschise nu
   * se suprascriu reciproc.
   */
  saveNotificationPreferences(
    changes: Record<string, boolean>,
  ): Promise<NotificationPreferences> {
    const preferences = Object.entries(changes).map(([type, enabled]) => ({ type, enabled }));
    return api.put<NotificationPreferences>('/notifications/preferences', { preferences });
  },

  leaderboardNational(signal?: AbortSignal) {
    return api.get<LeaderboardEntry[]>('/profile/leaderboard/national', { signal });
  },

  leaderboardCities(signal?: AbortSignal) {
    return api.get<LeaderboardEntry[]>('/profile/leaderboard/cities', { signal });
  },

  topReaders(signal?: AbortSignal) {
    return api.get<LeaderboardEntry[]>('/profile/leaderboard/top-readers', { signal });
  },

  sellerAnalytics(signal?: AbortSignal) {
    return api.get<Record<string, unknown>>('/profile/seller-analytics', { signal });
  },

  readingChallenge(signal?: AbortSignal): Promise<ReadingChallenge> {
    return api.get<ReadingChallenge>('/profile/reading-challenge', { signal });
  },
};

/**
 * O intrare de clasament. TOATE cele trei clasamente întorc USERI, inclusiv
 * cel „pe orașe" - acela e topul userilor din orașul meu, nu un clasament al
 * orașelor. Diferă doar metrica: `booksExchangedCount` la schimburi,
 * `totalPages` la cititori.
 */
export interface LeaderboardEntry {
  id: string;
  name: string | null;
  username: string | null;
  nameVisible: boolean;
  profileImage: string | null;
  city: string | null;
  rating?: number;
  booksExchangedCount?: number;
  totalPages?: number;
}

/** Forma reală din follow.service.ts `getFollowStatus` - câmpul e `isFollowing`, nu `following`. */
export interface FollowStatus {
  isFollowing: boolean;
  followersCount: number;
  followingCount: number;
}

export const followRepository = {
  following(signal?: AbortSignal): Promise<PublicUser[]> {
    return api.get<PublicUser[]>('/users/me/following', { signal });
  },

  follow(userId: string): Promise<void> {
    return api.post(`/users/${userId}/follow`);
  },

  unfollow(userId: string): Promise<void> {
    return api.delete(`/users/${userId}/follow`);
  },

  isFollowing(userId: string, signal?: AbortSignal): Promise<FollowStatus> {
    return api.get<FollowStatus>(`/users/${userId}/follow`, { signal });
  },
};

export const profileKeys = {
  all: ['profile'] as const,
  me: () => ['profile', 'me'] as const,
  public: (userId: string) => ['profile', 'public', userId] as const,
  activityFeed: (filter?: string) =>
    filter ? (['profile', 'activity-feed', filter] as const) : (['profile', 'activity-feed'] as const),
  feedComments: (eventKey: string) => ['profile', 'feed-comments', eventKey] as const,
  notificationPreferences: () => ['profile', 'notification-preferences'] as const,
  following: () => ['profile', 'following'] as const,
  leaderboard: (scope: string) => ['profile', 'leaderboard', scope] as const,
  sellerAnalytics: () => ['profile', 'seller-analytics'] as const,
  readingChallenge: () => ['profile', 'reading-challenge'] as const,
  compatibility: (userId: string) => ['profile', 'compatibility', userId] as const,
};
