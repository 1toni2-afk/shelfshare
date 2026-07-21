import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../data/profile_repository.dart';

final publicProfileProvider = FutureProvider.family((ref, String userId) {
  return ref.watch(profileRepositoryProvider).getPublicProfile(userId);
});
