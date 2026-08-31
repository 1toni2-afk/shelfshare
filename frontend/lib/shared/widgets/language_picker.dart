import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/locale/l10n_extensions.dart';
import '../../core/locale/locale_controller.dart';

/// Selectorul de limbă - folosit atât din Setări, cât și din ecranul de login.
/// Bifa arată limba folosită efectiv (vezi [effectiveLocaleProvider]), nu
/// „Română" implicit peste o aplicație care rula în limba telefonului.
///
/// Stă aici, nu în `settings_screen.dart`, tocmai fiindcă îl folosește și
/// login-ul: ecranul de Setări e încărcat amânat (vezi `deferred_screen.dart`),
/// iar un import normal dinspre login ar fi tras tot ecranul de Setări înapoi
/// în bundle-ul inițial.
Future<void> showLanguagePicker(BuildContext context, WidgetRef ref) async {
  final current = ref.read(effectiveLocaleProvider);
  final chosen = await showDialog<AppLocale>(
    context: context,
    builder: (context) => SimpleDialog(
      title: Text(context.l10n.profileLanguage),
      children: [
        for (final locale in AppLocale.values)
          RadioListTile<AppLocale>(
            title: Text(locale.label),
            value: locale,
            // ignore: deprecated_member_use
            groupValue: current,
            // ignore: deprecated_member_use
            onChanged: (value) => Navigator.of(context).pop(value),
          ),
      ],
    ),
  );
  if (chosen != null) {
    await ref.read(localeControllerProvider.notifier).setLocale(chosen);
  }
}
