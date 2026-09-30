/**
 * Gazdele de pe care acceptăm o imagine dată ca URL de un user (copertă,
 * poza principală a anunțului, poză „din URL" în galerie).
 *
 * Imaginea e afișată tuturor celor care deschid anunțul sau cartea, deci un
 * URL oarecare le-ar trimite browserul pe serverul altcuiva: IP-ul și ora
 * fiecărei vizite (un pixel de urmărire), fără ca vreunul să fi dat click.
 * Sunt doar sursele pe care aplicația însăși le propune: coperțile din
 * căutarea externă și cele din catalogul curat. Pozele urcate de useri trec
 * separat, prin prefixul stocării noastre (vezi StorageService).
 */
export const EXTERNAL_IMAGE_HOSTS: ReadonlySet<string> = new Set([
  'covers.openlibrary.org',
  'books.google.com',
  'books.googleusercontent.com',
  'www.targulcartii.ro',
  'targulcartii.ro',
]);

/**
 * `ownPrefix` e baza publică a stocării (ex. `https://storage.shelfshare.ro/x`,
 * sau `http://localhost:59000/x` în zona de test), comparată ca prefix de cale:
 * gazda singură nu ajunge, fiindcă pe ea pot sta și alte bucket-uri.
 */
export function isAllowedImageUrl(raw: string, ownPrefix: string): boolean {
  let url: URL;
  try {
    url = new URL(raw);
  } catch {
    return false;
  }
  if (url.protocol !== 'https:' && url.protocol !== 'http:') return false;
  // `https://books.google.com@evil.test/x` are gazda evil.test; URL o
  // parsează corect, dar un user:parolă în URL n-are ce căuta aici oricum.
  if (url.username || url.password) return false;
  if (raw.startsWith(`${ownPrefix.replace(/\/+$/, '')}/`)) return true;
  return EXTERNAL_IMAGE_HOSTS.has(url.hostname.toLowerCase());
}
