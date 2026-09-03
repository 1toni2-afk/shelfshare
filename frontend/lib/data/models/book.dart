import '../../l10n/app_localizations.dart';

class BookGenre {
  final String genre;
  final int count;

  const BookGenre({required this.genre, required this.count});

  factory BookGenre.fromJson(Map<String, dynamic> json) {
    return BookGenre(
      genre: json['genre'] as String,
      count: json['count'] as int,
    );
  }
}

class BookStatEntry {
  final Book book;
  final int count;

  const BookStatEntry({required this.book, required this.count});

  factory BookStatEntry.fromJson(Map<String, dynamic> json) {
    return BookStatEntry(
      book: Book.fromJson(json['book'] as Map<String, dynamic>),
      count: json['count'] as int,
    );
  }
}

/// Statusul personal de citit pentru o carte din catalog (Public
/// Bookshelf) - independent de a deține sau nu un exemplar fizic listat.
enum BookshelfStatus { reading, wantToRead, finished }

extension BookshelfStatusX on BookshelfStatus {
  static BookshelfStatus fromJson(String value) {
    switch (value) {
      case 'READING':
        return BookshelfStatus.reading;
      case 'WANT_TO_READ':
        return BookshelfStatus.wantToRead;
      case 'FINISHED':
        return BookshelfStatus.finished;
      default:
        throw ArgumentError('Status necunoscut: $value');
    }
  }

  String toJson() {
    switch (this) {
      case BookshelfStatus.reading:
        return 'READING';
      case BookshelfStatus.wantToRead:
        return 'WANT_TO_READ';
      case BookshelfStatus.finished:
        return 'FINISHED';
    }
  }
}

/// Gruparea raftului (propriu sau public) pe cele 3 stări stocate - "Shared"
/// nu e parte din asta, se derivă din listările UserBook existente.
class Bookshelf {
  final List<Book> reading;
  final List<Book> wantToRead;
  final List<Book> finished;

  const Bookshelf({
    this.reading = const [],
    this.wantToRead = const [],
    this.finished = const [],
  });

  factory Bookshelf.fromJson(Map<String, dynamic> json) {
    return Bookshelf(
      reading: (json['reading'] as List<dynamic>? ?? [])
          .map((e) => Book.fromJson(e as Map<String, dynamic>))
          .toList(),
      wantToRead: (json['wantToRead'] as List<dynamic>? ?? [])
          .map((e) => Book.fromJson(e as Map<String, dynamic>))
          .toList(),
      finished: (json['finished'] as List<dynamic>? ?? [])
          .map((e) => Book.fromJson(e as Map<String, dynamic>))
          .toList(),
    );
  }
}

/// O carte pe care userul o DEȚINE dar nu a scos-o (încă) la listare -
/// prim-planul din My Shelf. Vine din `GET /bookshelf/me/owned`, care combină
/// BookshelfEntry (owned + status) cu ReadingProgress (pagina curentă și
/// numărul de pagini al ediției proprii, care poate diferi de catalog).
class OwnedBook {
  final Book book;
  final BookshelfStatus status;
  final int currentPage;
  final int? totalPages;

  /// Cartea are deja un anunț activ. Rămâne în secțiune doar cât e „în curs
  /// de citire" (progresul nu se vede nicăieri în grila de listări), dar
  /// cardul nu-i mai propune să o listeze - o are deja listată.
  final bool listed;

  const OwnedBook({
    required this.book,
    required this.status,
    this.currentPage = 0,
    this.totalPages,
    this.listed = false,
  });

  /// Fracție 0..1 pentru bara de progres. Null când nu știm totalul - atunci
  /// afișăm doar „Pagina X", fără bară (nu putem inventa un procent).
  double? get progress {
    final total = totalPages;
    if (total == null || total <= 0) return null;
    return (currentPage / total).clamp(0.0, 1.0);
  }

  /// Terminată de citit: fie marcată explicit FINISHED, fie progresul a ajuns
  /// la ultima pagină. Doar atunci oferim „scoate-o la schimb/vânzare".
  bool get isFinished {
    if (status == BookshelfStatus.finished) return true;
    final total = totalPages;
    return total != null && total > 0 && currentPage >= total;
  }

  factory OwnedBook.fromJson(Map<String, dynamic> json) {
    return OwnedBook(
      book: Book.fromJson(json['book'] as Map<String, dynamic>),
      status: BookshelfStatusX.fromJson(json['status'] as String),
      currentPage: (json['currentPage'] as num?)?.toInt() ?? 0,
      totalPages: (json['totalPages'] as num?)?.toInt(),
      listed: json['listed'] == true,
    );
  }
}

class SearchStat {
  final String query;
  final int count;

  const SearchStat({required this.query, required this.count});

  factory SearchStat.fromJson(Map<String, dynamic> json) {
    return SearchStat(
      query: json['query'] as String,
      count: json['count'] as int,
    );
  }
}

class AuthorStatEntry {
  final String author;
  final int count;

  const AuthorStatEntry({required this.author, required this.count});

  factory AuthorStatEntry.fromJson(Map<String, dynamic> json) {
    return AuthorStatEntry(
      author: json['author'] as String,
      count: json['count'] as int,
    );
  }
}

enum BookCondition { noua, foarteBuna, buna, acceptabila }

extension BookConditionX on BookCondition {
  static BookCondition fromJson(String value) {
    switch (value) {
      case 'NOUA':
        return BookCondition.noua;
      case 'FOARTE_BUNA':
        return BookCondition.foarteBuna;
      case 'BUNA':
        return BookCondition.buna;
      case 'ACCEPTABILA':
        return BookCondition.acceptabila;
      default:
        throw ArgumentError('Stare necunoscută: $value');
    }
  }

  String toJson() {
    switch (this) {
      case BookCondition.noua:
        return 'NOUA';
      case BookCondition.foarteBuna:
        return 'FOARTE_BUNA';
      case BookCondition.buna:
        return 'BUNA';
      case BookCondition.acceptabila:
        return 'ACCEPTABILA';
    }
  }

  /// Eticheta tradusă. Numele intern al enum-ului rămâne în română fiindcă
  /// oglindește valorile din baza de date (NOUA, FOARTE_BUNA, ...), dar textul
  /// afișat trebuie să urmeze limba aplicației.
  String label(AppLocalizations l10n) {
    switch (this) {
      case BookCondition.noua:
        return l10n.bookConditionNew;
      case BookCondition.foarteBuna:
        return l10n.bookConditionVeryGood;
      case BookCondition.buna:
        return l10n.bookConditionGood;
      case BookCondition.acceptabila:
        return l10n.bookConditionAcceptable;
    }
  }
}

/// Catalogul global de cărți - o ediție anume, indiferent cine o deține.
class Book {
  final String id;
  final String? isbn;
  final String title;
  final String? author;
  final String? description;
  final String? coverUrl;
  final String? publisher;
  final int? publishedYear;
  final int? pageCount;
  final String? language;
  final String? genre;
  final String? series;
  final int? seriesNumber;
  final double? referencePrice;
  final String? referencePriceCurrency;

  const Book({
    required this.id,
    this.isbn,
    required this.title,
    this.author,
    this.description,
    this.coverUrl,
    this.publisher,
    this.publishedYear,
    this.pageCount,
    this.language,
    this.genre,
    this.series,
    this.seriesNumber,
    this.referencePrice,
    this.referencePriceCurrency,
  });

  factory Book.fromJson(Map<String, dynamic> json) {
    return Book(
      id: json['id'] as String,
      isbn: json['isbn'] as String?,
      title: json['title'] as String,
      author: json['author'] as String?,
      description: json['description'] as String?,
      coverUrl: json['coverUrl'] as String?,
      publisher: json['publisher'] as String?,
      publishedYear: json['publishedYear'] as int?,
      pageCount: json['pageCount'] as int?,
      language: json['language'] as String?,
      genre: json['genre'] as String?,
      series: json['series'] as String?,
      seriesNumber: json['seriesNumber'] as int?,
      referencePrice: json['referencePrice'] != null
          ? double.parse(json['referencePrice'].toString())
          : null,
      referencePriceCurrency: json['referencePriceCurrency'] as String?,
    );
  }
}
