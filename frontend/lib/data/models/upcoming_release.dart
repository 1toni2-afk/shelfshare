class UpcomingRelease {
  final String id;
  final String title;
  final String? author;
  final String? coverUrl;
  final String? description;
  final String? isbn;
  final DateTime releaseDate;

  const UpcomingRelease({
    required this.id,
    required this.title,
    this.author,
    this.coverUrl,
    this.description,
    this.isbn,
    required this.releaseDate,
  });

  factory UpcomingRelease.fromJson(Map<String, dynamic> json) {
    return UpcomingRelease(
      id: json['id'] as String,
      title: json['title'] as String,
      author: json['author'] as String?,
      coverUrl: json['coverUrl'] as String?,
      description: json['description'] as String?,
      isbn: json['isbn'] as String?,
      releaseDate: DateTime.parse(json['releaseDate'] as String),
    );
  }
}
