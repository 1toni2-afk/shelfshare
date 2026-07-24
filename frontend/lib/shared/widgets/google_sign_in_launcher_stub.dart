import 'package:url_launcher/url_launcher.dart';

// Pe Android/iOS nu există "navigare de pagină întreagă" ca pe web - deschidem
// browser-ul extern. Prinderea callback-ului de întoarcere (/auth/google/callback)
// necesită deep linking, care e o lucrare separată, nu încă legată aici.
void launchGoogleSignIn(String url) {
  launchUrl(Uri.parse(url), mode: LaunchMode.externalApplication);
}
