import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/network/providers.dart';

class PlaceResult {
  final String displayName;
  final double lat;
  final double lng;
  final String? category;

  const PlaceResult({
    required this.displayName,
    required this.lat,
    required this.lng,
    this.category,
  });

  factory PlaceResult.fromJson(Map<String, dynamic> json) {
    return PlaceResult(
      displayName: json['displayName'] as String,
      lat: (json['lat'] as num).toDouble(),
      lng: (json['lng'] as num).toDouble(),
      category: json['category'] as String?,
    );
  }
}

class PlacesRepository {
  PlacesRepository(this._ref);
  final Ref _ref;

  Future<List<PlaceResult>> search(String query) async {
    final dio = _ref.read(apiClientProvider).dio;
    final response = await dio.get('/places/search', queryParameters: {'q': query});
    return (response.data as List)
        .map((e) => PlaceResult.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  Future<List<PlaceResult>> meetingPoints(double lat, double lng) async {
    final dio = _ref.read(apiClientProvider).dio;
    final response = await dio.get(
      '/places/meeting-points',
      queryParameters: {'lat': lat, 'lng': lng},
    );
    return (response.data as List)
        .map((e) => PlaceResult.fromJson(e as Map<String, dynamic>))
        .toList();
  }
}

final placesRepositoryProvider = Provider<PlacesRepository>((ref) {
  return PlacesRepository(ref);
});
