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

  Future<List<ExchangeRequest>> getSent() => _getList('/exchanges/sent');

  Future<List<ExchangeRequest>> getReceived() => _getList('/exchanges/received');

  Future<List<ExchangeRequest>> _getList(String path) async {
    final dio = _ref.read(apiClientProvider).dio;
    final response = await dio.get(path);
    return (response.data as List<dynamic>)
        .map((e) => ExchangeRequest.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  Future<ExchangeRequest> accept(String id) => _action(id, 'accept');

  Future<ExchangeRequest> reject(String id) => _action(id, 'reject');

  Future<ExchangeRequest> cancel(String id) => _action(id, 'cancel');

  Future<ExchangeRequest> complete(String id) => _action(id, 'complete');

  Future<ExchangeRequest> _action(String id, String action) async {
    final dio = _ref.read(apiClientProvider).dio;
    final response = await dio.post('/exchanges/$id/$action');
    return ExchangeRequest.fromJson(response.data as Map<String, dynamic>);
  }
}

final exchangesRepositoryProvider = Provider<ExchangesRepository>((ref) {
  return ExchangesRepository(ref);
});
