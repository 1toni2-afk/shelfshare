import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/theme/app_theme.dart';
import '../../../data/models/book.dart';
import '../../../data/models/user.dart';
import '../../../data/models/user_book.dart';
import '../../../shared/widgets/book_cover.dart';
import '../../../shared/widgets/centered_scrollable.dart';
import '../../auth/application/auth_controller.dart';
import '../../auth/application/auth_state.dart';
import '../../chat/data/chat_repository.dart';
import '../../exchanges/data/exchanges_repository.dart';
import '../../wishlist/application/wishlist_controller.dart';
import '../application/book_detail_controller.dart';
import '../data/books_repository.dart';

class BookDetailScreen extends ConsumerStatefulWidget {
  const BookDetailScreen({super.key, required this.userBookId, this.fallbackOwner});
  final String userBookId;

  /// Owner deja cunoscut din ecranul de proveniență (Home/Browse), folosit
  /// când endpoint-ul de detalii nu include relația de owner - vezi
  /// project-book-detail-missing-owner în memorie.
  final PublicUser? fallbackOwner;

  @override
  ConsumerState<BookDetailScreen> createState() => _BookDetailScreenState();
}

class _BookDetailScreenState extends ConsumerState<BookDetailScreen> {
  bool _sheetOpen = false;

  Future<void> _requestExchange(UserBook book) async {
    if (_sheetOpen) return;
    _sheetOpen = true;
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      builder: (context) => _RequestExchangeSheet(requestedBook: book),
    );
    _sheetOpen = false;
  }

  Future<void> _messageOwner(PublicUser owner) async {
    final conversation = await ref.read(chatRepositoryProvider).startConversation(owner.id);
    if (mounted) {
      context.push('/chat/${conversation.id}', extra: owner);
    }
  }

  @override
  Widget build(BuildContext context) {
    final async = ref.watch(bookDetailProvider(widget.userBookId));
    final bookId = async.value?.book.id;
    final wishlistState = ref.watch(wishlistControllerProvider);
    final isWishlisted = bookId != null &&
        (wishlistState.value ?? const []).any((item) => item.book.id == bookId);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Detalii carte'),
        actions: [
          if (bookId != null)
            IconButton(
              icon: Icon(isWishlisted ? Icons.favorite : Icons.favorite_border),
              color: isWishlisted ? AppColors.destructive : null,
              onPressed: () => ref.read(wishlistControllerProvider.notifier).toggle(bookId),
            ),
        ],
      ),
      body: SafeArea(
        child: async.when(
          data: (book) {
            final owner = book.owner ?? widget.fallbackOwner;
            return _BookDetailContent(
              book: book,
              owner: owner,
              onRequestExchange: () => _requestExchange(book),
              onMessageOwner: owner == null ? null : () => _messageOwner(owner),
            );
          },
          loading: () => const CenteredScrollable(child: CircularProgressIndicator()),
          error: (error, _) => CenteredScrollable(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text('Nu am putut încărca cartea.'),
                const SizedBox(height: 8),
                OutlinedButton(
                  onPressed: () => ref.invalidate(bookDetailProvider(widget.userBookId)),
                  child: const Text('Încearcă din nou'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _BookDetailContent extends ConsumerWidget {
  const _BookDetailContent({
    required this.book,
    required this.owner,
    required this.onRequestExchange,
    required this.onMessageOwner,
  });
  final UserBook book;
  final PublicUser? owner;
  final VoidCallback onRequestExchange;
  final VoidCallback? onMessageOwner;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final authState = ref.watch(authControllerProvider);
    final currentUserId = authState is AuthAuthenticated ? authState.user.id : null;
    final isOwnBook = currentUserId != null && currentUserId == book.userId;

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Center(child: BookCover(url: book.book.coverUrl, width: 180, height: 252)),
        const SizedBox(height: 20),
        Text(
          book.book.title,
          style: Theme.of(context).textTheme.headlineSmall,
          textAlign: TextAlign.center,
        ),
        if (book.book.author != null)
          Padding(
            padding: const EdgeInsets.only(top: 4),
            child: Text(
              book.book.author!,
              style: Theme.of(context)
                  .textTheme
                  .bodyLarge
                  ?.copyWith(color: AppColors.mutedForeground),
              textAlign: TextAlign.center,
            ),
          ),
        const SizedBox(height: 16),
        Wrap(
          alignment: WrapAlignment.center,
          spacing: 8,
          runSpacing: 8,
          children: [
            Chip(label: Text(book.condition.label)),
            if (book.language != null) Chip(label: Text(book.language!)),
            if (book.isHardcover) const Chip(label: Text('Cartonată')),
            Chip(
              label: Text(book.availableForSwap ? 'Disponibilă la schimb' : 'Indisponibilă'),
              backgroundColor:
                  book.availableForSwap ? AppColors.accent.withValues(alpha: 0.15) : AppColors.muted,
            ),
          ],
        ),
        if (book.book.description != null && book.book.description!.isNotEmpty) ...[
          const SizedBox(height: 24),
          Text('Descriere', style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 8),
          Text(book.book.description!),
        ],
        if (book.book.genre != null ||
            book.book.publisher != null ||
            book.book.publishedYear != null ||
            book.book.pageCount != null) ...[
          const SizedBox(height: 24),
          Text('Detalii', style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 8),
          if (book.book.genre != null) _DetailRow(label: 'Gen', value: book.book.genre!),
          if (book.book.publisher != null) _DetailRow(label: 'Editură', value: book.book.publisher!),
          if (book.book.publishedYear != null)
            _DetailRow(label: 'An apariție', value: book.book.publishedYear.toString()),
          if (book.book.pageCount != null)
            _DetailRow(label: 'Pagini', value: book.book.pageCount.toString()),
        ],
        if (owner != null) ...[
          const SizedBox(height: 24),
          Text('Proprietar', style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 8),
          ListTile(
            contentPadding: EdgeInsets.zero,
            leading: CircleAvatar(
              backgroundImage: owner!.profileImage != null ? NetworkImage(owner!.profileImage!) : null,
              child: owner!.profileImage == null ? const Icon(Icons.person) : null,
            ),
            title: Text(owner!.name ?? 'Utilizator'),
            subtitle: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (owner!.city != null) ...[
                  Text(owner!.city!),
                  const Text(' · '),
                ],
                const Icon(Icons.star, size: 14, color: AppColors.accent),
                Text(' ${owner!.rating.toStringAsFixed(1)}'),
              ],
            ),
            trailing: isOwnBook
                ? null
                : IconButton(
                    icon: const Icon(Icons.chat_bubble_outline),
                    onPressed: onMessageOwner,
                  ),
          ),
        ],
        if (book.photos.isNotEmpty) ...[
          const SizedBox(height: 24),
          Text('Poze', style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 8),
          SizedBox(
            height: 100,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              itemCount: book.photos.length,
              separatorBuilder: (_, _) => const SizedBox(width: 8),
              itemBuilder: (context, index) => ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: Image.network(
                  book.photos[index],
                  width: 100,
                  height: 100,
                  fit: BoxFit.cover,
                ),
              ),
            ),
          ),
        ],
        const SizedBox(height: 32),
        if (!isOwnBook)
          ElevatedButton(
            onPressed: book.availableForSwap ? onRequestExchange : null,
            child: Text(book.availableForSwap ? 'Cere la schimb' : 'Indisponibilă la schimb'),
          ),
      ],
    );
  }
}

class _DetailRow extends StatelessWidget {
  const _DetailRow({required this.label, required this.value});
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 120,
            child: Text(label, style: Theme.of(context).textTheme.bodySmall),
          ),
          Expanded(child: Text(value)),
        ],
      ),
    );
  }
}

class _RequestExchangeSheet extends ConsumerStatefulWidget {
  const _RequestExchangeSheet({required this.requestedBook});
  final UserBook requestedBook;

  @override
  ConsumerState<_RequestExchangeSheet> createState() => _RequestExchangeSheetState();
}

class _RequestExchangeSheetState extends ConsumerState<_RequestExchangeSheet> {
  final _messageController = TextEditingController();
  String? _offeredBookId;
  bool _isSubmitting = false;
  bool _isLoadingMyBooks = true;
  List<UserBook>? _myBooks;

  @override
  void initState() {
    super.initState();
    _loadMyBooks();
  }

  @override
  void dispose() {
    _messageController.dispose();
    super.dispose();
  }

  Future<void> _loadMyBooks() async {
    try {
      final books = await ref.read(booksRepositoryProvider).getMyLibrary();
      if (mounted) {
        setState(() {
          _myBooks = books.where((b) => b.availableForSwap).toList();
          _isLoadingMyBooks = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _isLoadingMyBooks = false);
    }
  }

  Future<void> _submit() async {
    setState(() => _isSubmitting = true);
    try {
      await ref.read(exchangesRepositoryProvider).createRequest(
            requestedBookId: widget.requestedBook.id,
            offeredBookId: _offeredBookId,
            message: _messageController.text.trim().isEmpty ? null : _messageController.text.trim(),
          );
      if (mounted) {
        Navigator.of(context).pop();
        ScaffoldMessenger.of(context)
            .showSnackBar(const SnackBar(content: Text('Cerere de schimb trimisă')));
      }
    } on DioException catch (e) {
      final data = e.response?.data;
      final message = data is Map && data['message'] != null
          ? (data['message'] is List ? (data['message'] as List).join(', ') : data['message'].toString())
          : 'Nu am putut trimite cererea.';
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
      }
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(
        left: 24,
        right: 24,
        top: 24,
        bottom: MediaQuery.of(context).viewInsets.bottom + 24,
      ),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              'Cere „${widget.requestedBook.book.title}" la schimb',
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 20),
            if (_isLoadingMyBooks)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 16),
                child: Center(child: CircularProgressIndicator()),
              )
            else if (_myBooks == null || _myBooks!.isEmpty)
              Padding(
                padding: const EdgeInsets.only(bottom: 16),
                child: Text(
                  'Nu ai cărți disponibile de oferit - poți trimite cererea și fără.',
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              )
            else
              DropdownButtonFormField<String?>(
                initialValue: _offeredBookId,
                decoration: const InputDecoration(labelText: 'Oferă una din cărțile tale (opțional)'),
                items: [
                  const DropdownMenuItem(value: null, child: Text('Fără ofertă')),
                  for (final userBook in _myBooks!)
                    DropdownMenuItem(value: userBook.id, child: Text(userBook.book.title)),
                ],
                onChanged: (value) => setState(() => _offeredBookId = value),
              ),
            const SizedBox(height: 16),
            TextField(
              controller: _messageController,
              maxLines: 3,
              decoration: const InputDecoration(labelText: 'Mesaj (opțional)'),
            ),
            const SizedBox(height: 24),
            ElevatedButton(
              onPressed: _isSubmitting ? null : _submit,
              child: _isSubmitting
                  ? const SizedBox(
                      height: 20,
                      width: 20,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Text('Trimite cererea'),
            ),
          ],
        ),
      ),
    );
  }
}
