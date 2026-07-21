import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../data/models/price_offer.dart';
import '../data/offers_repository.dart';

class OffersData {
  const OffersData({required this.sent, required this.received});
  final List<PriceOffer> sent;
  final List<PriceOffer> received;
}

class OffersController extends AsyncNotifier<OffersData> {
  @override
  Future<OffersData> build() => _load();

  Future<OffersData> _load() async {
    final repository = ref.read(offersRepositoryProvider);
    final results = await Future.wait([
      repository.getSent(),
      repository.getReceived(),
    ]);
    return OffersData(sent: results[0], received: results[1]);
  }

  Future<void> refresh() async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(_load);
  }

  void _patchLocally(PriceOffer updated) {
    final current = state.value;
    if (current == null) return;
    state = AsyncData(
      OffersData(
        sent: [for (final o in current.sent) if (o.id == updated.id) updated else o],
        received: [for (final o in current.received) if (o.id == updated.id) updated else o],
      ),
    );
  }

  Future<void> accept(String id) async {
    final updated = await ref.read(offersRepositoryProvider).accept(id);
    _patchLocally(updated);
  }

  Future<void> reject(String id) async {
    final updated = await ref.read(offersRepositoryProvider).reject(id);
    _patchLocally(updated);
  }

  Future<void> cancel(String id) async {
    final updated = await ref.read(offersRepositoryProvider).cancel(id);
    _patchLocally(updated);
  }
}

final offersControllerProvider = AsyncNotifierProvider<OffersController, OffersData>(
  OffersController.new,
);
