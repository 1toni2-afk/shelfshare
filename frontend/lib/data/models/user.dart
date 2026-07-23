import 'book.dart';
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
  final int booksSharedCount;
  final int booksReceivedCount;
  final bool isEmailVerified;
  final bool isAdmin;
  final bool showAcquisitionHistory;
  final String? referralCode;
  final int referralCount;
  final TrustScore? trustScore;
  final List<Achievement>? achievements;
  final ImpactStats? impactStats;
  final GamificationStats? gamification;

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
    this.booksSharedCount = 0,
    this.booksReceivedCount = 0,
    this.isEmailVerified = false,
    this.isAdmin = false,
    this.showAcquisitionHistory = false,
    this.referralCode,
    this.referralCount = 0,
    this.trustScore,
    this.achievements,
    this.impactStats,
    this.gamification,
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
      booksSharedCount: json['booksSharedCount'] as int? ?? 0,
      booksReceivedCount: json['booksReceivedCount'] as int? ?? 0,
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
      impactStats: json['impactStats'] != null
          ? ImpactStats.fromJson(json['impactStats'] as Map<String, dynamic>)
          : null,
      gamification: json['gamification'] != null
          ? GamificationStats.fromJson(json['gamification'] as Map<String, dynamic>)
          : null,
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
  final DateTime? lastActiveAt;
  final double? responseRate;
  final double? averageSwapTimeHours;
  final double? avgCommunicationRating;
  final double? avgPunctualityRating;
  final double? avgConditionRating;

  const TrustScore({
    required this.score,
    required this.accountAgeDays,
    required this.isEmailVerified,
    required this.completedExchanges,
    required this.rating,
    this.completedExchangeRate,
    this.averageResponseHours,
    this.cancellationRate,
    this.lastActiveAt,
    this.responseRate,
    this.averageSwapTimeHours,
    this.avgCommunicationRating,
    this.avgPunctualityRating,
    this.avgConditionRating,
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
      lastActiveAt: json['lastActiveAt'] != null ? DateTime.parse(json['lastActiveAt'] as String) : null,
      responseRate: (json['responseRate'] as num?)?.toDouble(),
      averageSwapTimeHours: (json['averageSwapTimeHours'] as num?)?.toDouble(),
      avgCommunicationRating: (json['avgCommunicationRating'] as num?)?.toDouble(),
      avgPunctualityRating: (json['avgPunctualityRating'] as num?)?.toDouble(),
      avgConditionRating: (json['avgConditionRating'] as num?)?.toDouble(),
    );
  }
}

/// XP & Levels + Reading Streak - vezi getGamificationStats în
/// backend/src/profile/profile.service.ts pentru formula de nivel.
class GamificationStats {
  final int xp;
  final int level;
  final int xpToNextLevel;
  final int currentStreakDays;
  final int longestStreakDays;

  const GamificationStats({
    required this.xp,
    required this.level,
    required this.xpToNextLevel,
    required this.currentStreakDays,
    required this.longestStreakDays,
  });

  factory GamificationStats.fromJson(Map<String, dynamic> json) {
    return GamificationStats(
      xp: json['xp'] as int,
      level: json['level'] as int,
      xpToNextLevel: json['xpToNextLevel'] as int,
      currentStreakDays: json['currentStreakDays'] as int,
      longestStreakDays: json['longestStreakDays'] as int,
    );
  }
}

class MonthlyChallenge {
  final String key;
  final String label;
  final int progress;
  final int goal;
  final bool completed;

  const MonthlyChallenge({
    required this.key,
    required this.label,
    required this.progress,
    required this.goal,
    required this.completed,
  });

  factory MonthlyChallenge.fromJson(Map<String, dynamic> json) {
    return MonthlyChallenge(
      key: json['key'] as String,
      label: json['label'] as String,
      progress: json['progress'] as int,
      goal: json['goal'] as int,
      completed: json['completed'] as bool,
    );
  }
}

class ReadingChallenge {
  final int year;
  final int? goal;
  final int progress;

  const ReadingChallenge({required this.year, this.goal, required this.progress});

  factory ReadingChallenge.fromJson(Map<String, dynamic> json) {
    return ReadingChallenge(
      year: json['year'] as int,
      goal: json['goal'] as int?,
      progress: json['progress'] as int,
    );
  }
}

class ActivityEvent {
  final String type;
  final String userId;
  final String? userName;
  final String bookTitle;
  final String? bookCoverUrl;
  final DateTime date;

  const ActivityEvent({
    required this.type,
    required this.userId,
    this.userName,
    required this.bookTitle,
    this.bookCoverUrl,
    required this.date,
  });

  factory ActivityEvent.fromJson(Map<String, dynamic> json) {
    return ActivityEvent(
      type: json['type'] as String,
      userId: json['userId'] as String,
      userName: json['userName'] as String?,
      bookTitle: json['bookTitle'] as String,
      bookCoverUrl: json['bookCoverUrl'] as String?,
      date: DateTime.parse(json['date'] as String),
    );
  }
}

/// "Impact" - Money Saved / Total Value of Books Exchanged / Estimated CO2
/// Saved, calculate din `Book.referencePrice` acolo unde există - vezi
/// getImpactStats în backend/src/profile/profile.service.ts pentru formula
/// exactă și limitările ei (cărțile fără preț de referință nu contribuie
/// la Money Saved).
class ImpactStats {
  final double totalValueExchanged;
  final double moneySaved;
  final double co2SavedKg;

  const ImpactStats({
    required this.totalValueExchanged,
    required this.moneySaved,
    required this.co2SavedKg,
  });

  factory ImpactStats.fromJson(Map<String, dynamic> json) {
    return ImpactStats(
      totalValueExchanged: (json['totalValueExchanged'] as num).toDouble(),
      moneySaved: (json['moneySaved'] as num).toDouble(),
      co2SavedKg: (json['co2SavedKg'] as num).toDouble(),
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

class TopReaderEntry {
  final String id;
  final String? name;
  final String? city;
  final String? profileImage;
  final int totalPages;

  const TopReaderEntry({
    required this.id,
    this.name,
    this.city,
    this.profileImage,
    required this.totalPages,
  });

  factory TopReaderEntry.fromJson(Map<String, dynamic> json) {
    return TopReaderEntry(
      id: json['id'] as String,
      name: json['name'] as String?,
      city: json['city'] as String?,
      profileImage: json['profileImage'] as String?,
      totalPages: json['totalPages'] as int,
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
  final String? longestBookTitle;
  final int? longestBookPages;

  const ReadingStats({
    required this.totalListed,
    required this.totalPages,
    this.favoriteGenre,
    this.topGenres = const [],
    this.longestBookTitle,
    this.longestBookPages,
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
      longestBookTitle: json['longestBookTitle'] as String?,
      longestBookPages: json['longestBookPages'] as int?,
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
  final int? booksSharedCount;
  final int? booksReceivedCount;
  final DateTime? memberSince;
  final List<UserBook>? listedBooks;
  final int? listingsCount;
  final List<AcquisitionHistoryEntry>? acquisitionHistory;
  final TrustScore? trustScore;
  final List<Review>? reviews;
  final ReadingStats? readingStats;
  final List<Achievement>? achievements;
  final ImpactStats? impactStats;
  final Bookshelf? bookshelf;
  final GamificationStats? gamification;

  const PublicUser({
    required this.id,
    this.name,
    this.username,
    this.city,
    this.profileImage,
    this.rating = 0,
    this.bio,
    this.booksExchangedCount,
    this.booksSharedCount,
    this.booksReceivedCount,
    this.memberSince,
    this.listedBooks,
    this.listingsCount,
    this.acquisitionHistory,
    this.trustScore,
    this.reviews,
    this.readingStats,
    this.achievements,
    this.impactStats,
    this.bookshelf,
    this.gamification,
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
      booksSharedCount: json['booksSharedCount'] as int?,
      booksReceivedCount: json['booksReceivedCount'] as int?,
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
      impactStats: json['impactStats'] != null
          ? ImpactStats.fromJson(json['impactStats'] as Map<String, dynamic>)
          : null,
      bookshelf: json['bookshelf'] != null
          ? Bookshelf.fromJson(json['bookshelf'] as Map<String, dynamic>)
          : null,
      gamification: json['gamification'] != null
          ? GamificationStats.fromJson(json['gamification'] as Map<String, dynamic>)
          : null,
    );
  }
}
