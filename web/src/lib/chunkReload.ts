/**
 * Ieșirea dintr-o filă rămasă pe un build vechi.
 *
 * Ecranele se încarcă la cerere (`lazy`), din fișiere cu hash în nume. După
 * un deploy, o filă deschisă de dinainte cere încă numele vechi; dacă nu mai
 * există, importul pică cu „Failed to fetch dynamically imported module" și
 * orice „Încearcă din nou" cere același fișier inexistent. Singura ieșire e o
 * reîncărcare a paginii, care aduce index.html-ul nou și numele noi.
 *
 * Serverul păstrează o vreme bucățile vechi (vezi archivePreviousAssetsPlugin
 * din vite.config.ts), deci asta e plasa pentru ce scapă de arhivă.
 */

const RELOAD_KEY = 'ss-chunk-reload-at';
/** Sub pragul ăsta, o a doua eroare înseamnă că reîncărcarea n-a ajutat. */
const RELOAD_COOLDOWN_MS = 10_000;

export function isChunkLoadError(error: unknown): boolean {
  if (!(error instanceof Error)) return false;
  return /Failed to fetch dynamically imported module|Importing a module script failed|error loading dynamically imported module|Unable to preload CSS/i.test(
    error.message,
  );
}

/**
 * Reîncarcă pagina, dar nu mai des de o dată la 10 secunde - dacă fișierul
 * lipsește și după reîncărcare, o buclă ar bloca fila. Întoarce `false` când
 * a refuzat, ca apelantul să afișeze eroarea în loc să aștepte.
 */
export function reloadForNewBuild(): boolean {
  try {
    const last = Number(sessionStorage.getItem(RELOAD_KEY) ?? 0);
    if (Date.now() - last < RELOAD_COOLDOWN_MS) return false;
    sessionStorage.setItem(RELOAD_KEY, String(Date.now()));
  } catch {
    /* fără sessionStorage nu putem păzi bucla; reîncărcăm o dată oricum */
  }
  window.location.reload();
  return true;
}

/**
 * Vite emite `vite:preloadError` când un import dinamic (sau CSS-ul lui) nu
 * se poate încărca. `preventDefault` oprește aruncarea erorii - pagina se
 * reîncarcă oricum.
 */
export function installChunkReloadHandler(): void {
  window.addEventListener('vite:preloadError', (event) => {
    if (reloadForNewBuild()) event.preventDefault();
  });
}
