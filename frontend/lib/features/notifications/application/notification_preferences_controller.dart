import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../data/models/notification_preferences.dart';
import '../data/notifications_repository.dart';

/// Preferințele de notificare din Setări.
///
/// Se încarcă doar când e deschis grupul „Notificări" (providerul e citit
/// abia de acolo) - e o cerere în plus care n-are ce căuta pe drumul de
/// pornire a aplicației.
class NotificationPreferencesController
    extends AsyncNotifier<NotificationPreferences> {
  @override
  Future<NotificationPreferences> build() {
    return ref.read(notificationsRepositoryProvider).getPreferences();
  }

  /// Comută o categorie întreagă (toate tipurile ei odată).
  ///
  /// Optimist: switch-ul se mișcă imediat, iar dacă PUT-ul eșuează revenim la
  /// starea dinainte. Fără asta, comutatorul ar rămâne blocat pe vechea
  /// valoare până se întoarce serverul, ceea ce pare o interfață stricată.
  Future<void> setCategory(NotificationCategory category, bool enabled) async {
    final current = state.value;
    if (current == null) return;

    final changes = {for (final type in category.types) type: enabled};
    state = AsyncData({...current, ...changes});
    try {
      state = AsyncData(
        await ref.read(notificationsRepositoryProvider).setPreferences(changes),
      );
    } catch (_) {
      state = AsyncData(current);
      rethrow;
    }
  }
}

final notificationPreferencesControllerProvider = AsyncNotifierProvider<
    NotificationPreferencesController, NotificationPreferences>(
  NotificationPreferencesController.new,
);
