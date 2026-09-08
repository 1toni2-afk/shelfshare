import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/locale/l10n_extensions.dart';
import '../../../core/theme/app_theme.dart';
import '../../../data/models/book_request.dart';
import '../../../l10n/app_localizations.dart';
import '../../../shared/widgets/centered_scrollable.dart';
import '../application/book_requests_controller.dart';
import 'request_book_dialog.dart';

/// Cererile de carte ale userului și ce s-a ales de ele. Fără ecranul ăsta,
/// formularul ar fi o cutie poștală fără răspuns: cererile sunt căutate nopți
/// la rând, iar omul trebuie să poată vedea că încă se caută (sau că nu s-a
/// găsit nimic), nu doar să aștepte o notificare care poate nu vine.
class BookRequestsScreen extends ConsumerWidget {
  const BookRequestsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(bookRequestsControllerProvider);
    final l10n = context.l10n;

    return Scaffold(
      appBar: AppBar(title: Text(l10n.bookRequestsTitle)),
      floatingActionButton: FloatingActionButton(
        onPressed: () => showRequestBookDialog(context, ref),
        tooltip: l10n.bookRequestTitle,
        child: const Icon(Icons.add),
      ),
      body: SafeArea(
        child: RefreshIndicator(
          onRefresh: () =>
              ref.read(bookRequestsControllerProvider.notifier).refresh(),
          child: state.when(
            data: (requests) {
              if (requests.isEmpty) {
                return CenteredScrollable(
                  child: Text(
                    l10n.bookRequestsEmpty,
                    textAlign: TextAlign.center,
                  ),
                );
              }
              return ListView.separated(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.all(16),
                itemCount: requests.length,
                separatorBuilder: (_, _) => const SizedBox(height: 8),
                itemBuilder: (context, index) =>
                    _BookRequestTile(request: requests[index]),
              );
            },
            loading: () =>
                const CenteredScrollable(child: CircularProgressIndicator()),
            error: (error, _) => CenteredScrollable(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(l10n.bookRequestsLoadError),
                  const SizedBox(height: 8),
                  OutlinedButton(
                    onPressed: () => ref
                        .read(bookRequestsControllerProvider.notifier)
                        .refresh(),
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

class _BookRequestTile extends ConsumerWidget {
  const _BookRequestTile({required this.request});
  final BookRequest request;

  String _statusLabel(AppLocalizations l10n) {
    switch (request.status) {
      case BookRequestStatus.pending:
        return l10n.bookRequestStatusPending;
      case BookRequestStatus.fulfilled:
        return l10n.bookRequestStatusFulfilled;
      case BookRequestStatus.notFound:
        return l10n.bookRequestStatusNotFound;
      case BookRequestStatus.cancelled:
        return l10n.bookRequestStatusCancelled;
      case BookRequestStatus.unknown:
        return l10n.bookRequestStatusPending;
    }
  }

  IconData get _statusIcon {
    switch (request.status) {
      case BookRequestStatus.fulfilled:
        return Icons.check_circle_outline;
      case BookRequestStatus.notFound:
        return Icons.search_off;
      case BookRequestStatus.cancelled:
        return Icons.cancel_outlined;
      case BookRequestStatus.pending:
      case BookRequestStatus.unknown:
        return Icons.hourglass_empty;
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final subtitle = [
      if (request.author != null && request.author!.isNotEmpty) request.author!,
      _statusLabel(l10n),
      // Câte nopți a fost căutată deja - singurul semn vizibil că se lucrează
      // la ea între trimitere și notificare.
      if (request.status == BookRequestStatus.pending && request.attempts > 0)
        l10n.bookRequestAttempts(request.attempts),
    ].join(' • ');

    return Card(
      margin: EdgeInsets.zero,
      child: ListTile(
        leading: Icon(_statusIcon, color: AppColors.mutedForeground),
        title: Text(request.title),
        subtitle: Text(
          subtitle,
          style: Theme.of(context)
              .textTheme
              .bodySmall
              ?.copyWith(color: AppColors.mutedForeground),
        ),
        trailing: request.status == BookRequestStatus.fulfilled &&
                request.bookId != null
            ? TextButton(
                onPressed: () => context.push('/work/${request.bookId}'),
                child: Text(l10n.bookRequestOpenBook),
              )
            : request.status == BookRequestStatus.pending
                ? IconButton(
                    icon: const Icon(Icons.delete_outline),
                    tooltip: l10n.commonCancel,
                    onPressed: () => ref
                        .read(bookRequestsControllerProvider.notifier)
                        .cancel(request.id),
                  )
                : null,
      ),
    );
  }
}
