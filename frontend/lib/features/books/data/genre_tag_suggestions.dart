/// Genurile propuse în UI + tagurile relevante pentru fiecare.
///
/// Lista de genuri e oglinda celei din backend
/// (`backend/src/common/constants/book-genres.ts`) - câmpul `books.genre`
/// rămâne text liber (cărțile importate din surse externe pot avea orice),
/// deci asta e doar ce sugerăm noi la scriere.
///
/// Tagurile sunt sugestii statice, per gen: la +Share, după ce userul alege
/// un gen, îi arătăm tagurile potrivite genului respectiv în loc de o listă
/// globală generică. Fallback-ul (`_generalTags`) acoperă cazul în care genul
/// e gol sau vine din afara listei.
const Map<String, List<String>> genreTagSuggestions = {
  'Ficțiune': ['contemporan', 'ficțiune literară', 'povestiri', 'debut', 'premiat'],
  'Non-ficțiune': ['eseu', 'documentar', 'jurnalism', 'memorii', 'știință populară'],
  'Clasic': ['literatură universală', 'ediție veche', 'lectură școlară', 'secolul XIX', 'cartonată'],
  'Clasic românesc': ['literatură română', 'lectură școlară', 'interbelic', 'ediție veche', 'bacalaureat'],
  'Fantasy': ['high fantasy', 'magie', 'dragoni', 'serie', 'lume secundară'],
  'SF': ['space opera', 'cyberpunk', 'roboți', 'călătorie în timp', 'hard SF'],
  'Thriller': ['suspans', 'psihologic', 'crimă', 'spionaj', 'page-turner'],
  'Mister': ['detectiv', 'crimă', 'cozy mystery', 'anchetă', 'whodunit'],
  'Distopie': ['post-apocaliptic', 'societate totalitară', 'supraviețuire', 'clasic modern', 'young adult'],
  'Romantic': ['comedie romantică', 'dragoste', 'contemporan', 'slow burn', 'de vacanță'],
  'Istoric': ['al doilea război mondial', 'roman istoric', 'evul mediu', 'documentat', 'biografic'],
  'Biografie': ['memorii', 'autobiografie', 'personalități', 'jurnal', 'inspirațional'],
  'Dezvoltare personală': ['motivațional', 'obiceiuri', 'productivitate', 'mindfulness', 'carieră'],
  'Psihologie': ['psihologie cognitivă', 'terapie', 'relații', 'comportament', 'academic'],
  'Filosofie': ['stoicism', 'etică', 'filosofie antică', 'existențialism', 'eseu'],
  'Business': ['antreprenoriat', 'management', 'finanțe personale', 'marketing', 'startup'],
  'Poezie': ['poezie modernă', 'poezie clasică', 'antologie', 'haiku', 'ediție bilingvă'],
  'Copii': ['ilustrată', 'lectură cu voce tare', '3-6 ani', '7-10 ani', 'basme'],
  'Young adult': ['coming of age', 'serie', 'romantic', 'fantasy YA', 'liceu'],
  'Benzi desenate': ['manga', 'graphic novel', 'supereroi', 'color', 'serie'],
};

/// Genurile propuse la scriere în câmpul „Gen" (autocomplete).
List<String> get suggestedGenres => genreTagSuggestions.keys.toList();

const List<String> _generalTags = [
  'stare foarte bună',
  'ediție rară',
  'cartonată',
  'lectură de vară',
  'cadou',
];

/// Tagurile propuse pentru genul scris de user. Potrivirea e case-insensitive
/// și tolerantă la genuri din surse externe („Science Fiction" -> „SF" nu se
/// mapează, dar „sf" da) - pentru orice altceva cădem pe lista generală.
List<String> tagSuggestionsForGenre(String? genre) {
  final normalized = genre?.trim().toLowerCase();
  if (normalized == null || normalized.isEmpty) return _generalTags;
  for (final entry in genreTagSuggestions.entries) {
    if (entry.key.toLowerCase() == normalized) return entry.value;
  }
  return _generalTags;
}
