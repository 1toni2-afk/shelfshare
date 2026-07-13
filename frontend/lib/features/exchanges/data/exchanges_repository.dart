import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/network/providers.dart';
import '../../../data/models/exchange_request.dart';

class ExchangesRepository {
  ExchangesRepository(this._ref);
  final Ref _ref;

  Future<ExchangeRequest> createRequest({
    required String requestedBookId,
    String? offeredBookId,
    double? offeredAmount,
    String? message,
  }) async {
    final dio = _ref.read(apiClientProvider).dio;
    final response = await dio.post('/exchanges', data: {
      'requestedBookId': requestedBookId,
      'offeredBookId': ?offeredBookId,
      'offeredAmount': ?offeredAmount,
      if (message != null && message.isNotEmpty) 'message': message,
    });
    return ExchangeRequest.fromJson(response.data as Map<String, dynamic>);
  }
}

final exchangesRepositoryProvider = Provider<ExchangesRepository>((ref) {
  return ExchangesRepository(ref);
});
