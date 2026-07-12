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
    );
  }
}
