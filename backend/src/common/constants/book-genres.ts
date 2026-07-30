/**
 * Genurile propuse în chestionarul de profil de cititor.
 *
 * Sunt aceleași etichete folosite în `books.genre` pentru cărțile adăugate din
 * aplicație, ca potrivirea cu preferințele userului să fie o comparație directă.
 * Cărțile importate din surse externe pot avea și alte genuri - de asta câmpul
 * din DB rămâne text liber, iar lista de aici e doar ce oferim în UI.
 */
export const BOOK_GENRES = [
  'Ficțiune',
  'Non-ficțiune',
  'Clasic',
  'Clasic românesc',
  'Fantasy',
  'SF',
  'Thriller',
  'Mister',
  'Distopie',
  'Romantic',
  'Istoric',
  'Biografie',
  'Dezvoltare personală',
  'Psihologie',
  'Filosofie',
  'Business',
  'Poezie',
  'Copii',
  'Young adult',
  'Benzi desenate',
] as const;

export type BookGenre = (typeof BOOK_GENRES)[number];
