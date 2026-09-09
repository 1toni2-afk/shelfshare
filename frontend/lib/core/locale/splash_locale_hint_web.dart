import 'package:web/web.dart' as web;

/// Codul limbii, în text clar, pentru splash-ul din index.html.
///
/// Nu e un secret (e o preferință de afișare), deci localStorage simplu e
/// suficient - iar splash-ul chiar are nevoie să-l poată citi fără Flutter.
/// Scrierea poate arunca dacă browserul blochează stocarea (mod privat,
/// cookies interzise); atunci splash-ul cade pe limba browserului, ceea ce e
/// exact comportamentul de dinaintea alegerii explicite.
void saveSplashLocaleHint(String code) {
  try {
    web.window.localStorage.setItem('splash_locale', code);
  } catch (_) {}
}
