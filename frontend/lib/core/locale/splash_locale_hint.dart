// Splash-ul din web/index.html rulează înainte ca Flutter să pornească, deci
// nu are cum să afle limba aleasă de user din `flutter_secure_storage` (acolo
// valoarea e împachetată, nu e un simplu cod de limbă). Îi lăsăm un indiciu
// în text clar, în localStorage, la fiecare schimbare de limbă.
//
// Import condiționat: `package:web` nu compilează pentru Android/iOS - vezi
// același tipar în core/utils/browser_download.dart.
export 'splash_locale_hint_stub.dart'
    if (dart.library.js_interop) 'splash_locale_hint_web.dart';
