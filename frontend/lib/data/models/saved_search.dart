class SavedSearch {
  final String id;
  final String label;
  final String? genre;
  final String? city;
  final double? maxPrice;
  final DateTime createdAt;

  const SavedSearch({
    required this.id,
    required this.label,
    this.genre,
    this.city,
    this.maxPrice,
    required this.createdAt,
  });

  factory SavedSearch.fromJson(Map<String, dynamic> json) {
    return SavedSearch(
      id: json['id'] as String,
      label: json['label'] as String,
      genre: json['genre'] as String?,
      city: json['city'] as String?,
      maxPrice: json['maxPrice'] != null ? double.parse(json['maxPrice'].toString()) : null,
      createdAt: DateTime.parse(json['createdAt'] as String),
    );
  }
}
