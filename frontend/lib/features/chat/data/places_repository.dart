import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/network/providers.dart';

class PlaceResult {
  final String displayName;
  final double lat;
  final double lng;

  const PlaceResult({required this.displayName, required this.lat, required this.lng});

  factory PlaceResult.fromJson(Map<String, dynamic> json) {
    return PlaceResult(
      displayName: json['displayName'] as String,
      lat: (json['lat'] as num).toDouble(),
      lng: (json['lng'] as num).toDouble(),
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
}

final placesRepositoryProvider = Provider<PlacesRepository>((ref) {
  return PlacesRepository(ref);
});
