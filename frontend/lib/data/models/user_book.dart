import 'book.dart';
import 'user.dart';

/// Exemplarul concret al unei cărți deținut de un utilizator - starea
/// fizică, pozele reale, disponibilitatea pentru schimb.
class UserBook {
  final String id;
  final String userId;
  final Book book;
  final PublicUser? owner; // prezent doar în /books/browse
  final BookCondition condition;
  final String? language;
  final String? edition;
  final bool isHardcover;
  final bool availableForSwap;
  final List<String> photos;
  final DateTime createdAt;

  const UserBook({
    required this.id,
    required this.userId,
    required this.book,
    this.owner,
    required this.condition,
    this.language,
    this.edition,
    this.isHardcover = false,
    this.availableForSwap = true,
    this.photos = const [],
    required this.createdAt,
  });

  factory UserBook.fromJson(Map<String, dynamic> json) {
    return UserBook(
      id: json['id'] as String,
      userId: json['userId'] as String,
      book: Book.fromJson(json['book'] as Map<String, dynamic>),
      owner: json['user'] != null
          ? PublicUser.fromJson(json['user'] as Map<String, dynamic>)
          : null,
      condition: BookConditionX.fromJson(json['condition'] as String),
      language: json['language'] as String?,
      edition: json['edition'] as String?,
      isHardcover: json['isHardcover'] as bool? ?? false,
      availableForSwap: json['availableForSwap'] as bool? ?? true,
      photos: (json['photos'] as List<dynamic>?)
              ?.map((e) => e as String)
              .toList() ??
          const [],
      createdAt: DateTime.parse(json['createdAt'] as String),
    );
  }
}
