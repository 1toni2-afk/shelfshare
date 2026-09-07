/// Contractul comun pentru cele două destinații de analytics: gtag.js pe web
/// și Firebase Analytics pe Android/iOS.
///
/// Nu e o abstractizare de dragul abstractizării - cele două SDK-uri n-au
/// nimic în comun la nivel de cod (unul e JS interop, celălalt un plugin cu
/// canal de platformă) și, mai important, niciunul nu COMPILEAZĂ pe platforma
/// celuilalt: `dart:js_interop` nu există pe mobil, iar firebase_analytics
/// n-are ce căuta în bundle-ul web, unde gtag.js e deja încărcat (și deja
/// gated pe consimțământ) din index.html. De aceea implementarea se alege la
/// compilare, prin importul condiționat din `analytics.dart`.
abstract class AnalyticsBackend {
  /// Apelat o singură dată la pornire, înainte de primul `screenView`.
  /// Trebuie să degradeze silențios: analytics-ul e opțional, o eroare aici
  /// nu are voie să împiedice pornirea aplicației.
  Future<void> initialize();

  /// O vizualizare de ecran. [location] e calea reală, cu parametrii
  /// completați (`/books/abc123`), [routeName] e tiparul rutei
  /// (`/books/:id`) - vezi `analytics.dart` pentru de ce le trimitem pe
  /// amândouă.
  void screenView({required String location, required String routeName});

  /// Un eveniment propriu. Numele vin din [AnalyticsEvents]; parametrii
  /// trebuie să rămână fără date personale (vezi nota din `analytics.dart`).
  void event(String name, Map<String, Object> parameters);

  /// `true` doar dacă userul a apăsat explicit „Accept". Lipsa unei alegeri
  /// și un refuz se comportă identic - zero trafic - și se disting doar prin
  /// [consentAnswered].
  bool get consentGranted;

  /// `true` dacă userul a apucat să răspundă (indiferent cum). Folosit ca să
  /// știm dacă mai trebuie să întrebăm o dată.
  bool get consentAnswered;

  /// Schimbă alegerea userului și o persistă. Pornește colectarea imediat
  /// când primește `true` - fără repornirea aplicației.
  Future<void> setConsent(bool granted);
}
