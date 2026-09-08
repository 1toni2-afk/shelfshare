import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../data/models/admin_book_request.dart';
import '../data/admin_repository.dart';

/// Filtrul de status al panoului. `null` = toate. Riverpod 3 a scos
/// `StateProvider`, deci e un `Notifier` simplu cu un singur setter.
class AdminBookRequestFilter extends Notifier<String?> {
  @override
  String? build() => 'PENDING';

  void set(String? status) => state = status;
}

final adminBookRequestFilterProvider =
    NotifierProvider<AdminBookRequestFilter, String?>(
        AdminBookRequestFilter.new);

/// Cererile de carte pentru panoul de admin, refăcute la fiecare schimbare de
/// filtru: filtrarea se face pe server (`?status=`), nu în client, ca panoul
/// să nu descarce toate cererile ca să le arate doar pe cele în așteptare.
final adminBookRequestsProvider =
    FutureProvider.autoDispose<List<AdminBookRequest>>((ref) {
  final status = ref.watch(adminBookRequestFilterProvider);
  return ref.read(adminRepositoryProvider).getBookRequests(status: status);
});
