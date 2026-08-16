export interface ExternalBookResult {
  isbn: string | null;
  title: string;
  author: string | null;
  description: string | null;
  coverUrl: string | null;
  publisher: string | null;
  publishedYear: number | null;
  pageCount: number | null;
  language: string | null;
  genre: string | null;
  /**
   * Subiectele/categoriile brute din sursa externă (Open Library `subjects` /
   * `subject`, Google Books `categories`), curățate de etichetele faceted
   * („prefix:valoare") și limitate la primele ~20. `genre` e practic primul
   * element din lista asta; restul sunt folosite în client ca sugestii de
   * taguri la adăugarea unei cărți. Mereu array (niciodată null) ca să nu
   * trebuiască verificat în fiecare consumator.
   */
  subjects: string[];
  source: 'open_library' | 'google_books';
}
