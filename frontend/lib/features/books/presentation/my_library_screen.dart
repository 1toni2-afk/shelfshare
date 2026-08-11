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

enum _StatusFilter { all, available, unavailable, transferred }

/// Categoria de anunț - derivată din câmpurile UserBook, nu stocată separat
/// (nu există coloană `listingType`; vezi și add_book_screen.dart#_ListingMode,
/// unde „donație" = preț 0 nenegociabil, aceeași convenție folosită aici).
enum _ListingCategory { swap, sale, auction, donation }

_ListingCategory _categoryOf(UserBook b) {
  if (b.isAuction) return _ListingCategory.auction;
  if (b.isForSale) {
    return (b.salePrice == null || b.salePrice == 0)
        ? _ListingCategory.donation
        : _ListingCategory.sale;
  }
  return _ListingCategory.swap;
}

extension on _ListingCategory {
  String label(AppLocalizations l10n) => switch (this) {
        _ListingCategory.swap => l10n.shareListingModeSwap,
        _ListingCategory.sale => l10n.shareListingModeSale,
        _ListingCategory.auction => l10n.shareListingModeAuction,
        _ListingCategory.donation => l10n.shareListingModeDonation,
      };
}

class _MyLibraryScreenState extends ConsumerState<MyLibraryScreen> {
  bool _sheetOpen = false;
  bool _isGridView = true;
  _StatusFilter _filter = _StatusFilter.all;
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
        // Fără `scrollable: true`, conținutul fix (2 câmpuri) + rândul de
        // acțiuni (Renunță/Trimite) nu au cum să se comprime când apare
        // tastatura - se suprapun cu al doilea câmp. Scrollable face
        // conținutul să deruleze sub tastatură, cu acțiunile mereu vizibile
        // dedesubt.
        scrollable: true,
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

  /// Grila sau lista de carduri pentru un subset filtrat. Shrink-wrapped și
  /// fără scroll propriu - trăiește într-un ListView exterior. `trailingAdd`
  /// adaugă un card „Add a book" la final - locul cel mai natural pentru
  /// acțiune, în grila unificată (Milestone 20).
  Widget _booksView(List<_ShelfItem> items, {bool trailingAdd = false}) {
    if (!_isGridView) {
      return ListView.separated(
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        itemCount: items.length + (trailingAdd ? 1 : 0),
        separatorBuilder: (_, _) => const SizedBox(height: 8),
        itemBuilder: (context, index) {
          if (index >= items.length) {
            return ListTile(
              leading: const Icon(Icons.add),
              title: Text(context.l10n.myShelfShare),
              onTap: () => context.push('/library/add'),
            );
          }
          final item = items[index];
          return _MyLibraryListRow(
            userBook: item.userBook,
            status: item.status,
            selected: _selectedIds.contains(item.userBook.id),
            onTap: item.status == _StatusFilter.transferred
                ? () => context.push('/books/${item.userBook.id}')
                : () => _handleTap(item.userBook),
            onLongPress: item.status == _StatusFilter.transferred
                ? null
                : () => _toggleSelected(item.userBook.id),
            onMenu: item.status == _StatusFilter.transferred
                ? null
                : () => _openActions(item.userBook),
          );
        },
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
      itemCount: items.length + (trailingAdd ? 1 : 0),
      itemBuilder: (context, index) {
        if (index >= items.length) {
          return _AddBookCard(onTap: () => context.push('/library/add'));
        }
        final item = items[index];
        return _MyLibraryCard(
          userBook: item.userBook,
          status: item.status,
          selected: _selectedIds.contains(item.userBook.id),
          onTap: item.status == _StatusFilter.transferred
              ? () => context.push('/books/${item.userBook.id}')
              : () => _handleTap(item.userBook),
          onLongPress: item.status == _StatusFilter.transferred
              ? null
              : () => _toggleSelected(item.userBook.id),
          onMenu: item.status == _StatusFilter.transferred
              ? null
              : () => _openActions(item.userBook),
        );
      },
    );
  }

  /// Grupează pe categorie de anunț (Swap/Vânzare/Licitație/Donație), ca în
  /// structura cerută - „Available: Swap, Donation, etc". Fiecare grup nevid
  /// primește un mic antet; ordinea e fixă (nu depinde de ce apare primul în
  /// listă), ca secțiunile să nu-și schimbe locul la fiecare refresh.
  Widget _categorizedView(List<_ShelfItem> items, {bool trailingAdd = false}) {
    final l10n = context.l10n;
    final byCategory = <_ListingCategory, List<_ShelfItem>>{};
    for (final item in items) {
      (byCategory[_categoryOf(item.userBook)] ??= []).add(item);
    }
    final nonEmptyCategories = [
      for (final category in _ListingCategory.values)
        if (byCategory[category]?.isNotEmpty ?? false) category,
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        for (final category in nonEmptyCategories) ...[
          Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: Text(
              '${category.label(l10n)} (${byCategory[category]!.length})',
              style: Theme.of(context).textTheme.labelLarge?.copyWith(color: AppColors.mutedForeground),
            ),
          ),
          _booksView(byCategory[category]!),
          if (category != nonEmptyCategories.last) const SizedBox(height: 20),
        ],
        if (trailingAdd) ...[
          if (nonEmptyCategories.isNotEmpty) const SizedBox(height: 20),
          _booksView(const [], trailingAdd: true),
        ],
      ],
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
    final isDesktop = MediaQuery.of(context).size.width >= 900;

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
              final transferred = ref.watch(emptiedShelvesProvider).value ?? const [];
              final available = [
                for (final b in books) if (b.availableForSwap) _ShelfItem(b, _StatusFilter.available),
              ];
              final unavailable = [
                for (final b in books) if (!b.availableForSwap) _ShelfItem(b, _StatusFilter.unavailable),
              ];
              final transferredItems = [
                for (final b in transferred) _ShelfItem(b, _StatusFilter.transferred),
              ];
              // Indisponibile ȘI transferate erau două categorii separate care,
              // pentru user, arătau ca „aceleași cărți" (ambele sunt cărți pe care
              // nu le mai poate schimba acum) - unificate într-un singur grup,
              // afișat restrâns by default (vezi ExpansionTile mai jos), fiecare
              // carte păstrându-și eticheta proprie (Indisponibilă/Transferată).
              final unavailableOrTransferred = [...unavailable, ...transferredItems];
              final all = [...available, ...unavailableOrTransferred];
              final filtered = switch (_filter) {
                _StatusFilter.all => all,
                _StatusFilter.available => available,
                _StatusFilter.unavailable => unavailableOrTransferred,
                _StatusFilter.transferred => unavailableOrTransferred,
              };

              final showCollapsedUnavailable = _filter == _StatusFilter.all;

              final mainColumn = ListView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.all(16),
                children: [
                  Text(
                    l10n.libraryShelfSubtitle(all.length, available.length),
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(color: AppColors.mutedForeground),
                  ),
                  const SizedBox(height: 12),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      _StatusPill(
                        label: l10n.libraryFilterAll(all.length),
                        selected: _filter == _StatusFilter.all,
                        onTap: () => setState(() => _filter = _StatusFilter.all),
                      ),
                      _StatusPill(
                        label: l10n.libraryFilterAvailable(available.length),
                        selected: _filter == _StatusFilter.available,
                        onTap: () => setState(() => _filter = _StatusFilter.available),
                      ),
                      _StatusPill(
                        label: l10n.libraryFilterUnavailable(unavailableOrTransferred.length),
                        selected: _filter == _StatusFilter.unavailable,
                        onTap: () => setState(() => _filter = _StatusFilter.unavailable),
                      ),
                    ],
                  ),
                  const SizedBox(height: 14),
                  const Divider(height: 1),
                  const SizedBox(height: 18),
                  if (showCollapsedUnavailable) ...[
                    _categorizedView(available, trailingAdd: true),
                    if (unavailableOrTransferred.isNotEmpty) ...[
                      const SizedBox(height: 18),
                      _UnavailableSection(
                        count: unavailableOrTransferred.length,
                        child: _categorizedView(unavailableOrTransferred),
                      ),
                    ],
                  ] else
                    _categorizedView(filtered, trailingAdd: true),
                ],
              );

              // Pe desktop, o coloană dreapta cu statistica raftului umple
              // golul mort din dreapta grid-ului - același tipar ca profilul
              // propriu (About/Stats/Top genres), nu doar conținutul întins
              // pe toată lățimea cu spațiu gol necontrolat lângă el.
              if (!isDesktop) return mainColumn;
              return Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(child: mainColumn),
                  SizedBox(
                    width: 280,
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(0, 16, 16, 16),
                      child: _ShelfOverviewCard(
                        total: all.length,
                        available: available.length,
                        unavailable: unavailable.length,
                        transferred: transferredItems.length,
                      ),
                    ),
                  ),
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

/// Secțiunea „Indisponibile" din tab-ul All - restrânsă by default (userul o
/// deschide explicit), ca lista principală să nu fie dominată de cărți pe
/// care nu le mai poate schimba acum oricum.
class _UnavailableSection extends StatelessWidget {
  const _UnavailableSection({required this.count, required this.child});
  final int count;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return Theme(
      data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
      child: ExpansionTile(
        initiallyExpanded: false,
        tilePadding: EdgeInsets.zero,
        title: Text(
          l10n.libraryFilterUnavailable(count),
          style: Theme.of(context).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w600),
        ),
        children: [Padding(padding: const EdgeInsets.only(top: 8), child: child)],
      ),
    );
  }
}

/// Un item al gridului unificat: cartea + statusul cu care e afișată acum
/// (poate diferi de `userBook.availableForSwap` pentru cele transferate, care
/// nu mai au sens ca „unavailable" - au propriul badge).
class _ShelfItem {
  const _ShelfItem(this.userBook, this.status);
  final UserBook userBook;
  final _StatusFilter status;
}

/// Badge-ul de status - același text/culoare pe card (grid) și pe rând (listă).
class _StatusChipLabel extends StatelessWidget {
  const _StatusChipLabel({required this.status, this.dense = false});
  final _StatusFilter status;
  final bool dense;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final (label, color, bg) = switch (status) {
      _StatusFilter.available => (
          l10n.libraryAvailable,
          AppColors.accent,
          AppColors.accent.withValues(alpha: dense ? 0.9 : 0.15),
        ),
      _StatusFilter.unavailable => (
          l10n.libraryUnavailable,
          AppColors.mutedForeground,
          dense ? AppColors.muted.withValues(alpha: 0.9) : AppColors.muted,
        ),
      _StatusFilter.transferred => (
          l10n.inventoryTransferred,
          AppColors.accent,
          AppColors.accent.withValues(alpha: dense ? 0.9 : 0.15),
        ),
      _StatusFilter.all => (l10n.libraryAvailable, AppColors.accent, AppColors.accent.withValues(alpha: 0.15)),
    };
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(8)),
      child: Text(
        label,
        style: Theme.of(context).textTheme.bodySmall?.copyWith(
              color: dense && status == _StatusFilter.available ? AppColors.primaryForeground : color,
              fontWeight: FontWeight.w600,
              fontSize: dense ? 11 : null,
            ),
      ),
    );
  }
}

class _MyLibraryListRow extends StatelessWidget {
  const _MyLibraryListRow({
    required this.userBook,
    required this.status,
    required this.onTap,
    this.onLongPress,
    this.onMenu,
    this.selected = false,
  });
  final UserBook userBook;
  final _StatusFilter status;
  final VoidCallback onTap;
  final VoidCallback? onLongPress;
  final VoidCallback? onMenu;
  final bool selected;

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: EdgeInsets.zero,
      color: selected ? AppColors.accent.withValues(alpha: 0.1) : null,
      child: Opacity(
        opacity: status == _StatusFilter.available ? 1 : 0.75,
        child: ListTile(
          onTap: onTap,
          onLongPress: onLongPress,
          leading: selected
              ? const Icon(Icons.check_circle, color: AppColors.accent)
              : BookCover(
                  url: userBook.book.coverUrl,
                  fallbackUrl: userBook.photos.isNotEmpty ? userBook.photos.first : null,
                  title: userBook.book.title,
                  width: 44,
                  height: 62,
                ),
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
              _StatusChipLabel(status: status),
              if (onMenu != null)
                IconButton(
                  icon: const Icon(Icons.more_horiz),
                  tooltip: context.l10n.libraryEditListing,
                  onPressed: onMenu,
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _MyLibraryCard extends StatelessWidget {
  const _MyLibraryCard({
    required this.userBook,
    required this.status,
    required this.onTap,
    this.onLongPress,
    this.onMenu,
    this.selected = false,
  });
  final UserBook userBook;
  final _StatusFilter status;
  final VoidCallback onTap;
  final VoidCallback? onLongPress;
  final VoidCallback? onMenu;
  final bool selected;

  @override
  Widget build(BuildContext context) {
    // Fără lățime fixă: cardul umple celula grilei, ca pe Home. Eticheta de
    // status stă peste copertă (colț stânga-sus), „⋯" în colțul opus - nu
    // mai concurează cu inima de wishlist din alte ecrane (Milestone 20).
    return GestureDetector(
      onLongPress: onLongPress,
      child: Opacity(
        opacity: status == _StatusFilter.available ? 1 : 0.65,
        child: Stack(
          children: [
            BookCard(userBook: userBook, onTap: onTap, showWishlistHeart: false),
            Positioned(
              top: 6,
              left: 6,
              child: _StatusChipLabel(status: status, dense: true),
            ),
            if (selected)
              const Positioned(
                top: 6,
                right: 6,
                child: Icon(Icons.check_circle, color: AppColors.accent),
              )
            else if (onMenu != null)
              Positioned(
                top: 0,
                right: 0,
                child: Material(
                  color: Colors.transparent,
                  child: IconButton(
                    icon: const Icon(Icons.more_horiz, size: 18),
                    tooltip: context.l10n.libraryEditListing,
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
      ),
    );
  }
}

/// Coloana dreapta pe desktop (Milestone 23): un rezumat rapid al raftului,
/// în același spirit ca cardurile din profilul propriu. Nu introduce date
/// noi - doar sumarizează ce oricum se calculează pentru filtre.
class _ShelfOverviewCard extends StatelessWidget {
  const _ShelfOverviewCard({
    required this.total,
    required this.available,
    required this.unavailable,
    required this.transferred,
  });
  final int total;
  final int available;
  final int unavailable;
  final int transferred;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(l10n.libraryOverviewTitle, style: Theme.of(context).textTheme.titleSmall),
            const SizedBox(height: 14),
            _OverviewRow(color: AppColors.accent, label: l10n.libraryAvailable, count: available, total: total),
            const SizedBox(height: 10),
            _OverviewRow(
                color: AppColors.mutedForeground, label: l10n.libraryUnavailable, count: unavailable, total: total),
            const SizedBox(height: 10),
            _OverviewRow(
                color: AppColors.primary, label: l10n.inventoryTransferred, count: transferred, total: total),
            const Divider(height: 28),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(l10n.libraryOverviewTotal, style: Theme.of(context).textTheme.bodyMedium),
                Text('$total', style: Theme.of(context).textTheme.titleMedium),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _OverviewRow extends StatelessWidget {
  const _OverviewRow({
    required this.color,
    required this.label,
    required this.count,
    required this.total,
  });
  final Color color;
  final String label;
  final int count;
  final int total;

  @override
  Widget build(BuildContext context) {
    final ratio = total == 0 ? 0.0 : count / total;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(label, style: Theme.of(context).textTheme.bodySmall),
            Text('$count', style: Theme.of(context).textTheme.bodySmall?.copyWith(fontWeight: FontWeight.w600)),
          ],
        ),
        const SizedBox(height: 4),
        ClipRRect(
          borderRadius: BorderRadius.circular(3),
          child: LinearProgressIndicator(
            value: ratio,
            minHeight: 5,
            backgroundColor: AppColors.muted,
            valueColor: AlwaysStoppedAnimation(color),
          ),
        ),
      ],
    );
  }
}

class _StatusPill extends StatelessWidget {
  const _StatusPill({required this.label, required this.selected, required this.onTap});
  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(999),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
        decoration: BoxDecoration(
          color: selected ? AppColors.accent.withValues(alpha: 0.15) : Colors.transparent,
          borderRadius: BorderRadius.circular(999),
          border: Border.all(color: selected ? AppColors.accent.withValues(alpha: 0.4) : AppColors.border),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 13,
            color: selected ? AppColors.accent : AppColors.mutedForeground,
            fontWeight: selected ? FontWeight.w600 : FontWeight.normal,
          ),
        ),
      ),
    );
  }
}

class _AddBookCard extends StatelessWidget {
  const _AddBookCard({required this.onTap});
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: AspectRatio(
        aspectRatio: 2 / 3,
        child: DecoratedBox(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: AppColors.border, style: BorderStyle.solid),
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.add, size: 22, color: AppColors.mutedForeground),
              const SizedBox(height: 6),
              Text(context.l10n.myShelfShare, style: TextStyle(fontSize: 12, color: AppColors.mutedForeground)),
            ],
          ),
        ),
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

