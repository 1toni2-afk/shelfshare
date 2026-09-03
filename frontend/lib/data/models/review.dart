class BookReview {
  final String id;
  final String userId;

  /// Ediția pe care a fost scrisă recenzia. Pe pagina operei recenziile vin
  /// de pe TOATE edițiile ei, deci ștergerea trebuie să țintească ediția
  /// corectă, nu cea deschisă în acel moment.
  final String bookId;
  final int rating;
  final String? text;
  final String? authorName;
  final String? authorAvatar;
  final DateTime createdAt;

  const BookReview({
    required this.id,
    required this.userId,
    required this.bookId,
    required this.rating,
    this.text,
    this.authorName,
    this.authorAvatar,
    required this.createdAt,
  });

  factory BookReview.fromJson(Map<String, dynamic> json) {
    final user = json['user'] as Map<String, dynamic>;
    return BookReview(
      id: json['id'] as String,
      userId: json['userId'] as String,
      bookId: json['bookId'] as String,
      rating: json['rating'] as int,
      text: json['text'] as String?,
      authorName: user['name'] as String?,
      authorAvatar: user['profileImage'] as String?,
      createdAt: DateTime.parse(json['createdAt'] as String),
    );
  }
}

class BookReviews {
  final double? averageRating;
  final int reviewCount;
  final List<BookReview> reviews;

  const BookReviews({required this.averageRating, required this.reviewCount, required this.reviews});

  factory BookReviews.fromJson(Map<String, dynamic> json) {
    return BookReviews(
      averageRating: (json['averageRating'] as num?)?.toDouble(),
      reviewCount: json['reviewCount'] as int,
      reviews: (json['reviews'] as List).map((e) => BookReview.fromJson(e as Map<String, dynamic>)).toList(),
    );
  }
}

class MyReview {
  final int rating;
  final String? text;

  const MyReview({required this.rating, this.text});

  factory MyReview.fromJson(Map<String, dynamic> json) {
    return MyReview(rating: json['rating'] as int, text: json['text'] as String?);
  }
}
