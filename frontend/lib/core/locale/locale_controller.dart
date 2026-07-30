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

/// Limba pe care aplicația o folosește *efectiv*: alegerea salvată de user,
/// altfel prima limbă a dispozitivului care e suportată, altfel română.
///
/// Există ca să nu mai mintă interfața: selectorul de limbă arăta „Română"
/// bifat cât timp nu exista o alegere salvată (`null ?? AppLocale.ro`), în
/// timp ce `MaterialApp` primea `locale: null` și urma limba telefonului -
/// deci pe un telefon în engleză bifa spunea română, iar aplicația era în
/// engleză. Acum atât `MaterialApp`, cât și selectorul citesc de aici.
final effectiveLocaleProvider = Provider<AppLocale>((ref) {
  final saved = ref.watch(localeControllerProvider).value;
  if (saved != null) return saved;
  for (final deviceLocale in WidgetsBinding.instance.platformDispatcher.locales) {
    for (final supported in AppLocale.values) {
      if (supported.code == deviceLocale.languageCode) return supported;
    }
  }
  return AppLocale.ro;
});
