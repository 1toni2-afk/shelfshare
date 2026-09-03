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

class StatsSnapshotPoint {
  final DateTime date;
  final int totalUsers;
  final int totalBooks;
  final int totalExchanges;

  const StatsSnapshotPoint({
    required this.date,
    required this.totalUsers,
    required this.totalBooks,
    required this.totalExchanges,
  });

  factory StatsSnapshotPoint.fromJson(Map<String, dynamic> json) {
    return StatsSnapshotPoint(
      date: DateTime.parse(json['date'] as String),
      totalUsers: json['totalUsers'] as int,
      totalBooks: json['totalBooks'] as int,
      totalExchanges: json['totalExchanges'] as int,
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

/// Un oraș pe heat map-ul din panoul de admin, cu cele trei măsuri pe care le
/// putem atribui unui oraș: câți useri au orașul în profil, câte anunțuri
/// active au ei și câte cereri de schimb au pornit de acolo.
class HeatmapZone {
  final String city;
  final int users;
  final int listings;
  final int exchanges;
  final double lat;
  final double lng;

  const HeatmapZone({
    required this.city,
    required this.users,
    required this.listings,
    required this.exchanges,
    required this.lat,
    required this.lng,
  });

  int valueFor(HeatmapMetric metric) => switch (metric) {
        HeatmapMetric.users => users,
        HeatmapMetric.listings => listings,
        HeatmapMetric.exchanges => exchanges,
      };

  factory HeatmapZone.fromJson(Map<String, dynamic> json) {
    return HeatmapZone(
      city: json['city'] as String,
      users: (json['users'] as num?)?.toInt() ?? 0,
      listings: (json['listings'] as num?)?.toInt() ?? 0,
      exchanges: (json['exchanges'] as num?)?.toInt() ?? 0,
      lat: (json['lat'] as num).toDouble(),
      lng: (json['lng'] as num).toDouble(),
    );
  }
}

enum HeatmapMetric { users, listings, exchanges }

/// O zi din seria de folosire a aplicației. `activeUsers` și `actions` vin din
/// jurnalul de activitate (fișiere), restul din baza de date - vezi
/// AdminService.getUsageStats.
class UsageDay {
  final String date;
  final int activeUsers;
  final int actions;
  final int newUsers;
  final int listings;
  final int swipes;
  final int searches;
  final int messages;
  final int offers;
  final int exchanges;

  const UsageDay({
    required this.date,
    required this.activeUsers,
    required this.actions,
    required this.newUsers,
    required this.listings,
    required this.swipes,
    required this.searches,
    required this.messages,
    required this.offers,
    required this.exchanges,
  });

  int valueFor(UsageSeries series) => switch (series) {
        UsageSeries.activeUsers => activeUsers,
        UsageSeries.actions => actions,
        UsageSeries.newUsers => newUsers,
        UsageSeries.listings => listings,
        UsageSeries.swipes => swipes,
        UsageSeries.searches => searches,
        UsageSeries.messages => messages,
        UsageSeries.offers => offers,
        UsageSeries.exchanges => exchanges,
      };

  factory UsageDay.fromJson(Map<String, dynamic> json) {
    int at(String key) => (json[key] as num?)?.toInt() ?? 0;
    return UsageDay(
      date: json['date'] as String,
      activeUsers: at('activeUsers'),
      actions: at('actions'),
      newUsers: at('newUsers'),
      listings: at('listings'),
      swipes: at('swipes'),
      searches: at('searches'),
      messages: at('messages'),
      offers: at('offers'),
      exchanges: at('exchanges'),
    );
  }
}

enum UsageSeries {
  activeUsers,
  actions,
  newUsers,
  listings,
  swipes,
  searches,
  messages,
  offers,
  exchanges,
}

class UsageActionCount {
  final String action;
  final int count;

  const UsageActionCount({required this.action, required this.count});

  factory UsageActionCount.fromJson(Map<String, dynamic> json) {
    return UsageActionCount(
      action: json['action'] as String,
      count: (json['count'] as num).toInt(),
    );
  }
}

/// Câți useri au folosit măcar o dată fiecare funcție - praguri independente,
/// nu o pâlnie (vezi [ConversionFunnel] pentru pâlnie).
class UsageAdoption {
  final int totalUsers;
  final int withListing;
  final int withSwipe;
  final int withWishlist;
  final int withShelf;
  final int withMessage;

  const UsageAdoption({
    required this.totalUsers,
    required this.withListing,
    required this.withSwipe,
    required this.withWishlist,
    required this.withShelf,
    required this.withMessage,
  });

  factory UsageAdoption.fromJson(Map<String, dynamic> json) {
    int at(String key) => (json[key] as num?)?.toInt() ?? 0;
    return UsageAdoption(
      totalUsers: at('totalUsers'),
      withListing: at('withListing'),
      withSwipe: at('withSwipe'),
      withWishlist: at('withWishlist'),
      withShelf: at('withShelf'),
      withMessage: at('withMessage'),
    );
  }
}

class UsageStats {
  final List<UsageDay> days;
  final List<UsageActionCount> byAction;

  /// Fals când nu există niciun fișier de jurnal în fereastra cerută - altfel
  /// „0 useri activi" s-ar citi ca „nimeni n-a folosit aplicația", nu ca
  /// „n-avem de unde ști".
  final bool logAvailable;
  final Map<String, int> totals;
  final UsageAdoption adoption;

  const UsageStats({
    required this.days,
    required this.byAction,
    required this.logAvailable,
    required this.totals,
    required this.adoption,
  });

  factory UsageStats.fromJson(Map<String, dynamic> json) {
    return UsageStats(
      days: (json['days'] as List? ?? const [])
          .map((e) => UsageDay.fromJson(e as Map<String, dynamic>))
          .toList(),
      byAction: (json['byAction'] as List? ?? const [])
          .map((e) => UsageActionCount.fromJson(e as Map<String, dynamic>))
          .toList(),
      logAvailable: json['logAvailable'] == true,
      totals: {
        for (final entry in (json['totals'] as Map? ?? const {}).entries)
          entry.key as String: (entry.value as num?)?.toInt() ?? 0,
      },
      adoption: UsageAdoption.fromJson(
        (json['adoption'] as Map? ?? const {}).cast<String, dynamic>(),
      ),
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
  final bool isPremium;
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
    this.isPremium = false,
    required this.rating,
    required this.booksExchangedCount,
    required this.createdAt,
  });

  AdminUser copyWith({bool? isBanned, bool? isPremium}) {
    return AdminUser(
      id: id,
      email: email,
      name: name,
      city: city,
      isEmailVerified: isEmailVerified,
      isBanned: isBanned ?? this.isBanned,
      isAdmin: isAdmin,
      isPremium: isPremium ?? this.isPremium,
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
      isPremium: json['isPremium'] as bool? ?? false,
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

/// Ce anume s-a raportat. Vine ca `targetType` de pe backend, unde e stocat
/// pe langa cheile straine tipate - vezi ReportTargetType in schema.prisma.
/// Panoul de moderare filtreaza dupa el, ca sa fie un singur panou pentru
/// toate tipurile, nu cate unul per tip.
enum ReportTargetType { user, listing, review, conversation, groupPost, exchange }

extension ReportTargetTypeX on ReportTargetType {
  static ReportTargetType fromJson(String value) {
    switch (value) {
      case 'LISTING':
        return ReportTargetType.listing;
      case 'REVIEW':
        return ReportTargetType.review;
      case 'CONVERSATION':
        return ReportTargetType.conversation;
      case 'GROUP_POST':
        return ReportTargetType.groupPost;
      case 'EXCHANGE':
        return ReportTargetType.exchange;
      case 'USER':
      default:
        return ReportTargetType.user;
    }
  }

  String toJson() {
    switch (this) {
      case ReportTargetType.user:
        return 'USER';
      case ReportTargetType.listing:
        return 'LISTING';
      case ReportTargetType.review:
        return 'REVIEW';
      case ReportTargetType.conversation:
        return 'CONVERSATION';
      case ReportTargetType.groupPost:
        return 'GROUP_POST';
      case ReportTargetType.exchange:
        return 'EXCHANGE';
    }
  }

  /// Doar continutul poate fi ascuns automat (vezi AUTO_HIDEABLE_TARGETS pe
  /// backend) - deci doar acolo are sens actiunea de repunere.
  bool get isHideable =>
      this == ReportTargetType.listing ||
      this == ReportTargetType.review ||
      this == ReportTargetType.groupPost;
}

enum ReportStatus { open, inProgress, resolved, dismissed }

extension ReportStatusX on ReportStatus {
  static ReportStatus fromJson(String value) {
    switch (value) {
      case 'IN_PROGRESS':
        return ReportStatus.inProgress;
      case 'RESOLVED':
        return ReportStatus.resolved;
      case 'DISMISSED':
        return ReportStatus.dismissed;
      case 'OPEN':
      default:
        return ReportStatus.open;
    }
  }

  String toJson() {
    switch (this) {
      case ReportStatus.open:
        return 'OPEN';
      case ReportStatus.inProgress:
        return 'IN_PROGRESS';
      case ReportStatus.resolved:
        return 'RESOLVED';
      case ReportStatus.dismissed:
        return 'DISMISSED';
    }
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
  final ReportStatus status;
  final String? assignedToEmail;
  final String? assignedToName;
  final String? resolutionNote;
  final DateTime? resolvedAt;
  final String? groupPostId;
  final String? groupPostContent;
  final String? reviewId;
  final String? reviewText;
  final int? reviewRating;

  final ReportTargetType targetType;

  /// Anuntul raportat, cand tinta e un anunt.
  final String? userBookId;
  final String? userBookTitle;

  /// Setat cand continutul a fost deja ascuns automat de praguri (vezi
  /// ReportsService.applyAutoHide). Moderatorul trebuie sa vada asta: altfel
  /// n-ar sti daca mai are ceva de facut sau doar de confirmat.
  final DateTime? contentHiddenAt;

  const UserReport({
    required this.id,
    required this.reason,
    this.details,
    required this.reporterEmail,
    this.reporterName,
    required this.reportedEmail,
    this.reportedName,
    required this.createdAt,
    this.status = ReportStatus.open,
    this.assignedToEmail,
    this.assignedToName,
    this.resolutionNote,
    this.resolvedAt,
    this.groupPostId,
    this.groupPostContent,
    this.reviewId,
    this.reviewText,
    this.reviewRating,
    this.targetType = ReportTargetType.user,
    this.userBookId,
    this.userBookTitle,
    this.contentHiddenAt,
  });

  factory UserReport.fromJson(Map<String, dynamic> json) {
    final reporter = json['reporter'] as Map<String, dynamic>;
    final reportedUser = json['reportedUser'] as Map<String, dynamic>;
    final assignedTo = json['assignedTo'] as Map<String, dynamic>?;
    final groupPost = json['groupPost'] as Map<String, dynamic>?;
    final review = json['review'] as Map<String, dynamic>?;
    final userBook = json['userBook'] as Map<String, dynamic>?;
    return UserReport(
      id: json['id'] as String,
      reason: json['reason'] as String,
      details: json['details'] as String?,
      reporterEmail: reporter['email'] as String,
      reporterName: reporter['name'] as String?,
      reportedEmail: reportedUser['email'] as String,
      reportedName: reportedUser['name'] as String?,
      createdAt: DateTime.parse(json['createdAt'] as String),
      status: ReportStatusX.fromJson(json['status'] as String? ?? 'OPEN'),
      assignedToEmail: assignedTo?['email'] as String?,
      assignedToName: assignedTo?['name'] as String?,
      resolutionNote: json['resolutionNote'] as String?,
      resolvedAt: json['resolvedAt'] != null ? DateTime.parse(json['resolvedAt'] as String) : null,
      groupPostId: groupPost?['id'] as String?,
      groupPostContent: groupPost?['content'] as String?,
      reviewId: review?['id'] as String?,
      reviewText: review?['text'] as String?,
      reviewRating: review?['rating'] as int?,
      targetType:
          ReportTargetTypeX.fromJson(json['targetType'] as String? ?? 'USER'),
      userBookId: userBook?['id'] as String?,
      userBookTitle:
          (userBook?['book'] as Map<String, dynamic>?)?['title'] as String?,
      // `hiddenAt` vine de pe tinta, nu de pe raport - de pe oricare din cele
      // doua tipuri de continut incluse in raspuns.
      contentHiddenAt: _parseHiddenAt(groupPost) ?? _parseHiddenAt(review),
    );
  }

  static DateTime? _parseHiddenAt(Map<String, dynamic>? target) {
    final value = target?['hiddenAt'];
    return value is String ? DateTime.tryParse(value) : null;
  }

  UserReport copyWith({
    ReportStatus? status,
    String? assignedToEmail,
    String? assignedToName,
    String? resolutionNote,
    DateTime? resolvedAt,
  }) {
    return UserReport(
      id: id,
      reason: reason,
      details: details,
      reporterEmail: reporterEmail,
      reporterName: reporterName,
      reportedEmail: reportedEmail,
      reportedName: reportedName,
      createdAt: createdAt,
      status: status ?? this.status,
      assignedToEmail: assignedToEmail ?? this.assignedToEmail,
      assignedToName: assignedToName ?? this.assignedToName,
      resolutionNote: resolutionNote ?? this.resolutionNote,
      resolvedAt: resolvedAt ?? this.resolvedAt,
      groupPostId: groupPostId,
      groupPostContent: groupPostContent,
      reviewId: reviewId,
      reviewText: reviewText,
      reviewRating: reviewRating,
      targetType: targetType,
      userBookId: userBookId,
      userBookTitle: userBookTitle,
      contentHiddenAt: contentHiddenAt,
    );
  }
}

class FeedbackItem {
  final String id;
  final String message;
  final String? photoUrl;
  final String userEmail;
  final String? userName;
  final DateTime createdAt;

  const FeedbackItem({
    required this.id,
    required this.message,
    this.photoUrl,
    required this.userEmail,
    this.userName,
    required this.createdAt,
  });

  factory FeedbackItem.fromJson(Map<String, dynamic> json) {
    final user = json['user'] as Map<String, dynamic>;
    return FeedbackItem(
      id: json['id'] as String,
      message: json['message'] as String,
      photoUrl: json['photoUrl'] as String?,
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

/// Cheile de acces la funcții încă în rulare, acordat per user din panoul de
/// admin. Trebuie să rămână identice cu FEATURE_FLAG_KEYS din backend
/// (common/constants/feature-flags.ts) - o funcție nouă înseamnă o intrare
/// aici, plus o etichetă în [featureFlagLabel].
const kFeatureFlagKeys = <String>['advanced_statistics'];

class FeatureFlagValue {
  final String key;
  final bool enabled;

  const FeatureFlagValue({required this.key, required this.enabled});

  FeatureFlagValue copyWith({bool? enabled}) =>
      FeatureFlagValue(key: key, enabled: enabled ?? this.enabled);

  factory FeatureFlagValue.fromJson(Map<String, dynamic> json) {
    return FeatureFlagValue(
      key: json['key'] as String,
      enabled: json['enabled'] as bool,
    );
  }

  Map<String, dynamic> toJson() => {'key': key, 'enabled': enabled};
}

/// Breakdown-ul scorului de interes al unui anunț - vezi
/// backend/src/books/listing-score.service.ts. Nu e vizibil userilor
/// normali, doar din acest panou de admin.
class ListingScoreBreakdown {
  final String userBookId;
  final String bookTitle;
  final String? bookAuthor;
  final Map<String, int> counts;
  final double popularityScore;
  final double exchangePotentialScore;
  final double? manualScoreOverride;

  const ListingScoreBreakdown({
    required this.userBookId,
    required this.bookTitle,
    this.bookAuthor,
    required this.counts,
    required this.popularityScore,
    required this.exchangePotentialScore,
    this.manualScoreOverride,
  });

  factory ListingScoreBreakdown.fromJson(Map<String, dynamic> json) {
    final book = json['book'] as Map<String, dynamic>;
    final counts = json['counts'] as Map<String, dynamic>;
    return ListingScoreBreakdown(
      userBookId: json['userBookId'] as String,
      bookTitle: book['title'] as String,
      bookAuthor: book['author'] as String?,
      counts: counts.map((key, value) => MapEntry(key, value as int)),
      popularityScore: (json['popularityScore'] as num).toDouble(),
      exchangePotentialScore: (json['exchangePotentialScore'] as num).toDouble(),
      manualScoreOverride: (json['manualScoreOverride'] as num?)?.toDouble(),
    );
  }
}

/// Catalogul de permisiuni granulare (Admin Control Panel, Milestone 19) -
/// trebuie să rămână identic cu ADMIN_PERMISSION_KEYS din backend
/// (admin/constants/admin-permissions.ts).
const kAdminPermissionKeys = <String>[
  'users.view',
  'users.edit',
  'users.suspend',
  'users.ban',
  'users.delete',
  'books.view',
  'books.edit',
  'books.hide',
  'books.delete',
  'reports.view',
  'reports.resolve',
  'reports.dismiss',
  'exchanges.view',
  'exchanges.manage',
  'admins.view',
  'admins.create',
  'admins.edit',
  'admins.delete',
  'moderation.approve',
  'moderation.review',
];

class AdminRole {
  final String id;
  final String name;
  final String label;
  final List<String> permissions;

  const AdminRole({
    required this.id,
    required this.name,
    required this.label,
    required this.permissions,
  });

  bool get isCustom => name == 'CUSTOM';

  factory AdminRole.fromJson(Map<String, dynamic> json) {
    return AdminRole(
      id: json['id'] as String,
      name: json['name'] as String,
      label: json['label'] as String,
      permissions: (json['permissions'] as List).map((e) => e as String).toList(),
    );
  }
}

class AdminRolesPage {
  final List<AdminRole> roles;
  final List<String> permissionKeys;

  const AdminRolesPage({required this.roles, required this.permissionKeys});

  factory AdminRolesPage.fromJson(Map<String, dynamic> json) {
    return AdminRolesPage(
      roles: (json['roles'] as List)
          .map((e) => AdminRole.fromJson(e as Map<String, dynamic>))
          .toList(),
      permissionKeys: (json['permissionKeys'] as List).map((e) => e as String).toList(),
    );
  }
}

class Administrator {
  final String id;
  final String email;
  final String? name;
  final String? username;
  final AdminRole? adminRole;

  const Administrator({
    required this.id,
    required this.email,
    this.name,
    this.username,
    this.adminRole,
  });

  factory Administrator.fromJson(Map<String, dynamic> json) {
    final role = json['adminRole'] as Map<String, dynamic>?;
    return Administrator(
      id: json['id'] as String,
      email: json['email'] as String,
      name: json['name'] as String?,
      username: json['username'] as String?,
      adminRole: role != null ? AdminRole.fromJson(role) : null,
    );
  }
}

/// Feature backlog #19: pre-înscriere -> onboarding -> primul anunț -> primul
/// schimb finalizat. Numere brute per treaptă, nu neapărat un subset strict
/// unele-din-altele (un user poate lista o carte fără să fi "completat"
/// formal onboarding-ul, de exemplu).
class ConversionFunnel {
  final int preRegistrations;
  final int registeredUsers;
  final int onboardedUsers;
  final int listedUsers;
  final int exchangedUsers;

  const ConversionFunnel({
    required this.preRegistrations,
    required this.registeredUsers,
    required this.onboardedUsers,
    required this.listedUsers,
    required this.exchangedUsers,
  });

  factory ConversionFunnel.fromJson(Map<String, dynamic> json) {
    return ConversionFunnel(
      preRegistrations: json['preRegistrations'] as int,
      registeredUsers: json['registeredUsers'] as int,
      onboardedUsers: json['onboardedUsers'] as int,
      listedUsers: json['listedUsers'] as int,
      exchangedUsers: json['exchangedUsers'] as int,
    );
  }
}

class UserFeatureFlags {
  final String userId;
  final String email;
  final String? name;
  final List<FeatureFlagValue> flags;

  const UserFeatureFlags({
    required this.userId,
    required this.email,
    this.name,
    required this.flags,
  });

  factory UserFeatureFlags.fromJson(Map<String, dynamic> json) {
    final user = json['user'] as Map<String, dynamic>;
    return UserFeatureFlags(
      userId: user['id'] as String,
      email: user['email'] as String,
      name: user['name'] as String?,
      flags: (json['flags'] as List)
          .map((e) => FeatureFlagValue.fromJson(e as Map<String, dynamic>))
          .toList(),
    );
  }
}

/// Un contor din coada de moderare: câte rapoarte are o combinație anume de
/// (tip de țintă, status). Panoul le agregă pentru etichetele filtrelor.
class ReportCount {
  final ReportTargetType targetType;
  final ReportStatus status;
  final int count;

  const ReportCount({
    required this.targetType,
    required this.status,
    required this.count,
  });

  factory ReportCount.fromJson(Map<String, dynamic> json) {
    return ReportCount(
      targetType: ReportTargetTypeX.fromJson(json['targetType'] as String),
      status: ReportStatusX.fromJson(json['status'] as String),
      count: (json['count'] as num).toInt(),
    );
  }
}
