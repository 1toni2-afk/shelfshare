import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import '../locale/l10n_extensions.dart';

/// Deschide una dintre paginile de suport (Safety Center, About dev, Help
/// Center) - conținut pur static, mutat din Flutter în HTML simplu servit
/// direct de `scripts/static-server.js` (vezi STATIC_HTML_PAGES acolo), ca să
/// nu mai stea în spatele ecranului de login și să fie vizibil crawlerelor.
/// [path] e ruta absolută (ex. '/safety-center').
Future<void> openSupportPage(BuildContext context, String path) async {
  final uri = Uri.parse('https://shelfshare.ro$path');
  final opened = await launchUrl(uri, mode: LaunchMode.externalApplication);
  if (!opened && context.mounted) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(context.l10n.aboutDevOpenError)),
    );
  }
}

/// Limbile în care există documentele legale, servite tot de static-server
/// (vezi LEGAL_LANGS acolo - lista trebuie ținută sincronizată cu asta).
/// Româna e implicită și stă în rădăcină (/privacy), restul sub prefixul lor
/// (/en/privacy).
const _legalLangs = {'ro', 'en', 'de', 'hu'};

/// Deschide politica de confidențialitate sau termenii, în limba interfeței.
/// [doc] e 'privacy' sau 'terms'.
///
/// O limbă a aplicației fără traducere a documentelor cade pe română, nu pe
/// o adresă inexistentă - altfel adăugarea unei limbi noi în aplicație ar
/// produce tăcut un 404 aici.
Future<void> openLegalPage(BuildContext context, String doc) {
  final lang = Localizations.localeOf(context).languageCode;
  final path =
      (lang == 'ro' || !_legalLangs.contains(lang)) ? '/$doc' : '/$lang/$doc';
  return openSupportPage(context, path);
}
