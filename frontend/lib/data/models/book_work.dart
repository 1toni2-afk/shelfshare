import 'book.dart';
import 'review.dart';
import 'user_book.dart';

/// Pagina „despre carte": o singură OPERĂ, cu toate edițiile ei, recenziile
/// adunate peste ele și exemplarele listate în aplicație.
///
/// Vine din `GET /books/work/:bookId`. Edițiile sunt grupate pe server la
/// interogare (titlu+autor normalizate), nu printr-un tabel separat - vezi
/// BooksService.getWork pentru ce înseamnă asta în practică.
class BookWork {
  /// Ediția cerută - cea ale cărei date se afișează în antet.
  final Book book;

  /// Toate edițiile aceleiași opere, `book` mereu prima.
  final List<Book> editions;

  final BookReviews reviews;

  /// Exemplarele scoase la schimb/vânzare în aplicație, pentru ORICE ediție
  /// a operei. Goale când nimeni nu o listează acum.
  final List<UserBook> listings;

  const BookWork({
    required this.book,
    required this.editions,
    required this.reviews,
    required this.listings,
  });

  factory BookWork.fromJson(Map<String, dynamic> json) {
    return BookWork(
      book: Book.fromJson(json['book'] as Map<String, dynamic>),
      editions: (json['editions'] as List? ?? const [])
          .map((e) => Book.fromJson(e as Map<String, dynamic>))
          .toList(),
      reviews: BookReviews.fromJson(json['reviews'] as Map<String, dynamic>),
      listings: (json['listings'] as List? ?? const [])
          .map((e) => UserBook.fromJson(e as Map<String, dynamic>))
          .toList(),
    );
  }
}
