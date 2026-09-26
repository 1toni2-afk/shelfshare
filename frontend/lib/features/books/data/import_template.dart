/// Coloanele pe care le citește importul de CSV și șablonul pe care îl
/// descarcă userul din pagina de import.
///
/// Numele coloanelor sunt în engleză și NU se traduc: backend-ul le compară
/// literal, cu `header.trim().toLowerCase() === 'title'` (vezi `csvValue` din
/// books.service.ts). Sunt aceleași nume pe care le scriu Goodreads și
/// StoryGraph în exporturile lor, de-aia un export de-al lor merge încărcat
/// direct, fără să fie rearanjat.
library;

/// Antetul șablonului - și, de la Milestone-ul ăsta, și antetul exportului din
/// „Cărțile mele", ca un fișier exportat de aici să poată fi încărcat înapoi.
const kImportCsvColumns = [
  'title',
  'author',
  'isbn',
  'shelf',
  'condition',
  'language',
  'city',
  'price',
  'description',
];

/// Valorile acceptate în coloana `condition` (enum-ul BookCondition din
/// backend). Le arătăm ca atare în pagina de import - orice altceva e ignorat
/// și rândul primește „BUNA".
const kImportConditions = ['NOUA', 'FOARTE_BUNA', 'BUNA', 'ACCEPTABILA'];

/// Șablonul descărcabil: antetul plus trei rânduri care arată cele trei
/// destinații posibile (anunț în piață, raft de lectură, favorite), ca omul să
/// nu fie nevoit să citească documentația ca să înțeleagă coloana `shelf`.
///
/// Începe cu BOM: fără el, Excel deschide un CSV UTF-8 în codepage-ul de
/// sistem și strică diacriticele din chiar fișierul pe care i-l dăm noi ca
/// exemplu.
String buildImportTemplateCsv() {
  const rows = [
    'Dune,Frank Herbert,9780441013593,swap,BUNA,Română,Cluj-Napoca,25,Ediție cartonată',
    'Solaris,Stanisław Lem,,read,,Română,,,',
    'Kafka pe malul mării,Haruki Murakami,,to-read,,,,,',
  ];
  return '﻿${kImportCsvColumns.join(',')}\r\n${rows.join('\r\n')}\r\n';
}

/// Numele sub care se descarcă șablonul. Extensia rămâne .csv chiar dacă omul
/// îl deschide în Excel - importul refuză un .xlsx.
const kImportTemplateFilename = 'sablon-import-shelfshare.csv';

/// Pagina de export a bibliotecii de pe Goodreads („Export Library").
const kGoodreadsExportUrl = 'https://www.goodreads.com/review/import';

/// Echivalentul de pe StoryGraph.
const kStoryGraphExportUrl = 'https://app.thestorygraph.com/user-export';
