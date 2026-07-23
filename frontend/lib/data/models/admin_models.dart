class AdminStats {
  final int totalUsers;
  final int verifiedUsers;
  final int totalBooks;
  final int totalListings;
  final int totalExchanges;
  final int completedExchanges;
  final int pendingExchanges;

  const AdminStats({
    required this.totalUsers,
    required this.verifiedUsers,
    required this.totalBooks,
    required this.totalListings,
    required this.totalExchanges,
    required this.completedExchanges,
    required this.pendingExchanges,
  });

  factory AdminStats.fromJson(Map<String, dynamic> json) {
    final users = json['users'] as Map<String, dynamic>;
    final books = json['books'] as Map<String, dynamic>;
    final exchanges = json['exchanges'] as Map<String, dynamic>;
    return AdminStats(
      totalUsers: users['total'] as int,
      verifiedUsers: users['verified'] as int,
      totalBooks: books['totalInCatalog'] as int,
      totalListings: books['totalListings'] as int,
      totalExchanges: exchanges['total'] as int,
      completedExchanges: exchanges['completed'] as int,
      pendingExchanges: exchanges['pending'] as int,
    );
  }
}

class GenreListingCount {
  final String genre;
  final int count;

  const GenreListingCount({required this.genre, required this.count});

  factory GenreListingCount.fromJson(Map<String, dynamic> json) {
    return GenreListingCount(genre: json['genre'] as String, count: json['count'] as int);
  }
}

class MarketplaceStats {
  final double gmv;
  final int completedSalesCount;
  final int completedAuctionsCount;
  final double averageSalePrice;
  final List<GenreListingCount> topGenresByListings;

  const MarketplaceStats({
    required this.gmv,
    required this.completedSalesCount,
    required this.completedAuctionsCount,
    required this.averageSalePrice,
    required this.topGenresByListings,
  });

  factory MarketplaceStats.fromJson(Map<String, dynamic> json) {
    return MarketplaceStats(
      gmv: (json['gmv'] as num).toDouble(),
      completedSalesCount: json['completedSalesCount'] as int,
      completedAuctionsCount: json['completedAuctionsCount'] as int,
      averageSalePrice: (json['averageSalePrice'] as num).toDouble(),
      topGenresByListings: (json['topGenresByListings'] as List)
          .map((e) => GenreListingCount.fromJson(e as Map<String, dynamic>))
          .toList(),
    );
  }
}

class ActiveZone {
  final String city;
  final int count;
  final double lat;
  final double lng;

  const ActiveZone({required this.city, required this.count, required this.lat, required this.lng});

  factory ActiveZone.fromJson(Map<String, dynamic> json) {
    return ActiveZone(
      city: json['city'] as String,
      count: json['count'] as int,
      lat: (json['lat'] as num).toDouble(),
      lng: (json['lng'] as num).toDouble(),
    );
  }
}

class AdminUser {
  final String id;
  final String email;
  final String? name;
  final String? city;
  final bool isEmailVerified;
  final bool isBanned;
  final bool isAdmin;
  final double rating;
  final int booksExchangedCount;
  final DateTime createdAt;

  const AdminUser({
    required this.id,
    required this.email,
    this.name,
    this.city,
    required this.isEmailVerified,
    required this.isBanned,
    required this.isAdmin,
    required this.rating,
    required this.booksExchangedCount,
    required this.createdAt,
  });

  AdminUser copyWith({bool? isBanned}) {
    return AdminUser(
      id: id,
      email: email,
      name: name,
      city: city,
      isEmailVerified: isEmailVerified,
      isBanned: isBanned ?? this.isBanned,
      isAdmin: isAdmin,
      rating: rating,
      booksExchangedCount: booksExchangedCount,
      createdAt: createdAt,
    );
  }

  factory AdminUser.fromJson(Map<String, dynamic> json) {
    return AdminUser(
      id: json['id'] as String,
      email: json['email'] as String,
      name: json['name'] as String?,
      city: json['city'] as String?,
      isEmailVerified: json['isEmailVerified'] as bool,
      isBanned: json['isBanned'] as bool,
      isAdmin: json['isAdmin'] as bool,
      rating: (json['rating'] as num).toDouble(),
      booksExchangedCount: json['booksExchangedCount'] as int,
      createdAt: DateTime.parse(json['createdAt'] as String),
    );
  }
}

class AdminUsersPage {
  final List<AdminUser> items;
  final int limit;
  final int offset;

  const AdminUsersPage({
    required this.items,
    required this.limit,
    required this.offset,
  });

  factory AdminUsersPage.fromJson(Map<String, dynamic> json) {
    return AdminUsersPage(
      items: (json['items'] as List)
          .map((e) => AdminUser.fromJson(e as Map<String, dynamic>))
          .toList(),
      limit: json['limit'] as int,
      offset: json['offset'] as int,
    );
  }
}

class UserReport {
  final String id;
  final String reason;
  final String? details;
  final String reporterEmail;
  final String? reporterName;
  final String reportedEmail;
  final String? reportedName;
  final DateTime createdAt;

  const UserReport({
    required this.id,
    required this.reason,
    this.details,
    required this.reporterEmail,
    this.reporterName,
    required this.reportedEmail,
    this.reportedName,
    required this.createdAt,
  });

  factory UserReport.fromJson(Map<String, dynamic> json) {
    final reporter = json['reporter'] as Map<String, dynamic>;
    final reportedUser = json['reportedUser'] as Map<String, dynamic>;
    return UserReport(
      id: json['id'] as String,
      reason: json['reason'] as String,
      details: json['details'] as String?,
      reporterEmail: reporter['email'] as String,
      reporterName: reporter['name'] as String?,
      reportedEmail: reportedUser['email'] as String,
      reportedName: reportedUser['name'] as String?,
      createdAt: DateTime.parse(json['createdAt'] as String),
    );
  }
}

class FeedbackItem {
  final String id;
  final String message;
  final String userEmail;
  final String? userName;
  final DateTime createdAt;

  const FeedbackItem({
    required this.id,
    required this.message,
    required this.userEmail,
    this.userName,
    required this.createdAt,
  });

  factory FeedbackItem.fromJson(Map<String, dynamic> json) {
    final user = json['user'] as Map<String, dynamic>;
    return FeedbackItem(
      id: json['id'] as String,
      message: json['message'] as String,
      userEmail: user['email'] as String,
      userName: user['name'] as String?,
      createdAt: DateTime.parse(json['createdAt'] as String),
    );
  }
}

class SupportRequestItem {
  final String id;
  final String name;
  final String email;
  final String? phone;
  final String message;
  final DateTime createdAt;

  const SupportRequestItem({
    required this.id,
    required this.name,
    required this.email,
    this.phone,
    required this.message,
    required this.createdAt,
  });

  factory SupportRequestItem.fromJson(Map<String, dynamic> json) {
    return SupportRequestItem(
      id: json['id'] as String,
      name: json['name'] as String,
      email: json['email'] as String,
      phone: json['phone'] as String?,
      message: json['message'] as String,
      createdAt: DateTime.parse(json['createdAt'] as String),
    );
  }
}

class InactiveListing {
  final String id;
  final String bookTitle;
  final String? bookAuthor;
  final String ownerEmail;
  final String? ownerName;
  final DateTime createdAt;

  const InactiveListing({
    required this.id,
    required this.bookTitle,
    this.bookAuthor,
    required this.ownerEmail,
    this.ownerName,
    required this.createdAt,
  });

  factory InactiveListing.fromJson(Map<String, dynamic> json) {
    final book = json['book'] as Map<String, dynamic>;
    final user = json['user'] as Map<String, dynamic>;
    return InactiveListing(
      id: json['id'] as String,
      bookTitle: book['title'] as String,
      bookAuthor: book['author'] as String?,
      ownerEmail: user['email'] as String,
      ownerName: user['name'] as String?,
      createdAt: DateTime.parse(json['createdAt'] as String),
    );
  }
}
