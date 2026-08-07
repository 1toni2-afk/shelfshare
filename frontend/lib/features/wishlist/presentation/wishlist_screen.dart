import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/locale/l10n_extensions.dart';
import '../../../core/theme/app_theme.dart';
import '../../../data/models/wishlist_item.dart';
import '../../../shared/widgets/book_cover.dart';
import '../../../shared/widgets/book_grid_metrics.dart';
import '../../../shared/widgets/centered_scrollable.dart';
import '../../books/presentation/browse_screen.dart';
import '../application/wishlist_controller.dart';

class WishlistScreen extends ConsumerWidget {
  const WishlistScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(wishlistControllerProvider);
    final l10n = context.l10n;

    return Scaffold(
      appBar: AppBar(title: Text(l10n.wishlistTitle)),
      body: SafeArea(
        child: RefreshIndicator(
          onRefresh: () => ref.read(wishlistControllerProvider.notifier).refresh(),
          child: state.when(
            data: (items) {
              if (items.isEmpty) {
                return CenteredScrollable(
                  child: Text(l10n.wishlistEmpty),
                );
              }
              return Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 1180),
                  child: ListView(
                    physics: const AlwaysScrollableScrollPhysics(),
                    padding: const EdgeInsets.all(16),
                    children: [
                      Text(
                        l10n.wishlistCount(items.length),
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(color: AppColors.mutedForeground),
                      ),
                      const SizedBox(height: 16),
                      GridView.builder(
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
                          maxCrossAxisExtent: kBookCardMaxWidth,
                          mainAxisSpacing: kBookGridMainAxisSpacing,
                          crossAxisSpacing: kBookGridCrossAxisSpacing,
                          childAspectRatio: kBookCardAspectRatio,
                        ),
                        itemCount: items.length,
                        itemBuilder: (context, index) => _WishlistCard(item: items[index]),
                      ),
                    ],
                  ),
                ),
              );
            },
            loading: () => const CenteredScrollable(child: CircularProgressIndicator()),
            error: (error, _) => CenteredScrollable(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(l10n.wishlistLoadError),
                  const SizedBox(height: 8),
                  OutlinedButton(
                    onPressed: () => ref.read(wishlistControllerProvider.notifier).refresh(),
                    child: Text(l10n.commonRetry),
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
    return GestureDetector(
      onTap: () => context.push('/browse', extra: SearchScreenArgs(title: item.book.title)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          AspectRatio(
            aspectRatio: 2 / 3,
            child: Stack(
              fit: StackFit.expand,
              children: [
                BookCover.expand(url: item.book.coverUrl, title: item.book.title),
                Positioned(
                  top: 6,
                  right: 6,
                  // Ești deja pe Wishlist - o inimă roșie pe fiecare card nu
                  // comunică nimic. Singura acțiune care are sens aici e
                  // scoaterea din listă, deci devine un „×" discret.
                  child: _RemoveButton(
                    onTap: () => ref.read(wishlistControllerProvider.notifier).toggle(item.book.id),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 8),
          // Înălțime fixă pe titlu - un titlu pe o linie vs. unul pe două nu
          // mai decalează rândul următor al grilei.
          SizedBox(
            height: 36,
            child: Text(
              item.book.title,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w600),
            ),
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

class _RemoveButton extends StatelessWidget {
  const _RemoveButton({required this.onTap});
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: Container(
        width: 26,
        height: 26,
        decoration: BoxDecoration(
          color: Colors.black.withValues(alpha: 0.4),
          shape: BoxShape.circle,
        ),
        child: const Icon(Icons.close, size: 15, color: Colors.white),
      ),
    );
  }
}
