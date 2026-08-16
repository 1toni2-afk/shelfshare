import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../data/models/price_offer.dart';
import '../../chat/data/chat_socket_service.dart';
import '../data/offers_repository.dart';

class OffersData {
  const OffersData({required this.sent, required this.received});
  final List<PriceOffer> sent;
  final List<PriceOffer> received;
}

class OffersController extends AsyncNotifier<OffersData> {
  @override
  Future<OffersData> build() async {
    // O ofertă nouă/actualizată vine ca o notificare live pe același socket
    // ca cel din clopoțel - la fel ca ExchangesController. Fără acest
    // listener, o ofertă primită apărea doar în notificare (clopoțel), nu și
    // în lista de oferte, până la un refresh manual (pull-to-refresh sau
    // remontarea ecranului).
    final socketService = ref.read(chatSocketServiceProvider);
    await socketService.connect();
    socketService.onNotification(_silentReload);
    ref.onDispose(() => socketService.offNotification(_silentReload));

    return _load();
  }

  Future<OffersData> _load() async {
    final repository = ref.read(offersRepositoryProvider);
    final results = await Future.wait([
      repository.getSent(),
      repository.getReceived(),
    ]);
    return OffersData(sent: results[0], received: results[1]);
  }

  Future<void> _silentReload() async {
    final result = await AsyncValue.guard(_load);
    state = result;
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

  Future<void> cancel(String id, {String? reason, String? details}) =>
      _apply((r) => r.cancel(id, reason: reason, details: details));

  Future<void> postpone(String id) => _apply((r) => r.postpone(id));

  Future<void> markDone(String id, {String? comment}) =>
      _apply((r) => r.markDone(id, comment: comment));

  Future<void> disputeDone(String id) => _apply((r) => r.disputeDone(id));

  Future<void> shareContact(String id, {String? phone}) =>
      _apply((r) => r.shareContact(id, phone: phone));

  Future<void> acknowledgeSafety(String id) => _apply((r) => r.acknowledgeSafety(id));

  Future<void> proposeMeeting(
    String id, {
    required DateTime meetingTime,
    required String meetingLocation,
  }) =>
      _apply((r) => r.proposeMeeting(id, meetingTime: meetingTime, meetingLocation: meetingLocation));

  Future<void> acceptMeeting(String id) => _apply((r) => r.acceptMeeting(id));

  Future<void> declineMeeting(String id) => _apply((r) => r.declineMeeting(id));

  Future<String> calendarUrl(String id) => ref.read(offersRepositoryProvider).calendarUrl(id);

  Future<void> _apply(Future<PriceOffer> Function(OffersRepository) action) async {
    final updated = await action(ref.read(offersRepositoryProvider));
    _patchLocally(updated);
  }
}

final offersControllerProvider = AsyncNotifierProvider<OffersController, OffersData>(
  OffersController.new,
);
