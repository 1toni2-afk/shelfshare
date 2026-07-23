import 'book.dart';

/// "Collections" - liste curate de cărți definite liber de user, distincte
/// de raftul de citit (BookshelfEntry) și de wishlist.
class BookCollection {
  final String id;
  final String name;
  final String? description;
  final bool isPublic;
  final List<Book> items;
  final int itemCount;
  final DateTime createdAt;
  final DateTime updatedAt;

  const BookCollection({
    required this.id,
    required this.name,
    this.description,
    required this.isPublic,
    required this.items,
    required this.itemCount,
    required this.createdAt,
    required this.updatedAt,
  });

  factory BookCollection.fromJson(Map<String, dynamic> json) {
    final rawItems = json['items'] as List<dynamic>? ?? [];
    return BookCollection(
      id: json['id'] as String,
      name: json['name'] as String,
      description: json['description'] as String?,
      isPublic: json['isPublic'] as bool? ?? true,
      items: rawItems
          .map((e) => Book.fromJson((e as Map<String, dynamic>)['book'] as Map<String, dynamic>))
          .toList(),
      itemCount: (json['_count'] as Map<String, dynamic>?)?['items'] as int? ?? rawItems.length,
      createdAt: DateTime.parse(json['createdAt'] as String),
      updatedAt: DateTime.parse(json['updatedAt'] as String),
    );
  }
}
