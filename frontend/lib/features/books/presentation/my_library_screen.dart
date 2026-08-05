import 'package:dio/dio.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/locale/l10n_extensions.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/utils/browser_download.dart';
import '../../../l10n/app_localizations.dart';
import '../../../data/models/book.dart';
import '../../../data/models/user_book.dart';
import '../../../shared/widgets/book_card.dart';
import '../../../shared/widgets/book_cover.dart';
import '../../../shared/widgets/book_grid_metrics.dart';
import '../../../shared/widgets/centered_scrollable.dart';
import '../application/my_library_controller.dart';
import '../data/books_repository.dart';
import 'edit_listing_sheet.dart';

class MyLibraryScreen extends ConsumerStatefulWidget {
  const MyLibraryScreen({super.key});

  @override
  ConsumerState<MyLibraryScreen> createState() => _MyLibraryScreenState();
}

class _MyLibraryScreenState extends ConsumerState<MyLibraryScreen> {
  bool _sheetOpen = false;
  bool _isGridView = true;
  final Set<String> _selectedIds = {};

  bool get _selectionMode => _selectedIds.isNotEmpty;

  void _toggleSelected(String userBookId) {
    setState(() {
      if (_selectedIds.contains(userBookId)) {
        _selectedIds.remove(userBookId);
      } else {
        _selectedIds.add(userBookId);
      }
    });
  }

  void _handleTap(UserBook userBook) {
    if (_selectionMode) {
      _toggleSelected(userBook.id);
    } else {
      // Click pe listare => pagina anunțului (unde e și opțiunea de edit pentru
      // cărțile proprii). Acțiunile rapide (edit/disponibilitate/șterge) rămân
      // la un tap distanță prin cele 3 puncte de pe card. (Milestone 18)
      context.push('/books/${userBook.id}', extra: userBook.owner);
    }
  }

  /// Bulk edit descrieri: dialog cu 2 câmpuri (adaugă la sfârșit, șterge din
  /// text). Aplicat pe cărțile selectate care nu sunt permanent transferate
  /// și nici în coșul de gunoi.
  Future<void> _bulkEditDescriptions(List<UserBook> allBooks) async {
    final l10n = context.l10n;
    final appendController = TextEditingController();
    final removeController = TextEditingController();
    final result = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(l10n.inventoryBulkEditDescription),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: appendController,
              maxLines: 3,
              decoration: InputDecoration(labelText: l10n.inventoryAppendText),
            ),
            const SizedBox(height: 8),
            TextField(
              controller: removeController,
              decoration: InputDecoration(labelText: l10n.inventoryRemoveText),
            ),
          ],
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: Text(l10n.commonGiveUp)),
          TextButton(
              onPressed: () => Navigator.of(context).pop(true),
              child: Text(l10n.commonSubmit)),
        ],
      ),
    );
    if (result != true) return;

    final append = appendController.text;
    final remove = removeController.text;
    if (append.isEmpty && remove.isEmpty) return;

    final selectedBooks = allBooks
        .where((b) => _selectedIds.contains(b.id) && !b.permanentlyTransferred)
        .toList();

    final changed = await ref
        .read(myLibraryControllerProvider.notifier)
        .bulkTransformDescriptions(selectedBooks, (current) {
      var next = current;
      if (remove.isNotEmpty) next = next.replaceAll(remove, '');
      if (append.isNotEmpty) {
        next = next.isEmpty ? append : '$next $append';
      }
      // Limita e enforced pe backend, dar tăiem local ca să nu-i dam 400 pe
      // useri care ar depăși constant.
      if (next.length > 256) next = next.substring(0, 256);
      return next;
    });
    if (mounted) {
      setState(() => _selectedIds.clear());
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('${l10n.inventoryDescriptionDone} ($changed)')),
      );
    }
  }

  /// Marchează în bulk anunțurile ca disponibile sau nu (înlocuiește vechiul
  /// buton unidirecțional de „ascunde" - user cerea și calea inversă).
  Future<void> _bulkSetAvailability(bool available) async {
    final notifier = ref.read(myLibraryControllerProvider.notifier);
    for (final id in _selectedIds.toList()) {
      await notifier.setAvailability(id, availableForSwap: available);
    }
    if (mounted) {
      setState(() => _selectedIds.clear());
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(context.l10n.inventoryBulkDone)));
    }
  }

  Future<void> _bulkDelete() async {
    final l10n = context.l10n;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(l10n.inventoryDeleteConfirmTitle),
        content: Text(l10n.inventoryDeleteConfirmBody(_selectedIds.length)),
        actions: [
          TextButton(onPressed: () => Navigator.of(context).pop(false), child: Text(l10n.commonGiveUp)),
          TextButton(onPressed: () => Navigator.of(context).pop(true), child: Text(l10n.commonDelete)),
        ],
      ),
    );
    if (confirmed != true) return;

    final notifier = ref.read(myLibraryControllerProvider.notifier);
    for (final id in _selectedIds.toList()) {
      await notifier.deleteBook(id);
    }
    if (mounted) {
      setState(() => _selectedIds.clear());
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(l10n.inventoryBulkDone)));
    }
  }

  /// Grila sau lista de carduri pentru un subset (disponibile / indisponibile).
  /// Shrink-wrapped și fără scroll propriu - trăiește într-un ListView exterior.
  Widget _booksView(List<UserBook> books) {
    if (!_isGridView) {
      return ListView.separated(
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        itemCount: books.length,
        separatorBuilder: (_, _) => const SizedBox(height: 8),
        itemBuilder: (context, index) => _MyLibraryListRow(
          userBook: books[index],
          selected: _selectedIds.contains(books[index].id),
          onTap: () => _handleTap(books[index]),
          onLongPress: () => _toggleSelected(books[index].id),
          onMenu: () => _openActions(books[index]),
        ),
      );
    }
    // Aceeași grilă ca pe Home (vezi book_grid_metrics.dart).
    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
        maxCrossAxisExtent: kBookCardMaxWidth,
        mainAxisSpacing: kBookGridMainAxisSpacing,
        crossAxisSpacing: kBookGridCrossAxisSpacing,
        childAspectRatio: kBookCardAspectRatio,
      ),
      itemCount: books.length,
      itemBuilder: (context, index) {
        final userBook = books[index];
        return _MyLibraryCard(
          userBook: userBook,
          selected: _selectedIds.contains(userBook.id),
          onTap: () => _handleTap(userBook),
          onLongPress: () => _toggleSelected(userBook.id),
          onMenu: () => _openActions(userBook),
        );
      },
    );
  }

  Future<void> _openActions(UserBook userBook) async {
    if (_sheetOpen) return;
    _sheetOpen = true;
    await showModalBottomSheet<void>(
      context: context,
      builder: (context) => _BookActionsSheet(userBook: userBook),
    );
    _sheetOpen = false;
  }

  void _exportCsv(AppLocalizations l10n, List<UserBook> books) {
    final rows = [
      [
        l10n.csvHeaderTitle,
        l10n.filtersAuthor,
        l10n.filtersCondition,
        l10n.filtersLanguage,
        l10n.csvHeaderAvailableForSwap,
        l10n.csvHeaderForSale,
        l10n.csvHeaderPrice,
      ].join(','),
      for (final b in books)
        [
          _csvEscape(b.book.title),
          _csvEscape(b.book.author ?? ''),
          b.condition.label(l10n),
          b.language ?? '',
          b.availableForSwap ? l10n.commonYes : l10n.commonNo,
          b.isForSale ? l10n.commonYes : l10n.commonNo,
          b.salePrice?.toStringAsFixed(0) ?? '',
        ].join(','),
    ];
    downloadTextFile(
      filename: 'biblioteca-shelfshare.csv',
      content: rows.join('\r\n'),
      mimeType: 'text/csv',
    );
  }

  String _csvEscape(String value) {
    if (value.contains(',') || value.contains('"')) {
      return '"${value.replaceAll('"', '""')}"';
    }
    return value;
  }

  Future<void> _importListingsCsv() async {
    final l10n = context.l10n;
    final result = await FilePicker.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['csv'],
      withData: true,
    );
    final file = result?.files.firstOrNull;
    if (file?.bytes == null) return;
    if (!mounted) return;

    showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (_) => const Center(child: CircularProgressIndicator()),
    );
    try {
      final summary = await ref
          .read(booksRepositoryProvider)
          .importListingsCsv(bytes: file!.bytes!, filename: file.name);
      ref.invalidate(myLibraryControllerProvider);
      if (mounted) {
        Navigator.of(context, rootNavigator: true).pop();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(l10n.libraryImportSummary(summary.created.length, summary.failed.length))),
        );
      }
    } on DioException catch (e) {
      if (mounted) {
        Navigator.of(context, rootNavigator: true).pop();
        final data = e.response?.data;
        final message = data is Map && data['message'] != null
            ? (data['message'] is List ? (data['message'] as List).join(', ') : data['message'].toString())
            : l10n.libraryImportError;
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(myLibraryControllerProvider);
    final l10n = context.l10n;

    return Scaffold(
      appBar: _selectionMode
          ? AppBar(
              title: Text(l10n.inventorySelectedCount(_selectedIds.length)),
              leading: IconButton(
                icon: const Icon(Icons.close),
                onPressed: () => setState(() => _selectedIds.clear()),
              ),
              actions: [
                IconButton(
                  icon: const Icon(Icons.select_all),
                  tooltip: l10n.inventorySelectAll,
                  onPressed: () => setState(() {
                    // Toggle: dacă toate sunt deja selectate, deselectează tot;
                    // altfel selectează tot ce e afișat curent.
                    final all = (state.value ?? const []).map((b) => b.id).toSet();
                    if (_selectedIds.length == all.length) {
                      _selectedIds.clear();
                    } else {
                      _selectedIds
                        ..clear()
                        ..addAll(all);
                    }
                  }),
                ),
              ],
            )
          : AppBar(
              title: Text(l10n.libraryTitle),
              actions: [
                IconButton(
                  icon: Icon(_isGridView ? Icons.view_list_outlined : Icons.grid_view_outlined),
                  tooltip: _isGridView ? l10n.libraryViewAsList : l10n.libraryViewAsGrid,
                  onPressed: () => setState(() => _isGridView = !_isGridView),
                ),
                PopupMenuButton<String>(
                  icon: const Icon(Icons.more_vert),
                  onSelected: (value) {
                    switch (value) {
                      case 'export':
                        _exportCsv(l10n, state.value ?? const []);
                      case 'import':
                        _importListingsCsv();
                      case 'bulk-add':
                        context.push('/library/bulk-add');
                      case 'trash':
                        context.push('/library/trash');
                    }
                  },
                  itemBuilder: (context) => [
                    PopupMenuItem(value: 'export', child: Text(l10n.libraryExportCsv)),
                    PopupMenuItem(value: 'import', child: Text(l10n.libraryImportCsv)),
                    PopupMenuItem(value: 'bulk-add', child: Text(l10n.libraryBulkAdd)),
                    PopupMenuItem(value: 'trash', child: Text(l10n.libraryTrash)),
                  ],
                ),
              ],
            ),
      // FAB extended = iconă + label (cerință Milestone 10). Icon-ul simplu era
      // greu de descifrat pentru useri noi. Labelul NU conține „+" - plusul e
      // deja în iconiță, iar împreună apăreau două.
      floatingActionButton: _selectionMode
          ? null
          : FloatingActionButton.extended(
              onPressed: () => context.push('/library/add'),
              icon: const Icon(Icons.add),
              label: Text(l10n.myShelfShare),
            ),
      bottomNavigationBar: _selectionMode
          ? BottomAppBar(
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  IconButton(
                    icon: const Icon(Icons.visibility_off_outlined),
                    tooltip: l10n.inventoryMarkUnavailable,
                    onPressed: () => _bulkSetAvailability(false),
                  ),
                  IconButton(
                    icon: const Icon(Icons.visibility_outlined),
                    tooltip: l10n.inventoryMarkAvailable,
                    onPressed: () => _bulkSetAvailability(true),
                  ),
                  IconButton(
                    icon: const Icon(Icons.edit_note),
                    tooltip: l10n.inventoryBulkEditDescription,
                    onPressed: () => _bulkEditDescriptions(state.value ?? const []),
                  ),
                  IconButton(
                    icon: const Icon(Icons.delete_outline),
                    tooltip: l10n.commonDelete,
                    onPressed: _bulkDelete,
                  ),
                ],
              ),
            )
          : null,
      body: SafeArea(
        child: RefreshIndicator(
          onRefresh: () => ref.read(myLibraryControllerProvider.notifier).refresh(),
          child: state.when(
            data: (books) {
              if (books.isEmpty) {
                return CenteredScrollable(
                  child: Text(l10n.libraryEmpty),
                );
              }
              // Milestone 18: cărțile disponibile se văd toate direct;
              // indisponibilele stau într-un dropdown închis by default.
              final available = [
                for (final b in books) if (b.availableForSwap) b,
              ];
              final unavailable = [
                for (final b in books) if (!b.availableForSwap) b,
              ];
              return ListView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.all(16),
                children: [
                  if (available.isNotEmpty) _booksView(available),
                  if (unavailable.isNotEmpty) ...[
                    const SizedBox(height: 8),
                    Theme(
                      // Ascundem liniile implicite ale ExpansionTile.
                      data: Theme.of(context)
                          .copyWith(dividerColor: Colors.transparent),
                      child: ExpansionTile(
                        tilePadding: EdgeInsets.zero,
                        childrenPadding: const EdgeInsets.only(top: 8),
                        initiallyExpanded: false,
                        title: Text(
                          '${l10n.libraryUnavailable} (${unavailable.length})',
                          style: Theme.of(context)
                              .textTheme
                              .titleSmall
                              ?.copyWith(color: AppColors.mutedForeground),
                        ),
                        children: [_booksView(unavailable)],
                      ),
                    ),
                  ],
                  const SizedBox(height: 32),
                  const _EmptiedShelvesSection(),
                ],
              );
            },
            loading: () => const CenteredScrollable(child: CircularProgressIndicator()),
            error: (error, _) => CenteredScrollable(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(l10n.libraryLoadError),
                  const SizedBox(height: 8),
                  OutlinedButton(
                    onPressed: () => ref.read(myLibraryControllerProvider.notifier).refresh(),
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

class _MyLibraryListRow extends StatelessWidget {
  const _MyLibraryListRow({
    required this.userBook,
    required this.onTap,
    required this.onLongPress,
    required this.onMenu,
    this.selected = false,
  });
  final UserBook userBook;
  final VoidCallback onTap;
  final VoidCallback onLongPress;
  final VoidCallback onMenu;
  final bool selected;

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: EdgeInsets.zero,
      color: selected ? AppColors.accent.withValues(alpha: 0.1) : null,
      child: ListTile(
        onTap: onTap,
        onLongPress: onLongPress,
        leading: selected
            ? const Icon(Icons.check_circle, color: AppColors.accent)
            : BookCover(url: userBook.book.coverUrl, fallbackUrl: userBook.photos.isNotEmpty ? userBook.photos.first : null, width: 44, height: 62),
        title: Text(userBook.book.title, maxLines: 1, overflow: TextOverflow.ellipsis),
        subtitle: Text(
          [
            if (userBook.book.author != null) userBook.book.author!,
            userBook.condition.label(context.l10n),
            if (userBook.isForSale && userBook.salePrice != null)
              context.l10n.priceLei(userBook.salePrice!.toStringAsFixed(0)),
          ].join(' · '),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
              decoration: BoxDecoration(
                color: userBook.availableForSwap
                    ? AppColors.accent.withValues(alpha: 0.15)
                    : AppColors.muted,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                userBook.availableForSwap ? context.l10n.libraryAvailable : context.l10n.libraryUnavailable,
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: userBook.availableForSwap ? AppColors.accent : AppColors.mutedForeground,
                      fontWeight: FontWeight.w600,
                    ),
              ),
            ),
            // 3 puncte: acțiuni pe anunț (editează, disponibilitate, șterge).
            IconButton(
              icon: const Icon(Icons.more_vert),
              tooltip: context.l10n.libraryEditListing,
              onPressed: onMenu,
            ),
          ],
        ),
      ),
    );
  }
}

class _MyLibraryCard extends StatelessWidget {
  const _MyLibraryCard({
    required this.userBook,
    required this.onTap,
    required this.onLongPress,
    required this.onMenu,
    this.selected = false,
  });
  final UserBook userBook;
  final VoidCallback onTap;
  final VoidCallback onLongPress;
  final VoidCallback onMenu;
  final bool selected;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;

    // Fără lățime fixă: cardul umple celula grilei, ca pe Home. Eticheta de
    // disponibilitate stă peste copertă, nu sub card - dedesubt ar fi depășit
    // înălțimea celulei (kBookCardAspectRatio e calculat pentru copertă +
    // titlu + autor, atât).
    return GestureDetector(
      onLongPress: onLongPress,
      child: Stack(
        children: [
          BookCard(userBook: userBook, onTap: onTap),
          Positioned(
            top: 6,
            left: 6,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
              decoration: BoxDecoration(
                color: userBook.availableForSwap
                    ? AppColors.accent.withValues(alpha: 0.9)
                    : AppColors.muted.withValues(alpha: 0.9),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                userBook.availableForSwap ? l10n.libraryAvailable : l10n.libraryUnavailable,
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: userBook.availableForSwap
                          ? AppColors.primaryForeground
                          : AppColors.mutedForeground,
                      fontWeight: FontWeight.w600,
                      fontSize: 11,
                    ),
              ),
            ),
          ),
          if (selected)
            const Positioned(
              top: 6,
              right: 6,
              child: Icon(Icons.check_circle, color: AppColors.accent),
            )
          else
            // 3 puncte în dreapta sus: acțiuni pe anunț (editează,
            // disponibilitate, șterge). Ascuns în modul de selecție, unde locul
            // e ocupat de bifă.
            Positioned(
              top: 0,
              right: 0,
              child: Material(
                color: Colors.transparent,
                child: IconButton(
                  icon: const Icon(Icons.more_vert, size: 20),
                  tooltip: l10n.libraryEditListing,
                  style: IconButton.styleFrom(
                    backgroundColor: AppColors.muted.withValues(alpha: 0.7),
                    minimumSize: const Size(32, 32),
                    padding: EdgeInsets.zero,
                  ),
                  onPressed: onMenu,
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _BookActionsSheet extends ConsumerWidget {
  const _BookActionsSheet({required this.userBook});
  final UserBook userBook;

  Future<void> _confirmDelete(BuildContext context, WidgetRef ref) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(context.l10n.libraryDeleteConfirmTitle),
        content: Text(context.l10n.libraryDeleteConfirmBody(userBook.book.title)),
        actions: [
          // Ambele butoane albe (Milestone 18) - implicit erau în culoarea de
          // accent, greu de citit pe fundalul dialogului.
          TextButton(
            style: TextButton.styleFrom(foregroundColor: Colors.white),
            onPressed: () => Navigator.of(context).pop(false),
            child: Text(context.l10n.commonGiveUp),
          ),
          TextButton(
            style: TextButton.styleFrom(foregroundColor: Colors.white),
            onPressed: () => Navigator.of(context).pop(true),
            child: Text(context.l10n.commonDelete),
          ),
        ],
      ),
    );
    if (confirmed == true) {
      await ref.read(myLibraryControllerProvider.notifier).deleteBook(userBook.id);
      if (context.mounted) {
        Navigator.of(context).pop();
      }
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final books = ref.watch(myLibraryControllerProvider).value ?? const [];
    final current = books.firstWhere(
      (book) => book.id == userBook.id,
      orElse: () => userBook,
    );

    return SafeArea(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(24, 24, 24, 8),
            child: Text(current.book.title, style: Theme.of(context).textTheme.titleLarge),
          ),
          SwitchListTile(
            title: Text(context.l10n.libraryAvailableForSwap),
            value: current.availableForSwap,
            onChanged: (value) => ref
                .read(myLibraryControllerProvider.notifier)
                .setAvailability(userBook.id, availableForSwap: value),
          ),
          ListTile(
            leading: const Icon(Icons.edit_outlined),
            title: Text(context.l10n.libraryEditListing),
            onTap: () async {
              Navigator.of(context).pop();
              await showModalBottomSheet<void>(
                context: context,
                isScrollControlled: true,
                builder: (context) => EditListingSheet(userBook: current),
              );
            },
          ),
          ListTile(
            leading: const Icon(Icons.delete_outline, color: AppColors.destructive),
            title: Text(context.l10n.libraryDeleteBook, style: const TextStyle(color: AppColors.destructive)),
            onTap: () => _confirmDelete(context, ref),
          ),
          const SizedBox(height: 8),
        ],
      ),
    );
  }
}

/// „Emptied Shelves" - cărțile deja transferate. Marcate ca istoric imutabil
/// în josul bibliotecii, cu badge de „schimbată" - user cerea să apară
/// permanent ca fiind indisponibile.
class _EmptiedShelvesSection extends ConsumerWidget {
  const _EmptiedShelvesSection();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final async = ref.watch(emptiedShelvesProvider);
    return async.when(
      loading: () => const SizedBox.shrink(),
      error: (_, _) => const SizedBox.shrink(),
      data: (items) {
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.archive_outlined, size: 20, color: AppColors.mutedForeground),
                const SizedBox(width: 8),
                Text(
                  l10n.libraryEmptiedShelves,
                  style: Theme.of(context).textTheme.titleMedium,
                ),
              ],
            ),
            const SizedBox(height: 12),
            if (items.isEmpty)
              Text(
                l10n.libraryEmptiedShelvesEmpty,
                style: Theme.of(context).textTheme.bodySmall,
              )
            else
              Wrap(
                spacing: 12,
                runSpacing: 12,
                children: [
                  for (final b in items) _EmptiedShelfCard(userBook: b),
                ],
              ),
          ],
        );
      },
    );
  }
}

class _EmptiedShelfCard extends StatelessWidget {
  const _EmptiedShelfCard({required this.userBook});
  final UserBook userBook;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 120,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Stack(
            children: [
              // Cover afișat cu opacitate redusă ca să indice „nu mai e activă".
              Opacity(
                opacity: 0.55,
                child: BookCover(url: userBook.book.coverUrl, fallbackUrl: userBook.photos.isNotEmpty ? userBook.photos.first : null, width: 120, height: 168),
              ),
              Positioned(
                left: 4,
                top: 4,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                    color: AppColors.foreground.withValues(alpha: 0.8),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Text(
                    context.l10n.inventoryTransferred,
                    style: TextStyle(color: AppColors.background, fontSize: 10),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            userBook.book.title,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: Theme.of(context).textTheme.bodySmall,
          ),
        ],
      ),
    );
  }
}
