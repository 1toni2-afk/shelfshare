import 'book_request.dart';

/// O cerere de carte așa cum o vede panoul de admin: cererea propriu-zisă,
/// plus cine a făcut-o și câți oameni așteaptă același titlu.
///
/// Distinct de [BookRequest] (ce vede userul despre cererile lui) tocmai
/// pentru că are câmpuri pe care un user nu trebuie să le primească niciodată:
/// emailul solicitantului.
class AdminBookRequest {
  final String id;
  final String title;
  final String? author;
  final String? isbn;
  final String? note;
  final BookRequestStatus status;

  /// Câte nopți a fost căutată fără succes.
  final int attempts;

  /// Câți useri DISTINCȚI așteaptă același titlu normalizat. E cheia după care
  /// se ordonează căutarea de noapte, deci și ordinea în care merită privite.
  final int demand;

  final String? resolvedSource;
  final DateTime createdAt;
  final DateTime? lastAttemptAt;

  final String requesterEmail;
  final String? requesterName;

  /// Cartea găsită, dacă a fost - id-ul duce la pagina operei.
  final String? bookId;
  final String? bookTitle;

  const AdminBookRequest({
    required this.id,
    required this.title,
    this.author,
    this.isbn,
    this.note,
    required this.status,
    required this.attempts,
    required this.demand,
    this.resolvedSource,
    required this.createdAt,
    this.lastAttemptAt,
    required this.requesterEmail,
    this.requesterName,
    this.bookId,
    this.bookTitle,
  });

  factory AdminBookRequest.fromJson(Map<String, dynamic> json) {
    final user = json['user'] as Map<String, dynamic>?;
    final book = json['book'] as Map<String, dynamic>?;
    return AdminBookRequest(
      id: json['id'] as String,
      title: json['title'] as String,
      author: json['author'] as String?,
      isbn: json['isbn'] as String?,
      note: json['note'] as String?,
      status: bookRequestStatusFromJson(json['status'] as String?),
      attempts: (json['attempts'] as num?)?.toInt() ?? 0,
      demand: (json['demand'] as num?)?.toInt() ?? 0,
      resolvedSource: json['resolvedSource'] as String?,
      createdAt: DateTime.parse(json['createdAt'] as String),
      lastAttemptAt: json['lastAttemptAt'] == null
          ? null
          : DateTime.parse(json['lastAttemptAt'] as String),
      requesterEmail: user?['email'] as String? ?? '',
      requesterName: user?['name'] as String?,
      bookId: book?['id'] as String?,
      bookTitle: book?['title'] as String?,
    );
  }
}
