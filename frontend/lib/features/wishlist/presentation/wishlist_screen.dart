import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/theme/app_theme.dart';
import '../../../data/models/wishlist_item.dart';
import '../../../shared/widgets/book_cover.dart';
import '../../../shared/widgets/centered_scrollable.dart';
import '../../books/presentation/browse_screen.dart';
import '../application/wishlist_controller.dart';

class WishlistScreen extends ConsumerWidget {
  const WishlistScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(wishlistControllerProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Lista de dorințe')),
      body: SafeArea(
        child: RefreshIndicator(
          onRefresh: () => ref.read(wishlistControllerProvider.notifier).refresh(),
          child: state.when(
            data: (items) {
              if (items.isEmpty) {
                return const CenteredScrollable(
                  child: Text('Nu ai adăugat încă nicio carte în lista de dorințe.'),
                );
              }
              return ListView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.all(16),
                children: [
                  Wrap(
                    spacing: 16,
                    runSpacing: 20,
                    children: [
                      for (final item in items) _WishlistCard(item: item),
                    ],
                  ),
                ],
              );
            },
            loading: () => const CenteredScrollable(child: CircularProgressIndicator()),
            error: (error, _) => CenteredScrollable(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text('Nu am putut încărca lista de dorințe.'),
                  const SizedBox(height: 8),
                  OutlinedButton(
                    onPressed: () => ref.read(wishlistControllerProvider.notifier).refresh(),
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

class _WishlistCard extends ConsumerWidget {
  const _WishlistCard({required this.item});
  final WishlistItem item;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return SizedBox(
      width: 160,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Stack(
            children: [
              GestureDetector(
                onTap: () => context.push('/search', extra: SearchScreenArgs(title: item.book.title)),
                child: BookCover(url: item.book.coverUrl, width: 160, height: 224),
              ),
              Positioned(
                top: 4,
                right: 4,
                child: Material(
                  color: AppColors.card,
                  shape: const CircleBorder(),
                  child: IconButton(
                    icon: const Icon(Icons.favorite, color: AppColors.destructive),
                    onPressed: () => ref.read(wishlistControllerProvider.notifier).toggle(item.book.id),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            item.book.title,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w600),
          ),
          if (item.book.author != null)
            Text(
              item.book.author!,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: Theme.of(context).textTheme.bodySmall,
            ),
        ],
      ),
    );
  }
}
