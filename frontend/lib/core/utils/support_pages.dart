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
