import 'user_book.dart';

class AppUser {
  final String id;
  final String email;
  final String? name;
  final String? username;
  final bool nameVisible;
  final String? city;
  final String? bio;
  final String? profileImage;
  final double rating;
  final int booksExchangedCount;
  final bool isEmailVerified;
  final bool isAdmin;
  final bool showAcquisitionHistory;
  final String? referralCode;
  final int referralCount;
  final TrustScore? trustScore;
  final List<Achievement>? achievements;

  const AppUser({
    required this.id,
    required this.email,
    this.name,
    this.username,
    this.nameVisible = true,
    this.city,
    this.bio,
    this.profileImage,
    this.rating = 0,
    this.booksExchangedCount = 0,
    this.isEmailVerified = false,
    this.isAdmin = false,
    this.showAcquisitionHistory = false,
    this.referralCode,
    this.referralCount = 0,
    this.trustScore,
    this.achievements,
  });

  factory AppUser.fromJson(Map<String, dynamic> json) {
    return AppUser(
      id: json['id'] as String,
      email: json['email'] as String,
      name: json['name'] as String?,
      username: json['username'] as String?,
      nameVisible: json['nameVisible'] as bool? ?? true,
      city: json['city'] as String?,
      bio: json['bio'] as String?,
      profileImage: json['profileImage'] as String?,
      rating: (json['rating'] as num?)?.toDouble() ?? 0,
      booksExchangedCount: json['booksExchangedCount'] as int? ?? 0,
      isEmailVerified: json['isEmailVerified'] as bool? ?? false,
      isAdmin: json['isAdmin'] as bool? ?? false,
      showAcquisitionHistory: json['showAcquisitionHistory'] as bool? ?? false,
      referralCode: json['referralCode'] as String?,
      referralCount: json['referralCount'] as int? ?? 0,
      trustScore: json['trustScore'] != null
          ? TrustScore.fromJson(json['trustScore'] as Map<String, dynamic>)
          : null,
      achievements: (json['achievements'] as List<dynamic>?)
          ?.map((e) => Achievement.fromJson(e as Map<String, dynamic>))
          .toList(),
    );
  }
}

/// Indicator simplu de încredere (0-100) calculat din date deja existente -
/// NU e o verificare certificată de identitate. Vezi computeTrustScore în
/// backend/src/profile/profile.service.ts pentru formula exactă.
class TrustScore {
  final int score;
  final int accountAgeDays;
  final bool isEmailVerified;
  final int completedExchanges;
  final double rating;
  final double? completedExchangeRate;
  final double? averageResponseHours;
  final double? cancellationRate;

  const TrustScore({
    required this.score,
    required this.accountAgeDays,
    required this.isEmailVerified,
    required this.completedExchanges,
    required this.rating,
    this.completedExchangeRate,
    this.averageResponseHours,
    this.cancellationRate,
  });

  factory TrustScore.fromJson(Map<String, dynamic> json) {
    return TrustScore(
      score: json['score'] as int,
      accountAgeDays: json['accountAgeDays'] as int,
      isEmailVerified: json['isEmailVerified'] as bool,
      completedExchanges: json['completedExchanges'] as int,
      rating: (json['rating'] as num).toDouble(),
      completedExchangeRate: (json['completedExchangeRate'] as num?)?.toDouble(),
      averageResponseHours: (json['averageResponseHours'] as num?)?.toDouble(),
      cancellationRate: (json['cancellationRate'] as num?)?.toDouble(),
    );
  }
}

class AcquisitionHistoryEntry {
  final String bookTitle;
  final String? bookCoverUrl;
  final DateTime date;
  final String type;

  const AcquisitionHistoryEntry({
    required this.bookTitle,
    this.bookCoverUrl,
    required this.date,
    required this.type,
  });

  factory AcquisitionHistoryEntry.fromJson(Map<String, dynamic> json) {
    return AcquisitionHistoryEntry(
      bookTitle: json['bookTitle'] as String,
      bookCoverUrl: json['bookCoverUrl'] as String?,
      date: DateTime.parse(json['date'] as String),
      type: json['type'] as String,
    );
  }
}

class Review {
  final String reviewerId;
  final String? reviewerName;
  final String? reviewerImage;
  final int? rating;
  final String? comment;
  final DateTime date;

  const Review({
    required this.reviewerId,
    this.reviewerName,
    this.reviewerImage,
    this.rating,
    this.comment,
    required this.date,
  });

  factory Review.fromJson(Map<String, dynamic> json) {
    return Review(
      reviewerId: json['reviewerId'] as String,
      reviewerName: json['reviewerName'] as String?,
      reviewerImage: json['reviewerImage'] as String?,
      rating: json['rating'] as int?,
      comment: json['comment'] as String?,
      date: DateTime.parse(json['date'] as String),
    );
  }
}

class CityLeaderboardEntry {
  final String id;
  final String? name;
  final String? username;
  final String? city;
  final String? profileImage;
  final double rating;
  final int booksExchangedCount;

  const CityLeaderboardEntry({
    required this.id,
    this.name,
    this.username,
    this.city,
    this.profileImage,
    required this.rating,
    required this.booksExchangedCount,
  });

  factory CityLeaderboardEntry.fromJson(Map<String, dynamic> json) {
    return CityLeaderboardEntry(
      id: json['id'] as String,
      name: json['name'] as String?,
      username: json['username'] as String?,
      city: json['city'] as String?,
      profileImage: json['profileImage'] as String?,
      rating: (json['rating'] as num).toDouble(),
      booksExchangedCount: json['booksExchangedCount'] as int,
    );
  }
}

class Achievement {
  final String key;
  final String label;
  final String description;
  final bool achieved;

  const Achievement({
    required this.key,
    required this.label,
    required this.description,
    required this.achieved,
  });

  factory Achievement.fromJson(Map<String, dynamic> json) {
    return Achievement(
      key: json['key'] as String,
      label: json['label'] as String,
      description: json['description'] as String,
      achieved: json['achieved'] as bool,
    );
  }
}

class ReadingStats {
  final int totalListed;
  final int totalPages;
  final String? favoriteGenre;
  final List<GenreCount> topGenres;

  const ReadingStats({
    required this.totalListed,
    required this.totalPages,
    this.favoriteGenre,
    this.topGenres = const [],
  });

  factory ReadingStats.fromJson(Map<String, dynamic> json) {
    return ReadingStats(
      totalListed: json['totalListed'] as int,
      totalPages: json['totalPages'] as int,
      favoriteGenre: json['favoriteGenre'] as String?,
      topGenres: (json['topGenres'] as List<dynamic>?)
              ?.map((e) => GenreCount.fromJson(e as Map<String, dynamic>))
              .toList() ??
          const [],
    );
  }
}

class GenreCount {
  final String genre;
  final int count;

  const GenreCount({required this.genre, required this.count});

  factory GenreCount.fromJson(Map<String, dynamic> json) {
    return GenreCount(genre: json['genre'] as String, count: json['count'] as int);
  }
}

/// Versiune redusă a userului, folosită când vine ca relație în alt răspuns
/// (ex: proprietarul unei cărți din /books/browse) - nu conține email.
/// `listedBooks`/`listingsCount`/`acquisitionHistory` vin doar din
/// /profile/:userId (profilul public complet), nu din relațiile scurte.
class PublicUser {
  final String id;
  final String? name;
  final String? username;
  final String? city;
  final String? profileImage;
  final double rating;
  final String? bio;
  final int? booksExchangedCount;
  final DateTime? memberSince;
  final List<UserBook>? listedBooks;
  final int? listingsCount;
  final List<AcquisitionHistoryEntry>? acquisitionHistory;
  final TrustScore? trustScore;
  final List<Review>? reviews;
  final ReadingStats? readingStats;
  final List<Achievement>? achievements;

  const PublicUser({
    required this.id,
    this.name,
    this.username,
    this.city,
    this.profileImage,
    this.rating = 0,
    this.bio,
    this.booksExchangedCount,
    this.memberSince,
    this.listedBooks,
    this.listingsCount,
    this.acquisitionHistory,
    this.trustScore,
    this.reviews,
    this.readingStats,
    this.achievements,
  });

  factory PublicUser.fromJson(Map<String, dynamic> json) {
    return PublicUser(
      id: json['id'] as String,
      name: json['name'] as String?,
      username: json['username'] as String?,
      city: json['city'] as String?,
      profileImage: json['profileImage'] as String?,
      rating: (json['rating'] as num?)?.toDouble() ?? 0,
      bio: json['bio'] as String?,
      booksExchangedCount: json['booksExchangedCount'] as int?,
      memberSince: json['memberSince'] != null
          ? DateTime.parse(json['memberSince'] as String)
          : null,
      listedBooks: (json['listedBooks'] as List<dynamic>?)
          ?.map((e) => UserBook.fromJson(e as Map<String, dynamic>))
          .toList(),
      listingsCount: json['listingsCount'] as int?,
      acquisitionHistory: (json['acquisitionHistory'] as List<dynamic>?)
          ?.map((e) => AcquisitionHistoryEntry.fromJson(e as Map<String, dynamic>))
          .toList(),
      trustScore: json['trustScore'] != null
          ? TrustScore.fromJson(json['trustScore'] as Map<String, dynamic>)
          : null,
      reviews: (json['reviews'] as List<dynamic>?)
          ?.map((e) => Review.fromJson(e as Map<String, dynamic>))
          .toList(),
      readingStats: json['readingStats'] != null
          ? ReadingStats.fromJson(json['readingStats'] as Map<String, dynamic>)
          : null,
      achievements: (json['achievements'] as List<dynamic>?)
          ?.map((e) => Achievement.fromJson(e as Map<String, dynamic>))
          .toList(),
    );
  }
}
