import '../../data/models/app_notification.dart';

/// Ruta către care duce o notificare, sau `null` dacă tipul ei nu are o
/// destinație (tip necunoscut clientului, sau date insuficiente).
///
/// Funcție pură, fără `BuildContext`, tocmai ca să poată fi folosită din două
/// locuri foarte diferite: tap-ul pe un rând din lista de notificări (vezi
/// `notification_routing.dart`) și tap-ul pe o notificare de sistem, care e
/// procesat în afara arborelui de widget-uri, uneori chiar înainte ca
/// aplicația să aibă un router (vezi `push_notifications_service.dart`).
///
/// Datele vin fie din API (`Map<String, dynamic>`), fie din payload-ul FCM
/// (`Map<String, String>`) - de-asta citim totul prin `_str`, nu prin cast.
String? routeForNotification(NotificationType type, Map<String, dynamic>? data) {
  String? at(String key) => data?[key]?.toString();

  switch (type) {
    case NotificationType.wishlistBookAvailable:
    case NotificationType.priceChanged:
      return '/wishlist';

    case NotificationType.newMessage:
      final conversationId = at('conversationId');
      return conversationId == null ? null : '/chat/$conversationId';

    case NotificationType.exchangeRequestReceived:
    case NotificationType.exchangeRequestRejected:
    case NotificationType.exchangeMeetingScheduled:
    case NotificationType.exchangeBookPending:
    case NotificationType.exchangeReopened:
      return '/exchanges';

    case NotificationType.exchangeRequestAccepted:
    case NotificationType.exchangeMeetingProposed:
    case NotificationType.exchangeMeetingAccepted:
    case NotificationType.exchangeMeetingDeclined:
    case NotificationType.exchangeContactShared:
    case NotificationType.exchangeReady:
    case NotificationType.exchangePostponed:
    case NotificationType.exchangeDonePendingConfirmation:
    case NotificationType.exchangeDoneDisputed:
    case NotificationType.exchangeCompleted:
    case NotificationType.exchangeCancelled:
      // Aceste tipuri sunt partajate între schimburile carte-contra-carte
      // (exchangeRequestId în data) și vânzările cu bani (offerId în data) -
      // vezi backend/src/offers/offers.service.ts, care refolosește aceleași
      // NotificationType-uri EXCHANGE_* ca exchanges.service.ts.
      final exchangeRequestId = at('exchangeRequestId');
      if (exchangeRequestId != null) return '/exchanges/$exchangeRequestId/ready';
      final offerId = at('offerId');
      if (offerId != null) return '/offers/$offerId/ready';
      return '/exchanges';

    case NotificationType.priceOfferAccepted:
      // Odată acceptată, oferta intră în flow-ul de „ready to sell"
      // (programare etc.) - nu mai e doar un card de chat, ca înainte de
      // sale-flow v2.
      final acceptedOfferId = at('offerId');
      return acceptedOfferId == null ? '/exchanges' : '/offers/$acceptedOfferId/ready';

    case NotificationType.priceOfferReceived:
    case NotificationType.priceOfferRejected:
      // Oferta e vizibilă și acționabilă direct în chat (vezi
      // Message.priceOfferId) - trimitem acolo, nu la ecranul separat de
      // schimburi. Notificările vechi n-au conversationId - fallback
      // /exchanges.
      final conversationId = at('conversationId');
      return conversationId == null ? '/exchanges' : '/chat/$conversationId';

    case NotificationType.followedUserNewBook:
      // Duce direct la anunțul nou postat, nu la profilul proprietarului -
      // userBookId lipsește doar la notificările vechi, dinainte de a fi
      // trimis de backend (vezi follow.service.ts), caz în care rămânem cu
      // fallback pe profil.
      final newBookUserBookId = at('userBookId');
      if (newBookUserBookId != null) return '/books/$newBookUserBookId';
      final followedUserId = at('userId');
      return followedUserId == null ? null : '/users/$followedUserId';

    case NotificationType.nearbyBookListed:
    case NotificationType.interestBookListed:
    case NotificationType.seriesVolumeAvailable:
      return '/search';

    case NotificationType.savedSearchMatch:
      return '/saved-searches';

    case NotificationType.outbid:
    case NotificationType.auctionWon:
    case NotificationType.auctionEnded:
      final auctionId = at('auctionId');
      return auctionId == null ? null : '/auctions/$auctionId';

    case NotificationType.unknown:
      // Tip necunoscut clientului - afișăm textul, fără acțiune la tap.
      return null;
  }
}
