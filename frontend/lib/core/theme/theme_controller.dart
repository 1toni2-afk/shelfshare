import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../network/providers.dart';

/// Preferința de temă a userului - `system` urmărește modul dispozitivului.
enum AppThemeMode {
  system('system'),
  light('light'),
  dark('dark');

  const AppThemeMode(this.code);
  final String code;

  static AppThemeMode fromCode(String? code) =>
      AppThemeMode.values.firstWhere((m) => m.code == code, orElse: () => AppThemeMode.system);
}

const _themeStorageKey = 'app_theme_mode';

class ThemeController extends AsyncNotifier<AppThemeMode> {
  @override
  Future<AppThemeMode> build() async {
    final storage = ref.read(secureStorageProvider);
    final saved = await storage.read(key: _themeStorageKey);
    return AppThemeMode.fromCode(saved);
  }

  Future<void> setThemeMode(AppThemeMode mode) async {
    state = AsyncData(mode);
    await ref.read(secureStorageProvider).write(key: _themeStorageKey, value: mode.code);
  }
}

final themeControllerProvider = AsyncNotifierProvider<ThemeController, AppThemeMode>(
  ThemeController.new,
);
