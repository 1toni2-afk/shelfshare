import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../data/models/exchange_request.dart';
import '../data/exchanges_repository.dart';

class ExchangesData {
  const ExchangesData({required this.received, required this.sent});
  final List<ExchangeRequest> received;
  final List<ExchangeRequest> sent;
}

class ExchangesController extends AsyncNotifier<ExchangesData> {
  @override
  Future<ExchangesData> build() => _load();

  Future<ExchangesData> _load() async {
    final repository = ref.read(exchangesRepositoryProvider);
    final results = await Future.wait([repository.getReceived(), repository.getSent()]);
    return ExchangesData(received: results[0], sent: results[1]);
  }

  Future<void> refresh() async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(_load);
  }

  Future<void> accept(String id) => _apply((r) => r.accept(id));

  Future<void> reject(String id) => _apply((r) => r.reject(id));

  Future<void> cancel(String id) => _apply((r) => r.cancel(id));

  Future<void> complete(String id) => _apply((r) => r.complete(id));

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
