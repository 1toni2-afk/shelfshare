import type { CapacitorConfig } from '@capacitor/cli';

/**
 * Împachetarea aplicației web (`/web`) ca aplicație Android.
 *
 * `appId` e IDENTIC cu cel al aplicației Flutter (vezi
 * frontend/android/app/build.gradle.kts). Nu e o coincidență și nu se poate
 * schimba: Google Play identifică o aplicație după el, iar un id diferit ar
 * apărea ca aplicație complet nouă, nu ca actualizare - utilizatorii existenți
 * n-ar primi-o niciodată, iar recenziile și instalările ar rămâne pe cea veche.
 */
const config: CapacitorConfig = {
  appId: 'ro.shelfshare.shelfshare',
  appName: 'ShelfShare',
  webDir: 'dist',

  server: {
    /*
      Originea din care WebView-ul servește aplicația împachetată.

      Implicit ar fi `https://localhost`, iar asta ar rupe TOT: politica de CORS
      a backendului acceptă în producție doar `FRONTEND_URL` și gazdele din
      `PUBLIC_HOSTNAME` (vezi common/utils/cors-origin.ts). O aplicație care
      cere de la `https://localhost` ar fi respinsă la fiecare apel, inclusiv la
      socketul de chat.

      Cu un `hostname` propriu, originea devine `https://app.shelfshare.ro` -
      un nume real, care se adaugă în `PUBLIC_HOSTNAME` ca orice alt frontend.
      Fișierele sunt tot cele din pachet, locale; numele nu declanșează nicio
      cerere de rețea către acel domeniu.

      Alternativa - să punem „localhost" în `PUBLIC_HOSTNAME` pe producție - ar
      fi lărgit politica pentru orice pagină locală de pe orice mașină. Un nume
      dedicat costă la fel de puțin și nu slăbește nimic.
    */
    androidScheme: 'https',
    hostname: 'app.shelfshare.ro',
  },

  android: {
    // Fișierele vin din pachet, nu de pe rețea: fără trafic în clar nu avem
    // nevoie de excepții de securitate, deci le lăsăm interzise.
    allowMixedContent: false,
  },
};

export default config;
