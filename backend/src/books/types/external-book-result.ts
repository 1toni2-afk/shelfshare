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
  source: 'open_library' | 'google_books';
}
