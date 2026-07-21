import 'dart:js_interop';
import 'dart:typed_data';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:web/web.dart' as web;
import 'package:dio/dio.dart';
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

  Future<List<ExchangeRequest>> getSent() async {
    final dio = _ref.read(apiClientProvider).dio;
    final response = await dio.get('/exchanges/sent');
    return (response.data as List)
        .map((e) => ExchangeRequest.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  Future<List<ExchangeRequest>> getReceived() async {
    final dio = _ref.read(apiClientProvider).dio;
    final response = await dio.get('/exchanges/received');
    return (response.data as List)
        .map((e) => ExchangeRequest.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  Future<ExchangeRequest> accept(String id) async {
    final dio = _ref.read(apiClientProvider).dio;
    final response = await dio.post('/exchanges/$id/accept');
    return ExchangeRequest.fromJson(response.data as Map<String, dynamic>);
  }

  Future<ExchangeRequest> reject(String id) async {
    final dio = _ref.read(apiClientProvider).dio;
    final response = await dio.post('/exchanges/$id/reject');
    return ExchangeRequest.fromJson(response.data as Map<String, dynamic>);
  }

  Future<ExchangeRequest> cancel(String id) async {
    final dio = _ref.read(apiClientProvider).dio;
    final response = await dio.post('/exchanges/$id/cancel');
    return ExchangeRequest.fromJson(response.data as Map<String, dynamic>);
  }

  Future<ExchangeRequest> complete(String id) async {
    final dio = _ref.read(apiClientProvider).dio;
    final response = await dio.post('/exchanges/$id/complete');
    return ExchangeRequest.fromJson(response.data as Map<String, dynamic>);
  }

  Future<ExchangeRequest> rate(String id, int value, {String? comment}) async {
    final dio = _ref.read(apiClientProvider).dio;
    final response = await dio.post('/exchanges/$id/rate', data: {
      'value': value,
      if (comment != null && comment.isNotEmpty) 'comment': comment,
    });
    return ExchangeRequest.fromJson(response.data as Map<String, dynamic>);
  }

  Future<ExchangeRequest> setMeeting(String id, DateTime meetingAt) async {
    final dio = _ref.read(apiClientProvider).dio;
    final response = await dio.patch(
      '/exchanges/$id/meeting',
      data: {'meetingAt': meetingAt.toIso8601String()},
    );
    return ExchangeRequest.fromJson(response.data as Map<String, dynamic>);
  }

  /// Descarcă fișierul .ics direct din browser - endpoint-ul cere JWT în
  /// header, deci nu poate fi un simplu link <a href>; luăm bytes-ii prin
  /// Dio (care atașează automat tokenul) și declanșăm descărcarea cu un
  /// Blob + click pe un <a> temporar.
  Future<void> downloadIcs(String id) async {
    final dio = _ref.read(apiClientProvider).dio;
    final response = await dio.get<List<int>>(
      '/exchanges/$id/ics',
      options: Options(responseType: ResponseType.bytes),
    );
    final bytes = Uint8List.fromList(response.data!);
    final blob = web.Blob([bytes.toJS].toJS, web.BlobPropertyBag(type: 'text/calendar'));
    final url = web.URL.createObjectURL(blob);
    final anchor = web.document.createElement('a') as web.HTMLAnchorElement
      ..href = url
      ..download = 'schimb-$id.ics';
    web.document.body!.appendChild(anchor);
    anchor.click();
    anchor.remove();
    web.URL.revokeObjectURL(url);
  }
}

final exchangesRepositoryProvider = Provider<ExchangesRepository>((ref) {
  return ExchangesRepository(ref);
});
