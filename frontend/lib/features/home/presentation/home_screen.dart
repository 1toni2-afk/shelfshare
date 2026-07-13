import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../data/models/user_book.dart';
import '../../../shared/widgets/book_card.dart';
import '../../../shared/widgets/centered_scrollable.dart';
import '../../../shared/widgets/section_header.dart';
import '../../auth/application/auth_controller.dart';
import '../../auth/application/auth_state.dart';
import '../../notifications/application/notifications_controller.dart';
import '../application/home_controller.dart';

class HomeScreen extends ConsumerWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final authState = ref.watch(authControllerProvider);
    final homeAsync = ref.watch(homeControllerProvider);
    final name = authState is AuthAuthenticated ? authState.user.name : null;
    final unreadCount =
        (ref.watch(notificationsControllerProvider).value ?? const []).where((n) => !n.isRead).length;

    return Scaffold(
      appBar: AppBar(
        title: Text(name != null && name.isNotEmpty ? 'Salut, $name!' : 'Bine ai venit!'),
        actions: [
          IconButton(
            icon: Badge(
              label: Text('$unreadCount'),
              isLabelVisible: unreadCount > 0,
              child: const Icon(Icons.notifications_outlined),
            ),
            onPressed: () => context.push('/notifications'),
          ),
          IconButton(
            icon: const Icon(Icons.favorite_border),
            onPressed: () => context.push('/wishlist'),
          ),
          IconButton(
            icon: const Icon(Icons.search),
            onPressed: () => context.go('/search'),
          ),
        ],
      ),
      body: SafeArea(
        child: RefreshIndicator(
          onRefresh: () => ref.read(homeControllerProvider.notifier).refresh(),
          child: homeAsync.when(
            data: (data) => _HomeContent(data: data),
            loading: () => CenteredScrollable(
              child: const CircularProgressIndicator(),
            ),
            error: (error, _) => CenteredScrollable(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text('Nu am putut încărca cărțile.'),
                  const SizedBox(height: 8),
                  OutlinedButton(
                    onPressed: () => ref.read(homeControllerProvider.notifier).refresh(),
                    child: const Text('Încearcă din nou'),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _HomeContent extends StatelessWidget {
  const _HomeContent({required this.data});
  final HomeData data;

  @override
  Widget build(BuildContext context) {
    if (data.recent.isEmpty && data.nearby.isEmpty) {
      return CenteredScrollable(
        child: Text(
          'Nu există încă cărți disponibile.',
          style: Theme.of(context).textTheme.bodyMedium,
        ),
      );
    }

    return ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.symmetric(vertical: 16),
      children: [
        if (data.recent.isNotEmpty) ...[
          const SectionHeader(title: 'Adăugate recent'),
          const SizedBox(height: 12),
          _BookRow(books: data.recent),
          const SizedBox(height: 24),
        ],
        if (data.nearby.isNotEmpty) ...[
          const SectionHeader(title: 'Din orașul tău'),
          const SizedBox(height: 12),
          _BookRow(books: data.nearby),
        ],
      ],
    );
  }
}

class _BookRow extends StatelessWidget {
  const _BookRow({required this.books});
  final List<UserBook> books;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 270,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        itemCount: books.length,
        separatorBuilder: (_, _) => const SizedBox(width: 12),
        itemBuilder: (context, index) => BookCard(
          userBook: books[index],
          onTap: () => context.push(
            '/books/${books[index].id}',
            extra: books[index].owner,
          ),
        ),
      ),
    );
  }
}
