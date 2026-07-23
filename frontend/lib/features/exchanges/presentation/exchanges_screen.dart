import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../../core/locale/l10n_extensions.dart';
import '../../../core/theme/app_theme.dart';
import '../../../data/models/exchange_request.dart';
import '../../../data/models/price_offer.dart';
import '../../../shared/widgets/book_cover.dart';
import '../../../shared/widgets/centered_scrollable.dart';
import '../../auth/application/auth_controller.dart';
import '../../auth/application/auth_state.dart';
import '../../books/presentation/relist_book_sheet.dart';
import '../../chat/data/chat_repository.dart';
import '../../offers/application/offers_controller.dart';
import '../application/exchanges_controller.dart';

String _formatDateTime(DateTime dateTime) {
  final local = dateTime.toLocal();
  String two(int n) => n.toString().padLeft(2, '0');
  return '${two(local.day)}.${two(local.month)}.${local.year}, ${two(local.hour)}:${two(local.minute)}';
}

class ExchangesScreen extends StatefulWidget {
  const ExchangesScreen({super.key});

  @override
  State<ExchangesScreen> createState() => _ExchangesScreenState();
}

class _ExchangesScreenState extends State<ExchangesScreen> with SingleTickerProviderStateMixin {
  late final TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 4, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.exchangesTitle),
        bottom: TabBar(
          controller: _tabController,
          isScrollable: true,
          tabs: [
            Tab(text: l10n.exchangesTabReceived),
            Tab(text: l10n.exchangesTabSent),
            Tab(text: l10n.offersTabReceived),
            Tab(text: l10n.offersTabSent),
          ],
        ),
      ),
      body: SafeArea(
        child: TabBarView(
          controller: _tabController,
          children: const [
            _ExchangeList(mode: _ExchangeListMode.received),
            _ExchangeList(mode: _ExchangeListMode.sent),
            _OfferList(mode: _OfferListMode.received),
            _OfferList(mode: _OfferListMode.sent),
          ],
        ),
      ),
    );
  }
}

enum _ExchangeListMode { received, sent }

class _ExchangeList extends ConsumerWidget {
  const _ExchangeList({required this.mode});
  final _ExchangeListMode mode;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(exchangesControllerProvider);
    final authState = ref.watch(authControllerProvider);
    final myUserId = authState is AuthAuthenticated ? authState.user.id : null;

    return RefreshIndicator(
      onRefresh: () => ref.read(exchangesControllerProvider.notifier).refresh(),
      child: async.when(
        data: (data) {
          final items = mode == _ExchangeListMode.received ? data.received : data.sent;
          if (items.isEmpty) {
            return CenteredScrollable(
              child: Text(
                mode == _ExchangeListMode.received
                    ? context.l10n.exchangesEmptyReceived
                    : context.l10n.exchangesEmptySent,
              ),
            );
          }
          return ListView.separated(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.all(16),
            itemCount: items.length,
            separatorBuilder: (_, _) => const SizedBox(height: 12),
            itemBuilder: (context, index) => _ExchangeCard(
              exchange: items[index],
              isReceived: mode == _ExchangeListMode.received,
              myUserId: myUserId,
            ),
          );
        },
        loading: () => const CenteredScrollable(child: CircularProgressIndicator()),
        error: (error, _) => CenteredScrollable(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(context.l10n.exchangesLoadError),
              const SizedBox(height: 8),
              OutlinedButton(
                onPressed: () => ref.read(exchangesControllerProvider.notifier).refresh(),
                child: Text(context.l10n.commonRetry),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ExchangeCard extends ConsumerWidget {
  const _ExchangeCard({
    required this.exchange,
    required this.isReceived,
    required this.myUserId,
  });

  final ExchangeRequest exchange;
  final bool isReceived;
  final String? myUserId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final counterpart = isReceived ? exchange.requester : exchange.owner;
    final alreadyRated = myUserId != null && exchange.myRatingGiven(myUserId!);
    final l10n = context.l10n;

    return Card(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                GestureDetector(
                  onTap: () => context.push(
                    '/books/${exchange.requestedBook.id}',
                    extra: isReceived ? null : exchange.owner,
                  ),
                  child: BookCover(url: exchange.requestedBook.book.coverUrl, width: 56, height: 78),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      GestureDetector(
                        onTap: () => context.push(
                          '/books/${exchange.requestedBook.id}',
                          extra: isReceived ? null : exchange.owner,
                        ),
                        child: Text(
                          exchange.requestedBook.book.title,
                          style: Theme.of(context).textTheme.titleSmall,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      const SizedBox(height: 4),
                      GestureDetector(
                        behavior: HitTestBehavior.opaque,
                        onTap: () => context.push('/users/${counterpart.id}', extra: counterpart),
                        child: Text(
                          isReceived
                              ? l10n.exchangeRequestedBy(counterpart.name ?? l10n.commonAnonymousUser)
                              : l10n.exchangeFrom(counterpart.name ?? l10n.commonAnonymousUser),
                          style: Theme.of(context)
                              .textTheme
                              .bodySmall
                              ?.copyWith(color: AppColors.mutedForeground, decoration: TextDecoration.underline),
                        ),
                      ),
                      if (exchange.offeredBook != null)
                        Text(
                          l10n.exchangeOffersBook(exchange.offeredBook!.book.title),
                          style: Theme.of(context).textTheme.bodySmall,
                        )
                      else if (exchange.offeredAmount != null)
                        Text(
                          l10n.exchangeOffersAmount(exchange.offeredAmount!.toStringAsFixed(0)),
                          style: Theme.of(context).textTheme.bodySmall,
                        ),
                    ],
                  ),
                ),
                _StatusChip(status: exchange.status),
              ],
            ),
            if (exchange.message != null && exchange.message!.isNotEmpty) ...[
              const SizedBox(height: 8),
              Text(
                '„${exchange.message}"',
                style: Theme.of(context).textTheme.bodySmall?.copyWith(fontStyle: FontStyle.italic),
              ),
            ],
            const SizedBox(height: 12),
            _Actions(
              exchange: exchange,
              isReceived: isReceived,
              alreadyRated: alreadyRated,
            ),
          ],
        ),
      ),
    );
  }
}

class _StatusChip extends StatelessWidget {
  const _StatusChip({required this.status});
  final ExchangeStatus status;

  @override
  Widget build(BuildContext context) {
    final (color, bg) = switch (status) {
      ExchangeStatus.pending => (AppColors.accent, AppColors.accent.withValues(alpha: 0.15)),
      ExchangeStatus.accepted => (AppColors.primary, AppColors.primary.withValues(alpha: 0.15)),
      ExchangeStatus.completed => (const Color(0xFF2E7D32), const Color(0xFF2E7D32).withValues(alpha: 0.12)),
      ExchangeStatus.rejected => (AppColors.destructive, AppColors.destructive.withValues(alpha: 0.12)),
      ExchangeStatus.cancelled => (AppColors.mutedForeground, AppColors.muted),
    };
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(8)),
      child: Text(status.label, style: TextStyle(color: color, fontSize: 12, fontWeight: FontWeight.w600)),
    );
  }
}

class _Actions extends ConsumerWidget {
  const _Actions({
    required this.exchange,
    required this.isReceived,
    required this.alreadyRated,
  });

  final ExchangeRequest exchange;
  final bool isReceived;
  final bool alreadyRated;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final notifier = ref.read(exchangesControllerProvider.notifier);
    final l10n = context.l10n;

    if (exchange.status == ExchangeStatus.pending && isReceived) {
      return Row(
        mainAxisAlignment: MainAxisAlignment.end,
        children: [
          OutlinedButton(
            onPressed: () => notifier.reject(exchange.id),
            child: Text(l10n.exchangeReject),
          ),
          const SizedBox(width: 8),
          ElevatedButton(
            onPressed: () => notifier.accept(exchange.id),
            child: Text(l10n.exchangeAccept),
          ),
        ],
      );
    }

    if (exchange.status == ExchangeStatus.pending && !isReceived) {
      return Align(
        alignment: Alignment.centerRight,
        child: OutlinedButton(
          onPressed: () => notifier.cancel(exchange.id),
          child: Text(l10n.exchangeCancelRequest),
        ),
      );
    }

    if (exchange.status == ExchangeStatus.accepted) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          if (exchange.meetingTime != null) ...[
            _MeetingInfo(request: exchange),
            const SizedBox(height: 8),
          ],
          Wrap(
            alignment: WrapAlignment.end,
            spacing: 8,
            runSpacing: 8,
            children: [
              OutlinedButton(
                onPressed: () => _openMeetingSheet(context, exchange),
                child: Text(exchange.meetingTime == null ? l10n.exchangeScheduleMeeting : l10n.exchangeReschedule),
              ),
              if (exchange.meetingTime != null) ...[
                OutlinedButton(
                  onPressed: () => _openCalendar(context, ref, exchange.id),
                  child: Text(l10n.exchangeAddToCalendar),
                ),
                OutlinedButton(
                  onPressed: () => _showQrDialog(context, exchange.id),
                  child: Text(l10n.exchangeQrCode),
                ),
              ],
              ElevatedButton(
                onPressed: () => notifier.complete(exchange.id),
                child: Text(l10n.exchangeMarkComplete),
              ),
            ],
          ),
        ],
      );
    }

    if (exchange.status == ExchangeStatus.completed) {
      return Wrap(
        alignment: WrapAlignment.end,
        spacing: 8,
        runSpacing: 8,
        children: [
          if (!isReceived)
            OutlinedButton(
              onPressed: () => showRelistBookSheet(
                context,
                originalUserBookId: exchange.requestedBook.id,
                bookTitle: exchange.requestedBook.book.title,
              ),
              child: Text(l10n.commonAddToLibrary),
            ),
          alreadyRated
              ? Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.check_circle, size: 16, color: Color(0xFF2E7D32)),
                    const SizedBox(width: 4),
                    Text(l10n.exchangeRated, style: const TextStyle(color: Color(0xFF2E7D32))),
                  ],
                )
              : OutlinedButton.icon(
                  icon: const Icon(Icons.star_border, size: 18),
                  label: Text(l10n.exchangeRate),
                  onPressed: () => _showRatingDialog(context, ref),
                ),
        ],
      );
    }

    return const SizedBox.shrink();
  }

  Future<void> _showRatingDialog(BuildContext context, WidgetRef ref) async {
    final result = await showDialog<RatingResult>(
      context: context,
      builder: (context) => _RatingDialog(exchange: exchange),
    );
    if (result != null) {
      await ref.read(exchangesControllerProvider.notifier).rate(
            exchange.id,
            result.value,
            comment: result.comment,
            communication: result.communication,
            punctuality: result.punctuality,
            condition: result.condition,
          );
    }
  }

  Future<void> _openMeetingSheet(BuildContext context, ExchangeRequest request) {
    return showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      builder: (context) => _MeetingSheet(request: request),
    );
  }

  Future<void> _openCalendar(BuildContext context, WidgetRef ref, String id) async {
    try {
      final notifier = ref.read(exchangesControllerProvider.notifier);
      final url = await notifier.calendarUrl(id);
      final launched = await launchUrl(Uri.parse(url), mode: LaunchMode.externalApplication);
      if (!launched && context.mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(context.l10n.exchangeCalendarError)));
      }
    } catch (_) {
      if (context.mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(context.l10n.exchangeCalendarError)));
      }
    }
  }

  void _showQrDialog(BuildContext context, String exchangeId) {
    showDialog<void>(
      context: context,
      builder: (context) => _ExchangeQrDialog(exchangeId: exchangeId),
    );
  }
}

class RatingResult {
  const RatingResult({
    required this.value,
    this.comment,
    this.communication,
    this.punctuality,
    this.condition,
  });
  final int value;
  final String? comment;
  final int? communication;
  final int? punctuality;
  final int? condition;
}

class _RatingDialog extends StatefulWidget {
  const _RatingDialog({required this.exchange});
  final ExchangeRequest exchange;

  @override
  State<_RatingDialog> createState() => _RatingDialogState();
}

class _RatingDialogState extends State<_RatingDialog> {
  int _selected = 5;
  int? _communication;
  int? _punctuality;
  int? _condition;
  final _commentController = TextEditingController();

  @override
  void dispose() {
    _commentController.dispose();
    super.dispose();
  }

  Widget _starRow(String label, int? value, ValueChanged<int> onChanged) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: Theme.of(context).textTheme.bodySmall),
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            for (var i = 1; i <= 5; i++)
              IconButton(
                icon: Icon(
                  value != null && i <= value ? Icons.star : Icons.star_border,
                  color: AppColors.accent,
                  size: 20,
                ),
                onPressed: () => onChanged(i),
              ),
          ],
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return AlertDialog(
      title: Text(l10n.exchangeRatingDialogTitle),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            _starRow(l10n.exchangeRatingOverall, _selected, (v) => setState(() => _selected = v)),
            _starRow(
              l10n.exchangeRatingCommunication,
              _communication,
              (v) => setState(() => _communication = v),
            ),
            _starRow(
              l10n.exchangeRatingPunctuality,
              _punctuality,
              (v) => setState(() => _punctuality = v),
            ),
            _starRow(
              l10n.exchangeRatingCondition,
              _condition,
              (v) => setState(() => _condition = v),
            ),
            TextField(
              controller: _commentController,
              maxLines: 3,
              decoration: InputDecoration(labelText: l10n.exchangeReviewOptional),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: Text(l10n.commonCancel),
        ),
        ElevatedButton(
          onPressed: () => Navigator.of(context).pop(
            RatingResult(
              value: _selected,
              comment: _commentController.text.trim().isEmpty ? null : _commentController.text.trim(),
              communication: _communication,
              punctuality: _punctuality,
              condition: _condition,
            ),
          ),
          child: Text(l10n.commonSubmit),
        ),
      ],
    );
  }
}

/// Codul QR încodează un link către /exchanges/:id/confirm - celălalt
/// participant îl scanează cu orice cameră/aplicație de scanare de pe
/// telefon și pagina se deschide direct în browser, fără nevoie de o
/// funcție de scanare separată în aplicație.
class _ExchangeQrDialog extends StatelessWidget {
  const _ExchangeQrDialog({required this.exchangeId});
  final String exchangeId;

  @override
  Widget build(BuildContext context) {
    final link = '${Uri.base.origin}/exchanges/$exchangeId/confirm';
    final l10n = context.l10n;
    return AlertDialog(
      title: Text(l10n.exchangeQrDialogTitle),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            l10n.exchangeQrDialogBody,
            style: Theme.of(context).textTheme.bodySmall,
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 16),
          QrImageView(data: link, size: 200),
        ],
      ),
      actions: [
        TextButton(onPressed: () => Navigator.of(context).pop(), child: Text(l10n.commonClose)),
      ],
    );
  }
}

class _MeetingInfo extends StatelessWidget {
  const _MeetingInfo({required this.request});
  final ExchangeRequest request;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: AppColors.primary.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.event, size: 18, color: AppColors.primary),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              '${_formatDateTime(request.meetingTime!)} • ${request.meetingLocation}',
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ),
        ],
      ),
    );
  }
}

class _MeetingSheet extends ConsumerStatefulWidget {
  const _MeetingSheet({required this.request});
  final ExchangeRequest request;

  @override
  ConsumerState<_MeetingSheet> createState() => _MeetingSheetState();
}

class _MeetingSheetState extends ConsumerState<_MeetingSheet> {
  late DateTime? _dateTime = widget.request.meetingTime?.toLocal();
  late final _locationController = TextEditingController(text: widget.request.meetingLocation);
  bool _isSubmitting = false;

  @override
  void dispose() {
    _locationController.dispose();
    super.dispose();
  }

  Future<void> _pickDateTime() async {
    final now = DateTime.now();
    final initial = _dateTime ?? now.add(const Duration(days: 1));
    final date = await showDatePicker(
      context: context,
      initialDate: initial.isBefore(now) ? now : initial,
      firstDate: now,
      lastDate: now.add(const Duration(days: 365)),
    );
    if (date == null || !mounted) return;
    final time = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.fromDateTime(initial),
    );
    if (time == null) return;
    setState(() {
      _dateTime = DateTime(date.year, date.month, date.day, time.hour, time.minute);
    });
  }

  Future<void> _submit() async {
    final dateTime = _dateTime;
    final location = _locationController.text.trim();
    if (dateTime == null || location.isEmpty) return;

    setState(() => _isSubmitting = true);
    try {
      await ref.read(exchangesControllerProvider.notifier).setMeeting(
            widget.request.id,
            meetingTime: dateTime,
            meetingLocation: location,
          );
      if (mounted) Navigator.of(context).pop();
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(context.l10n.exchangeMeetingSaveError)));
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
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(l10n.exchangeMeetingSheetTitle, style: Theme.of(context).textTheme.titleLarge),
          const SizedBox(height: 20),
          OutlinedButton.icon(
            onPressed: _pickDateTime,
            icon: const Icon(Icons.calendar_today),
            label: Text(_dateTime == null ? l10n.exchangePickDateTime : _formatDateTime(_dateTime!)),
          ),
          const SizedBox(height: 16),
          TextField(
            controller: _locationController,
            maxLength: 200,
            decoration: InputDecoration(labelText: l10n.exchangeLocationLabel),
          ),
          const SizedBox(height: 8),
          ElevatedButton(
            onPressed: _isSubmitting ? null : _submit,
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
    );
  }
}

enum _OfferListMode { received, sent }

class _OfferList extends ConsumerWidget {
  const _OfferList({required this.mode});
  final _OfferListMode mode;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(offersControllerProvider);

    return RefreshIndicator(
      onRefresh: () => ref.read(offersControllerProvider.notifier).refresh(),
      child: async.when(
        data: (data) {
          final items = mode == _OfferListMode.received ? data.received : data.sent;
          if (items.isEmpty) {
            return CenteredScrollable(
              child: Text(
                mode == _OfferListMode.received
                    ? context.l10n.offersEmptyReceived
                    : context.l10n.offersEmptySent,
              ),
            );
          }
          return ListView.separated(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.all(16),
            itemCount: items.length,
            separatorBuilder: (_, _) => const SizedBox(height: 12),
            itemBuilder: (context, index) => _OfferCard(
              offer: items[index],
              isReceived: mode == _OfferListMode.received,
            ),
          );
        },
        loading: () => const CenteredScrollable(child: CircularProgressIndicator()),
        error: (error, _) => CenteredScrollable(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(context.l10n.offersLoadError),
              const SizedBox(height: 8),
              OutlinedButton(
                onPressed: () => ref.read(offersControllerProvider.notifier).refresh(),
                child: Text(context.l10n.commonRetry),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _OfferCard extends ConsumerWidget {
  const _OfferCard({required this.offer, required this.isReceived});
  final PriceOffer offer;
  final bool isReceived;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final counterpart = isReceived ? offer.buyer : offer.owner;
    final l10n = context.l10n;

    return Card(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                GestureDetector(
                  onTap: () => context.push('/books/${offer.userBook.id}'),
                  child: BookCover(url: offer.userBook.book.coverUrl, width: 56, height: 78),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      GestureDetector(
                        onTap: () => context.push('/books/${offer.userBook.id}'),
                        child: Text(
                          offer.userBook.book.title,
                          style: Theme.of(context).textTheme.titleSmall,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      const SizedBox(height: 4),
                      GestureDetector(
                        behavior: HitTestBehavior.opaque,
                        onTap: () => context.push('/users/${counterpart.id}', extra: counterpart),
                        child: Text(
                          isReceived
                              ? l10n.exchangeFrom(counterpart.name ?? l10n.commonAnonymousUser)
                              : l10n.offerTo(counterpart.name ?? l10n.commonAnonymousUser),
                          style: Theme.of(context)
                              .textTheme
                              .bodySmall
                              ?.copyWith(color: AppColors.mutedForeground, decoration: TextDecoration.underline),
                        ),
                      ),
                      Text(
                        l10n.offerAmountLine(l10n.priceLei(offer.amount.toStringAsFixed(0))),
                        style: Theme.of(context)
                            .textTheme
                            .bodyMedium
                            ?.copyWith(fontWeight: FontWeight.w600, color: AppColors.accent),
                      ),
                    ],
                  ),
                ),
                _OfferStatusChip(status: offer.status),
              ],
            ),
            if (offer.message != null && offer.message!.isNotEmpty) ...[
              const SizedBox(height: 8),
              Text(
                '„${offer.message}"',
                style: Theme.of(context).textTheme.bodySmall?.copyWith(fontStyle: FontStyle.italic),
              ),
            ],
            if (offer.status == OfferStatus.pending) ...[
              const SizedBox(height: 12),
              _OfferActions(offer: offer, isReceived: isReceived),
            ],
            if (offer.status == OfferStatus.accepted && !isReceived) ...[
              const SizedBox(height: 12),
              Align(
                alignment: Alignment.centerRight,
                child: OutlinedButton(
                  onPressed: () => showRelistBookSheet(
                    context,
                    originalUserBookId: offer.userBook.id,
                    bookTitle: offer.userBook.book.title,
                  ),
                  child: Text(l10n.commonAddToLibrary),
                ),
              ),
            ],
            if (offer.status == OfferStatus.accepted && isReceived) ...[
              const SizedBox(height: 12),
              Align(
                alignment: Alignment.centerRight,
                child: OutlinedButton.icon(
                  icon: const Icon(Icons.chat_bubble_outline, size: 18),
                  onPressed: () async {
                    final conversation =
                        await ref.read(chatRepositoryProvider).startConversation(counterpart.id);
                    if (context.mounted) {
                      context.push('/chat/${conversation.id}', extra: counterpart);
                    }
                  },
                  label: Text(l10n.commonSendMessage),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _OfferStatusChip extends StatelessWidget {
  const _OfferStatusChip({required this.status});
  final OfferStatus status;

  @override
  Widget build(BuildContext context) {
    final (color, bg) = switch (status) {
      OfferStatus.pending => (AppColors.accent, AppColors.accent.withValues(alpha: 0.15)),
      OfferStatus.accepted => (const Color(0xFF2E7D32), const Color(0xFF2E7D32).withValues(alpha: 0.12)),
      OfferStatus.rejected => (AppColors.destructive, AppColors.destructive.withValues(alpha: 0.12)),
      OfferStatus.cancelled => (AppColors.mutedForeground, AppColors.muted),
    };
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(8)),
      child: Text(status.label, style: TextStyle(color: color, fontSize: 12, fontWeight: FontWeight.w600)),
    );
  }
}

class _OfferActions extends ConsumerWidget {
  const _OfferActions({required this.offer, required this.isReceived});
  final PriceOffer offer;
  final bool isReceived;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final notifier = ref.read(offersControllerProvider.notifier);
    final l10n = context.l10n;

    if (isReceived) {
      return Row(
        mainAxisAlignment: MainAxisAlignment.end,
        children: [
          OutlinedButton(
            onPressed: () => notifier.reject(offer.id),
            child: Text(l10n.exchangeReject),
          ),
          const SizedBox(width: 8),
          ElevatedButton(
            onPressed: () => notifier.accept(offer.id),
            child: Text(l10n.exchangeAccept),
          ),
        ],
      );
    }

    return Align(
      alignment: Alignment.centerRight,
      child: OutlinedButton(
        onPressed: () => notifier.cancel(offer.id),
        child: Text(l10n.offerCancel),
      ),
    );
  }
}
