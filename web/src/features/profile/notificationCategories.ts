/**
 * Categoriile de notificări din Setări.
 *
 * Serverul ține preferința pe TIP (vezi NotificationPreference din
 * schema.prisma), dar ecranul comută CATEGORII: 31 de comutatoare individuale
 * n-ar fi de citit, iar tipurile dintr-o categorie n-au sens separat - nimeni
 * nu vrea „licitații" pornit, dar „ai fost depășit" oprit.
 *
 * Excepția sunt cele două notificări de urmărire, fiecare cu categoria ei: „a
 * listat o carte" și „a terminat o carte" diferă ca frecvență și ca interes.
 *
 * Reuniunea tipurilor de aici acoperă toate tipurile COMUTABILE din backend
 * (CONFIGURABLE_NOTIFICATION_TYPES). Un tip nou trebuie adăugat și aici, altfel
 * rămâne fără comutator în interfață. Nu sunt incluse, intenționat: mesajele de
 * la echipa de suport (nu se pot opri) și vechea notificare pe gen.
 *
 * Ordinea urmează ce contează pentru user, nu alfabetul: întâi ce i se
 * întâmplă LUI, apoi ce a cerut, apoi descoperirea.
 */
export interface NotificationCategory {
  id: string;
  labelKey: string;
  types: string[];
}

export const NOTIFICATION_CATEGORIES: NotificationCategory[] = [
  { id: 'messages', labelKey: 'notificationPrefMessages', types: ['NEW_MESSAGE'] },
  {
    id: 'exchanges',
    labelKey: 'notificationPrefExchanges',
    types: [
      'EXCHANGE_REQUEST_RECEIVED',
      'EXCHANGE_REQUEST_ACCEPTED',
      'EXCHANGE_REQUEST_REJECTED',
      'EXCHANGE_MEETING_SCHEDULED',
      'EXCHANGE_MEETING_PROPOSED',
      'EXCHANGE_MEETING_ACCEPTED',
      'EXCHANGE_MEETING_DECLINED',
      'EXCHANGE_CONTACT_SHARED',
      'EXCHANGE_READY',
      'EXCHANGE_POSTPONED',
      'EXCHANGE_DONE_PENDING_CONFIRMATION',
      'EXCHANGE_DONE_DISPUTED',
      'EXCHANGE_COMPLETED',
      'EXCHANGE_CANCELLED',
      'EXCHANGE_BOOK_PENDING',
      'EXCHANGE_REOPENED',
    ],
  },
  {
    id: 'offers',
    labelKey: 'notificationPrefOffers',
    types: ['PRICE_OFFER_RECEIVED', 'PRICE_OFFER_ACCEPTED', 'PRICE_OFFER_REJECTED', 'PRICE_CHANGED'],
  },
  {
    id: 'auctions',
    labelKey: 'notificationPrefAuctions',
    types: ['OUTBID', 'AUCTION_WON', 'AUCTION_ENDED'],
  },
  { id: 'groupPosts', labelKey: 'notificationPrefGroupPosts', types: ['GROUP_POST'] },
  {
    id: 'followedUserNewBook',
    labelKey: 'notificationPrefFollowedNewBook',
    types: ['FOLLOWED_USER_NEW_BOOK'],
  },
  {
    id: 'followedUserFinishedBook',
    labelKey: 'notificationPrefFollowedFinishedBook',
    types: ['FOLLOWED_USER_FINISHED_BOOK'],
  },
  { id: 'nearbyCity', labelKey: 'notificationPrefNearbyCity', types: ['NEARBY_BOOK_LISTED'] },
  {
    id: 'discovery',
    labelKey: 'notificationPrefDiscovery',
    types: [
      'WISHLIST_BOOK_AVAILABLE',
      'SAVED_SEARCH_MATCH',
      'SERIES_VOLUME_AVAILABLE',
      'BOOK_REQUEST_FOUND',
    ],
  },
];

/**
 * O categorie e pornită dacă MĂCAR UN tip din ea e pornit.
 *
 * Nu „toate pornite": după ce serverul adaugă un tip nou la o categorie
 * existentă, acela vine implicit pe `true`, dar un user care oprise categoria
 * ar vedea-o brusc pornită la loc. Cu „măcar unul", comutatorul reflectă ce
 * chiar primește userul.
 */
export function isCategoryEnabled(
  category: NotificationCategory,
  preferences: Record<string, boolean>,
): boolean {
  return category.types.some((type) => preferences[type] !== false);
}
