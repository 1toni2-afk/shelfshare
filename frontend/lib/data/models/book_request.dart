/// Starea unei cereri de carte („nu găsesc cartea") - vezi BookRequestStatus
/// din backend/prisma/schema.prisma.
enum BookRequestStatus {
  /// În așteptare: intră în căutarea de noapte prin catalog, Google Books,
  /// Open Library și librăriile românești.
  pending,

  /// Găsită - `bookId` e completat.
  fulfilled,

  /// Căutată 14 nopți fără rezultat. Nu mai e reluată automat.
  notFound,

  /// Anulată de user.
  cancelled,

  /// Stare trimisă de un backend mai nou decât aplicația - vezi
  /// NotificationType.unknown pentru același compromis.
  unknown,
}

/// Statusul primit de la server. Funcție la nivel de fișier, nu metodă
/// privată: o folosește și [AdminBookRequest], care parsează aceleași rânduri
/// dintr-un alt endpoint.
BookRequestStatus bookRequestStatusFromJson(String? value) {
  switch (value) {
    case 'PENDING':
      return BookRequestStatus.pending;
    case 'FULFILLED':
      return BookRequestStatus.fulfilled;
    case 'NOT_FOUND':
      return BookRequestStatus.notFound;
    case 'CANCELLED':
      return BookRequestStatus.cancelled;
    default:
      return BookRequestStatus.unknown;
  }
}

class BookRequest {
  final String id;
  final String title;
  final String? author;
  final String? isbn;
  final String? note;
  final BookRequestStatus status;
  final int attempts;

  /// Cartea găsită, dacă a fost. Duce la pagina operei (`/work/<id>`).
  final String? bookId;

  /// Cine a găsit-o („catalog", „google_books", „libris"...).
  final String? resolvedSource;

  final DateTime createdAt;
  final DateTime? fulfilledAt;

  const BookRequest({
    required this.id,
    required this.title,
    this.author,
    this.isbn,
    this.note,
    required this.status,
    required this.attempts,
    this.bookId,
    this.resolvedSource,
    required this.createdAt,
    this.fulfilledAt,
  });

  factory BookRequest.fromJson(Map<String, dynamic> json) {
    return BookRequest(
      id: json['id'] as String,
      title: json['title'] as String,
      author: json['author'] as String?,
      isbn: json['isbn'] as String?,
      note: json['note'] as String?,
      status: bookRequestStatusFromJson(json['status'] as String?),
      attempts: (json['attempts'] as num?)?.toInt() ?? 0,
      bookId: json['bookId'] as String?,
      resolvedSource: json['resolvedSource'] as String?,
      createdAt: DateTime.parse(json['createdAt'] as String),
      fulfilledAt: json['fulfilledAt'] == null
          ? null
          : DateTime.parse(json['fulfilledAt'] as String),
    );
  }
}

/// Răspunsul la trimiterea formularului. Backend-ul mai încearcă o dată în
/// catalog cu titlul STRUCTURAT (titlu separat de autor, spre deosebire de
/// textul liber din care a venit userul), deci se poate întâmpla să găsească
/// pe loc cartea - caz în care nu se mai creează nicio cerere.
class BookRequestResult {
  final bool found;
  final String? bookId;
  final BookRequest? request;

  const BookRequestResult({required this.found, this.bookId, this.request});

  factory BookRequestResult.fromJson(Map<String, dynamic> json) {
    final book = json['book'] as Map<String, dynamic>?;
    final request = json['request'] as Map<String, dynamic>?;
    return BookRequestResult(
      found: json['status'] == 'found',
      bookId: book?['id'] as String?,
      request: request == null ? null : BookRequest.fromJson(request),
    );
  }
}
