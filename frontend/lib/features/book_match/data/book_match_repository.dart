import 'dart:math';

import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/network/providers.dart';

/// O carte din coada de „Book Match" (ecranul de swipe). `isDiscovery` vine de
/// la backend și trebuie trimis înapoi neatins la POST /book-match/swipe -
/// serverul îl folosește ca să știe dacă swipe-ul a consumat din boost-ul de
/// descoperire sau a venit din recomandările „calde".
class BookMatchCard {
  const BookMatchCard({
    required this.bookId,
    required this.title,
    this.author,
    this.coverUrl,
    this.genre,
    this.publishedYear,
    this.description,
    this.isDiscovery = false,
  });

  final String bookId;
  final String title;
  final String? author;
  final String? coverUrl;
  final String? genre;
  final int? publishedYear;
  final String? description;
  final bool isDiscovery;

  factory BookMatchCard.fromJson(Map<String, dynamic> json) {
    return BookMatchCard(
      bookId: json['bookId'] as String,
      title: (json['title'] as String?) ?? '',
      author: json['author'] as String?,
      coverUrl: json['coverUrl'] as String?,
      genre: json['genre'] as String?,
      publishedYear: (json['publishedYear'] as num?)?.toInt(),
      description: json['description'] as String?,
      isDiscovery: json['isDiscovery'] == true,
    );
  }
}

class BookMatchQueue {
  const BookMatchQueue({required this.sessionId, required this.cards});
  final String sessionId;
  final List<BookMatchCard> cards;

  factory BookMatchQueue.fromJson(Map<String, dynamic> json) {
    return BookMatchQueue(
      sessionId: (json['sessionId'] as String?) ?? '',
      cards: ((json['cards'] as List?) ?? const [])
          .map((e) => BookMatchCard.fromJson(e as Map<String, dynamic>))
          .toList(),
    );
  }
}

class BookMatchSwipeResult {
  const BookMatchSwipeResult({
    required this.recorded,
    required this.addedToWishlist,
    required this.onboardingSwipesCount,
    required this.discoveryBoostSwipesRemaining,
  });

  final bool recorded;
  final bool addedToWishlist;
  final int onboardingSwipesCount;
  final int discoveryBoostSwipesRemaining;

  factory BookMatchSwipeResult.fromJson(Map<String, dynamic> json) {
    return BookMatchSwipeResult(
      recorded: json['recorded'] == true,
      addedToWishlist: json['addedToWishlist'] == true,
      onboardingSwipesCount: (json['onboardingSwipesCount'] as num?)?.toInt() ?? 0,
      discoveryBoostSwipesRemaining:
          (json['discoveryBoostSwipesRemaining'] as num?)?.toInt() ?? 0,
    );
  }
}

class BookMatchStatus {
  const BookMatchStatus({
    required this.onboardingSwipesCount,
    required this.onboardingTarget,
    required this.isOnboarding,
    required this.canRecalibrate,
    this.cooldownEndsAt,
    this.lastRecalibrationAt,
    required this.discoveryBoostSwipesRemaining,
  });

  final int onboardingSwipesCount;
  final int onboardingTarget;
  final bool isOnboarding;
  final bool canRecalibrate;
  final DateTime? cooldownEndsAt;
  final DateTime? lastRecalibrationAt;
  final int discoveryBoostSwipesRemaining;

  /// Zile rămase până la următoarea recalibrare, rotunjite în sus (backendul
  /// întoarce `daysRemaining` doar în răspunsul de eroare 400, nu și aici).
  int get daysRemaining {
    final end = cooldownEndsAt;
    if (end == null) return 0;
    final diff = end.difference(DateTime.now());
    if (diff.isNegative) return 0;
    return (diff.inHours / 24).ceil().clamp(1, 3650);
  }

  factory BookMatchStatus.fromJson(Map<String, dynamic> json) {
    return BookMatchStatus(
      onboardingSwipesCount: (json['onboardingSwipesCount'] as num?)?.toInt() ?? 0,
      onboardingTarget: (json['onboardingTarget'] as num?)?.toInt() ?? 50,
      isOnboarding: json['isOnboarding'] == true,
      canRecalibrate: json['canRecalibrate'] == true,
      cooldownEndsAt: _parseDate(json['cooldownEndsAt']),
      lastRecalibrationAt: _parseDate(json['lastRecalibrationAt']),
      discoveryBoostSwipesRemaining:
          (json['discoveryBoostSwipesRemaining'] as num?)?.toInt() ?? 0,
    );
  }
}

DateTime? _parseDate(Object? value) {
  if (value is! String || value.isEmpty) return null;
  return DateTime.tryParse(value)?.toLocal();
}

/// Aruncată când POST /book-match/recalibrate întoarce 400 cu
/// `error: 'RECALIBRATION_COOLDOWN'`. `message` e deja localizat (română) de
/// backend, dar ecranul preferă textul propriu din ARB și îl folosește doar ca
/// rezervă.
class RecalibrationCooldownException implements Exception {
  const RecalibrationCooldownException({
    required this.daysRemaining,
    this.cooldownEndsAt,
    this.message,
  });

  final int daysRemaining;
  final DateTime? cooldownEndsAt;
  final String? message;

  @override
  String toString() => message ?? 'RECALIBRATION_COOLDOWN';
}

class BookMatchRepository {
  BookMatchRepository(this._ref);
  final Ref _ref;

  Future<BookMatchQueue> getQueue({required String sessionId, int size = 10}) async {
    final dio = _ref.read(apiClientProvider).dio;
    final response = await dio.get(
      '/book-match/queue',
      queryParameters: {'sessionId': sessionId, 'size': size.clamp(1, 50)},
    );
    return BookMatchQueue.fromJson(response.data as Map<String, dynamic>);
  }

  Future<BookMatchSwipeResult> swipe({
    required String bookId,
    required String action,
    required String sessionId,
    required bool isDiscovery,
  }) async {
    final dio = _ref.read(apiClientProvider).dio;
    final response = await dio.post('/book-match/swipe', data: {
      'bookId': bookId,
      'action': action,
      'sessionId': sessionId,
      'isDiscovery': isDiscovery,
    });
    return BookMatchSwipeResult.fromJson(response.data as Map<String, dynamic>);
  }

  Future<BookMatchStatus> getStatus() async {
    final dio = _ref.read(apiClientProvider).dio;
    final response = await dio.get('/book-match/status');
    return BookMatchStatus.fromJson(response.data as Map<String, dynamic>);
  }

  /// Aruncă [RecalibrationCooldownException] dacă serverul refuză cu 400 /
  /// RECALIBRATION_COOLDOWN; orice altă eroare urcă neatinsă.
  Future<void> recalibrate() async {
    final dio = _ref.read(apiClientProvider).dio;
    try {
      await dio.post('/book-match/recalibrate');
    } on DioException catch (e) {
      final data = e.response?.data;
      if (e.response?.statusCode == 400 &&
          data is Map &&
          data['error'] == 'RECALIBRATION_COOLDOWN') {
        throw RecalibrationCooldownException(
          daysRemaining: (data['daysRemaining'] as num?)?.toInt() ?? 0,
          cooldownEndsAt: _parseDate(data['cooldownEndsAt']),
          message: data['message'] as String?,
        );
      }
      rethrow;
    }
  }
}

final bookMatchRepositoryProvider = Provider<BookMatchRepository>((ref) {
  return BookMatchRepository(ref);
});

/// UUID v4 fără dependință nouă în pubspec (proiectul nu are pachetul `uuid`).
/// Formatul contează - backendul validează `sessionId` ca UUID.
String generateUuidV4() {
  final random = Random.secure();
  final bytes = List<int>.generate(16, (_) => random.nextInt(256));
  bytes[6] = (bytes[6] & 0x0f) | 0x40; // versiunea 4
  bytes[8] = (bytes[8] & 0x3f) | 0x80; // varianta RFC 4122
  final hex = bytes.map((b) => b.toRadixString(16).padLeft(2, '0')).join();
  return '${hex.substring(0, 8)}-${hex.substring(8, 12)}-'
      '${hex.substring(12, 16)}-${hex.substring(16, 20)}-${hex.substring(20)}';
}
