import { api } from '@/lib/api/client';
import type { AppUser, PublicUser, ReadingChallenge, UserBook } from '@/types/models';

export interface PublicProfile extends PublicUser {
  bio: string | null;
  booksExchangedCount: number;
  booksSharedCount: number;
  booksReceivedCount: number;
  languages: string[];
  createdAt: string | null;
  listedBooks?: UserBook[];
  isFollowing?: boolean;
  followersCount?: number;
  followingCount?: number;
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
  counterpartyName?: string | null;
  /** doar `sale` - convertit deja la number pe server */
  amount?: number;
  /** doar `reading_progress` */
  currentPage?: number;
  totalPages?: number | null;
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

  activityFeed(signal?: AbortSignal): Promise<ActivityEntry[]> {
    return api.get<ActivityEntry[]>('/profile/activity-feed', { signal });
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

  isFollowing(userId: string, signal?: AbortSignal): Promise<{ following: boolean }> {
    return api.get<{ following: boolean }>(`/users/${userId}/follow`, { signal });
  },
};

export const profileKeys = {
  all: ['profile'] as const,
  me: () => ['profile', 'me'] as const,
  public: (userId: string) => ['profile', 'public', userId] as const,
  activityFeed: () => ['profile', 'activity-feed'] as const,
  notificationPreferences: () => ['profile', 'notification-preferences'] as const,
  following: () => ['profile', 'following'] as const,
  leaderboard: (scope: string) => ['profile', 'leaderboard', scope] as const,
  sellerAnalytics: () => ['profile', 'seller-analytics'] as const,
  readingChallenge: () => ['profile', 'reading-challenge'] as const,
};
