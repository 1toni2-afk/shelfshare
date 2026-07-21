class MapCity {
  final String city;
  final double lat;
  final double lng;
  final int count;

  const MapCity({
    required this.city,
    required this.lat,
    required this.lng,
    required this.count,
  });

  factory MapCity.fromJson(Map<String, dynamic> json) {
    return MapCity(
      city: json['city'] as String,
      lat: (json['lat'] as num).toDouble(),
      lng: (json['lng'] as num).toDouble(),
      count: json['count'] as int,
    );
  }
}
