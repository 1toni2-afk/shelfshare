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

export const DEFAULT_DESCRIPTION =
  'ShelfShare - schimbă, vinde sau cumpără cărți second-hand de la alți cititori din România.';

export const LANDING_META: DocumentMeta = {
  title: 'ShelfShare - schimbă și cumpără cărți second-hand în România',
  description:
    'Comunitatea de cititori din România unde cărțile citite își găsesc un cititor nou. Îți listezi cărțile, cauți ce vrei să citești și te înțelegi direct cu proprietarul - prin schimb sau la un preț stabilit de voi.',
  path: '/',
};

export const BROWSE_META: DocumentMeta = {
  title: 'Catalog de cărți second-hand | ShelfShare',
  description:
    'Caută printre cărțile puse la schimb sau la vânzare de cititorii ShelfShare. Filtrează după titlu, autor, gen, stare și oraș.',
  path: '/browse',
};

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
