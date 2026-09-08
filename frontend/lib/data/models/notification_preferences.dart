import 'package:flutter/material.dart';

import '../../l10n/app_localizations.dart';

/// O categorie de notificări din Setări.
///
/// Serverul ține preferința pe TIP (vezi NotificationPreference în
/// schema.prisma), dar ecranul de setări comută categorii: 31 de switch-uri
/// individuale n-ar fi de citit, iar tipurile dintr-o categorie n-au sens
/// separat - nimeni nu vrea „licitații" pornit, dar „ai fost depășit" oprit.
///
/// Excepția sunt cele două notificări de urmărire, fiecare cu categoria ei:
/// „a listat o carte" și „a terminat o carte" sunt evenimente diferite ca
/// frecvență și ca interes, deci se pot opri separat.
class NotificationCategory {
  const NotificationCategory({
    required this.id,
    required this.icon,
    required this.types,
    required this.labelOf,
  });

  final String id;
  final IconData icon;

  /// Tipurile de pe server (exact valorile enum-ului `NotificationType`).
  final List<String> types;

  final String Function(AppLocalizations l10n) labelOf;
}

/// Toate categoriile, în ordinea din ecranul de setări. Reuniunea `types`-
/// urilor de aici acoperă TOATE tipurile din backend - un tip nou trebuie
/// adăugat și aici, altfel rămâne fără comutator în interfață.
final List<NotificationCategory> kNotificationCategories = [
  NotificationCategory(
    id: 'followedUserNewBook',
    icon: Icons.library_add_outlined,
    types: const ['FOLLOWED_USER_NEW_BOOK'],
    labelOf: (l) => l.notificationPrefFollowedNewBook,
  ),
  NotificationCategory(
    id: 'followedUserFinishedBook',
    icon: Icons.auto_stories_outlined,
    types: const ['FOLLOWED_USER_FINISHED_BOOK'],
    labelOf: (l) => l.notificationPrefFollowedFinishedBook,
  ),
  NotificationCategory(
    id: 'messages',
    icon: Icons.chat_bubble_outline,
    types: const ['NEW_MESSAGE'],
    labelOf: (l) => l.notificationPrefMessages,
  ),
  NotificationCategory(
    id: 'exchanges',
    icon: Icons.swap_horiz,
    types: const [
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
    labelOf: (l) => l.notificationPrefExchanges,
  ),
  NotificationCategory(
    id: 'offers',
    icon: Icons.sell_outlined,
    types: const [
      'PRICE_OFFER_RECEIVED',
      'PRICE_OFFER_ACCEPTED',
      'PRICE_OFFER_REJECTED',
      'PRICE_CHANGED',
    ],
    labelOf: (l) => l.notificationPrefOffers,
  ),
  NotificationCategory(
    id: 'auctions',
    icon: Icons.gavel_outlined,
    types: const ['OUTBID', 'AUCTION_WON', 'AUCTION_ENDED'],
    labelOf: (l) => l.notificationPrefAuctions,
  ),
  NotificationCategory(
    id: 'discovery',
    icon: Icons.travel_explore_outlined,
    types: const [
      'WISHLIST_BOOK_AVAILABLE',
      'NEARBY_BOOK_LISTED',
      'INTEREST_BOOK_LISTED',
      'SAVED_SEARCH_MATCH',
      'SERIES_VOLUME_AVAILABLE',
      'BOOK_REQUEST_FOUND',
    ],
    labelOf: (l) => l.notificationPrefDiscovery,
  ),
];

/// Preferințele userului: tip de pe server -> pornit/oprit. Backend-ul
/// întoarce harta COMPLETĂ (inclusiv tipurile fără rând în DB, implicit
/// pornite), deci aici nu mai e nevoie de nicio convenție de „lipsă".
typedef NotificationPreferences = Map<String, bool>;

extension NotificationPreferencesX on NotificationPreferences {
  /// O categorie e pornită doar dacă TOATE tipurile ei sunt pornite. Așa o
  /// stare mixtă (posibilă doar dacă tipurile au fost setate de o versiune
  /// anterioară cu altă grupare) se arată ca „oprit", iar o atingere de
  /// switch o aduce înapoi într-o stare consistentă.
  bool isCategoryEnabled(NotificationCategory category) =>
      category.types.every((t) => this[t] ?? true);
}
