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

  /// Ziua de naștere, doar zi + lună (fără an) - folosită pentru mesajul
  /// „La mulți ani" din salutul paginii principale. Vine doar pe profilul
  /// propriu, nu și pe cel public.
  final int? birthdayDay;
  final int? birthdayMonth;

  /// Limbile în care userul citește. Doar informativ pe cardul „Despre" din
  /// profilul lateral. Default „Română" pe backend, deci lista nu e niciodată
  /// null - dar poate fi goală dacă userul le-a șters explicit.
  final List<String> languages;

  final String? profileImage;
  final double rating;
  final int booksExchangedCount;
  final int booksSharedCount;
  final int booksReceivedCount;
  final bool isEmailVerified;
  final bool isAdmin;
  final bool isPremium;
  final bool showAcquisitionHistory;

  /// Preferință per-admin: badge de scor pe TOATE cardurile de carte, nu
  /// doar pe top 256. Fără efect pentru non-admini (backend-ul nu întoarce
  /// niciodată scoruri pentru ei, indiferent de acest flag) - vezi
  /// listing_score_cache.dart.
  final bool showAllListingScores;

  final String? referralCode;
  final int referralCount;

  /// Când s-a înregistrat contul. Folosit pentru cardul „Membru din" din
  /// coloana laterală a profilului. Vine ca ISO de la backend.
  final DateTime? createdAt;

  final TrustScore? trustScore;
  final List<Achievement>? achievements;
  final ImpactStats? impactStats;

  /// Statistici derivate din biblioteca proprie (top genuri, total pagini,
  /// cea mai lungă carte). Milestone 17 le folosește pe cardul „Top genuri"
  /// din coloana laterală a profilului propriu.
  final ReadingStats? readingStats;

  final GamificationStats? gamification;
  /// Setat dacă userul a cerut ștergerea contului - contul se șterge efectiv
  /// la această dată dacă nu anulează între timp. Vezi AccountDeletionService.
  final DateTime? deletionScheduledAt;

  /// Profilul de cititor (chestionarul de la primul login).
  /// `readingSurveyCompletedAt` e setat și când userul a sărit peste el, ca
  /// să nu îl mai întrebăm - vezi redirect-ul din app_router.dart.
  final List<String> favoriteGenres;
  final List<String> favoriteAuthors;
  final String? readingPace;
  final DateTime? readingSurveyCompletedAt;

  /// Scopul declarat la onboarding (swap/sell/discover/all) - doar informativ.
  final String? onboardingPurpose;

  const AppUser({
    required this.id,
    required this.email,
    this.name,
    this.username,
    this.nameVisible = true,
    this.city,
    this.bio,
    this.birthdayDay,
    this.birthdayMonth,
    this.languages = const ['Română'],
    this.profileImage,
    this.rating = 0,
    this.booksExchangedCount = 0,
    this.booksSharedCount = 0,
    this.booksReceivedCount = 0,
    this.isEmailVerified = false,
    this.isAdmin = false,
    this.isPremium = false,
    this.showAcquisitionHistory = false,
    this.showAllListingScores = false,
    this.referralCode,
    this.referralCount = 0,
    this.createdAt,
    this.trustScore,
    this.achievements,
    this.impactStats,
    this.readingStats,
    this.gamification,
    this.deletionScheduledAt,
    this.favoriteGenres = const [],
    this.favoriteAuthors = const [],
    this.readingPace,
    this.readingSurveyCompletedAt,
    this.onboardingPurpose,
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
      birthdayDay: json['birthdayDay'] as int?,
      birthdayMonth: json['birthdayMonth'] as int?,
      languages: (json['languages'] as List<dynamic>? ?? const ['Română'])
          .map((e) => e as String)
          .toList(),
      profileImage: json['profileImage'] as String?,
      rating: (json['rating'] as num?)?.toDouble() ?? 0,
      booksExchangedCount: json['booksExchangedCount'] as int? ?? 0,
      booksSharedCount: json['booksSharedCount'] as int? ?? 0,
      booksReceivedCount: json['booksReceivedCount'] as int? ?? 0,
      isEmailVerified: json['isEmailVerified'] as bool? ?? false,
      isAdmin: json['isAdmin'] as bool? ?? false,
      isPremium: json['isPremium'] as bool? ?? false,
      showAcquisitionHistory: json['showAcquisitionHistory'] as bool? ?? false,
      showAllListingScores: json['showAllListingScores'] as bool? ?? false,
      referralCode: json['referralCode'] as String?,
      referralCount: json['referralCount'] as int? ?? 0,
      createdAt: json['createdAt'] != null
          ? DateTime.parse(json['createdAt'] as String)
          : null,
      trustScore: json['trustScore'] != null
          ? TrustScore.fromJson(json['trustScore'] as Map<String, dynamic>)
          : null,
      achievements: (json['achievements'] as List<dynamic>?)
          ?.map((e) => Achievement.fromJson(e as Map<String, dynamic>))
          .toList(),
      impactStats: json['impactStats'] != null
          ? ImpactStats.fromJson(json['impactStats'] as Map<String, dynamic>)
          : null,
      readingStats: json['readingStats'] != null
          ? ReadingStats.fromJson(json['readingStats'] as Map<String, dynamic>)
          : null,
      gamification: json['gamification'] != null
          ? GamificationStats.fromJson(json['gamification'] as Map<String, dynamic>)
          : null,
      deletionScheduledAt: json['deletionScheduledAt'] != null
          ? DateTime.parse(json['deletionScheduledAt'] as String)
          : null,
      favoriteGenres:
          (json['favoriteGenres'] as List<dynamic>?)?.cast<String>() ?? const [],
      favoriteAuthors:
          (json['favoriteAuthors'] as List<dynamic>?)?.cast<String>() ?? const [],
      readingPace: json['readingPace'] as String?,
      readingSurveyCompletedAt: json['readingSurveyCompletedAt'] != null
          ? DateTime.parse(json['readingSurveyCompletedAt'] as String)
          : null,
      onboardingPurpose: json['onboardingPurpose'] as String?,
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
class TopListingViews {
  final String title;
  final int views;

  const TopListingViews({required this.title, required this.views});

  factory TopListingViews.fromJson(Map<String, dynamic> json) {
    return TopListingViews(title: json['title'] as String, views: json['views'] as int);
  }
}

/// "Advanced Analytics" (Premium) - statistici de vânzător calculate din date deja existente.
class SellerAnalytics {
  final int totalListings;
  final int totalViews;
  final int totalOffersReceived;
  final int acceptedOffersCount;
  final double conversionRate;
  final double totalRevenue;
  final List<TopListingViews> topListingsByViews;

  const SellerAnalytics({
    required this.totalListings,
    required this.totalViews,
    required this.totalOffersReceived,
    required this.acceptedOffersCount,
    required this.conversionRate,
    required this.totalRevenue,
    required this.topListingsByViews,
  });

  factory SellerAnalytics.fromJson(Map<String, dynamic> json) {
    return SellerAnalytics(
      totalListings: json['totalListings'] as int,
      totalViews: json['totalViews'] as int,
      totalOffersReceived: json['totalOffersReceived'] as int,
      acceptedOffersCount: json['acceptedOffersCount'] as int,
      conversionRate: (json['conversionRate'] as num).toDouble(),
      totalRevenue: (json['totalRevenue'] as num).toDouble(),
      topListingsByViews: (json['topListingsByViews'] as List)
          .map((e) => TopListingViews.fromJson(e as Map<String, dynamic>))
          .toList(),
    );
  }
}

class GamificationStats {
  final int xp;
  final int level;
  final int xpToNextLevel;
  final int currentStreakDays;
  final int longestStreakDays;

  /// Cât XP costă un nivel. Nu există nivel maxim - curba e liniară.
  final int xpPerLevel;

  /// Cât XP dă fiecare acțiune, cheie → valoare, exact cum îl calculează
  /// backend-ul (`XP_REWARDS` din common/utils/xp.ts). Vine de la server ca să
  /// nu ținem o copie a valorilor în Dart, care s-ar desincroniza.
  final Map<String, int> xpRewards;

  const GamificationStats({
    required this.xp,
    required this.level,
    required this.xpToNextLevel,
    required this.currentStreakDays,
    required this.longestStreakDays,
    this.xpPerLevel = 100,
    this.xpRewards = const {},
  });

  factory GamificationStats.fromJson(Map<String, dynamic> json) {
    return GamificationStats(
      xp: json['xp'] as int,
      level: json['level'] as int,
      xpToNextLevel: json['xpToNextLevel'] as int,
      currentStreakDays: json['currentStreakDays'] as int,
      longestStreakDays: json['longestStreakDays'] as int,
      xpPerLevel: json['xpPerLevel'] as int? ?? 100,
      xpRewards: (json['xpRewards'] as Map<String, dynamic>? ?? const {})
          .map((key, value) => MapEntry(key, value as int)),
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
  final String? userAvatar;
  final String bookTitle;
  final String? bookAuthor;
  final String? bookCoverUrl;
  final String? genre;
  final String? caption;
  final DateTime date;
  final double? amount;

  // Doar pentru type == 'completed_exchange', la un schimb carte-contra-carte.
  final String? offeredBookTitle;
  final String? offeredBookCoverUrl;
  final String? counterpartyName;

  // Doar pentru type == 'reading_progress'.
  final int? currentPage;
  final int? totalPages;

  const ActivityEvent({
    required this.type,
    required this.userId,
    this.userName,
    this.userAvatar,
    required this.bookTitle,
    this.bookAuthor,
    this.bookCoverUrl,
    this.genre,
    this.caption,
    required this.date,
    this.amount,
    this.offeredBookTitle,
    this.offeredBookCoverUrl,
    this.counterpartyName,
    this.currentPage,
    this.totalPages,
  });

  factory ActivityEvent.fromJson(Map<String, dynamic> json) {
    return ActivityEvent(
      type: json['type'] as String,
      userId: json['userId'] as String,
      userName: json['userName'] as String?,
      userAvatar: json['userAvatar'] as String?,
      bookTitle: json['bookTitle'] as String,
      bookAuthor: json['bookAuthor'] as String?,
      bookCoverUrl: json['bookCoverUrl'] as String?,
      genre: json['genre'] as String?,
      caption: json['caption'] as String?,
      date: DateTime.parse(json['date'] as String),
      amount: (json['amount'] as num?)?.toDouble(),
      offeredBookTitle: json['offeredBookTitle'] as String?,
      offeredBookCoverUrl: json['offeredBookCoverUrl'] as String?,
      counterpartyName: json['counterpartyName'] as String?,
      currentPage: json['currentPage'] as int?,
      totalPages: json['totalPages'] as int?,
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

/// "People with Similar Taste" - alți useri clasați după numărul de genuri
/// comune cu userul curent (vezi getSimilarTasteUsers în backend).
class SimilarTasteUser {
  final String id;
  final String? name;
  final String? city;
  final String? profileImage;
  final double rating;
  final int sharedGenres;

  const SimilarTasteUser({
    required this.id,
    this.name,
    this.city,
    this.profileImage,
    required this.rating,
    required this.sharedGenres,
  });

  factory SimilarTasteUser.fromJson(Map<String, dynamic> json) {
    return SimilarTasteUser(
      id: json['id'] as String,
      name: json['name'] as String?,
      city: json['city'] as String?,
      profileImage: json['profileImage'] as String?,
      rating: (json['rating'] as num).toDouble(),
      sharedGenres: json['sharedGenres'] as int,
    );
  }
}

/// O carte dintr-un match de "Smart Swap" - suficient pentru a o afișa
/// (fără toate detaliile complete ale unui UserBook).
class SmartMatchBook {
  final String userBookId;
  final String title;
  final String? coverUrl;

  const SmartMatchBook({required this.userBookId, required this.title, this.coverUrl});

  factory SmartMatchBook.fromJson(Map<String, dynamic> json) {
    return SmartMatchBook(
      userBookId: json['userBookId'] as String,
      title: json['title'] as String,
      coverUrl: json['coverUrl'] as String?,
    );
  }
}

/// "Smart Swap / Auto Match" - dublă coincidență de dorințe cu un alt user:
/// el are ceva de pe wishlist-ul meu, eu am ceva de pe wishlist-ul lui.
class SmartMatch {
  final PublicUser owner;
  final List<SmartMatchBook> theirBooks;
  final List<SmartMatchBook> myBooksTheyWant;

  const SmartMatch({
    required this.owner,
    required this.theirBooks,
    required this.myBooksTheyWant,
  });

  factory SmartMatch.fromJson(Map<String, dynamic> json) {
    return SmartMatch(
      owner: PublicUser.fromJson(json['owner'] as Map<String, dynamic>),
      theirBooks: (json['theirBooks'] as List<dynamic>)
          .map((e) => SmartMatchBook.fromJson(e as Map<String, dynamic>))
          .toList(),
      myBooksTheyWant: (json['myBooksTheyWant'] as List<dynamic>)
          .map((e) => SmartMatchBook.fromJson(e as Map<String, dynamic>))
          .toList(),
    );
  }
}

class AcquisitionHistoryEntry {
  final String? userBookId;
  final String bookTitle;
  final String? bookCoverUrl;
  final DateTime date;
  final String type;

  const AcquisitionHistoryEntry({
    this.userBookId,
    required this.bookTitle,
    this.bookCoverUrl,
    required this.date,
    required this.type,
  });

  factory AcquisitionHistoryEntry.fromJson(Map<String, dynamic> json) {
    return AcquisitionHistoryEntry(
      userBookId: json['userBookId'] as String?,
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
  final bool isPremium;
  final double rating;
  final String? bio;

  /// Limbile în care userul citește - vin doar de pe profilul public complet
  /// (/profile/:userId), nu din relațiile scurte. Gol dacă lipsește.
  final List<String> languages;

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

  /// Prezență în chat - vin doar din endpoint-urile de conversații, nu de pe
  /// profilul public (vezi PARTICIPANT_SELECT în conversations.service.ts).
  final bool isOnline;
  final DateTime? lastSeenAt;

  const PublicUser({
    required this.id,
    this.name,
    this.username,
    this.city,
    this.profileImage,
    this.isPremium = false,
    this.rating = 0,
    this.bio,
    this.languages = const [],
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
    this.isOnline = false,
    this.lastSeenAt,
  });

  PublicUser copyWithPresence({required bool isOnline, DateTime? lastSeenAt}) {
    return PublicUser(
      id: id,
      name: name,
      username: username,
      city: city,
      profileImage: profileImage,
      isPremium: isPremium,
      rating: rating,
      bio: bio,
      languages: languages,
      booksExchangedCount: booksExchangedCount,
      booksSharedCount: booksSharedCount,
      booksReceivedCount: booksReceivedCount,
      memberSince: memberSince,
      listedBooks: listedBooks,
      listingsCount: listingsCount,
      acquisitionHistory: acquisitionHistory,
      trustScore: trustScore,
      reviews: reviews,
      readingStats: readingStats,
      achievements: achievements,
      impactStats: impactStats,
      bookshelf: bookshelf,
      gamification: gamification,
      isOnline: isOnline,
      lastSeenAt: lastSeenAt ?? this.lastSeenAt,
    );
  }

  factory PublicUser.fromJson(Map<String, dynamic> json) {
    return PublicUser(
      id: json['id'] as String,
      name: json['name'] as String?,
      username: json['username'] as String?,
      city: json['city'] as String?,
      profileImage: json['profileImage'] as String?,
      isPremium: json['isPremium'] as bool? ?? false,
      rating: (json['rating'] as num?)?.toDouble() ?? 0,
      bio: json['bio'] as String?,
      languages: (json['languages'] as List<dynamic>? ?? const [])
          .map((e) => e as String)
          .toList(),
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
      isOnline: json['isOnline'] as bool? ?? false,
      lastSeenAt: json['lastSeenAt'] != null
          ? DateTime.parse(json['lastSeenAt'] as String)
          : null,
    );
  }
}
