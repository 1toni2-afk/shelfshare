import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../core/locale/l10n_extensions.dart';
import '../../../core/theme/app_theme.dart';
import '../../../data/models/exchange_request.dart';
import '../../../data/models/user.dart';
import '../../../shared/widgets/book_cover.dart';
import '../../../shared/widgets/centered_scrollable.dart';
import '../../../shared/widgets/report_reason_dialog.dart';
import '../../../shared/widgets/scannable_qr.dart';
import '../../auth/application/auth_controller.dart';
import '../../auth/application/auth_state.dart';
import '../../chat/data/chat_repository.dart';
import '../../safety/data/safety_repository.dart';
import '../application/exchanges_controller.dart';
import '../data/exchanges_repository.dart';
import 'meeting_sheet.dart';

/// Hub-ul schimbului "în desfășurare" (punctul 6 din flow) - concentrează
/// programarea, partajarea contactului, safety ack și acțiunile finale
/// (Cancel/Postpone/Done) într-un singur loc, ca userul să nu mai sară
/// între ecrane separate pentru fiecare pas.
class ReadyToExchangeScreen extends ConsumerStatefulWidget {
  const ReadyToExchangeScreen({super.key, required this.exchangeId, this.initial});

  final String exchangeId;
  final ExchangeRequest? initial;

  @override
  ConsumerState<ReadyToExchangeScreen> createState() => _ReadyToExchangeScreenState();
}

class _ReadyToExchangeScreenState extends ConsumerState<ReadyToExchangeScreen> {
  ExchangeRequest? _exchange;
  bool _loading = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _exchange = widget.initial;
    if (_exchange == null) {
      _fetch();
    }
  }

  Future<void> _fetch() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final result = await ref.read(exchangesRepositoryProvider).getOne(widget.exchangeId);
      if (mounted) setState(() => _exchange = result);
    } catch (_) {
      if (mounted) setState(() => _error = context.l10n.exchangesLoadError);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  /// Fiecare acțiune de mutație întoarce cererea actualizată - o folosim
  /// direct, plus un refresh silențios al listei din exchanges_screen ca
  /// să rămână sincronizată dacă userul se întoarce acolo.
  void _apply(ExchangeRequest updated) {
    if (mounted) setState(() => _exchange = updated);
    ref.read(exchangesControllerProvider.notifier).refresh();
  }

  Future<void> _run(Future<ExchangeRequest> Function() action) async {
    try {
      final updated = await action();
      _apply(updated);
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(context.l10n.commonGenericError)));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final exchange = _exchange;
    final authState = ref.watch(authControllerProvider);
    final myUserId = authState is AuthAuthenticated ? authState.user.id : null;

    return Scaffold(
      appBar: AppBar(title: Text(l10n.readyTitle)),
      body: SafeArea(
        child: exchange == null || myUserId == null
            ? CenteredScrollable(
                child: _loading
                    ? const CircularProgressIndicator()
                    : Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(_error ?? l10n.exchangesLoadError),
                          const SizedBox(height: 8),
                          OutlinedButton(onPressed: _fetch, child: Text(l10n.commonRetry)),
                        ],
                      ),
              )
            : _ReadyBody(
                exchange: exchange,
                myUserId: myUserId,
                onApply: _apply,
                onRun: _run,
              ),
      ),
    );
  }
}

class _ReadyBody extends ConsumerWidget {
  const _ReadyBody({
    required this.exchange,
    required this.myUserId,
    required this.onApply,
    required this.onRun,
  });

  final ExchangeRequest exchange;
  final String myUserId;
  final void Function(ExchangeRequest) onApply;
  final Future<void> Function(Future<ExchangeRequest> Function()) onRun;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final isRequester = exchange.isRequester(myUserId);
    final other = isRequester ? exchange.owner : exchange.requester;

    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 640),
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            _BookSummaryCard(exchange: exchange, other: other),
            const SizedBox(height: 16),
            _MeetingSection(exchange: exchange, myUserId: myUserId, other: other, onRun: onRun),
            const SizedBox(height: 16),
            _ContactSection(exchange: exchange, myUserId: myUserId, other: other, onRun: onRun),
            const SizedBox(height: 16),
            _SafetySection(exchange: exchange, myUserId: myUserId, onRun: onRun),
            const SizedBox(height: 16),
            Align(
              alignment: Alignment.center,
              child: TextButton.icon(
                icon: const Icon(Icons.flag_outlined, size: 18),
                label: Text(l10n.readyReportIssue),
                onPressed: () => _reportIssue(context, ref, other.id),
              ),
            ),
            const SizedBox(height: 12),
            _ActionRow(exchange: exchange, myUserId: myUserId, onRun: onRun),
            const SizedBox(height: 16),
          ],
        ),
      ),
    );
  }

  Future<void> _reportIssue(BuildContext context, WidgetRef ref, String otherUserId) async {
    final reason = await showDialog<ReportReason>(
      context: context,
      builder: (context) => const ReportReasonDialog(),
    );
    if (reason == null) return;
    try {
      await ref.read(safetyRepositoryProvider).reportUser(otherUserId, reason: reason);
      if (context.mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(context.l10n.reportSubmitted)));
      }
    } catch (_) {
      if (context.mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(context.l10n.commonGenericError)));
      }
    }
  }
}

class _BookSummaryCard extends StatelessWidget {
  const _BookSummaryCard({required this.exchange, required this.other});
  final ExchangeRequest exchange;
  final PublicUser other;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final offeredBook = exchange.offeredBook;
    return Card(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                BookCover(
                  url: exchange.requestedBook.book.coverUrl,
                  fallbackUrl:
                      exchange.requestedBook.photos.isNotEmpty ? exchange.requestedBook.photos.first : null,
                  title: exchange.requestedBook.book.title,
                  width: 56,
                  height: 78,
                ),
                if (offeredBook != null) ...[
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 6),
                    child: Icon(Icons.swap_horiz, size: 18, color: AppColors.mutedForeground),
                  ),
                  BookCover(
                    url: offeredBook.book.coverUrl,
                    fallbackUrl: offeredBook.photos.isNotEmpty ? offeredBook.photos.first : null,
                    title: offeredBook.book.title,
                    width: 56,
                    height: 78,
                  ),
                ],
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(exchange.requestedBook.book.title, style: Theme.of(context).textTheme.titleSmall),
                      if (exchange.offeredAmount != null)
                        Text(
                          l10n.exchangeOffersAmount(exchange.offeredAmount!.toStringAsFixed(0)),
                          style: Theme.of(context).textTheme.bodySmall,
                        ),
                      const SizedBox(height: 10),
                      Row(
                        children: [
                          CircleAvatar(
                            radius: 14,
                            backgroundImage:
                                other.profileImage != null ? NetworkImage(other.profileImage!) : null,
                            child: other.profileImage == null ? const Icon(Icons.person, size: 14) : null,
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              other.name ?? l10n.commonAnonymousUser,
                              style: Theme.of(context).textTheme.bodyMedium,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _MeetingSection extends StatelessWidget {
  const _MeetingSection({
    required this.exchange,
    required this.myUserId,
    required this.other,
    required this.onRun,
  });

  final ExchangeRequest exchange;
  final String myUserId;
  final PublicUser other;
  final Future<void> Function(Future<ExchangeRequest> Function()) onRun;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return Card(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Consumer(
          builder: (context, ref, _) {
            final notifier = ref.read(exchangesControllerProvider.notifier);
            final repository = ref.read(exchangesRepositoryProvider);

            if (exchange.meetingAwaitsMyResponse(myUserId)) {
              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(l10n.readyMeetingAwaitingYou, style: Theme.of(context).textTheme.titleSmall),
                  const SizedBox(height: 6),
                  Text('${formatMeetingDateTime(exchange.meetingTime!.toLocal())} • ${exchange.meetingLocation}'),
                  const SizedBox(height: 12),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      OutlinedButton(
                        onPressed: () => onRun(() => repository.declineMeeting(exchange.id)),
                        child: Text(l10n.readyMeetingDecline),
                      ),
                      const SizedBox(width: 8),
                      ElevatedButton(
                        onPressed: () => onRun(() => repository.acceptMeeting(exchange.id)),
                        child: Text(l10n.readyMeetingAccept),
                      ),
                    ],
                  ),
                ],
              );
            }

            if (exchange.meetingAwaitsOtherResponse(myUserId)) {
              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(l10n.readyMeetingProposedByMe, style: Theme.of(context).textTheme.titleSmall),
                  const SizedBox(height: 6),
                  Text('${formatMeetingDateTime(exchange.meetingTime!.toLocal())} • ${exchange.meetingLocation}'),
                ],
              );
            }

            if (exchange.isMeetingConfirmed) {
              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(Icons.event_available, size: 18, color: AppColors.success),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          '${formatMeetingDateTime(exchange.meetingTime!.toLocal())} • ${exchange.meetingLocation}',
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      OutlinedButton(
                        onPressed: () => showMeetingSheet(context, exchange),
                        child: Text(l10n.exchangeReschedule),
                      ),
                      OutlinedButton(
                        onPressed: () => _openCalendar(context, notifier, exchange.id),
                        child: Text(l10n.exchangeAddToCalendar),
                      ),
                      OutlinedButton(
                        onPressed: () => _showQrDialog(context, exchange.id),
                        child: Text(l10n.exchangeQrCode),
                      ),
                    ],
                  ),
                ],
              );
            }

            return Align(
              alignment: Alignment.centerLeft,
              child: ElevatedButton(
                onPressed: () => showMeetingSheet(context, exchange),
                child: Text(l10n.exchangeScheduleMeeting),
              ),
            );
          },
        ),
      ),
    );
  }

  Future<void> _openCalendar(BuildContext context, ExchangesController notifier, String id) async {
    try {
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
    showDialog<void>(context: context, builder: (context) => _ExchangeQrDialog(exchangeId: exchangeId));
  }
}

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
          Text(l10n.exchangeQrDialogBody, style: Theme.of(context).textTheme.bodySmall, textAlign: TextAlign.center),
          const SizedBox(height: 16),
          ScannableQr(data: link),
        ],
      ),
      actions: [
        TextButton(onPressed: () => Navigator.of(context).pop(), child: Text(l10n.commonClose)),
      ],
    );
  }
}

class _ContactSection extends ConsumerStatefulWidget {
  const _ContactSection({
    required this.exchange,
    required this.myUserId,
    required this.other,
    required this.onRun,
  });

  final ExchangeRequest exchange;
  final String myUserId;
  final PublicUser other;
  final Future<void> Function(Future<ExchangeRequest> Function()) onRun;

  @override
  ConsumerState<_ContactSection> createState() => _ContactSectionState();
}

class _ContactSectionState extends ConsumerState<_ContactSection> {
  final _phoneController = TextEditingController();

  @override
  void dispose() {
    _phoneController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final exchange = widget.exchange;
    final myShared = exchange.myContactShared(widget.myUserId);
    final otherPhone = exchange.otherContactPhone(widget.myUserId);
    final otherShared = exchange.otherContactShared(widget.myUserId);

    return Card(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(l10n.readyContactTitle, style: Theme.of(context).textTheme.titleSmall),
            const SizedBox(height: 10),
            if (!myShared) ...[
              TextField(
                controller: _phoneController,
                keyboardType: TextInputType.phone,
                decoration: InputDecoration(labelText: l10n.readyContactPhoneLabel),
              ),
              const SizedBox(height: 8),
              Align(
                alignment: Alignment.centerRight,
                child: OutlinedButton(
                  onPressed: () => widget.onRun(() => ref.read(exchangesRepositoryProvider).shareContact(
                        exchange.id,
                        phone: _phoneController.text.trim().isEmpty ? null : _phoneController.text.trim(),
                      )),
                  child: Text(l10n.readyContactShare),
                ),
              ),
            ] else
              Row(
                children: [
                  Icon(Icons.check_circle, size: 16, color: AppColors.success),
                  const SizedBox(width: 6),
                  Text(l10n.readyContactShared),
                ],
              ),
            const SizedBox(height: 12),
            if (otherShared)
              Text(
                otherPhone != null
                    ? l10n.readyContactOtherPhone(otherPhone)
                    : l10n.readyContactSharedNoPhone,
              ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                if (otherPhone != null)
                  OutlinedButton.icon(
                    icon: const Icon(Icons.call, size: 18),
                    label: Text(l10n.readyContactCall(widget.other.name ?? l10n.commonAnonymousUser)),
                    onPressed: () => launchUrl(Uri(scheme: 'tel', path: otherPhone)),
                  ),
                OutlinedButton.icon(
                  icon: const Icon(Icons.chat_bubble_outline, size: 18),
                  label: Text(l10n.readyContactMessageInApp),
                  onPressed: () async {
                    final conversation =
                        await ref.read(chatRepositoryProvider).startConversation(widget.other.id);
                    if (context.mounted) {
                      context.push('/chat/${conversation.id}', extra: widget.other);
                    }
                  },
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _SafetySection extends ConsumerWidget {
  const _SafetySection({required this.exchange, required this.myUserId, required this.onRun});

  final ExchangeRequest exchange;
  final String myUserId;
  final Future<void> Function(Future<ExchangeRequest> Function()) onRun;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final myAck = exchange.mySafetyAck(myUserId);
    final otherAck = exchange.otherSafetyAck(myUserId);

    return Card(
      margin: EdgeInsets.zero,
      color: myAck && otherAck ? AppColors.success.withValues(alpha: 0.08) : null,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  myAck && otherAck ? Icons.handshake : Icons.privacy_tip_outlined,
                  color: myAck && otherAck ? AppColors.success : AppColors.accent,
                ),
                const SizedBox(width: 8),
                Expanded(child: Text(l10n.readySafetyTitle, style: Theme.of(context).textTheme.titleSmall)),
              ],
            ),
            const SizedBox(height: 8),
            TextButton(
              onPressed: () => context.push('/safety-center'),
              child: Text(l10n.readySafetyViewLink),
            ),
            if (!myAck)
              Align(
                alignment: Alignment.centerLeft,
                child: ElevatedButton(
                  onPressed: () => onRun(() => ref.read(exchangesRepositoryProvider).acknowledgeSafety(exchange.id)),
                  child: Text(l10n.readySafetyAck),
                ),
              )
            else if (!otherAck)
              Text(l10n.readySafetyWaitingOther, style: Theme.of(context).textTheme.bodySmall)
            else
              Text(
                l10n.readySafetyBothReady,
                style: Theme.of(context).textTheme.bodySmall?.copyWith(color: AppColors.success),
              ),
          ],
        ),
      ),
    );
  }
}

class _ActionRow extends StatelessWidget {
  const _ActionRow({required this.exchange, required this.myUserId, required this.onRun});

  final ExchangeRequest exchange;
  final String myUserId;
  final Future<void> Function(Future<ExchangeRequest> Function()) onRun;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;

    if (exchange.isAwaitingMyConfirmation(myUserId)) {
      return Consumer(builder: (context, ref, _) {
        final repository = ref.read(exchangesRepositoryProvider);
        return Column(
          children: [
            Text(l10n.readyOtherMarkedDone, textAlign: TextAlign.center),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: () => onRun(() => repository.disputeDone(exchange.id)),
                    child: Text(l10n.readyDisputeDone),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: ElevatedButton(
                    onPressed: () => _confirmDone(context, repository),
                    child: Text(l10n.readyConfirmDone),
                  ),
                ),
              ],
            ),
          ],
        );
      });
    }

    if (exchange.isAwaitingOtherConfirmation(myUserId)) {
      return Text(l10n.readyWaitingConfirmation, textAlign: TextAlign.center);
    }

    return Consumer(builder: (context, ref, _) {
      final repository = ref.read(exchangesRepositoryProvider);
      return Row(
        children: [
          Expanded(
            flex: 2,
            child: OutlinedButton(
              style: OutlinedButton.styleFrom(
                foregroundColor: AppColors.destructive,
                side: const BorderSide(color: AppColors.destructive),
              ),
              onPressed: () => _cancel(context, repository),
              child: Text(l10n.readyCancel),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            flex: 1,
            child: OutlinedButton(
              onPressed: exchange.meetingTime == null
                  ? null
                  : () => onRun(() => repository.postpone(exchange.id)),
              child: const Icon(Icons.pause_circle_outline, size: 20),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            flex: 2,
            child: ElevatedButton(
              onPressed: () => _markDone(context, repository),
              child: Text(l10n.readyDone),
            ),
          ),
        ],
      );
    });
  }

  Future<void> _confirmDone(BuildContext context, ExchangesRepository repository) =>
      onRun(() => repository.markDone(exchange.id));

  Future<void> _markDone(BuildContext context, ExchangesRepository repository) async {
    final comment = await showModalBottomSheet<String?>(
      context: context,
      isScrollControlled: true,
      builder: (context) => const _DoneReviewSheet(),
    );
    if (comment == _cancelledSentinel) return;
    await onRun(() => repository.markDone(exchange.id, comment: comment));
  }

  Future<void> _cancel(BuildContext context, ExchangesRepository repository) async {
    final result = await showModalBottomSheet<_CancelResult?>(
      context: context,
      isScrollControlled: true,
      builder: (context) => const _CancelReasonSheet(),
    );
    if (result == null) return;
    await onRun(() => repository.cancel(exchange.id, reason: result.reason, details: result.details));
  }
}

const _cancelledSentinel = '__cancelled__';

class _DoneReviewSheet extends StatefulWidget {
  const _DoneReviewSheet();

  @override
  State<_DoneReviewSheet> createState() => _DoneReviewSheetState();
}

class _DoneReviewSheetState extends State<_DoneReviewSheet> {
  final _controller = TextEditingController();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
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
          Text(l10n.doneReviewTitle, style: Theme.of(context).textTheme.titleLarge),
          const SizedBox(height: 16),
          TextField(
            controller: _controller,
            maxLines: 3,
            decoration: InputDecoration(labelText: l10n.doneReviewLabel),
          ),
          const SizedBox(height: 16),
          ElevatedButton(
            onPressed: () => Navigator.of(context)
                .pop(_controller.text.trim().isEmpty ? null : _controller.text.trim()),
            child: Text(l10n.doneReviewSubmit),
          ),
        ],
      ),
    );
  }
}

class _CancelResult {
  const _CancelResult(this.reason, this.details);
  final String reason;
  final String? details;
}

class _CancelReasonSheet extends StatefulWidget {
  const _CancelReasonSheet();

  @override
  State<_CancelReasonSheet> createState() => _CancelReasonSheetState();
}

class _CancelReasonSheetState extends State<_CancelReasonSheet> {
  String _reason = 'no_show';
  final _detailsController = TextEditingController();

  @override
  void dispose() {
    _detailsController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final options = <(String, String)>[
      ('no_show', l10n.cancelReasonNoShow),
      ('book_mismatch', l10n.cancelReasonBookMismatch),
      ('changed_mind', l10n.cancelReasonChangedMind),
      ('other', l10n.cancelReasonOther),
    ];
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
          Text(l10n.cancelReasonTitle, style: Theme.of(context).textTheme.titleLarge),
          const SizedBox(height: 8),
          for (final (value, label) in options)
            RadioListTile<String>(
              contentPadding: EdgeInsets.zero,
              title: Text(label),
              value: value,
              // ignore: deprecated_member_use
              groupValue: _reason,
              // ignore: deprecated_member_use
              onChanged: (v) => setState(() => _reason = v!),
            ),
          TextField(
            controller: _detailsController,
            maxLines: 2,
            decoration: InputDecoration(labelText: l10n.cancelReasonDetailsLabel),
          ),
          const SizedBox(height: 16),
          ElevatedButton(
            onPressed: () => Navigator.of(context).pop(
              _CancelResult(
                _reason,
                _detailsController.text.trim().isEmpty ? null : _detailsController.text.trim(),
              ),
            ),
            child: Text(l10n.cancelReasonSubmit),
          ),
        ],
      ),
    );
  }
}
