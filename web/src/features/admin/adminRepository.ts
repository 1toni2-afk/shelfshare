import { api } from '@/lib/api/client';
import type { PublicUser } from '@/types/models';

/**
 * Statisticile sunt GRUPATE pe domenii, nu plate: `{users: {total, verified},
 * books: {totalInCatalog, totalListings}, exchanges: {total, completed,
 * pending}}`. Verificat pe răspunsul real - o presupunere de câmpuri plate
 * (`totalUsers` etc.) afișa peste tot „—", fără nicio eroare.
 */
export interface AdminStats {
  users?: { total?: number; verified?: number };
  books?: { totalInCatalog?: number; totalListings?: number };
  exchanges?: { total?: number; completed?: number; pending?: number };
}

/** Răspunsul de la `/admin/stats/usage`, a cărui formă variază. */
export type AdminUsageStats = Record<string, unknown>;

export interface AdminUser {
  id: string;
  email: string;
  name: string | null;
  username: string | null;
  city: string | null;
  /** Lipsește din lista paginată, prezent la căutare - de aceea e opțional. */
  profileImage?: string | null;
  isAdmin: boolean;
  isPremium: boolean;
  isBanned?: boolean;
  isEmailVerified?: boolean;
  rating?: number;
  booksExchangedCount?: number;
  createdAt: string;
}

export interface AdminReport {
  id: string;
  targetType: string;
  targetId: string;
  reason: string;
  status: string;
  createdAt: string;
  reporter?: PublicUser | null;
}

export interface Administrator {
  userId: string;
  email: string;
  name: string | null;
  role: string;
}

export interface AdminRole {
  id: string;
  name: string;
  permissions: string[];
}

export interface FeatureFlag {
  key: string;
  label?: string;
}

export interface AdminChatConversation {
  id: string;
  user: PublicUser;
  lastMessage: { content: string | null; createdAt: string } | null;
  unreadCount: number;
  updatedAt: string;
}

export interface AdminChatMessage {
  id: string;
  content: string | null;
  fromAdmin: boolean;
  createdAt: string;
}

export const adminRepository = {
  stats(signal?: AbortSignal): Promise<AdminStats> {
    return api.get<AdminStats>('/admin/stats', { signal });
  },

  usage(signal?: AbortSignal): Promise<AdminUsageStats> {
    return api.get<AdminUsageStats>('/admin/stats/usage', { signal });
  },

  marketplace(signal?: AbortSignal): Promise<AdminUsageStats> {
    return api.get<AdminUsageStats>('/admin/stats/marketplace', { signal });
  },

  /**
   * Două endpointuri distincte, cu forme DIFERITE: `/users` întoarce un plic
   * paginat `{items, limit, offset}`, iar `/users/search` un tablou simplu.
   * Normalizăm aici la un tablou, ca ecranul să nu poarte diferența - altfel
   * `.map` cade pe unul dintre cele două cazuri, cum s-a și întâmplat.
   *
   * Căutarea trimisă fără termen întoarce erori de validare, deci alegerea
   * endpointului se face după prezența termenului, nu invers.
   */
  async users(query: { q?: string } = {}, signal?: AbortSignal): Promise<AdminUser[]> {
    const term = query.q?.trim();
    if (term) {
      return api.get<AdminUser[]>('/admin/users/search', { query: { q: term }, signal });
    }
    const page = await api.get<{ items: AdminUser[] }>('/admin/users', { signal });
    return page.items ?? [];
  },

  banUser(id: string): Promise<void> {
    return api.post(`/admin/users/${id}/ban`);
  },

  unbanUser(id: string): Promise<void> {
    return api.post(`/admin/users/${id}/unban`);
  },

  togglePremium(id: string): Promise<void> {
    return api.post(`/admin/users/${id}/toggle-premium`);
  },

  reports(signal?: AbortSignal): Promise<AdminReport[]> {
    return api.get<AdminReport[]>('/admin/reports/users', { signal });
  },

  reportCounts(signal?: AbortSignal): Promise<Record<string, number>> {
    return api.get<Record<string, number>>('/admin/reports/counts', { signal });
  },

  setReportStatus(id: string, status: string): Promise<void> {
    return api.put(`/admin/reports/${id}/status`, { status });
  },

  unhideReport(id: string): Promise<void> {
    return api.post(`/admin/reports/${id}/unhide`);
  },

  inactiveListings(signal?: AbortSignal): Promise<Array<Record<string, unknown>>> {
    return api.get<Array<Record<string, unknown>>>('/admin/reports/inactive-listings', { signal });
  },

  administrators(signal?: AbortSignal): Promise<Administrator[]> {
    return api.get<Administrator[]>('/admin/administrators', { signal });
  },

  roles(signal?: AbortSignal): Promise<AdminRole[]> {
    return api.get<AdminRole[]>('/admin/roles', { signal });
  },

  featureFlags(signal?: AbortSignal): Promise<FeatureFlag[]> {
    return api.get<FeatureFlag[]>('/admin/feature-flags', { signal });
  },

  userFeatureFlags(id: string, signal?: AbortSignal): Promise<Record<string, boolean>> {
    return api.get<Record<string, boolean>>(`/admin/users/${id}/feature-flags`, { signal });
  },

  setUserFeatureFlags(id: string, flags: Record<string, boolean>): Promise<void> {
    return api.put(`/admin/users/${id}/feature-flags`, flags);
  },

  feedback(signal?: AbortSignal): Promise<Array<Record<string, unknown>>> {
    return api.get<Array<Record<string, unknown>>>('/admin/feedback', { signal });
  },

  supportRequests(signal?: AbortSignal): Promise<Array<Record<string, unknown>>> {
    return api.get<Array<Record<string, unknown>>>('/admin/support-requests', { signal });
  },
};

/**
 * Chatul cu suportul are DOUĂ perspective pe aceleași date: `/me` e firul
 * userului obișnuit cu echipa, `/conversations` e inboxul administratorului.
 * De aceea sunt în același repository, dar cu metode separate.
 */
export const adminChatRepository = {
  /**
   * `/admin-chat/me` întoarce conversația, nu lista de mesaje:
   * `{ id, messages }`. Despachetăm aici, ca ecranul să primească exact ce
   * afișează - altfel `thread.data.map` cade pe un obiect, exact ce se
   * întâmpla la „Chat cu un administrator".
   */
  myThread(signal?: AbortSignal): Promise<AdminChatMessage[]> {
    return api
      .get<{ id: string; messages: AdminChatMessage[] }>('/admin-chat/me', { signal })
      .then((conversation) => conversation.messages ?? []);
  },

  sendAsUser(content: string): Promise<AdminChatMessage> {
    return api.post<AdminChatMessage>('/admin-chat/me/messages', { content });
  },

  markMineRead(): Promise<void> {
    return api.post('/admin-chat/me/read');
  },

  inbox(signal?: AbortSignal): Promise<AdminChatConversation[]> {
    return api.get<AdminChatConversation[]>('/admin-chat/conversations', { signal });
  },

  messages(id: string, signal?: AbortSignal): Promise<AdminChatMessage[]> {
    return api.get<AdminChatMessage[]>(`/admin-chat/conversations/${id}/messages`, { signal });
  },

  sendAsAdmin(id: string, content: string): Promise<AdminChatMessage> {
    return api.post<AdminChatMessage>(`/admin-chat/conversations/${id}/messages`, { content });
  },
};

export const adminKeys = {
  stats: () => ['admin', 'stats'] as const,
  usage: () => ['admin', 'usage'] as const,
  users: (q: string) => ['admin', 'users', q] as const,
  reports: () => ['admin', 'reports'] as const,
  reportCounts: () => ['admin', 'reports', 'counts'] as const,
  inactiveListings: () => ['admin', 'inactive-listings'] as const,
  administrators: () => ['admin', 'administrators'] as const,
  roles: () => ['admin', 'roles'] as const,
  featureFlags: () => ['admin', 'feature-flags'] as const,
  feedback: () => ['admin', 'feedback'] as const,
  supportRequests: () => ['admin', 'support-requests'] as const,
  adminChatMine: () => ['admin-chat', 'me'] as const,
  adminChatInbox: () => ['admin-chat', 'conversations'] as const,
  adminChatMessages: (id: string) => ['admin-chat', 'conversations', id] as const,
};
