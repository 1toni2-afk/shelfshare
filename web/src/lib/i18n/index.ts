import i18n from 'i18next';
import { initReactI18next } from 'react-i18next';
import ICU from 'i18next-icu';
import { loadMessages, SUPPORTED_LOCALES, type AppLocale } from './locales';

export { SUPPORTED_LOCALES };
export type { AppLocale };

const STORAGE_KEY = 'shelfshare.locale';
const FALLBACK: AppLocale = 'ro';

/**
 * Limba aleasă explicit de user, dacă există; altfel prima limbă a browserului
 * pe care o suportăm; altfel româna.
 *
 * Nu folosim i18next-browser-languagedetector: ne trebuie EXACT aceeași
 * ordine de preferințe ca în LocaleController din Flutter, iar detectorul are
 * propriile reguli (cookie, querystring, tag `lang` din HTML) care ar produce
 * alegeri diferite între cele două aplicații pentru același user.
 */
function resolveInitialLocale(): AppLocale {
  const saved = readStoredLocale();
  if (saved) return saved;

  for (const tag of navigator.languages ?? []) {
    // `navigator.languages` dă tag-uri complete ("ro-RO", "de-AT"); noi avem
    // resurse doar pe limbă, nu pe regiune.
    const base = tag.split('-')[0]?.toLowerCase();
    if (base && (SUPPORTED_LOCALES as string[]).includes(base)) {
      return base as AppLocale;
    }
  }
  return FALLBACK;
}

function readStoredLocale(): AppLocale | null {
  try {
    const value = window.localStorage.getItem(STORAGE_KEY);
    return value && (SUPPORTED_LOCALES as string[]).includes(value)
      ? (value as AppLocale)
      : null;
  } catch {
    return null;
  }
}

const loaded = new Set<AppLocale>();

/** Aduce fișierul unei limbi o singură dată și îl înregistrează în i18next. */
async function ensureLoaded(locale: AppLocale): Promise<void> {
  if (loaded.has(locale)) return;
  const messages = await loadMessages(locale);
  i18n.addResourceBundle(locale, 'translation', messages, true, true);
  loaded.add(locale);
}

export async function setLocale(locale: AppLocale): Promise<void> {
  try {
    window.localStorage.setItem(STORAGE_KEY, locale);
  } catch {
    /* storage blocat - alegerea ține doar cât sesiunea */
  }
  await ensureLoaded(locale);
  await i18n.changeLanguage(locale);
  document.documentElement.lang = locale;
}

const initialLocale = resolveInitialLocale();

/**
 * Pornirea așteaptă fișierul de limbă. Alternativa (init sincron cu resurse
 * goale, urmat de încărcare) afișează o clipă cheile brute - „authLoginSubmit"
 * în loc de „Conectare" - la fiecare încărcare de pagină.
 */
export const i18nReady: Promise<void> = (async () => {
  const messages = await loadMessages(initialLocale);
  await i18n
    // ICU, nu interpolarea proprie a i18next: sursa e .arb, adică deja ICU
    // ("{count, plural, one{...} other{...}}"). Fără plugin, i18next ar afișa
    // literal acoladele, iar pluralul ar cere rescrierea tuturor cheilor.
    .use(ICU)
    .use(initReactI18next)
    .init({
      resources: { [initialLocale]: { translation: messages } },
      lng: initialLocale,
      fallbackLng: FALLBACK,
      // Cheile ARB sunt camelCase plate ("navHome", "bookDetailTitle"), nu
      // ierarhice. Fără asta, i18next ar tăia la primul punct dintr-o cheie și
      // ar căuta un obiect imbricat care nu există.
      keySeparator: false,
      nsSeparator: false,
      interpolation: { escapeValue: false },
      returnNull: false,
    });

  loaded.add(initialLocale);

  // Fallback-ul se aduce doar dacă userul chiar e pe altă limbă. Cele patru
  // limbi sunt acum la paritate (vezi numărătoarea tipărită de arb-to-json.mjs
  // la fiecare build), dar plasa rămâne: prima cheie adăugată doar în `ro` ar
  // apărea altfel pe ecran ca nume de cheie, nu ca text.
  if (initialLocale !== FALLBACK) {
    await ensureLoaded(FALLBACK);
  }

  document.documentElement.lang = initialLocale;
})();

export default i18n;
