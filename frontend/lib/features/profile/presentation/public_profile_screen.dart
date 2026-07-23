import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/locale/l10n_extensions.dart';
import '../../../core/theme/app_theme.dart';
import '../../../data/models/user.dart';
import '../../../shared/widgets/book_card.dart';
import '../../../shared/widgets/book_cover.dart';
import '../../../shared/widgets/centered_scrollable.dart';
import '../../../shared/widgets/profile_header.dart';
import '../../../shared/widgets/achievements_grid.dart';
import '../../../shared/widgets/profile_qr_dialog.dart';
import '../../../shared/widgets/trust_score_card.dart';
import '../../../shared/utils/share_link.dart';
import '../../auth/application/auth_controller.dart';
import '../../auth/application/auth_state.dart';
import '../../chat/data/chat_repository.dart';
import '../application/public_profile_controller.dart';
import '../data/follow_repository.dart';

class PublicProfileScreen extends ConsumerStatefulWidget {
  const PublicProfileScreen({super.key, required this.userId, this.fallback});
  final String userId;
  final PublicUser? fallback;

  @override
  ConsumerState<PublicProfileScreen> createState() => _PublicProfileScreenState();
}

class _PublicProfileScreenState extends ConsumerState<PublicProfileScreen> {
  bool _isMessaging = false;
  bool _isTogglingFollow = false;
  FollowStatus? _followStatus;

  @override
  void initState() {
    super.initState();
    _loadFollowStatus();
  }

  Future<void> _loadFollowStatus() async {
    try {
      final status = await ref.read(followRepositoryProvider).getStatus(widget.userId);
      if (mounted) setState(() => _followStatus = status);
    } catch (_) {
      // Nesemnificativ dacă eșuează - butonul de urmărire rămâne ascuns.
    }
  }

  Future<void> _toggleFollow() async {
    if (_isTogglingFollow) return;
    setState(() => _isTogglingFollow = true);
    final repository = ref.read(followRepositoryProvider);
    final isFollowing = _followStatus?.isFollowing ?? false;
    try {
      if (isFollowing) {
        await repository.unfollow(widget.userId);
      } else {
        await repository.follow(widget.userId);
      }
      await _loadFollowStatus();
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(context.l10n.publicProfileFollowUpdateError)));
      }
    } finally {
      if (mounted) setState(() => _isTogglingFollow = false);
    }
  }

  Future<void> _messageUser() async {
    if (_isMessaging) return;
    setState(() => _isMessaging = true);
    try {
      final conversation =
          await ref.read(chatRepositoryProvider).startConversation(widget.userId);
      if (mounted) context.push('/chat/${conversation.id}');
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(context.l10n.publicProfileMessageError)));
      }
    } finally {
      if (mounted) setState(() => _isMessaging = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final async = ref.watch(publicProfileProvider(widget.userId));
    final authState = ref.watch(authControllerProvider);
    final isOwnProfile =
        authState is AuthAuthenticated && authState.user.id == widget.userId;

    return Scaffold(
      appBar: AppBar(
        title: Text(context.l10n.publicProfileTitle),
        actions: [
          IconButton(
            icon: const Icon(Icons.qr_code_2),
            tooltip: context.l10n.profileQrTooltip,
            onPressed: () => showDialog<void>(
              context: context,
              builder: (context) => ProfileQrDialog(userId: widget.userId),
            ),
          ),
          IconButton(
            icon: const Icon(Icons.share_outlined),
            tooltip: context.l10n.profileCopyLink,
            onPressed: () => copyShareLink(context, '/users/${widget.userId}'),
          ),
        ],
      ),
      body: SafeArea(
        child: async.when(
          data: (user) => _Content(
            user: user,
            isOwnProfile: isOwnProfile,
            isMessaging: _isMessaging,
            onMessage: _messageUser,
            followStatus: _followStatus,
            isTogglingFollow: _isTogglingFollow,
            onToggleFollow: _toggleFollow,
          ),
          loading: () {
            final fallback = widget.fallback;
            if (fallback == null) {
              return const CenteredScrollable(child: CircularProgressIndicator());
            }
            return _Content(
              user: fallback,
              isOwnProfile: isOwnProfile,
              isMessaging: _isMessaging,
              onMessage: _messageUser,
              followStatus: _followStatus,
              isTogglingFollow: _isTogglingFollow,
              onToggleFollow: _toggleFollow,
            );
          },
          error: (error, _) => CenteredScrollable(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(context.l10n.profileLoadError),
                const SizedBox(height: 8),
                OutlinedButton(
                  onPressed: () => ref.invalidate(publicProfileProvider(widget.userId)),
                  child: Text(context.l10n.commonRetry),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _Content extends StatelessWidget {
  const _Content({
    required this.user,
    required this.isOwnProfile,
    required this.isMessaging,
    required this.onMessage,
    required this.followStatus,
    required this.isTogglingFollow,
    required this.onToggleFollow,
  });

  final PublicUser user;
  final bool isOwnProfile;
  final bool isMessaging;
  final VoidCallback onMessage;
  final FollowStatus? followStatus;
  final bool isTogglingFollow;
  final VoidCallback onToggleFollow;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.all(24),
      children: [
        ProfileHeader(
          profileImage: user.profileImage,
          name: user.name,
          username: user.username,
          subtitleLines: [
            if (user.city != null) user.city!,
            if (user.memberSince != null) l10n.publicProfileMemberSince(user.memberSince!.year),
            if (followStatus != null)
              l10n.publicProfileFollowersFollowing(
                followStatus!.followersCount,
                followStatus!.followingCount,
              ),
          ],
          rating: user.rating,
          booksExchangedCount: user.booksExchangedCount ?? 0,
          bio: user.bio,
        ),
        if (user.trustScore != null) ...[
          const SizedBox(height: 20),
          TrustScoreCard(trustScore: user.trustScore!),
        ],
        if (!isOwnProfile) ...[
          const SizedBox(height: 20),
          Row(
            children: [
              Expanded(
                child: ElevatedButton.icon(
                  icon: const Icon(Icons.chat_bubble_outline),
                  label: Text(l10n.commonSendMessage),
                  onPressed: isMessaging ? null : onMessage,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: OutlinedButton.icon(
                  icon: Icon(
                    (followStatus?.isFollowing ?? false) ? Icons.person_remove_outlined : Icons.person_add_outlined,
                  ),
                  label: Text(
                    (followStatus?.isFollowing ?? false) ? l10n.publicProfileUnfollow : l10n.publicProfileFollow,
                  ),
                  onPressed: isTogglingFollow ? null : onToggleFollow,
                ),
              ),
            ],
          ),
        ],
        if (user.readingStats != null) ...[
          const SizedBox(height: 32),
          Text(l10n.publicProfileReadingStats, style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 12),
          Wrap(
            spacing: 12,
            runSpacing: 12,
            children: [
              _StatChip(label: l10n.publicProfileBooksListed, value: '${user.readingStats!.totalListed}'),
              if (user.readingStats!.totalPages > 0)
                _StatChip(label: l10n.publicProfileTotalPages, value: '${user.readingStats!.totalPages}'),
              if (user.readingStats!.topGenres.length <= 1 && user.readingStats!.favoriteGenre != null)
                _StatChip(label: l10n.publicProfileFavoriteGenre, value: user.readingStats!.favoriteGenre!),
            ],
          ),
          if (user.readingStats!.topGenres.length > 1) ...[
            const SizedBox(height: 16),
            Text(l10n.publicProfileTopGenres, style: Theme.of(context).textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w600)),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (final entry in user.readingStats!.topGenres)
                  _StatChip(label: entry.genre, value: '${entry.count}'),
              ],
            ),
          ],
        ],
        if (user.achievements != null && user.achievements!.isNotEmpty) ...[
          const SizedBox(height: 32),
          Text(l10n.profileBadgesTitle, style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 12),
          AchievementsGrid(achievements: user.achievements!),
        ],
        if (user.listedBooks != null && user.listedBooks!.isNotEmpty) ...[
          const SizedBox(height: 32),
          Text(
            l10n.publicProfileListedBooksCount(user.listingsCount ?? user.listedBooks!.length),
            style: Theme.of(context).textTheme.titleMedium,
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 16,
            runSpacing: 20,
            children: [
              for (final userBook in user.listedBooks!)
                BookCard(
                  userBook: userBook,
                  width: 130,
                  onTap: () => context.push('/books/${userBook.id}', extra: user),
                ),
            ],
          ),
        ],
        if (user.acquisitionHistory != null) ...[
          const SizedBox(height: 32),
          Text(l10n.publicProfileAcquisitionHistory, style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 12),
          if (user.acquisitionHistory!.isEmpty)
            Text(
              l10n.publicProfileNoAcquisitions,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(color: AppColors.mutedForeground),
            )
          else
            for (final entry in user.acquisitionHistory!)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 4),
                child: Row(
                  children: [
                    BookCover(url: entry.bookCoverUrl, width: 32, height: 44),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        '${entry.bookTitle} · ${entry.date.day}.${entry.date.month}.${entry.date.year}',
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                    ),
                  ],
                ),
              ),
        ],
        if (user.reviews != null && user.reviews!.isNotEmpty) ...[
          const SizedBox(height: 32),
          Text(l10n.publicProfileReviewsCount(user.reviews!.length), style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 12),
          for (final review in user.reviews!)
            Card(
              margin: const EdgeInsets.only(bottom: 8),
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        CircleAvatar(
                          radius: 14,
                          backgroundImage:
                              review.reviewerImage != null ? NetworkImage(review.reviewerImage!) : null,
                          child: review.reviewerImage == null ? const Icon(Icons.person, size: 14) : null,
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            review.reviewerName ?? l10n.commonUnknownUser,
                            style: Theme.of(context).textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w600),
                          ),
                        ),
                        if (review.rating != null)
                          Row(
                            children: [
                              const Icon(Icons.star, size: 14, color: AppColors.accent),
                              Text(' ${review.rating}', style: Theme.of(context).textTheme.bodySmall),
                            ],
                          ),
                      ],
                    ),
                    if (review.comment != null && review.comment!.isNotEmpty) ...[
                      const SizedBox(height: 8),
                      Text(review.comment!, style: Theme.of(context).textTheme.bodySmall),
                    ],
                  ],
                ),
              ),
            ),
        ],
      ],
    );
  }
}

class _StatChip extends StatelessWidget {
  const _StatChip({required this.label, required this.value});
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(color: AppColors.muted, borderRadius: BorderRadius.circular(10)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(value, style: Theme.of(context).textTheme.titleSmall),
          Text(label, style: Theme.of(context).textTheme.bodySmall?.copyWith(color: AppColors.mutedForeground)),
        ],
      ),
    );
  }
}
