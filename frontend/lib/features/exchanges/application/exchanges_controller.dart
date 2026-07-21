import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../data/models/exchange_request.dart';
import '../data/exchanges_repository.dart';

class ExchangesData {
  const ExchangesData({required this.sent, required this.received});
  final List<ExchangeRequest> sent;
  final List<ExchangeRequest> received;
}

class ExchangesController extends AsyncNotifier<ExchangesData> {
  @override
  Future<ExchangesData> build() => _load();

  Future<ExchangesData> _load() async {
    final repository = ref.read(exchangesRepositoryProvider);
    final results = await Future.wait([
      repository.getSent(),
      repository.getReceived(),
    ]);
    return ExchangesData(sent: results[0], received: results[1]);
  }

  Future<void> refresh() async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(_load);
  }

  /// Fiecare acțiune de mutație întoarce deja cererea actualizată - o
  /// înlocuim direct în lista în care se află (trimise sau primite), fără
  /// să reîncărcăm ambele liste complete de la server.
  void _patchLocally(ExchangeRequest updated) {
    final current = state.value;
    if (current == null) return;
    state = AsyncData(
      ExchangesData(
        sent: [for (final e in current.sent) if (e.id == updated.id) updated else e],
        received: [for (final e in current.received) if (e.id == updated.id) updated else e],
      ),
    );
  }

  Future<void> accept(String id) async {
    final updated = await ref.read(exchangesRepositoryProvider).accept(id);
    _patchLocally(updated);
  }

  Future<void> reject(String id) async {
    final updated = await ref.read(exchangesRepositoryProvider).reject(id);
    _patchLocally(updated);
  }

  Future<void> cancel(String id) async {
    final updated = await ref.read(exchangesRepositoryProvider).cancel(id);
    _patchLocally(updated);
  }

  Future<void> complete(String id) async {
    final updated = await ref.read(exchangesRepositoryProvider).complete(id);
    _patchLocally(updated);
  }

  Future<void> rate(String id, int value, {String? comment}) async {
    final updated = await ref.read(exchangesRepositoryProvider).rate(id, value, comment: comment);
    _patchLocally(updated);
  }

  Future<void> setMeeting(String id, DateTime meetingAt) async {
    final updated = await ref.read(exchangesRepositoryProvider).setMeeting(id, meetingAt);
    _patchLocally(updated);
  }

  Future<void> downloadIcs(String id) {
    return ref.read(exchangesRepositoryProvider).downloadIcs(id);
  }
}

final exchangesControllerProvider =
    AsyncNotifierProvider<ExchangesController, ExchangesData>(
  ExchangesController.new,
);
