import 'package:flutter_test/flutter_test.dart';
import 'package:shelfshare/data/models/exchange_request.dart';

Map<String, dynamic> _userBookJson({String id = 'ub-1'}) => {
      'id': id,
      'userId': 'owner-1',
      'book': {'id': 'book-1', 'title': 'Cartea Test'},
      'condition': 'BUNA',
      'photos': <String>[],
      'createdAt': '2026-01-01T00:00:00.000Z',
    };

Map<String, dynamic> _exchangeJson({
  String status = 'PENDING',
  int? requesterRatingForOwner,
  int? ownerRatingForRequester,
}) =>
    {
      'id': 'ex-1',
      'requesterId': 'requester-1',
      'ownerId': 'owner-1',
      'requestedBook': _userBookJson(),
      'status': status,
      'requester': {'id': 'requester-1', 'name': 'Maria'},
      'owner': {'id': 'owner-1', 'name': 'Andrei'},
      'createdAt': '2026-01-01T00:00:00.000Z',
      'requesterRatingForOwner': ?requesterRatingForOwner,
      'ownerRatingForRequester': ?ownerRatingForRequester,
    };

void main() {
  group('ExchangeStatusX', () {
    test('mapează fiecare status din backend la eticheta corectă', () {
      expect(ExchangeStatusX.fromJson('PENDING'), ExchangeStatus.pending);
      expect(ExchangeStatusX.fromJson('ACCEPTED'), ExchangeStatus.accepted);
      expect(ExchangeStatusX.fromJson('REJECTED'), ExchangeStatus.rejected);
      expect(ExchangeStatusX.fromJson('CANCELLED'), ExchangeStatus.cancelled);
      expect(ExchangeStatusX.fromJson('COMPLETED'), ExchangeStatus.completed);
    });

    test('aruncă eroare pentru un status necunoscut', () {
      expect(() => ExchangeStatusX.fromJson('CEVA'), throwsArgumentError);
    });
  });

  group('ExchangeRequest.fromJson', () {
    test('parsează un schimb fără rating-uri', () {
      final exchange = ExchangeRequest.fromJson(_exchangeJson());

      expect(exchange.status, ExchangeStatus.pending);
      expect(exchange.requesterRatingForOwner, isNull);
      expect(exchange.ownerRatingForRequester, isNull);
    });

    test('parsează rating-urile când sunt prezente', () {
      final exchange = ExchangeRequest.fromJson(
        _exchangeJson(status: 'COMPLETED', requesterRatingForOwner: 5),
      );

      expect(exchange.requesterRatingForOwner, 5);
    });
  });

  group('ExchangeRequest.myRatingGiven', () {
    test('e true pentru solicitant dacă requesterRatingForOwner e setat', () {
      final exchange = ExchangeRequest.fromJson(
        _exchangeJson(status: 'COMPLETED', requesterRatingForOwner: 4),
      );

      expect(exchange.myRatingGiven('requester-1'), isTrue);
      expect(exchange.myRatingGiven('owner-1'), isFalse);
    });

    test('e true pentru proprietar dacă ownerRatingForRequester e setat', () {
      final exchange = ExchangeRequest.fromJson(
        _exchangeJson(status: 'COMPLETED', ownerRatingForRequester: 3),
      );

      expect(exchange.myRatingGiven('owner-1'), isTrue);
      expect(exchange.myRatingGiven('requester-1'), isFalse);
    });

    test('e false pentru un utilizator care nu e parte în schimb', () {
      final exchange = ExchangeRequest.fromJson(
        _exchangeJson(status: 'COMPLETED', requesterRatingForOwner: 5),
      );

      expect(exchange.myRatingGiven('altcineva'), isFalse);
    });
  });
}
