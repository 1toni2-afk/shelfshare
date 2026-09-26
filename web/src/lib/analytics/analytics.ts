import { Capacitor } from '@capacitor/core';

/**
 * Google Analytics pe web, cu consimțământ explicit - portat din Flutter
 * (frontend/web/index.html + core/analytics/analytics_backend_web.dart).
 *
 * Fără el, mutarea pe shelfshare.ro ar fi oprit statisticile web complet și
 * în tăcere: aplicația React n-avea niciun tag GA.
 *
 * Regula rămâne cea din Flutter: nicio cerere către Google până când omul nu
 * apasă „Accept". Refuzul și lipsa unei alegeri se comportă identic ca trafic
 * (zero); diferă doar prin faptul că un refuz nu mai reafișează bannerul.
 *
 * Cheia din localStorage e ACEEAȘI ca în Flutter (`ss-analytics-consent`):
 * după mutare, aplicația nouă rulează pe aceeași origine, deci alegerea deja
 * făcută de un vizitator se păstrează și nu-l mai întrebăm o dată.
 *
 * În aplicația de Android (Capacitor) nu se încarcă: acolo statisticile vin,
 * în Flutter, din Firebase Analytics, iar un tag web ar număra telefoanele
 * drept vizitatori de site.
 */

const GA_ID = 'G-36HN8BM30V';
const CONSENT_KEY = 'ss-analytics-consent';

export type AnalyticsConsent = 'granted' | 'denied' | null;

type Gtag = (...args: unknown[]) => void;

declare global {
  interface Window {
    dataLayer?: unknown[];
    gtag?: Gtag;
  }
}

let loaded = false;
const listeners = new Set<() => void>();

export function analyticsSupported(): boolean {
  return typeof window !== 'undefined' && !Capacitor.isNativePlatform();
}

export function getAnalyticsConsent(): AnalyticsConsent {
  try {
    const value = window.localStorage.getItem(CONSENT_KEY);
    return value === 'granted' || value === 'denied' ? value : null;
  } catch {
    // Mod privat sau storage blocat: ne purtăm ca și cum n-ar exista o alegere.
    return null;
  }
}

/** Pentru banner și ecranul de setări: se schimbă alegerea, se redesenează. */
export function subscribeAnalyticsConsent(listener: () => void): () => void {
  listeners.add(listener);
  return () => listeners.delete(listener);
}

export function setAnalyticsConsent(granted: boolean) {
  try {
    window.localStorage.setItem(CONSENT_KEY, granted ? 'granted' : 'denied');
  } catch {
    /* alegerea ține doar cât sesiunea */
  }
  if (granted) {
    loadAnalytics();
    window.gtag?.('consent', 'update', { analytics_storage: 'granted' });
    trackPageView();
  } else if (loaded) {
    // Scriptul deja încărcat nu se poate descărca; îi spunem să nu mai
    // păstreze nimic, iar trackPageView nu mai trimite nimic de acum.
    window.gtag?.('consent', 'update', { analytics_storage: 'denied' });
  }
  listeners.forEach((listener) => listener());
}

function loadAnalytics() {
  if (loaded || !analyticsSupported()) return;
  loaded = true;

  window.dataLayer = window.dataLayer || [];
  // gtag trebuie să împingă obiectul `arguments`, nu un tablou - așa îl
  // recunoaște scriptul Google.
  window.gtag = function gtag() {
    // eslint-disable-next-line prefer-rest-params
    window.dataLayer!.push(arguments);
  };
  window.gtag('js', new Date());
  // Page view-urile le trimitem noi, la fiecare schimbare de rută: aplicația e
  // un SPA, deci GA ar vedea altfel doar prima pagină.
  window.gtag('config', GA_ID, { send_page_view: false });

  const script = document.createElement('script');
  script.async = true;
  script.src = `https://www.googletagmanager.com/gtag/js?id=${GA_ID}`;
  document.head.appendChild(script);
}

/** Cât așteptăm titlul noului ecran înainte să trimitem oricum. */
const TITLE_WAIT_MS = 1500;

let pendingFlush: (() => void) | null = null;

/**
 * Un page_view pentru adresa curentă.
 *
 * Titlul îl pune ecranul abia după ce își încarcă datele (useDocumentMeta),
 * deci trimis imediat, evenimentul purta titlul paginii ANTERIOARE. Așteptăm
 * schimbarea lui `<title>`, cu plafon - un ecran cu același titlu ca
 * precedentul pleacă după TITLE_WAIT_MS.
 */
export function trackPageView() {
  if (!loaded || getAnalyticsConsent() !== 'granted') return;

  // O navigare nouă înainte ca precedenta să fi plecat: o trimitem pe aceea
  // acum, cu ce titlu are, ca să nu se piardă.
  pendingFlush?.();

  const location = window.location.href;
  const path = window.location.pathname;
  const previousTitle = document.title;
  let sent = false;

  const send = () => {
    if (sent) return;
    sent = true;
    observer.disconnect();
    window.clearTimeout(timer);
    if (pendingFlush === send) pendingFlush = null;
    window.gtag?.('event', 'page_view', {
      page_location: location,
      page_path: path,
      page_title: document.title,
    });
  };

  const observer = new MutationObserver(() => {
    if (document.title !== previousTitle) send();
  });
  observer.observe(document.head, { subtree: true, childList: true, characterData: true });
  const timer = window.setTimeout(send, TITLE_WAIT_MS);
  pendingFlush = send;
}

/** Pornire: dacă omul a acceptat deja (aici sau în aplicația Flutter), încărcăm direct. */
export function initAnalytics() {
  if (analyticsSupported() && getAnalyticsConsent() === 'granted') {
    loadAnalytics();
  }
}
