import { Capacitor } from '@capacitor/core';
import { App } from '@capacitor/app';
import { Browser } from '@capacitor/browser';
import type { createBrowserRouter } from 'react-router-dom';
import { API_BASE_URL } from '@/lib/api/client';

type AppRouter = ReturnType<typeof createBrowserRouter>;

/** True în aplicația de Android (Capacitor), false în browser. */
export const isNativeApp = Capacitor.isNativePlatform();

/**
 * Căile pe care le poate deschide un deep link `shelfshare://`. Doar
 * întoarcerea din fluxul Google: un link venit din afară nu trebuie să poată
 * duce aplicația pe un ecran arbitrar.
 */
const DEEP_LINK_PATHS = ['/auth/google/callback', '/login'];

/**
 * Legătura cu Android, instalată o singură dată la pornire.
 *
 * Butonul Back: fără pluginul App, Capacitor nu-l trimite deloc WebView-ului,
 * deci Android închidea activitatea - din pagina unei cărți, Back scotea omul
 * din aplicație în loc să-l ducă la lista de dinainte. Acum merge înapoi prin
 * istoricul routerului și iese din aplicație doar de pe primul ecran.
 *
 * Deep link-ul `shelfshare:///auth/google/callback?code=...`: capătul
 * fluxului Google pornit din aplicație (vezi `startGoogleLogin`).
 */
export function installNativeBridge(router: AppRouter): void {
  if (!isNativeApp) return;

  void App.addListener('backButton', ({ canGoBack }) => {
    if (canGoBack) {
      window.history.back();
    } else {
      void App.exitApp();
    }
  });

  void App.addListener('appUrlOpen', ({ url }) => {
    let target: URL;
    try {
      target = new URL(url);
    } catch {
      return;
    }
    if (!DEEP_LINK_PATHS.includes(target.pathname)) return;
    // Fila Chrome în care s-a făcut login-ul rămâne deschisă peste aplicație
    // dacă n-o închidem noi.
    void Browser.close().catch(() => undefined);
    void router.navigate(`${target.pathname}${target.search}`, { replace: true });
  });
}

/**
 * Login cu Google.
 *
 * Pe web e o navigare obișnuită: backendul redirecționează înapoi pe
 * `/auth/google/callback` al site-ului.
 *
 * În aplicație, Google refuză login-ul din WebView, deci fluxul pornește într-o
 * filă Chrome (Custom Tab). Înainte, linkul simplu deschidea browserul extern,
 * iar redirectul final ducea omul pe site - logat acolo, dar tot delogat în
 * aplicație, la nesfârșit. Cu `platform=mobile`, backendul încheie fluxul
 * printr-un deep link `shelfshare://`, pe care îl prinde `installNativeBridge`.
 */
export function startGoogleLogin(): void {
  if (!isNativeApp) {
    window.location.assign(`${API_BASE_URL}/auth/google`);
    return;
  }
  void Browser.open({ url: `${API_BASE_URL}/auth/google?platform=mobile` });
}
