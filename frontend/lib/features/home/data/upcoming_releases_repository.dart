import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/network/providers.dart';
import '../../../data/models/upcoming_release.dart';

class UpcomingReleasesRepository {
  UpcomingReleasesRepository(this._ref);
  final Ref _ref;

  Future<List<UpcomingRelease>> list() async {
    final dio = _ref.read(apiClientProvider).dio;
    final response = await dio.get('/upcoming-releases');
    return (response.data as List<dynamic>)
        .map((e) => UpcomingRelease.fromJson(e as Map<String, dynamic>))
        .toList();
  }
}

final upcomingReleasesRepositoryProvider =
    Provider<UpcomingReleasesRepository>((ref) {
  return UpcomingReleasesRepository(ref);
});
