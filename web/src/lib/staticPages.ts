/**
 * Adresele paginilor plain-HTML (centrul de siguranță, întrebări frecvente,
 * despre dezvoltator, confidențialitate, termeni), pe limbi.
 *
 * Paginile EXISTĂ în toate cele patru limbi de la început (vezi
 * TRANSLATED_PAGES din scripts/static-pages.js), dar linkurile către ele erau
 * scrise fix: `href="/privacy"`. Cine avea aplicația pe germană apăsa
 * „Datenschutz" și primea pagina în română, deși `/de/privacy` era acolo,
 * servită și indexată. Traducerea nu lipsea - lipsea drumul spre ea.
 *
 * De aceea calculul stă într-un singur loc: e aceeași regulă pentru subsolul
 * vizitatorului, pentru pagina de prezentare, pentru panoul de siguranță din
 * chat și pentru cititorul din aplicație - iar când se adaugă a cincea limbă,
 * se schimbă o singură listă.
 */

export const STATIC_PAGE_SLUGS = [
  'safety-center',
  'help-center',
  'about-dev',
  'privacy',
  'terms',
] as const;

export type StaticPageSlug = (typeof STATIC_PAGE_SLUGS)[number];

/** Limbile în care există fișierele. Oglindă a LEGAL_LANGS din static-pages.js. */
const PAGE_LANGS = ['ro', 'en', 'de', 'hu'];

/** Româna e implicită și stă în rădăcină; restul sub prefixul lor. */
const DEFAULT_LANG = 'ro';

/**
 * Adresa publică a paginii, în limba cerută.
 *
 * O limbă pe care n-o avem tradusă cade pe română, nu pe o adresă inexistentă:
 * `/fr/privacy` ar da 404 exact pe documentul pe care Play Console îl verifică.
 */
export function staticPageUrl(slug: StaticPageSlug, language: string): string {
  const lang = language.split('-')[0];
  return lang === DEFAULT_LANG || !PAGE_LANGS.includes(lang) ? `/${slug}` : `/${lang}/${slug}`;
}
