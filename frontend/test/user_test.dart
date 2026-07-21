import 'package:flutter_test/flutter_test.dart';
import 'package:shelfshare/data/models/user.dart';

void main() {
  group('AppUser.fromJson', () {
    test('parsează toate câmpurile, cu valori implicite pentru cele lipsă', () {
      final user = AppUser.fromJson({
        'id': 'u-1',
        'email': 'test@example.com',
      });

      expect(user.id, 'u-1');
      expect(user.email, 'test@example.com');
      expect(user.rating, 0);
      expect(user.booksExchangedCount, 0);
      expect(user.isEmailVerified, isFalse);
      expect(user.isAdmin, isFalse);
    });

    test('parsează isAdmin true pentru conturile de admin', () {
      final user = AppUser.fromJson({
        'id': 'u-1',
        'email': 'admin@shelfshare.demo',
        'isAdmin': true,
        'rating': 4.5,
        'booksExchangedCount': 3,
      });

      expect(user.isAdmin, isTrue);
      expect(user.rating, 4.5);
      expect(user.booksExchangedCount, 3);
    });
  });

  group('PublicUser.fromJson', () {
    test('parsează un profil minimal (relație scurtă, ex. owner pe o carte)', () {
      final user = PublicUser.fromJson({'id': 'u-2', 'rating': 3.2});

      expect(user.id, 'u-2');
      expect(user.rating, 3.2);
      expect(user.bio, isNull);
      expect(user.memberSince, isNull);
    });

    test('parsează un profil public complet, cu memberSince', () {
      final user = PublicUser.fromJson({
        'id': 'u-2',
        'name': 'Maria',
        'bio': 'Cititoare pasionată',
        'booksExchangedCount': 7,
        'memberSince': '2026-01-15T00:00:00.000Z',
      });

      expect(user.bio, 'Cititoare pasionată');
      expect(user.booksExchangedCount, 7);
      expect(user.memberSince, DateTime.parse('2026-01-15T00:00:00.000Z'));
    });
  });
}
