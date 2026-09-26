/**
 * Coloanele pe care le citește importul de CSV și șablonul pe care îl descarcă
 * userul din pagina de import. Port 1:1 al `import_template.dart`.
 *
 * Numele coloanelor sunt în engleză și NU se traduc: backendul le compară
 * literal, cu `header.trim().toLowerCase() === 'title'` (vezi `csvValue` din
 * books.service.ts). Sunt aceleași nume pe care le scriu Goodreads și
 * StoryGraph în exporturile lor, de-aia un export de-al lor merge încărcat
 * direct, fără să fie rearanjat.
 */
export const IMPORT_CSV_COLUMNS = [
  'title',
  'author',
  'isbn',
  'shelf',
  'condition',
  'language',
  'city',
  'price',
  'description',
] as const;

/**
 * Valorile acceptate în coloana `condition` (enumul BookCondition din backend).
 * Orice altceva e ignorat și rândul primește „BUNA".
 */
export const IMPORT_CONDITIONS = ['NOUA', 'FOARTE_BUNA', 'BUNA', 'ACCEPTABILA'] as const;

/** Numele sub care se descarcă șablonul. */
export const IMPORT_TEMPLATE_FILENAME = 'sablon-import-shelfshare.csv';

/** Pagina de export a bibliotecii de pe Goodreads („Export Library"). */
export const GOODREADS_EXPORT_URL = 'https://www.goodreads.com/review/import';

/** Echivalentul de pe StoryGraph. */
export const STORYGRAPH_EXPORT_URL = 'https://app.thestorygraph.com/user-export';

/**
 * Șablonul descărcabil: antetul plus trei rânduri care arată cele trei
 * destinații posibile (anunț în piață, raft de lectură, favorite), ca omul să
 * nu fie nevoit să citească documentația ca să înțeleagă coloana `shelf`.
 *
 * Începe cu BOM: fără el, Excel deschide un CSV UTF-8 în codepage-ul de sistem
 * și strică diacriticele din chiar fișierul pe care i-l dăm noi ca exemplu.
 */
export function buildImportTemplateCsv(): string {
  const rows = [
    'Dune,Frank Herbert,9780441013593,swap,BUNA,Română,Cluj-Napoca,25,Ediție cartonată',
    'Solaris,Stanisław Lem,,read,,Română,,,',
    'Kafka pe malul mării,Haruki Murakami,,to-read,,,,,',
  ];
  return `﻿${IMPORT_CSV_COLUMNS.join(',')}\r\n${rows.join('\r\n')}\r\n`;
}
