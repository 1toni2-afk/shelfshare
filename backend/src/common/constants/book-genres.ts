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

/**
 * Genuri „vecine" pentru fiecare gen din BOOK_GENRES - folosite de Book Match
 * ca să construiască discovery-ul din distanță controlată față de profil, nu
 * din tot catalogul la întâmplare. Relația nu e neapărat simetrică (ex. YA
 * duce spre Fantasy, dar Fantasy nu duce spre Copii), reflectă ce ar accepta
 * plauzibil un cititor al genului cheie, nu o taxonomie formală.
 */
export const GENRE_ADJACENCY: Record<string, readonly string[]> = {
  Ficțiune: ['Mister', 'Romantic', 'Poezie', 'Clasic'],
  'Non-ficțiune': ['Biografie', 'Filosofie', 'Business', 'Psihologie'],
  Clasic: ['Clasic românesc', 'Istoric', 'Poezie', 'Ficțiune'],
  'Clasic românesc': ['Clasic', 'Istoric', 'Poezie'],
  Fantasy: ['SF', 'Young adult', 'Mister'],
  SF: ['Fantasy', 'Distopie'],
  Thriller: ['Mister', 'Distopie'],
  Mister: ['Thriller', 'Ficțiune'],
  Distopie: ['SF', 'Ficțiune', 'Thriller'],
  Romantic: ['Young adult', 'Ficțiune'],
  Istoric: ['Biografie', 'Clasic'],
  Biografie: ['Istoric', 'Non-ficțiune'],
  'Dezvoltare personală': ['Psihologie', 'Business'],
  Psihologie: ['Dezvoltare personală', 'Filosofie'],
  Filosofie: ['Psihologie', 'Non-ficțiune'],
  Business: ['Dezvoltare personală', 'Non-ficțiune'],
  Poezie: ['Clasic', 'Ficțiune'],
  Copii: ['Young adult', 'Benzi desenate'],
  'Young adult': ['Fantasy', 'Romantic', 'Copii'],
  'Benzi desenate': ['Copii', 'Fantasy'],
};
