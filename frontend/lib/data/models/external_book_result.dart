/// Rezultat din căutarea externă (Open Library / Google Books), înainte
/// să fie salvat ca [Book] în catalogul propriu.
class ExternalBookResult {
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

  /// Subiectele/categoriile din sursa externă (Open Library `subjects`,
  /// Google Books `categories`), deja curățate de backend de etichetele
  /// tehnice. `genre` e primul element; restul devin sugestii de taguri în
  /// ecranul „Adaugă carte". Gol când sursa nu are nimic util.
  final List<String> subjects;
  final String source;

  const ExternalBookResult({
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
    this.subjects = const [],
    required this.source,
  });

  factory ExternalBookResult.fromJson(Map<String, dynamic> json) {
    return ExternalBookResult(
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
      subjects: (json['subjects'] as List<dynamic>? ?? const [])
          .map((e) => e as String)
          .toList(),
      source: json['source'] as String,
    );
  }
}
