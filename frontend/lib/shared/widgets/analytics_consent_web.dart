import 'package:web/web.dart' as web;

/// Banda de consimțământ pentru analytics e randată în web/index.html, nu în
/// Flutter, cu `position: fixed; bottom` - deci plutește exact peste zona în
/// care stă banda de instalare. Alegerea userului e ținută în localStorage
/// sub cheia de mai jos (vezi scriptul din index.html); cât timp lipsește,
/// banda de consimțământ e pe ecran.
const _consentKey = 'ss-analytics-consent';

bool analyticsConsentAnswered() {
  try {
    return web.window.localStorage.getItem(_consentKey) != null;
  } catch (_) {
    // Storage blocat (unele setări de confidențialitate): nu putem ști dacă
    // banda de consimțământ e afișată. Preferăm să nu ne suprapunem peste ea.
    return false;
  }
}
