/**
 * Metadatele paginilor publice cu conținut FIX (prezentare, catalog).
 *
 * Aceleași texte sunt scrise și de scripts/beta-server.js în HTML-ul livrat,
 * înainte ca React să pornească. Trebuie să rămână identice: dacă serverul ar
 * anunța un titlu, iar aplicația altul, un crawler ar vedea altceva decât
 * omul - exact definiția „cloaking"-ului, chiar dacă neintenționat.
 *
 * Cine schimbă un text de aici schimbă și constanta cu ACELAȘI NUME din
 * beta-server.js (PUBLIC_PAGE_META). Paginile cu conținut dinamic (o carte, un
 * profil, un grup) nu apar aici: titlul lor se construiește din datele
 * încărcate, cu aceleași funcții pe ambele părți - vezi `bookTitle` de mai jos.
 */
export interface DocumentMeta {
  title: string;
  description: string;
  /** Calea canonică, fără domeniu (îl adaugă `useDocumentMeta`). */
  path: string;
  image?: string;
  /** Structured data (schema.org). Serializat în `<script type="ld+json">`. */
  jsonLd?: Record<string, unknown>;
}

export const SITE_NAME = 'ShelfShare';

/*
  Doar CALEA canonică, nu și textele.

  Titlul și descrierea erau aici, fixe, în română. Le-au înlocuit cheile de
  traducere (`seoLandingTitle`, `seoBrowseTitle` și perechile lor), fiindcă
  altfel aplicația rescria `<head>`-ul cu varianta românească peste pagina pe
  care serverul tocmai o livrase în limba vizitatorului. Ecranele compun
  obiectul întreg: `{ ...LANDING_META, title: t(...), description: t(...) }`.
*/
export const LANDING_META: Pick<DocumentMeta, 'path'> = { path: '/' };

export const BROWSE_META: Pick<DocumentMeta, 'path'> = { path: '/browse' };

/** Titlul unei pagini de carte. Oglindit în beta-server.js (`bookTitle`). */
export function bookTitle(title: string, author?: string | null): string {
  const byline = author ? `${title} de ${author}` : title;
  return `${byline} | ${SITE_NAME}`;
}

/** Titlul unui profil public. Oglindit în beta-server.js (`profileTitle`). */
export function profileTitle(name: string): string {
  return `${name} | ${SITE_NAME}`;
}

/** Titlul unui grup de lectură. Oglindit în beta-server.js (`groupTitle`). */
export function groupTitle(name: string): string {
  return `${name} | ${SITE_NAME}`;
}
