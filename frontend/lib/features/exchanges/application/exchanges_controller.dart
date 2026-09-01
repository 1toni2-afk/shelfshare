import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../data/models/exchange_request.dart';
import '../../chat/data/chat_socket_service.dart';
import '../data/exchanges_repository.dart';

class ExchangesData {
  const ExchangesData({required this.received, required this.sent});
  final List<ExchangeRequest> received;
  final List<ExchangeRequest> sent;
}

class ExchangesController extends AsyncNotifier<ExchangesData> {
  @override
  Future<ExchangesData> build() async {
    // O cerere de schimb nouă/actualizată vine ca o notificare live pe
    // același socket ca cel din clopoțel - fără acest listener, lista
    // rămânea neschimbată până la un refresh manual de pagină (care
    // remonta ecranul și forța un refetch).
    final socketService = ref.read(chatSocketServiceProvider);
    // Fără await: lista vine pe HTTP și nu are de ce să aștepte socketul.
    // Vezi nota din ChatSocketService.connectInBackground.
    socketService.connectInBackground();
    socketService.onNotification(_silentReload);
    ref.onDispose(() => socketService.offNotification(_silentReload));

    return _load();
  }

  Future<ExchangesData> _load() async {
    final repository = ref.read(exchangesRepositoryProvider);
    final results = await Future.wait([repository.getReceived(), repository.getSent()]);
    return ExchangesData(received: results[0], sent: results[1]);
  }

  Future<void> _silentReload() async {
    final result = await AsyncValue.guard(_load);
    state = result;
  }

  Future<void> refresh() async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(_load);
  }

  Future<void> accept(String id) => _apply((r) => r.accept(id));

  Future<void> reject(String id) => _apply((r) => r.reject(id));

  Future<void> cancel(String id, {String? reason, String? details}) =>
      _apply((r) => r.cancel(id, reason: reason, details: details));

  Future<void> postpone(String id) => _apply((r) => r.postpone(id));

  Future<void> markDone(String id, {String? comment}) =>
      _apply((r) => r.markDone(id, comment: comment));

  Future<void> disputeDone(String id) => _apply((r) => r.disputeDone(id));

  Future<void> shareContact(String id, {String? phone}) =>
      _apply((r) => r.shareContact(id, phone: phone));

  Future<void> acknowledgeSafety(String id) => _apply((r) => r.acknowledgeSafety(id));

  Future<void> acceptMeeting(String id) => _apply((r) => r.acceptMeeting(id));

  Future<void> declineMeeting(String id) => _apply((r) => r.declineMeeting(id));

  Future<void> rate(
    String id,
    int value, {
    String? comment,
    int? communication,
    int? punctuality,
    int? condition,
  }) =>
      _apply((r) => r.rate(
            id,
            value,
            comment: comment,
            communication: communication,
            punctuality: punctuality,
            condition: condition,
          ));

  Future<void> setMeeting(
    String id, {
    required DateTime meetingTime,
    required String meetingLocation,
  }) =>
      _apply((r) => r.setMeeting(id, meetingTime: meetingTime, meetingLocation: meetingLocation));

  Future<String> calendarUrl(String id) =>
      ref.read(exchangesRepositoryProvider).calendarUrl(id);

  /// Fiecare acțiune de mutație întoarce deja cererea actualizată - o
  /// înlocuim direct în lista în care se află (trimise sau primite), fără
  /// să reîncărcăm ambele liste complete de la server.
  Future<void> _apply(Future<ExchangeRequest> Function(ExchangesRepository) action) async {
    final updated = await action(ref.read(exchangesRepositoryProvider));
    final current = state.value;
    if (current == null) return;
    List<ExchangeRequest> replace(List<ExchangeRequest> list) => [
          for (final request in list)
            if (request.id == updated.id) updated else request,
        ];
    state = AsyncData(ExchangesData(
      received: replace(current.received),
      sent: replace(current.sent),
    ));
  }
}

final exchangesControllerProvider = AsyncNotifierProvider<ExchangesController, ExchangesData>(
  ExchangesController.new,
);
