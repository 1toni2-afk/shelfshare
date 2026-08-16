import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/network/api_client.dart';
import '../../../core/network/providers.dart';
import '../../../data/models/price_offer.dart';

class OffersRepository {
  OffersRepository(this._ref);
  final Ref _ref;

  /// Backend-ul întoarce și `conversationId` (oferta se postează direct în
  /// chat) - vezi book_detail_screen.dart#_MakeOfferSheet, care deschide
  /// conversația imediat după trimitere.
  Future<(PriceOffer, String?)> createOffer(
    String userBookId, {
    required double amount,
    String? message,
  }) async {
    final dio = _ref.read(apiClientProvider).dio;
    final response = await dio.post('/books/$userBookId/offers', data: {
      'amount': amount,
      if (message != null && message.isNotEmpty) 'message': message,
    });
    final data = response.data as Map<String, dynamic>;
    return (PriceOffer.fromJson(data), data['conversationId'] as String?);
  }

  Future<List<PriceOffer>> getSent() async {
    final dio = _ref.read(apiClientProvider).dio;
    final response = await dio.get('/offers/sent');
    return (response.data as List)
        .map((e) => PriceOffer.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  Future<List<PriceOffer>> getReceived() async {
    final dio = _ref.read(apiClientProvider).dio;
    final response = await dio.get('/offers/received');
    return (response.data as List)
        .map((e) => PriceOffer.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  Future<PriceOffer> getOne(String id) async {
    final dio = _ref.read(apiClientProvider).dio;
    final response = await dio.get('/offers/$id');
    return PriceOffer.fromJson(response.data as Map<String, dynamic>);
  }

  Future<PriceOffer> accept(String id) async {
    final dio = _ref.read(apiClientProvider).dio;
    final response = await dio.post('/offers/$id/accept');
    return PriceOffer.fromJson(response.data as Map<String, dynamic>);
  }

  Future<PriceOffer> reject(String id) async {
    final dio = _ref.read(apiClientProvider).dio;
    final response = await dio.post('/offers/$id/reject');
    return PriceOffer.fromJson(response.data as Map<String, dynamic>);
  }

  Future<PriceOffer> cancel(String id, {String? reason, String? details}) async {
    final dio = _ref.read(apiClientProvider).dio;
    final response = await dio.post('/offers/$id/cancel', data: {
      'reason': ?reason,
      'details': ?details,
    });
    return PriceOffer.fromJson(response.data as Map<String, dynamic>);
  }

  Future<PriceOffer> postpone(String id) => _action(id, 'postpone');

  Future<PriceOffer> markDone(String id, {String? comment}) async {
    final dio = _ref.read(apiClientProvider).dio;
    final response = await dio.post('/offers/$id/done', data: {
      'comment': ?comment,
    });
    return PriceOffer.fromJson(response.data as Map<String, dynamic>);
  }

  Future<PriceOffer> disputeDone(String id) => _action(id, 'done/dispute');

  Future<PriceOffer> shareContact(String id, {String? phone}) async {
    final dio = _ref.read(apiClientProvider).dio;
    final response = await dio.post('/offers/$id/contact', data: {
      'phone': ?phone,
    });
    return PriceOffer.fromJson(response.data as Map<String, dynamic>);
  }

  Future<PriceOffer> acknowledgeSafety(String id) => _action(id, 'safety-ack');

  Future<PriceOffer> proposeMeeting(
    String id, {
    required DateTime meetingTime,
    required String meetingLocation,
  }) async {
    final dio = _ref.read(apiClientProvider).dio;
    final response = await dio.post('/offers/$id/meeting', data: {
      'meetingTime': meetingTime.toUtc().toIso8601String(),
      'meetingLocation': meetingLocation,
    });
    return PriceOffer.fromJson(response.data as Map<String, dynamic>);
  }

  Future<PriceOffer> acceptMeeting(String id) => _action(id, 'meeting/accept');

  Future<PriceOffer> declineMeeting(String id) => _action(id, 'meeting/decline');

  Future<String> calendarUrl(String id) async {
    final token = await _ref.read(tokenStorageProvider).getAccessToken();
    return '${ApiConfig.baseUrl}/offers/$id/calendar.ics?token=$token';
  }

  Future<PriceOffer> _action(String id, String action) async {
    final dio = _ref.read(apiClientProvider).dio;
    final response = await dio.post('/offers/$id/$action');
    return PriceOffer.fromJson(response.data as Map<String, dynamic>);
  }

  /// Contra-ofertă (Batch 11): închide oferta curentă și creează una nouă
  /// cu rolurile inversate. Backend-ul postează și un mesaj în chat.
  Future<PriceOffer> counter(String id, {required double amount, String? message}) async {
    final dio = _ref.read(apiClientProvider).dio;
    final response = await dio.post('/offers/$id/counter', data: {
      'amount': amount,
      if (message != null && message.isNotEmpty) 'message': message,
    });
    return PriceOffer.fromJson(response.data as Map<String, dynamic>);
  }
}

final offersRepositoryProvider = Provider<OffersRepository>((ref) {
  return OffersRepository(ref);
});
