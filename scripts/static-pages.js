/**
 * Harta paginilor plain-HTML din scripts/static-pages/, ca modul separat.
 *
 * De ce nu mai stă doar în static-server.js: paginile astea (centrul de
 * siguranță, întrebări frecvente, despre dezvoltator, politica de
 * confidențialitate, termenii) sunt legate din Setări în AMBELE frontenduri.
 * Pe shelfshare.ro le servea static-server.js, dar pe beta.shelfshare.ro
 * serverul nou nu le cunoștea: orice rută necunoscută primește index.html, deci
 * /safety-center ajungea în routerul React, care n-are ruta și afișa „pagină
 * inexistentă". Toate cele cinci intrări din Setări duceau în gol.
 *
 * Nu sunt rute de aplicație și nu au voie să devină: verificarea OAuth a
 * Google și Play Console cer ca documentele legale să răspundă FĂRĂ
 * autentificare, la adrese stabile.
 *
 * Deocamdată doar beta-server.js citește de aici; static-server.js își are încă
 * propria copie a hărții. Când beta ia locul producției, copia aceea dispare -
 * până atunci nu umblăm la serverul care ține site-ul live.
 */
const path = require('path');

const pagesDir = path.join(__dirname, 'static-pages');

// Paginile traduse în toate limbile aplicației. Româna e implicită: stă în
// rădăcină (/privacy), restul sub prefixul lor (/en/privacy). Fișierele
// urmează aceeași regulă: privacy.html pentru română, privacy.en.html restul.
//
// Documentele legale au fost primele traduse (le cere verificarea Google);
// centrul de siguranță, întrebările frecvente și pagina despre dezvoltator au
// venit după, fiindcă se citesc din aplicație, care are deja patru limbi - un
// text românesc sub o interfață englezească arată ca o pagină uitată.
const LEGAL_DOCS = ['privacy', 'terms'];
const TRANSLATED_PAGES = [...LEGAL_DOCS, 'safety-center', 'help-center', 'about-dev'];
const LEGAL_LANGS = ['ro', 'en', 'de', 'hu'];
const LEGAL_DEFAULT_LANG = 'ro';

/**
 * Fiecare pagină răspunde și cu, și fără „.html", ca să meargă indiferent de ce
 * formă a adresei ajunge dintr-un link extern sau din consola Google.
 * Canonical rămâne varianta fără extensie (vezi <link rel="canonical"> din
 * fișiere), deci dublura nu produce conținut duplicat.
 */
function bothForms(url, file) {
  return [
    [url, file],
    [`${url}.html`, file],
  ];
}

const STATIC_HTML_PAGES = Object.fromEntries([
  ...bothForms('/werewolf', path.join(pagesDir, 'werewolf.html')),
  ...bothForms('/werewolf/privacy', path.join(pagesDir, 'werewolf-privacy.html')),
  ...bothForms('/werewolf/terms', path.join(pagesDir, 'werewolf-terms.html')),
  ...TRANSLATED_PAGES.flatMap((doc) =>
    LEGAL_LANGS.flatMap((lang) => {
      const url = lang === LEGAL_DEFAULT_LANG ? `/${doc}` : `/${lang}/${doc}`;
      const suffix = lang === LEGAL_DEFAULT_LANG ? '' : `.${lang}`;
      return bothForms(url, path.join(pagesDir, `${doc}${suffix}.html`));
    }),
  ),
]);

module.exports = {
  STATIC_HTML_PAGES,
  LEGAL_DOCS,
  TRANSLATED_PAGES,
  LEGAL_LANGS,
  LEGAL_DEFAULT_LANG,
};
