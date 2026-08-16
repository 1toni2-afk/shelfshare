import 'book.dart';
import 'user.dart';
import 'wishlist_item.dart';

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
  final bool isForSale;
  final double? salePrice;
  final bool isNegotiable;

  /// „Sau vinde cu X lei" setat la listare pe un anunt de tip Schimb.
  /// Anuntul ramane Schimb (isForSale false), dar accepta si oferte in bani -
  /// pe pagina cartii apar doua butoane. Null = doar schimb.
  final double? swapSalePrice;
  final bool isAuction;
  final AuctionCardSummary? auction;
  final bool isPromoted;
  final int viewCount;
  final double? distanceKm;
  final List<String> photos;
  /// URL-ul pozei principale (Batch 8) - afișat cu prioritate în feed/carduri.
  /// Poate fi o intrare din `photos`, o copertă externă sau `book.coverUrl`.
  /// Când e null, se cade pe [primaryImageUrl] care alege pe rând: prima poză,
  /// apoi coperta cărții.
  final String? mainPhotoUrl;
  final DateTime createdAt;
  /// Setat true când un exchange s-a completat pe această listare - carte
  /// „plecată permanent", nu mai poate fi făcută disponibilă. Vezi Milestone 10.
  final bool permanentlyTransferred;
  /// Setat când userul a apăsat delete pe carte - rămâne în coșul de gunoi
  /// 7 zile, iar apoi cron-ul o șterge definitiv.
  final DateTime? deletedAt;
  /// Descriere per exemplar (independent de Book.description care e a operei).
  /// Max 256 caractere pe backend. Milestone 10.
  final String? description;
  /// Tag-uri custom (max 5). Milestone 10.
  final List<String> tags;
  /// Localitatea unde se face schimbul (distinctă de user.city). Milestone 10.
  final String? city;

  /// Câți useri au titlul la favorite (afișat lângă inimă pe pagina anunțului).
  /// Prezent doar în răspunsul de detaliu (/books/:id), null în browse.
  final int? favoriteCount;

  /// Dacă viewer-ul curent are titlul la favorite - sursă de adevăr de la
  /// server, ca inima să fie corectă chiar dacă lista de wishlist a clientului
  /// nu e încărcată. Prezent doar în răspunsul de detaliu; null în browse.
  final bool? isWishlisted;

  /// Dacă titlul e pe wishlist-ul viewer-ului, de unde a ajuns acolo
  /// (manual vs. Book Match) - decide ce iconiță se afișează în locul inimii.
  /// null când nu e pe wishlist sau în răspunsurile care nu-l trimit (browse).
  final WishlistSource? wishlistSource;

  /// Scorul intern de interes pe 14 zile care ordonează secțiunea „Cele mai
  /// căutate" (view unic 3p, refresh 0.1p, favorite 1p, fiecare punct
  /// expirând individual). Backendul îl trimite DOAR adminilor - pentru
  /// oricine altcineva e null și nu se afișează nicăieri.
  final double? searchScore;

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
    this.isForSale = false,
    this.salePrice,
    this.isNegotiable = true,
    this.swapSalePrice,
    this.isAuction = false,
    this.auction,
    this.isPromoted = false,
    this.viewCount = 0,
    this.distanceKm,
    this.photos = const [],
    this.mainPhotoUrl,
    required this.createdAt,
    this.permanentlyTransferred = false,
    this.deletedAt,
    this.description,
    this.tags = const [],
    this.city,
    this.favoriteCount,
    this.isWishlisted,
    this.wishlistSource,
    this.searchScore,
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
      isForSale: json['isForSale'] as bool? ?? false,
      salePrice: json['salePrice'] != null
          ? double.parse(json['salePrice'].toString())
          : null,
      isNegotiable: json['isNegotiable'] as bool? ?? true,
      swapSalePrice: json['swapSalePrice'] != null
          ? double.parse(json['swapSalePrice'].toString())
          : null,
      isAuction: json['isAuction'] as bool? ?? false,
      auction: json['auction'] != null
          ? AuctionCardSummary.fromJson(json['auction'] as Map<String, dynamic>)
          : null,
      isPromoted: json['isPromoted'] as bool? ?? false,
      viewCount: json['viewCount'] as int? ?? 0,
      distanceKm: (json['distanceKm'] as num?)?.toDouble(),
      photos: (json['photos'] as List<dynamic>?)
              ?.map((e) => e as String)
              .toList() ??
          const [],
      mainPhotoUrl: json['mainPhotoUrl'] as String?,
      createdAt: DateTime.parse(json['createdAt'] as String),
      permanentlyTransferred: json['permanentlyTransferred'] as bool? ?? false,
      deletedAt: json['deletedAt'] != null
          ? DateTime.parse(json['deletedAt'] as String)
          : null,
      description: json['description'] as String?,
      tags: (json['tags'] as List<dynamic>?)?.map((e) => e as String).toList() ?? const [],
      city: json['city'] as String?,
      favoriteCount: json['favoriteCount'] as int?,
      isWishlisted: json['isWishlisted'] as bool?,
      wishlistSource: json['wishlistSource'] != null
          ? WishlistSource.fromJson(json['wishlistSource'])
          : null,
      searchScore: (json['searchScore'] as num?)?.toDouble(),
    );
  }

  /// Imaginea de afișat în feed/carduri. Ordinea de fallback:
  /// 1. `mainPhotoUrl` (alegerea explicită a userului, prin steluța de pe o
  ///    poză urcată - vezi `onSetMain` din add_book_screen.dart),
  /// 2. coperta oficială a cărții (ISBN/lookup extern),
  /// 3. prima poză urcată, doar dacă nu există copertă oficială.
  /// Coperta oficială e default-ul, nu poza urcată: userul poate avea o
  /// poză a exemplarului lui, dar cea oficială e cea recunoscută/de calitate
  /// - userul alege explicit prin steluță dacă vrea să afișeze poza proprie.
  /// Poate fi null dacă niciuna nu e disponibilă - callerul afișează atunci
  /// propriul placeholder.
  String? get primaryImageUrl {
    if (mainPhotoUrl != null && mainPhotoUrl!.isNotEmpty) return mainPhotoUrl;
    if (book.coverUrl != null && book.coverUrl!.isNotEmpty) return book.coverUrl;
    if (photos.isNotEmpty) return photos.first;
    return null;
  }
}

/// Rezumatul licitației afișat pe cardul din browse/library - fără istoricul
/// de oferte, doar cât să arate prețul curent și timpul rămas.
class AuctionCardSummary {
  final String id;
  final double currentPrice;
  final DateTime endsAt;
  final String status;
  final double? buyNowPrice;

  const AuctionCardSummary({
    required this.id,
    required this.currentPrice,
    required this.endsAt,
    required this.status,
    this.buyNowPrice,
  });

  factory AuctionCardSummary.fromJson(Map<String, dynamic> json) {
    return AuctionCardSummary(
      id: json['id'] as String,
      currentPrice: double.parse(json['currentPrice'].toString()),
      endsAt: DateTime.parse(json['endsAt'] as String),
      status: json['status'] as String,
      buyNowPrice: json['buyNowPrice'] != null
          ? double.parse(json['buyNowPrice'].toString())
          : null,
    );
  }
}
