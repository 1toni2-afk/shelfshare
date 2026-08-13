import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/network/api_client.dart';
import '../../../core/network/providers.dart';
import '../../../data/models/exchange_request.dart';

class ExchangesRepository {
  ExchangesRepository(this._ref);
  final Ref _ref;

  /// Backend-ul întoarce și `conversationId` (cererea se postează direct în
  /// chat, la fel ca oferta de preț) - vezi book_detail_screen.dart, care
  /// deschide conversația imediat după trimitere.
  Future<(ExchangeRequest, String?)> createRequest({
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
    final data = response.data as Map<String, dynamic>;
    return (ExchangeRequest.fromJson(data), data['conversationId'] as String?);
  }

  Future<ExchangeRequest> getOne(String id) async {
    final dio = _ref.read(apiClientProvider).dio;
    final response = await dio.get('/exchanges/$id');
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

  /// [reason]/[details] sunt obligatorii doar când schimbul e ACCEPTED
  /// (formularul "What happened?") - o cerere PENDING se poate retrage fără motiv.
  Future<ExchangeRequest> cancel(String id, {String? reason, String? details}) async {
    final dio = _ref.read(apiClientProvider).dio;
    final response = await dio.post('/exchanges/$id/cancel', data: {
      'reason': ?reason,
      'details': ?details,
    });
    return ExchangeRequest.fromJson(response.data as Map<String, dynamic>);
  }

  Future<ExchangeRequest> postpone(String id) => _action(id, 'postpone');

  Future<ExchangeRequest> markDone(String id, {String? comment}) async {
    final dio = _ref.read(apiClientProvider).dio;
    final response = await dio.post('/exchanges/$id/done', data: {
      'comment': ?comment,
    });
    return ExchangeRequest.fromJson(response.data as Map<String, dynamic>);
  }

  Future<ExchangeRequest> disputeDone(String id) => _action(id, 'done/dispute');

  Future<ExchangeRequest> shareContact(String id, {String? phone}) async {
    final dio = _ref.read(apiClientProvider).dio;
    final response = await dio.post('/exchanges/$id/contact', data: {
      'phone': ?phone,
    });
    return ExchangeRequest.fromJson(response.data as Map<String, dynamic>);
  }

  Future<ExchangeRequest> acknowledgeSafety(String id) => _action(id, 'safety-ack');

  Future<ExchangeRequest> acceptMeeting(String id) => _action(id, 'meeting/accept');

  Future<ExchangeRequest> declineMeeting(String id) => _action(id, 'meeting/decline');

  Future<ExchangeRequest> _action(String id, String action) async {
    final dio = _ref.read(apiClientProvider).dio;
    final response = await dio.post('/exchanges/$id/$action');
    return ExchangeRequest.fromJson(response.data as Map<String, dynamic>);
  }

  Future<ExchangeRequest> rate(
    String id,
    int value, {
    String? comment,
    int? communication,
    int? punctuality,
    int? condition,
  }) async {
    final dio = _ref.read(apiClientProvider).dio;
    final response = await dio.post('/exchanges/$id/rate', data: {
      'value': value,
      if (comment != null && comment.isNotEmpty) 'comment': comment,
      'communication': ?communication,
      'punctuality': ?punctuality,
      'condition': ?condition,
    });
    return ExchangeRequest.fromJson(response.data as Map<String, dynamic>);
  }

  Future<ExchangeRequest> setMeeting(
    String id, {
    required DateTime meetingTime,
    required String meetingLocation,
  }) async {
    final dio = _ref.read(apiClientProvider).dio;
    final response = await dio.patch('/exchanges/$id/meeting', data: {
      'meetingTime': meetingTime.toUtc().toIso8601String(),
      'meetingLocation': meetingLocation,
    });
    return ExchangeRequest.fromJson(response.data as Map<String, dynamic>);
  }

  /// Link-ul de descărcare .ics, cu token-ul JWT în query - browserul îl
  /// deschide direct (via url_launcher) fără să poată atașa un header Authorization.
  Future<String> calendarUrl(String id) async {
    final token = await _ref.read(tokenStorageProvider).getAccessToken();
    return '${ApiConfig.baseUrl}/exchanges/$id/calendar.ics?token=$token';
  }
}

final exchangesRepositoryProvider = Provider<ExchangesRepository>((ref) {
  return ExchangesRepository(ref);
});
