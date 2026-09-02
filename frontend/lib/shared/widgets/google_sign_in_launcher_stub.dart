import 'package:url_launcher/url_launcher.dart';

/// Pe Android/iOS nu există "navigare de pagină întreagă" ca pe web - deschidem
/// browserul extern. `platform=mobile` îi spune backend-ului să încheie fluxul
/// cu un deep link (shelfshare:///auth/google/callback?code=...) în loc de un
/// redirect http; fără el userul rămânea în browser, pe varianta web, iar
/// aplicația nu afla niciodată că s-a autentificat.
void launchGoogleSignIn(String url) {
  final uri = Uri.parse(url).replace(queryParameters: {'platform': 'mobile'});
  launchUrl(uri, mode: LaunchMode.externalApplication);
}
