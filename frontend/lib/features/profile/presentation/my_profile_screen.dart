import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/locale/l10n_extensions.dart';
import '../../../core/theme/app_theme.dart';
import '../../../data/models/collection.dart';
import '../../../data/models/user.dart';
import '../../../shared/widgets/book_cover.dart';
import '../../../shared/widgets/centered_scrollable.dart';
import '../../../shared/widgets/profile_qr_dialog.dart';
import '../../../shared/widgets/trust_score_card.dart';
import '../../../shared/utils/share_link.dart';
import '../../books/application/my_library_controller.dart';
import '../../collections/data/collections_repository.dart';
import '../application/profile_controller.dart';
import '../data/profile_repository.dart';
import 'profile_side_cards.dart';

class MyProfileScreen extends ConsumerWidget {
  const MyProfileScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(profileControllerProvider);
    final l10n = context.l10n;

    return Scaffold(
      appBar: AppBar(
        // Milestone 16 QOL: titlul „My Profile" era împins spre stânga pe
        // desktop din cauza sidebar-ului; centrarea îl aliniază cu conținutul
        // profilului dedesubt.
        centerTitle: true,
        title: Text(l10n.profileTitle),
        actions: [
          IconButton(
            icon: const Icon(Icons.settings_outlined),
            tooltip: l10n.profileSettings,
            onPressed: () => context.go('/settings'),
          ),
        ],
      ),
      body: SafeArea(
        child: RefreshIndicator(
          onRefresh: () => ref.read(profileControllerProvider.notifier).refresh(),
          child: state.when(
            data: (user) => _ProfileContent(
              user: user,
              onEdit: () => context.push('/profile/edit'),
            ),
            loading: () => const CenteredScrollable(child: CircularProgressIndicator()),
            error: (error, _) => CenteredScrollable(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(l10n.profileLoadError),
                  const SizedBox(height: 8),
                  OutlinedButton(
                    onPressed: () => ref.read(profileControllerProvider.notifier).refresh(),
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

/// Lățimea maximă a coloanei de conținut din profil. Pe ecrane late, secțiunile
/// nu se mai întind de la margine la margine - rămân o coloană citibilă,
/// centrată, iar copertele păstrează dimensiunea reală (vezi [kCoverTileWidth]).
const kProfileContentMaxWidth = 560.0;

/// Lățimea unei coperte în rândurile de preview. Fixă intenționat: înainte
/// tile-urile se calculau ca fracțiune din lățimea ecranului, deci pe desktop 4
/// cărți acopereau o treime de ecran.
const kCoverTileWidth = 74.0;

/// Layout compact al profilului propriu (Milestone 11), inspirat de macheta
/// mobilă: header cu avatar + trust score compact în dreapta, o linie de
/// statistici cu bordură, un rând de acțiuni, apoi secțiunile de conținut
/// (challenge, library preview, collections, recent activity). Setările,
/// deconectarea, ștergerea contului și scurtăturile secundare stau pe ruta
/// `/profile/settings`, accesibilă prin iconița „⚙" din AppBar - profilul
/// principal rămâne scurt și scan-abil.
class _ProfileContent extends ConsumerWidget {
  const _ProfileContent({required this.user, required this.onEdit});
  final AppUser user;
  final VoidCallback onEdit;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Pe desktop (≥ 900 px) avem 2 coloane: cea centrală cu conținutul actual
    // limitat la kProfileContentMaxWidth, iar în dreapta cardurile
    // „Despre / Info / Statistici / Top genuri" (vezi profile_side_cards.dart).
    // Pe mobil rămâne layout-ul single-column existent.
    return MediaQuery.of(context).size.width >= kProfileDesktopBreakpoint
        ? Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(child: _centerColumn(context)),
              SizedBox(
                width: kProfileSideColumnWidth,
                child: ProfileSideColumn(user: user),
              ),
            ],
          )
        : _centerColumn(context);
  }

  Widget _centerColumn(BuildContext context) {
    final l10n = context.l10n;
    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: kProfileContentMaxWidth),
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 20),
          children: [
            _CompactHeader(user: user),
            // Bio-ul rămâne inline pe mobil (unde n-avem card lateral).
            // Pe desktop, e afișat pe cardul _AboutCard, deci îl scoatem
            // din coloana centrală ca să nu apară de două ori.
            if (MediaQuery.of(context).size.width < kProfileDesktopBreakpoint &&
                user.bio != null &&
                user.bio!.trim().isNotEmpty) ...[
              const SizedBox(height: 12),
              Text(
                user.bio!.trim(),
                style: TextStyle(
                  color: AppColors.mutedForeground,
                  fontSize: 13,
                  height: 1.35,
                ),
              ),
            ],
            const SizedBox(height: 16),
            _StatsRow(user: user),
            const SizedBox(height: 20),
            _PrimaryActions(user: user, onEdit: onEdit),
            const SizedBox(height: 24),
            const _ReadingChallengeMini(),
            const SizedBox(height: 24),
            const _LibraryPreview(),
            const SizedBox(height: 24),
            const _CollectionsPreview(),
            const SizedBox(height: 24),
            const _RecentActivityPreview(),
            const SizedBox(height: 32),
            Center(
              child: Text(
                l10n.profileMoreInSettings,
                style: TextStyle(color: AppColors.mutedForeground, fontSize: 12),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Header compact: avatar (56dp) + nume/username·oraș pe centru + trust score
/// compact pe dreapta. Trust score-ul afișează doar numărul + cuvânt „trust";
/// tap deschide un dialog cu detaliile (aceleași chip-uri de pe cardul mare).
class _CompactHeader extends ConsumerStatefulWidget {
  const _CompactHeader({required this.user});
  final AppUser user;

  @override
  ConsumerState<_CompactHeader> createState() => _CompactHeaderState();
}

class _CompactHeaderState extends ConsumerState<_CompactHeader> {
  bool _uploadingPhoto = false;

  AppUser get user => widget.user;

  void _openTrustDetails(BuildContext context) {
    if (user.trustScore == null) return;
    showDialog<void>(
      context: context,
      builder: (context) => Dialog(
        child: Padding(
          padding: const EdgeInsets.all(8),
          // Userul a apăsat deja pe scor - dialogul arată detaliile direct, nu
          // mai cere un al doilea tap ca să se extindă.
          child: SingleChildScrollView(
            child: TrustScoreCard(
              trustScore: user.trustScore!,
              initiallyExpanded: true,
              collapsible: false,
            ),
          ),
        ),
      ),
    );
  }

  /// Tap pe avatar: alege o poză nouă sau șterge-o pe cea existentă.
  Future<void> _changePhoto() async {
    final l10n = context.l10n;
    final hasPhoto = user.profileImage != null;

    final action = await showModalBottomSheet<String>(
      context: context,
      builder: (sheetContext) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.photo_library_outlined),
              title: Text(l10n.profilePhotoChoose),
              onTap: () => Navigator.of(sheetContext).pop('pick'),
            ),
            if (hasPhoto)
              ListTile(
                leading: const Icon(Icons.delete_outline, color: AppColors.destructive),
                title: Text(l10n.profilePhotoRemove),
                onTap: () => Navigator.of(sheetContext).pop('remove'),
              ),
          ],
        ),
      ),
    );
    if (action == null || !mounted) return;

    setState(() => _uploadingPhoto = true);
    try {
      final notifier = ref.read(profileControllerProvider.notifier);
      if (action == 'remove') {
        await notifier.removePhoto();
      } else {
        // Redimensionăm și recomprimăm încă la alegere: un avatar de 64dp nu are
        // nevoie de cei 8-12MB pe care îi scoate camera unui telefon modern, iar
        // fișierele mari sunt cel mai probabil să fie respinse pe drum (limita de
        // 8MB din backend, proxy-ul din față).
        final picked = await ImagePicker().pickImage(
          source: ImageSource.gallery,
          maxWidth: 1024,
          maxHeight: 1024,
          imageQuality: 85,
        );
        if (picked == null) return;
        await notifier.uploadPhoto(await picked.readAsBytes(), picked.name);
      }
    } on DioException catch (e) {
      // Arătăm mesajul serverului, nu un text generic: „couldn't update your
      // profile photo" nu spune nimic nici userului, nici nouă la depanare.
      if (mounted) {
        final data = e.response?.data;
        final message = (data is Map && data['message'] != null)
            ? data['message'].toString()
            : context.l10n.profilePhotoError;
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
      }
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(context.l10n.profilePhotoError)));
      }
    } finally {
      if (mounted) setState(() => _uploadingPhoto = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final displayName = user.name?.trim().isNotEmpty == true ? user.name! : user.email;
    final subtitleParts = [
      if (user.username != null) '@${user.username}',
      if (user.city != null && user.city!.isNotEmpty) user.city!,
    ];
    final trust = user.trustScore?.score;
    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        // Avatarul e și butonul de schimbare a pozei - insigna cu creion e
        // singurul indiciu vizual că se poate apăsa.
        GestureDetector(
          onTap: _uploadingPhoto ? null : _changePhoto,
          child: Stack(
            children: [
              CircleAvatar(
                radius: 32,
                backgroundColor: AppColors.muted,
                backgroundImage: user.profileImage != null
                    ? NetworkImage(user.profileImage!)
                    : null,
                child: _uploadingPhoto
                    ? const SizedBox(
                        height: 22,
                        width: 22,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : (user.profileImage == null
                        ? Icon(Icons.person, color: AppColors.mutedForeground, size: 32)
                        : null),
              ),
              Positioned(
                right: 0,
                bottom: 0,
                child: Container(
                  padding: const EdgeInsets.all(4),
                  decoration: BoxDecoration(
                    color: AppColors.primary,
                    shape: BoxShape.circle,
                    border: Border.all(color: AppColors.background, width: 2),
                  ),
                  child: const Icon(
                    Icons.photo_camera,
                    size: 12,
                    color: AppColors.primaryForeground,
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(width: 14),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Flexible(
                    child: Text(
                      displayName,
                      style: Theme.of(context).textTheme.titleMedium,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  if (user.isEmailVerified) ...[
                    const SizedBox(width: 6),
                    Icon(Icons.verified, size: 16, color: AppColors.accent),
                  ],
                ],
              ),
              if (subtitleParts.isNotEmpty)
                Text(
                  subtitleParts.join(' · '),
                  style: TextStyle(color: AppColors.mutedForeground, fontSize: 12),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
            ],
          ),
        ),
        if (trust != null)
          InkWell(
            onTap: () => _openTrustDetails(context),
            borderRadius: BorderRadius.circular(8),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
              child: Column(
                children: [
                  Text(
                    '$trust',
                    style: TextStyle(
                      color: AppColors.accent,
                      fontSize: 20,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  Text(
                    'trust',
                    style: TextStyle(color: AppColors.mutedForeground, fontSize: 10),
                  ),
                ],
              ),
            ),
          ),
      ],
    );
  }
}

/// Linia orizontală cu 3 statistici (books / swaps / rating), separată printr-o
/// linie subțire jos, ca reper vizual pentru finalul header-ului.
class _StatsRow extends StatelessWidget {
  const _StatsRow({required this.user});
  final AppUser user;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return Container(
      padding: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        border: Border(bottom: BorderSide(color: AppColors.border)),
      ),
      child: Row(
        children: [
          _stat(context, user.booksSharedCount.toString(), l10n.profileStatBooks),
          const SizedBox(width: 24),
          _stat(context, user.booksExchangedCount.toString(), l10n.profileStatSwaps),
          const SizedBox(width: 24),
          _stat(
            context,
            user.rating > 0 ? user.rating.toStringAsFixed(1) : '—',
            l10n.profileStatRating,
            icon: Icons.star_rounded,
          ),
        ],
      ),
    );
  }

  Widget _stat(BuildContext context, String value, String label, {IconData? icon}) {
    return Row(
      children: [
        if (icon != null) ...[
          Icon(icon, size: 15, color: AppColors.accent),
          const SizedBox(width: 3),
        ],
        Text(value, style: Theme.of(context).textTheme.titleSmall),
        const SizedBox(width: 6),
        Text(label, style: TextStyle(color: AppColors.mutedForeground, fontSize: 12)),
      ],
    );
  }
}

/// Rândul de acțiuni principale de sub statistici. Pentru profilul propriu:
/// Editează profil (buton primar lat) + QR (icon) + Share (icon).
class _PrimaryActions extends StatelessWidget {
  const _PrimaryActions({required this.user, required this.onEdit});
  final AppUser user;
  final VoidCallback onEdit;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return Row(
      children: [
        Expanded(
          flex: 3,
          child: ElevatedButton(
            onPressed: onEdit,
            child: Text(l10n.profileEditProfile),
          ),
        ),
        const SizedBox(width: 8),
        _iconButton(
          context: context,
          icon: Icons.qr_code_2,
          onTap: () => showDialog<void>(
            context: context,
            builder: (context) => ProfileQrDialog(userId: user.id),
          ),
        ),
        const SizedBox(width: 8),
        _iconButton(
          context: context,
          icon: Icons.share_outlined,
          onTap: () => shareAppLink(context, '/users/${user.id}'),
        ),
      ],
    );
  }

  Widget _iconButton({
    required BuildContext context,
    required IconData icon,
    required VoidCallback onTap,
  }) {
    return SizedBox(
      width: 44,
      height: 44,
      child: OutlinedButton(
        style: OutlinedButton.styleFrom(
          padding: EdgeInsets.zero,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        ),
        onPressed: onTap,
        child: Icon(icon, size: 20),
      ),
    );
  }
}

/// Reading challenge condensat: „N challenge · x/goal" + progress bar subțire.
/// Ascuns dacă userul nu a setat obiectivul anual.
class _ReadingChallengeMini extends ConsumerWidget {
  const _ReadingChallengeMini();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(_readingChallengeProvider);
    return async.when(
      loading: () => const SizedBox.shrink(),
      error: (_, _) => const SizedBox.shrink(),
      data: (challenge) {
        if (challenge.goal == null || challenge.goal == 0) return const SizedBox.shrink();
        final progress = (challenge.progress / challenge.goal!).clamp(0.0, 1.0);
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Text(
                  '${challenge.year} challenge',
                  style: TextStyle(color: AppColors.mutedForeground, fontSize: 12),
                ),
                const Spacer(),
                Text(
                  '${challenge.progress} / ${challenge.goal}',
                  style: TextStyle(color: AppColors.mutedForeground, fontSize: 12),
                ),
              ],
            ),
            const SizedBox(height: 7),
            ClipRRect(
              borderRadius: BorderRadius.circular(2),
              child: LinearProgressIndicator(
                value: progress,
                minHeight: 4,
                backgroundColor: AppColors.muted,
              ),
            ),
          ],
        );
      },
    );
  }
}

/// Preview library: titlu + „N available" + grid 5 coloane cu primele 4
/// coperte + tile „+N" (câte mai sunt).
class _LibraryPreview extends ConsumerWidget {
  const _LibraryPreview();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final async = ref.watch(myLibraryControllerProvider);
    return async.when(
      loading: () => const SizedBox.shrink(),
      error: (_, _) => const SizedBox.shrink(),
      data: (books) {
        // Doar cărțile „vii" (nu emptied shelves, nu trash) apar în preview -
        // afișăm inventarul curent.
        final active = books.where((b) => !b.permanentlyTransferred).toList();
        if (active.isEmpty) return const SizedBox.shrink();
        return InkWell(
          onTap: () => context.push('/library'),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Text(l10n.libraryTitle, style: Theme.of(context).textTheme.titleSmall),
                  const Spacer(),
                  Text(
                    l10n.profileLibraryAvailable(active.length),
                    style: TextStyle(color: AppColors.mutedForeground, fontSize: 11),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              // Copertele au lățime fixă și umplem rândul cu câte încap, în loc
              // să împărțim lățimea la 5: altfel, pe ecrane late, tile-urile
              // creșteau până la dimensiuni absurde.
              LayoutBuilder(
                builder: (context, constraints) {
                  const gap = 7.0;
                  // Guard pentru infinity: dacă părintele ne dă lățime
                  // neconstrânsă (ex. o pasă de măsurare), `.floor()` pe
                  // infinity aruncă UnsupportedError - același bug care în
                  // release lasă ecranul negru. Vezi _computeColumns din home.
                  final safeWidth =
                      constraints.maxWidth.isFinite && constraints.maxWidth > 0
                          ? constraints.maxWidth
                          : 300.0;
                  final slots = ((safeWidth + gap) / (kCoverTileWidth + gap))
                      .floor()
                      .clamp(2, 12);
                  final covers = active.take(slots - 1).toList();
                  final remaining = active.length - covers.length;
                  return Row(
                    children: [
                      for (final b in covers) ...[
                        SizedBox(
                          width: kCoverTileWidth,
                          child: AspectRatio(
                            aspectRatio: 2 / 3,
                            child: BookCover(url: b.book.coverUrl, borderRadius: 5),
                          ),
                        ),
                        const SizedBox(width: gap),
                      ],
                      SizedBox(
                        width: kCoverTileWidth,
                        child: AspectRatio(
                          aspectRatio: 2 / 3,
                          child: Container(
                            decoration: BoxDecoration(
                              color: AppColors.muted,
                              borderRadius: BorderRadius.circular(5),
                            ),
                            alignment: Alignment.center,
                            child: Text(
                              remaining > 0 ? '+$remaining' : '—',
                              style: TextStyle(
                                color: AppColors.mutedForeground,
                                fontSize: 12,
                              ),
                            ),
                          ),
                        ),
                      ),
                    ],
                  );
                },
              ),
            ],
          ),
        );
      },
    );
  }
}

/// Preview collections: chip-uri „nume · count". Ascuns dacă nu are colecții.
class _CollectionsPreview extends ConsumerWidget {
  const _CollectionsPreview();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final async = ref.watch(_myCollectionsPreviewProvider);
    return async.when(
      loading: () => const SizedBox.shrink(),
      error: (_, _) => const SizedBox.shrink(),
      data: (collections) {
        if (collections.isEmpty) return const SizedBox.shrink();
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(l10n.collectionsTitle, style: Theme.of(context).textTheme.titleSmall),
            const SizedBox(height: 10),
            Wrap(
              spacing: 7,
              runSpacing: 7,
              children: [
                for (final c in collections.take(6))
                  InkWell(
                    onTap: () => context.push('/collections/${c.id}'),
                    borderRadius: BorderRadius.circular(20),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
                      decoration: BoxDecoration(
                        border: Border.all(color: AppColors.border),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Text(
                        '${c.name} · ${c.itemCount}',
                        style: TextStyle(color: AppColors.mutedForeground, fontSize: 12),
                      ),
                    ),
                  ),
              ],
            ),
          ],
        );
      },
    );
  }
}

/// „Recent activity": ultimele acțiuni ale userului derivate din biblioteca
/// proprie (primele 4 cărți adăugate). Format compact stil twitter-timeline:
/// text stânga + timp relativ dreapta.
class _RecentActivityPreview extends ConsumerWidget {
  const _RecentActivityPreview();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final async = ref.watch(myLibraryControllerProvider);
    return async.when(
      loading: () => const SizedBox.shrink(),
      error: (_, _) => const SizedBox.shrink(),
      data: (books) {
        final events = books.take(4).toList();
        if (events.isEmpty) return const SizedBox.shrink();
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(l10n.profileRecentActivity,
                style: Theme.of(context).textTheme.titleSmall),
            const SizedBox(height: 10),
            for (final b in events)
              Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: Row(
                  children: [
                    Expanded(
                      child: Text.rich(
                        TextSpan(
                          text: '${l10n.profileActivityAdded} ',
                          style: TextStyle(color: AppColors.mutedForeground, fontSize: 12.5),
                          children: [
                            TextSpan(
                              text: b.book.title,
                              style: TextStyle(color: AppColors.foreground),
                            ),
                          ],
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    Text(
                      _relativeAge(b.createdAt),
                      style: TextStyle(color: AppColors.mutedForeground, fontSize: 12),
                    ),
                  ],
                ),
              ),
          ],
        );
      },
    );
  }

  static String _relativeAge(DateTime dt) {
    final diff = DateTime.now().difference(dt);
    if (diff.inMinutes < 60) return '${diff.inMinutes}m';
    if (diff.inHours < 24) return '${diff.inHours}h';
    if (diff.inDays < 7) return '${diff.inDays}d';
    if (diff.inDays < 30) return '${(diff.inDays / 7).floor()}w';
    return '${(diff.inDays / 30).floor()}mo';
  }
}

// Providers dedicati preview-urilor (evită dependența pe alte ecrane).
final _readingChallengeProvider = FutureProvider<ReadingChallenge>((ref) {
  return ref.watch(profileRepositoryProvider).getReadingChallenge();
});
final _myCollectionsPreviewProvider = FutureProvider<List<BookCollection>>((ref) {
  return ref.watch(collectionsRepositoryProvider).getMine();
});

