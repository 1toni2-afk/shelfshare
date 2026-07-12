import 'book.dart';

class WishlistItem {
  final String id;
  final Book book;
  final DateTime createdAt;

  const WishlistItem({
    required this.id,
    required this.book,
    required this.createdAt,
  });

  factory WishlistItem.fromJson(Map<String, dynamic> json) {
    return WishlistItem(
      id: json['id'] as String,
      book: Book.fromJson(json['book'] as Map<String, dynamic>),
      createdAt: DateTime.parse(json['createdAt'] as String),
    );
  }
}
