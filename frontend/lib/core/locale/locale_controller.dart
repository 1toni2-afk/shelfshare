import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../network/providers.dart';

/// Limbile disponibile în aplicație - codul e folosit atât pentru
/// `Locale(code)` cât și ca valoare persistată în secure storage.
enum AppLocale {
  ro('ro', 'Română'),
  en('en', 'English'),
  hu('hu', 'Magyar'),
  de('de', 'Deutsch');

  const AppLocale(this.code, this.label);
  final String code;
  final String label;

  Locale get locale => Locale(code);

  static AppLocale fromCode(String? code) =>
      AppLocale.values.firstWhere((l) => l.code == code, orElse: () => AppLocale.ro);
}

const _localeStorageKey = 'app_locale';

/// `null` = urmează limba dispozitivului (dacă e una suportată, altfel română).
class LocaleController extends AsyncNotifier<AppLocale?> {
  @override
  Future<AppLocale?> build() async {
    final storage = ref.read(secureStorageProvider);
    final saved = await storage.read(key: _localeStorageKey);
    return saved == null ? null : AppLocale.fromCode(saved);
  }

  Future<void> setLocale(AppLocale locale) async {
    state = AsyncData(locale);
    await ref.read(secureStorageProvider).write(key: _localeStorageKey, value: locale.code);
  }
}

final localeControllerProvider = AsyncNotifierProvider<LocaleController, AppLocale?>(
  LocaleController.new,
);
