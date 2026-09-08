import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/locale/l10n_extensions.dart';
import '../../../core/theme/app_theme.dart';
import '../../../data/models/admin_book_request.dart';
import '../../../data/models/book_request.dart';
import '../../../l10n/app_localizations.dart';
import '../../../shared/widgets/centered_scrollable.dart';
import '../application/admin_book_requests_controller.dart';

/// Cererile de carte trimise din formularul „nu găsesc cartea".
///
/// Ecranul e de OBSERVARE, nu de lucru: cererile se rezolvă singure, în
/// fiecare noapte (vezi BookRequestsService.resolvePendingRequests și
/// scripts/book-requests/nightly_book_requests.py). Ce contează aici e să se
/// vadă ce se caută, în ce ordine și ce nu găsește nimeni - un titlu cerut de
/// mulți oameni care rămâne negăsit e semnal că lipsește o sursă, nu că
/// trebuie apăsat un buton.
class AdminBookRequestsScreen extends ConsumerWidget {
  const AdminBookRequestsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final filter = ref.watch(adminBookRequestFilterProvider);
    final async = ref.watch(adminBookRequestsProvider);

    return Scaffold(
      appBar: AppBar(title: Text(l10n.adminBookRequestsTitle)),
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
              child: Wrap(
                spacing: 8,
                children: [
                  _filterChip(ref, l10n.adminBookRequestsFilterPending, 'PENDING', filter),
                  _filterChip(ref, l10n.adminBookRequestsFilterFulfilled, 'FULFILLED', filter),
                  _filterChip(ref, l10n.adminBookRequestsFilterNotFound, 'NOT_FOUND', filter),
                  _filterChip(ref, l10n.adminBookRequestsFilterAll, null, filter),
                ],
              ),
            ),
            Expanded(
              child: async.when(
                data: (requests) {
                  if (requests.isEmpty) {
                    return CenteredScrollable(
                      child: Text(
                        l10n.adminBookRequestsEmpty,
                        textAlign: TextAlign.center,
                      ),
                    );
                  }
                  return RefreshIndicator(
                    onRefresh: () async =>
                        ref.invalidate(adminBookRequestsProvider),
                    child: ListView.separated(
                      physics: const AlwaysScrollableScrollPhysics(),
                      padding: const EdgeInsets.all(16),
                      itemCount: requests.length + 1,
                      separatorBuilder: (_, _) => const SizedBox(height: 8),
                      itemBuilder: (context, index) {
                        if (index == 0) {
                          return Padding(
                            padding: const EdgeInsets.only(bottom: 4),
                            child: Text(
                              l10n.adminBookRequestsCount(requests.length),
                              style: Theme.of(context)
                                  .textTheme
                                  .bodySmall
                                  ?.copyWith(color: AppColors.mutedForeground),
                            ),
                          );
                        }
                        return _RequestTile(request: requests[index - 1]);
                      },
                    ),
                  );
                },
                loading: () =>
                    const CenteredScrollable(child: CircularProgressIndicator()),
                error: (error, _) => CenteredScrollable(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(l10n.adminLoadError),
                      const SizedBox(height: 8),
                      OutlinedButton(
                        onPressed: () =>
                            ref.invalidate(adminBookRequestsProvider),
                        child: Text(l10n.commonRetry),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _filterChip(
    WidgetRef ref,
    String label,
    String? value,
    String? selected,
  ) {
    return ChoiceChip(
      label: Text(label),
      selected: selected == value,
      onSelected: (_) =>
          ref.read(adminBookRequestFilterProvider.notifier).set(value),
    );
  }
}

class _RequestTile extends StatelessWidget {
  const _RequestTile({required this.request});
  final AdminBookRequest request;

  (String, Color) _status(AppLocalizations l10n) {
    switch (request.status) {
      case BookRequestStatus.pending:
        return (l10n.bookRequestStatusPending, AppColors.accent);
      case BookRequestStatus.fulfilled:
        return (l10n.bookRequestStatusFulfilled, Colors.green);
      case BookRequestStatus.notFound:
        return (l10n.bookRequestStatusNotFound, Colors.redAccent);
      case BookRequestStatus.cancelled:
        return (l10n.bookRequestStatusCancelled, AppColors.mutedForeground);
      case BookRequestStatus.unknown:
        return (l10n.bookRequestStatusPending, AppColors.mutedForeground);
    }
  }

  String _date(DateTime value) =>
      '${value.day.toString().padLeft(2, '0')}.${value.month.toString().padLeft(2, '0')}.${value.year}';

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final (statusLabel, statusColor) = _status(l10n);
    final muted = Theme.of(context)
        .textTheme
        .bodySmall
        ?.copyWith(color: AppColors.mutedForeground);

    return Card(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    request.title,
                    style: Theme.of(context).textTheme.titleSmall,
                  ),
                ),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                  decoration: BoxDecoration(
                    color: statusColor.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    statusLabel,
                    style: TextStyle(fontSize: 11, color: statusColor),
                  ),
                ),
              ],
            ),
            if (request.author != null && request.author!.isNotEmpty)
              Text(request.author!, style: muted),
            const SizedBox(height: 8),
            Wrap(
              spacing: 12,
              runSpacing: 4,
              children: [
                // Cine cere, ca să se poată răspunde omului direct dacă titlul
                // e scris greșit - de aceea emailul, nu doar numele.
                Text(request.requesterEmail, style: muted),
                Text(_date(request.createdAt), style: muted),
                // Numărul de solicitanți e chiar ordinea din coada de noapte.
                if (request.demand > 1)
                  Text(l10n.adminBookRequestsDemand(request.demand),
                      style: muted?.copyWith(color: AppColors.accent)),
                if (request.attempts > 0)
                  Text(l10n.bookRequestAttempts(request.attempts), style: muted),
                if (request.isbn != null)
                  Text('ISBN ${request.isbn}', style: muted),
                if (request.resolvedSource != null)
                  Text(l10n.adminBookRequestsFoundOn(request.resolvedSource!),
                      style: muted),
              ],
            ),
            if (request.note != null && request.note!.isNotEmpty) ...[
              const SizedBox(height: 8),
              Text('„${request.note}"', style: muted),
            ],
            if (request.bookId != null) ...[
              const SizedBox(height: 4),
              Align(
                alignment: Alignment.centerLeft,
                child: TextButton(
                  onPressed: () => context.push('/work/${request.bookId}'),
                  child: Text(l10n.bookRequestOpenBook),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
