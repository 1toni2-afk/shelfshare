import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../data/models/user_book.dart';
import '../../auth/application/auth_controller.dart';
import '../../auth/application/auth_state.dart';
import '../../books/data/books_repository.dart';

class HomeData {
  const HomeData({required this.recent, required this.nearby});
  final List<UserBook> recent;
  final List<UserBook> nearby;
}

class HomeController extends AsyncNotifier<HomeData> {
  @override
  Future<HomeData> build() => _load();

  Future<HomeData> _load() async {
    final repository = ref.read(booksRepositoryProvider);
    final authState = ref.read(authControllerProvider);
    final city = authState is AuthAuthenticated ? authState.user.city : null;

    final results = await Future.wait([
      repository.browse(limit: 10),
      if (city != null && city.isNotEmpty) repository.browse(city: city, limit: 10),
    ]);

    return HomeData(
      recent: results[0].items,
      nearby: results.length > 1 ? results[1].items : const [],
    );
  }

  Future<void> refresh() async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(_load);
  }
}

final homeControllerProvider = AsyncNotifierProvider<HomeController, HomeData>(
  HomeController.new,
);
