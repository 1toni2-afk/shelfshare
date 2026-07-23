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
import '../../../shared/widgets/centered_scrollable.dart';
import '../application/my_library_controller.dart';
import '../data/books_repository.dart';

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
      _openActions(userBook);
    }
  }

  Future<void> _bulkMarkUnavailable(List<UserBook> books) async {
    final notifier = ref.read(myLibraryControllerProvider.notifier);
    for (final id in _selectedIds.toList()) {
      await notifier.setAvailability(id, availableForSwap: false);
    }
    if (mounted) {
      setState(() => _selectedIds.clear());
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(context.l10n.inventoryBulkDone)));
    }
  }

  Future<void> _bulkChangePrice(List<UserBook> books) async {
    final l10n = context.l10n;
    final priceController = TextEditingController();
    final newPrice = await showDialog<double>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(l10n.inventoryChangePriceTitle),
        content: TextField(
          controller: priceController,
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          decoration: InputDecoration(labelText: l10n.addBookPriceLabel, suffixText: 'lei'),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.of(context).pop(), child: Text(l10n.commonGiveUp)),
          TextButton(
            onPressed: () =>
                Navigator.of(context).pop(double.tryParse(priceController.text.trim().replaceAll(',', '.'))),
            child: Text(l10n.commonSubmit),
          ),
        ],
      ),
    );
    if (newPrice == null) return;

    final notifier = ref.read(myLibraryControllerProvider.notifier);
    var changed = 0;
    for (final id in _selectedIds.toList()) {
      UserBook? book;
      for (final b in books) {
        if (b.id == id) book = b;
      }
      if (book == null || !book.isForSale) continue;
      await notifier.editListing(
        id,
        condition: book.condition,
        language: book.language,
        edition: book.edition,
        isHardcover: book.isHardcover,
        isForSale: true,
        salePrice: newPrice,
        isNegotiable: book.isNegotiable,
      );
      changed++;
    }
    if (mounted) {
      setState(() => _selectedIds.clear());
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(l10n.inventoryPriceChangedCount(changed))));
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
          b.condition.label,
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
    final result = await FilePicker.platform.pickFiles(
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
                    }
                  },
                  itemBuilder: (context) => [
                    PopupMenuItem(value: 'export', child: Text(l10n.libraryExportCsv)),
                    PopupMenuItem(value: 'import', child: Text(l10n.libraryImportCsv)),
                    PopupMenuItem(value: 'bulk-add', child: Text(l10n.libraryBulkAdd)),
                  ],
                ),
              ],
            ),
      floatingActionButton: _selectionMode
          ? null
          : FloatingActionButton(
              onPressed: () => context.push('/library/add'),
              child: const Icon(Icons.add),
            ),
      bottomNavigationBar: _selectionMode
          ? BottomAppBar(
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  IconButton(
                    icon: const Icon(Icons.visibility_off_outlined),
                    tooltip: l10n.inventoryMarkUnavailable,
                    onPressed: () => _bulkMarkUnavailable(state.value ?? const []),
                  ),
                  IconButton(
                    icon: const Icon(Icons.sell_outlined),
                    tooltip: l10n.inventoryChangePriceTitle,
                    onPressed: () => _bulkChangePrice(state.value ?? const []),
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
              if (!_isGridView) {
                return ListView.separated(
                  physics: const AlwaysScrollableScrollPhysics(),
                  padding: const EdgeInsets.all(16),
                  itemCount: books.length,
                  separatorBuilder: (_, _) => const SizedBox(height: 8),
                  itemBuilder: (context, index) => _MyLibraryListRow(
                    userBook: books[index],
                    selected: _selectedIds.contains(books[index].id),
                    onTap: () => _handleTap(books[index]),
                    onLongPress: () => _toggleSelected(books[index].id),
                  ),
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
                      for (final userBook in books)
                        _MyLibraryCard(
                          userBook: userBook,
                          selected: _selectedIds.contains(userBook.id),
                          onTap: () => _handleTap(userBook),
                          onLongPress: () => _toggleSelected(userBook.id),
                        ),
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
    this.selected = false,
  });
  final UserBook userBook;
  final VoidCallback onTap;
  final VoidCallback onLongPress;
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
            : BookCover(url: userBook.book.coverUrl, width: 44, height: 62),
        title: Text(userBook.book.title, maxLines: 1, overflow: TextOverflow.ellipsis),
        subtitle: Text(
          [
            if (userBook.book.author != null) userBook.book.author!,
            userBook.condition.label,
            if (userBook.isForSale && userBook.salePrice != null)
              context.l10n.priceLei(userBook.salePrice!.toStringAsFixed(0)),
          ].join(' · '),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        trailing: Container(
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
      ),
    );
  }
}

class _MyLibraryCard extends StatelessWidget {
  const _MyLibraryCard({
    required this.userBook,
    required this.onTap,
    required this.onLongPress,
    this.selected = false,
  });
  final UserBook userBook;
  final VoidCallback onTap;
  final VoidCallback onLongPress;
  final bool selected;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 160,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          GestureDetector(
            onLongPress: onLongPress,
            child: Stack(
              children: [
                BookCard(userBook: userBook, onTap: onTap, width: 160),
                if (selected)
                  const Positioned(
                    top: 4,
                    right: 4,
                    child: Icon(Icons.check_circle, color: AppColors.accent),
                  ),
              ],
            ),
          ),
          const SizedBox(height: 6),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
            decoration: BoxDecoration(
              color: userBook.availableForSwap
                  ? AppColors.accent.withValues(alpha: 0.15)
                  : AppColors.muted,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Text(
              userBook.availableForSwap ? 'Disponibilă' : 'Indisponibilă',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: userBook.availableForSwap ? AppColors.accent : AppColors.mutedForeground,
                    fontWeight: FontWeight.w600,
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
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: Text(context.l10n.commonGiveUp),
          ),
          TextButton(
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
                builder: (context) => _EditListingSheet(userBook: current),
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

class _EditListingSheet extends ConsumerStatefulWidget {
  const _EditListingSheet({required this.userBook});
  final UserBook userBook;

  @override
  ConsumerState<_EditListingSheet> createState() => _EditListingSheetState();
}

class _EditListingSheetState extends ConsumerState<_EditListingSheet> {
  late BookCondition _condition = widget.userBook.condition;
  late final _languageController = TextEditingController(text: widget.userBook.language);
  late final _editionController = TextEditingController(text: widget.userBook.edition);
  late bool _isHardcover = widget.userBook.isHardcover;
  late bool _isForSale = widget.userBook.isForSale;
  late bool _isNegotiable = widget.userBook.isNegotiable;
  late final _priceController = TextEditingController(
    text: widget.userBook.salePrice?.toStringAsFixed(0) ?? '',
  );
  bool _isSubmitting = false;

  @override
  void dispose() {
    _languageController.dispose();
    _editionController.dispose();
    _priceController.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final l10n = context.l10n;
    final salePrice = double.tryParse(_priceController.text.trim().replaceAll(',', '.'));
    if (_isForSale && salePrice == null) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(l10n.addBookInvalidPrice)));
      return;
    }
    if (_isForSale && widget.userBook.photos.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(l10n.addBookNeedPhoto)));
      return;
    }

    setState(() => _isSubmitting = true);
    try {
      await ref.read(myLibraryControllerProvider.notifier).editListing(
            widget.userBook.id,
            condition: _condition,
            language: _languageController.text.trim().isEmpty ? null : _languageController.text.trim(),
            edition: _editionController.text.trim().isEmpty ? null : _editionController.text.trim(),
            isHardcover: _isHardcover,
            isForSale: _isForSale,
            salePrice: _isForSale ? salePrice : null,
            isNegotiable: _isNegotiable,
          );
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(l10n.libraryEditListingSuccess)));
        Navigator.of(context).pop();
      }
    } on DioException catch (e) {
      if (mounted) {
        final data = e.response?.data;
        final message = data is Map && data['message'] != null
            ? (data['message'] is List ? (data['message'] as List).join(', ') : data['message'].toString())
            : l10n.addBookGenericError;
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
      }
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return Padding(
      padding: EdgeInsets.only(
        left: 24,
        right: 24,
        top: 24,
        bottom: MediaQuery.of(context).viewInsets.bottom + 24,
      ),
      child: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(l10n.libraryEditListingTitle, style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: 20),
            DropdownButtonFormField<BookCondition>(
              initialValue: _condition,
              decoration: InputDecoration(labelText: l10n.filtersCondition),
              items: [
                for (final condition in BookCondition.values)
                  DropdownMenuItem(value: condition, child: Text(condition.label)),
              ],
              onChanged: (value) {
                if (value != null) setState(() => _condition = value);
              },
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _languageController,
              decoration: InputDecoration(labelText: l10n.addBookLanguageOptional),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _editionController,
              decoration: InputDecoration(labelText: l10n.addBookEditionOptional),
            ),
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: Text(l10n.addBookHardcoverSwitch),
              value: _isHardcover,
              onChanged: (value) => setState(() => _isHardcover = value),
            ),
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: Text(l10n.addBookForSaleSwitch),
              subtitle: Text(l10n.addBookForSaleHint),
              value: _isForSale,
              onChanged: (value) => setState(() => _isForSale = value),
            ),
            if (_isForSale) ...[
              const SizedBox(height: 8),
              TextField(
                controller: _priceController,
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                decoration: InputDecoration(labelText: l10n.addBookPriceLabel, suffixText: 'lei'),
              ),
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                title: Text(l10n.addBookNonNegotiable),
                subtitle: Text(l10n.addBookNonNegotiableHint),
                value: !_isNegotiable,
                onChanged: (value) => setState(() => _isNegotiable = !value),
              ),
            ],
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: _isSubmitting ? null : _save,
              child: _isSubmitting
                  ? const SizedBox(
                      height: 20,
                      width: 20,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : Text(l10n.commonSave),
            ),
          ],
        ),
      ),
    );
  }
}
