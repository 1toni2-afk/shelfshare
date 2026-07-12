class AppUser {
  final String id;
  final String email;
  final String? name;
  final String? city;
  final String? bio;
  final String? profileImage;
  final double rating;
  final int booksExchangedCount;
  final bool isEmailVerified;

  const AppUser({
    required this.id,
    required this.email,
    this.name,
    this.city,
    this.bio,
    this.profileImage,
    this.rating = 0,
    this.booksExchangedCount = 0,
    this.isEmailVerified = false,
  });

  factory AppUser.fromJson(Map<String, dynamic> json) {
    return AppUser(
      id: json['id'] as String,
      email: json['email'] as String,
      name: json['name'] as String?,
      city: json['city'] as String?,
      bio: json['bio'] as String?,
      profileImage: json['profileImage'] as String?,
      rating: (json['rating'] as num?)?.toDouble() ?? 0,
      booksExchangedCount: json['booksExchangedCount'] as int? ?? 0,
      isEmailVerified: json['isEmailVerified'] as bool? ?? false,
    );
  }
}

/// Versiune redusă a userului, folosită când vine ca relație în alt răspuns
/// (ex: proprietarul unei cărți din /books/browse) - nu conține email.
class PublicUser {
  final String id;
  final String? name;
  final String? city;
  final String? profileImage;
  final double rating;

  const PublicUser({
    required this.id,
    this.name,
    this.city,
    this.profileImage,
    this.rating = 0,
  });

  factory PublicUser.fromJson(Map<String, dynamic> json) {
    return PublicUser(
      id: json['id'] as String,
      name: json['name'] as String?,
      city: json['city'] as String?,
      profileImage: json['profileImage'] as String?,
      rating: (json['rating'] as num?)?.toDouble() ?? 0,
    );
  }
}
