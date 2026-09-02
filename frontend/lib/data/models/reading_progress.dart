class ReadingProgress {
  final String bookId;
  final int currentPage;
  final int? totalPages;
  final DateTime updatedAt;

  const ReadingProgress({
    required this.bookId,
    required this.currentPage,
    this.totalPages,
    required this.updatedAt,
  });

  factory ReadingProgress.fromJson(Map<String, dynamic> json) {
    final book = json['book'] as Map<String, dynamic>?;
    return ReadingProgress(
      bookId: json['bookId'] as String,
      currentPage: json['currentPage'] as int,
      // Ediția proprie a userului bate catalogul - vezi
      // ReadingProgress.totalPages pe backend.
      totalPages: (json['totalPages'] as num?)?.toInt() ?? book?['pageCount'] as int?,
      updatedAt: DateTime.parse(json['updatedAt'] as String),
    );
  }
}
