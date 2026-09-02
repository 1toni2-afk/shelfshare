import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/collections_repository.dart';

/// Colecțiile proprii ale userului.
///
/// Stă aici, nu în `my_collections_screen.dart`, ca sheet-ul „Adaugă în listă"
/// (deschis din detaliul cărții, nivel 1) să nu tragă după el ecranul de
/// colecții - care e amânat la nivel 3. Vezi `core/router/deferred_screen.dart`.
final myCollectionsProvider = FutureProvider((ref) {
  return ref.watch(collectionsRepositoryProvider).getMine();
});
