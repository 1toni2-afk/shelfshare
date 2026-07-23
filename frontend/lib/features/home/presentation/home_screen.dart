import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import '../../../core/locale/l10n_extensions.dart';
import '../../../core/theme/app_theme.dart';
import '../../../data/models/upcoming_release.dart';
import '../../../data/models/user.dart';
import '../../../data/models/user_book.dart';
import '../../../shared/widgets/book_card.dart';
import '../../../shared/widgets/book_cover.dart';
import '../../../shared/widgets/centered_scrollable.dart';
import '../../../shared/widgets/section_header.dart';
import '../../auth/application/auth_controller.dart';
import '../../auth/application/auth_state.dart';
import '../../books/presentation/browse_screen.dart';
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
    final l10n = context.l10n;

    return Scaffold(
      appBar: AppBar(
        title: Text(name != null && name.isNotEmpty ? l10n.homeGreeting(name) : l10n.homeWelcome),
        actions: [
          IconButton(
            icon: const Icon(Icons.swap_horiz),
            onPressed: () => context.push('/exchanges'),
          ),
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
                  Text(l10n.homeLoadError),
                  const SizedBox(height: 8),
                  OutlinedButton(
                    onPressed: () => ref.read(homeControllerProvider.notifier).refresh(),
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

class _HomeContent extends StatelessWidget {
  const _HomeContent({required this.data});
  final HomeData data;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    if (data.recent.isEmpty && data.nearby.isEmpty && data.mostViewed.isEmpty) {
      return CenteredScrollable(
        child: Text(
          l10n.homeEmpty,
          style: Theme.of(context).textTheme.bodyMedium,
        ),
      );
    }

    return ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.symmetric(vertical: 16),
      children: [
        if (data.genres.isNotEmpty) ...[
          SectionHeader(title: l10n.homeCategories),
          const SizedBox(height: 12),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (final genre in data.genres)
                  ActionChip(
                    label: Text('${genre.genre} (${genre.count})'),
                    onPressed: () => context.push(
                      '/search',
                      extra: SearchScreenArgs(genre: genre.genre),
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(height: 24),
        ],
        if (data.recent.isNotEmpty) ...[
          SectionHeader(title: l10n.homeRecentlyAdded),
          const SizedBox(height: 12),
          _BookGrid(books: data.recent),
          const SizedBox(height: 24),
        ],
        if (data.mostViewed.isNotEmpty) ...[
          SectionHeader(title: l10n.homeMostViewed),
          const SizedBox(height: 12),
          _BookGrid(books: data.mostViewed),
          const SizedBox(height: 24),
        ],
        if (data.nearby.isNotEmpty) ...[
          SectionHeader(title: l10n.homeNearYou),
          const SizedBox(height: 12),
          _BookGrid(books: data.nearby),
          const SizedBox(height: 24),
        ],
        if (data.upcomingReleases.isNotEmpty) ...[
          SectionHeader(title: l10n.homeUpcomingBooks),
          const SizedBox(height: 12),
          _UpcomingReleasesList(releases: data.upcomingReleases),
          const SizedBox(height: 24),
        ],
        if (data.activeMembers.isNotEmpty) ...[
          SectionHeader(title: l10n.homeActiveMembers),
          const SizedBox(height: 12),
          _ActiveMembersRow(members: data.activeMembers),
        ],
      ],
    );
  }
}

class _ActiveMembersRow extends StatelessWidget {
  const _ActiveMembersRow({required this.members});
  final List<PublicUser> members;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 92,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        itemCount: members.length,
        separatorBuilder: (_, _) => const SizedBox(width: 16),
        itemBuilder: (context, index) {
          final member = members[index];
          return GestureDetector(
            onTap: () => context.push('/users/${member.id}', extra: member),
            child: SizedBox(
              width: 64,
              child: Column(
                children: [
                  CircleAvatar(
                    radius: 28,
                    backgroundImage: member.profileImage != null ? NetworkImage(member.profileImage!) : null,
                    child: member.profileImage == null ? const Icon(Icons.person) : null,
                  ),
                  const SizedBox(height: 4),
                  Text(
                    member.name ?? context.l10n.commonUnknownUser,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    textAlign: TextAlign.center,
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}

/// Cărțile curg pe mai multe coloane și dau scroll în jos - nu mai lateral
/// ca înainte (aceeași abordare ca la ecranul de căutare).
class _BookGrid extends StatelessWidget {
  const _BookGrid({required this.books});
  final List<UserBook> books;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Wrap(
        spacing: 16,
        runSpacing: 20,
        children: [
          for (final userBook in books)
            BookCard(
              userBook: userBook,
              width: 160,
              onTap: () => context.push('/books/${userBook.id}', extra: userBook.owner),
            ),
        ],
      ),
    );
  }
}

class _UpcomingReleasesList extends StatelessWidget {
  const _UpcomingReleasesList({required this.releases});
  final List<UpcomingRelease> releases;

  @override
  Widget build(BuildContext context) {
    return ListView.separated(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      padding: const EdgeInsets.symmetric(horizontal: 16),
      itemCount: releases.length,
      separatorBuilder: (_, _) => const Divider(),
      itemBuilder: (context, index) {
        final release = releases[index];
        return ListTile(
          contentPadding: EdgeInsets.zero,
          leading: BookCover(url: release.coverUrl, width: 48, height: 68),
          title: Text(release.title, maxLines: 1, overflow: TextOverflow.ellipsis),
          subtitle: Text(
            [
              if (release.author != null) release.author!,
              _formatReleaseDate(context, release.releaseDate),
            ].join(' · '),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          trailing: Icon(Icons.event_outlined, color: AppColors.mutedForeground),
        );
      },
    );
  }
}

String _formatReleaseDate(BuildContext context, DateTime date) {
  final locale = Localizations.localeOf(context).toString();
  return DateFormat('d MMM yyyy', locale).format(date);
}
