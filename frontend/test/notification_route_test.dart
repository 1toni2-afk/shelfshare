import 'package:flutter_test/flutter_test.dart';
import 'package:shelfshare/core/notifications/notification_route.dart';
import 'package:shelfshare/data/models/app_notification.dart';

void main() {
  group('routeForNotification', () {
    test('mesajul nou duce in conversatia lui, nu pe home', () {
      expect(
        routeForNotification(
          NotificationType.newMessage,
          {'conversationId': 'c-1'},
        ),
        '/chat/c-1',
      );
    });

    test('oferta de pret duce in chat, unde e actionabila', () {
      expect(
        routeForNotification(
          NotificationType.priceOfferReceived,
          {'conversationId': 'c-9'},
        ),
        '/chat/c-9',
      );
    });

    test('oferta acceptata duce in fluxul de vanzare al ofertei', () {
      expect(
        routeForNotification(
          NotificationType.priceOfferAccepted,
          {'offerId': 'o-2'},
        ),
        '/offers/o-2/ready',
      );
    });

    test('acelasi tip ruteaza dupa cheia prezenta - schimb sau vanzare', () {
      expect(
        routeForNotification(
          NotificationType.exchangeReady,
          {'exchangeRequestId': 'e-3'},
        ),
        '/exchanges/e-3/ready',
      );
      expect(
        routeForNotification(NotificationType.exchangeReady, {'offerId': 'o-3'}),
        '/offers/o-3/ready',
      );
      expect(
        routeForNotification(NotificationType.exchangeReady, null),
        '/exchanges',
      );
    });

    test('valorile din payload-ul FCM sunt string-uri, nu doar dynamic', () {
      // Acelasi tabel serveste si tap-ul pe notificarea de sistem, unde
      // `data` vine ca Map<String, String> - nu doar din API.
      final fcm = <String, String>{'conversationId': 'c-7'};
      expect(routeForNotification(NotificationType.newMessage, fcm), '/chat/c-7');
    });

    test('fara datele necesare nu inventam o destinatie', () {
      expect(routeForNotification(NotificationType.newMessage, null), isNull);
      expect(routeForNotification(NotificationType.unknown, const {}), isNull);
      expect(
        routeForNotification(NotificationType.auctionWon, const {}),
        isNull,
      );
    });

    test('anuntul unui user urmarit duce la anunt, cu profilul ca rezerva', () {
      expect(
        routeForNotification(
          NotificationType.followedUserNewBook,
          {'userBookId': 'ub-1', 'userId': 'u-1'},
        ),
        '/books/ub-1',
      );
      expect(
        routeForNotification(
          NotificationType.followedUserNewBook,
          {'userId': 'u-1'},
        ),
        '/users/u-1',
      );
    });
  });
}
