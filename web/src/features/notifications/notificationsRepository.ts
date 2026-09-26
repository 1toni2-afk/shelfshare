import { api } from '@/lib/api/client';

/**
 * Tipurile vin de la backend ca SNAKE_CASE. Le păstrăm ca `string`, nu ca
 * uniune închisă: un tip nou adăugat pe server nu trebuie să spargă ecranul de
 * notificări al unui client care încă n-a fost actualizat - cade pe ruta
 * implicită și se afișează normal.
 */
export interface AppNotification {
  id: string;
  type: string;
  message: string;
  data: Record<string, unknown> | null;
  isRead: boolean;
  createdAt: string;
}

export const notificationsRepository = {
  list(signal?: AbortSignal): Promise<AppNotification[]> {
    return api.get<AppNotification[]>('/notifications', { signal });
  },

  markRead(id: string): Promise<void> {
    return api.post(`/notifications/${id}/read`);
  },

  markAllRead(): Promise<void> {
    return api.post('/notifications/read-all');
  },
};

export const notificationsKeys = {
  all: ['notifications'] as const,
  list: () => ['notifications', 'list'] as const,
};

/**
 * Unde duce o notificare la click. Port al notification_route.dart.
 *
 * Întoarce `null` când notificarea nu are destinație (sau îi lipsesc datele) -
 * apelantul o randează atunci ca text simplu, nu ca link. Fără distincția asta
 * apăreau linkuri care nu duceau nicăieri, iar userul credea că e stricat.
 */
export function routeForNotification(notification: AppNotification): string | null {
  const at = (key: string): string | null => {
    const value = notification.data?.[key];
    return value === undefined || value === null ? null : String(value);
  };

  switch (notification.type) {
    case 'WISHLIST_BOOK_AVAILABLE':
    case 'PRICE_CHANGED':
      return '/wishlist';

    case 'NEW_MESSAGE': {
      const conversationId = at('conversationId');
      return conversationId ? `/chat/${conversationId}` : null;
    }

    case 'EXCHANGE_REQUEST_RECEIVED':
    case 'EXCHANGE_REQUEST_REJECTED':
    case 'EXCHANGE_MEETING_SCHEDULED':
    case 'EXCHANGE_BOOK_PENDING':
    case 'EXCHANGE_REOPENED':
      return '/exchanges';

    case 'EXCHANGE_REQUEST_ACCEPTED':
    case 'EXCHANGE_MEETING_PROPOSED':
    case 'EXCHANGE_MEETING_ACCEPTED':
    case 'EXCHANGE_MEETING_DECLINED':
    case 'EXCHANGE_CONTACT_SHARED':
    case 'EXCHANGE_READY':
    case 'EXCHANGE_POSTPONED':
    case 'EXCHANGE_DONE_PENDING_CONFIRMATION':
    case 'EXCHANGE_DONE_DISPUTED':
    case 'EXCHANGE_COMPLETED':
    case 'EXCHANGE_CANCELLED': {
      const exchangeRequestId = at('exchangeRequestId');
      if (exchangeRequestId) return `/exchanges/${exchangeRequestId}/ready`;
      const offerId = at('offerId');
      if (offerId) return `/offers/${offerId}/ready`;
      return '/exchanges';
    }

    case 'PRICE_OFFER_ACCEPTED': {
      const offerId = at('offerId');
      return offerId ? `/offers/${offerId}/ready` : '/exchanges';
    }

    case 'PRICE_OFFER_RECEIVED':
    case 'PRICE_OFFER_REJECTED': {
      const conversationId = at('conversationId');
      return conversationId ? `/chat/${conversationId}` : '/exchanges';
    }

    case 'FOLLOWED_USER_NEW_BOOK': {
      const userBookId = at('userBookId');
      if (userBookId) return `/books/${userBookId}`;
      const userId = at('userId');
      return userId ? `/users/${userId}` : null;
    }

    case 'FOLLOWED_USER_FINISHED_BOOK': {
      const bookId = at('bookId');
      if (bookId) return `/work/${bookId}`;
      const userId = at('userId');
      return userId ? `/users/${userId}` : null;
    }

    case 'NEARBY_BOOK_LISTED':
    case 'INTEREST_BOOK_LISTED':
    case 'SERIES_VOLUME_AVAILABLE':
      return '/search';

    case 'SAVED_SEARCH_MATCH':
      return '/saved-searches';

    case 'GROUP_POST': {
      const groupId = at('groupId');
      return groupId ? `/groups/${groupId}` : '/groups';
    }

    case 'ADMIN_MESSAGE':
      return '/support/chat';

    case 'BOOK_REQUEST_FOUND': {
      const bookId = at('bookId');
      return bookId ? `/work/${bookId}` : '/book-requests';
    }

    case 'OUTBID':
    case 'AUCTION_WON':
    case 'AUCTION_ENDED': {
      const auctionId = at('auctionId');
      return auctionId ? `/auctions/${auctionId}` : null;
    }

    default:
      return null;
  }
}

/** Categoriile după care filtrează ecranul de notificări. */
export function categoryOf(notification: AppNotification): 'messages' | 'exchanges' | 'other' {
  if (notification.type === 'NEW_MESSAGE') return 'messages';
  if (notification.type.startsWith('EXCHANGE_') || notification.type.startsWith('PRICE_OFFER_')) {
    return 'exchanges';
  }
  return 'other';
}
