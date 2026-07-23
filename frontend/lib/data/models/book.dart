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

  String get label {
    switch (this) {
      case BookCondition.noua:
        return 'Nouă';
      case BookCondition.foarteBuna:
        return 'Foarte bună';
      case BookCondition.buna:
        return 'Bună';
      case BookCondition.acceptabila:
        return 'Acceptabilă';
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
      referencePrice: json['referencePrice'] != null
          ? double.parse(json['referencePrice'].toString())
          : null,
      referencePriceCurrency: json['referencePriceCurrency'] as String?,
    );
  }
}
