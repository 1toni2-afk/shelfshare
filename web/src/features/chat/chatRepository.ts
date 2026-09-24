import { api } from '@/lib/api/client';
import type { PublicUser } from '@/types/models';

export interface ReplyPreview {
  id: string;
  senderId: string;
  content: string | null;
  photo: string | null;
}

export interface PriceOfferSummary {
  id: string;
  amount: string;
  status: string;
  message: string | null;
  bookTitle: string;
  bookAuthor: string | null;
  bookCoverUrl: string | null;
}

export interface ExchangeRequestSummary {
  id: string;
  status: string;
  offeredAmount: string | null;
  requestedBookTitle: string;
  requestedBookCoverUrl: string | null;
  offeredBookTitle: string | null;
  offeredBookCoverUrl: string | null;
}

export interface ChatMessage {
  id: string;
  conversationId: string;
  senderId: string;
  content: string | null;
  photo: string | null;
  location: string | null;
  locationLat: number | null;
  locationLng: number | null;
  meetingAt: string | null;
  priceOffer: PriceOfferSummary | null;
  exchangeRequest: ExchangeRequestSummary | null;
  replyTo: ReplyPreview | null;
  isRead: boolean;
  createdAt: string;
}

export interface Conversation {
  id: string;
  otherUser: PublicUser;
  lastMessage: ChatMessage | null;
  updatedAt: string;
  unreadCount: number;
  isArchived: boolean;
}

export const chatRepository = {
  /**
   * Inboxul SAU arhiva, nu amândouă: `GET /conversations` partiționează după
   * `?archived`, iar `isArchived` din răspuns e constant pe toată lista (vezi
   * getMyConversations din conversations.service.ts).
   *
   * De aceea nu se poate cere lista o singură dată și filtra în client: fără
   * parametru primeai doar inboxul, deci fila „Arhivate" rămânea goală pentru
   * totdeauna, iar o conversație arhivată dispărea fără urmă.
   */
  getConversations(archived = false, signal?: AbortSignal): Promise<Conversation[]> {
    return api.get<Conversation[]>('/conversations', { query: { archived }, signal });
  },

  getUnreadCount(signal?: AbortSignal): Promise<{ count: number }> {
    return api.get<{ count: number }>('/conversations/unread-count', { signal });
  },

  getMessages(conversationId: string, signal?: AbortSignal): Promise<ChatMessage[]> {
    return api.get<ChatMessage[]>(`/conversations/${conversationId}/messages`, { signal });
  },

  searchMessages(conversationId: string, query: string, signal?: AbortSignal) {
    return api.get<ChatMessage[]>(`/conversations/${conversationId}/messages/search`, {
      query: { q: query },
      signal,
    });
  },

  startConversation(otherUserId: string): Promise<Conversation> {
    return api.post<Conversation>('/conversations', { otherUserId });
  },

  archive(conversationId: string): Promise<void> {
    return api.post(`/conversations/${conversationId}/archive`);
  },

  unarchive(conversationId: string): Promise<void> {
    return api.delete(`/conversations/${conversationId}/archive`);
  },

  remove(conversationId: string): Promise<void> {
    return api.delete(`/conversations/${conversationId}`);
  },

  report(conversationId: string, reason: string): Promise<void> {
    return api.post(`/conversations/${conversationId}/report`, { reason });
  },

  /**
   * Pozele urcă pe HTTP, nu prin socket: socket.io ar serializa binarul în
   * memorie și l-ar trimite pe același canal cu mesajele text, blocându-le cât
   * durează transferul. Endpointul întoarce mesajul deja creat.
   */
  async sendPhoto(conversationId: string, file: File): Promise<ChatMessage> {
    const form = new FormData();
    form.append('photo', file);
    return api.request<ChatMessage>(`/conversations/${conversationId}/photos`, {
      method: 'POST',
      formData: form,
    });
  },
};

export const chatKeys = {
  all: ['chat'] as const,
  /**
   * Fără argument e PREFIXUL celor două liste (inbox + arhivă) - exact ce
   * trebuie unui `invalidateQueries`, care se potrivește pe prefix. Cu
   * argument e cheia unei liste anume.
   */
  conversations: (archived?: boolean) =>
    (archived === undefined ? ['chat', 'conversations'] : ['chat', 'conversations', archived]) as
      | readonly ['chat', 'conversations']
      | readonly ['chat', 'conversations', boolean],
  unreadCount: () => ['chat', 'unread-count'] as const,
  messages: (conversationId: string) => ['chat', 'messages', conversationId] as const,
};
