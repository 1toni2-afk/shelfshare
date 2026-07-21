import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/network/providers.dart';
import '../../../data/models/price_offer.dart';

class OffersRepository {
  OffersRepository(this._ref);
  final Ref _ref;

  Future<PriceOffer> createOffer(String userBookId, {required double amount, String? message}) async {
    final dio = _ref.read(apiClientProvider).dio;
    final response = await dio.post('/books/$userBookId/offers', data: {
      'amount': amount,
      if (message != null && message.isNotEmpty) 'message': message,
    });
    return PriceOffer.fromJson(response.data as Map<String, dynamic>);
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

  Future<PriceOffer> cancel(String id) async {
    final dio = _ref.read(apiClientProvider).dio;
    final response = await dio.post('/offers/$id/cancel');
    return PriceOffer.fromJson(response.data as Map<String, dynamic>);
  }
}

final offersRepositoryProvider = Provider<OffersRepository>((ref) {
  return OffersRepository(ref);
});
