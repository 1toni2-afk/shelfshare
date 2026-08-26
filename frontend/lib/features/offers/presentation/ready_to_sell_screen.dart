import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../core/locale/l10n_extensions.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/utils/support_pages.dart';
import '../../../data/models/price_offer.dart';
import '../../../data/models/user.dart';
import '../../../shared/widgets/book_cover.dart';
import '../../../shared/widgets/centered_scrollable.dart';
import '../../../shared/widgets/report_reason_dialog.dart';
import '../../auth/application/auth_controller.dart';
import '../../auth/application/auth_state.dart';
import '../../chat/data/chat_repository.dart';
import '../../safety/data/safety_repository.dart';
import '../../exchanges/presentation/meeting_sheet.dart' show formatMeetingDateTime;
import '../application/offers_controller.dart';
import '../data/offers_repository.dart';
import 'sell_meeting_sheet.dart';

/// Analog cu exchanges/presentation/ready_to_exchange_screen.dart, pentru o
/// vânzare cu bani (PriceOffer) - o vânzare acceptată tot presupune o
/// întâlnire fizică, deci trece prin același flow (programare, contact,
/// safety ack, Cancel/Postpone/Done cu confirmare mutuală).
class ReadyToSellScreen extends ConsumerStatefulWidget {
  const ReadyToSellScreen({super.key, required this.offerId, this.initial});

  final String offerId;
  final PriceOffer? initial;

  @override
  ConsumerState<ReadyToSellScreen> createState() => _ReadyToSellScreenState();
}

class _ReadyToSellScreenState extends ConsumerState<ReadyToSellScreen> {
  PriceOffer? _offer;
  bool _loading = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _offer = widget.initial;
    if (_offer == null) {
      _fetch();
    }
  }

  Future<void> _fetch() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final result = await ref.read(offersRepositoryProvider).getOne(widget.offerId);
      if (mounted) setState(() => _offer = result);
    } catch (_) {
      if (mounted) setState(() => _error = context.l10n.offersLoadError);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  void _apply(PriceOffer updated) {
    if (mounted) setState(() => _offer = updated);
    ref.read(offersControllerProvider.notifier).refresh();
  }

  Future<void> _run(Future<PriceOffer> Function() action) async {
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

    ref.listen(offersControllerProvider, (previous, next) {
      final data = next.value;
      if (data == null) return;
      for (final offer in [...data.received, ...data.sent]) {
        if (offer.id == widget.offerId) {
          if (mounted) setState(() => _offer = offer);
          break;
        }
      }
    });

    final offer = _offer;
    final authState = ref.watch(authControllerProvider);
    final myUserId = authState is AuthAuthenticated ? authState.user.id : null;

    return Scaffold(
      appBar: AppBar(title: Text(l10n.readyTitle)),
      body: SafeArea(
        child: offer == null || myUserId == null
            ? CenteredScrollable(
                child: _loading
                    ? const CircularProgressIndicator()
                    : Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(_error ?? l10n.offersLoadError),
                          const SizedBox(height: 8),
                          OutlinedButton(onPressed: _fetch, child: Text(l10n.commonRetry)),
                        ],
                      ),
              )
            : RefreshIndicator(
                onRefresh: _fetch,
                child: _ReadySellBody(
                  offer: offer,
                  myUserId: myUserId,
                  onRun: _run,
                ),
              ),
      ),
    );
  }
}

class _ReadySellBody extends ConsumerWidget {
  const _ReadySellBody({
    required this.offer,
    required this.myUserId,
    required this.onRun,
  });

  final PriceOffer offer;
  final String myUserId;
  final Future<void> Function(Future<PriceOffer> Function()) onRun;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final isBuyer = offer.isBuyer(myUserId);
    final other = isBuyer ? offer.owner : offer.buyer;
    final isTerminal = offer.status != OfferStatus.accepted;

    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 640),
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.all(16),
          children: [
            if (isTerminal) ...[
              _SaleStatusBanner(
                status: offer.status,
                cancelledBy: offer.cancelledBy,
                myUserId: myUserId,
                otherName: other.name ?? l10n.commonAnonymousUser,
              ),
              const SizedBox(height: 16),
            ],
            _OfferSummaryCard(offer: offer, other: other),
            if (!isTerminal) ...[
              const SizedBox(height: 16),
              _SellMeetingSection(offer: offer, myUserId: myUserId, other: other, onRun: onRun),
              const SizedBox(height: 16),
              _SellContactSection(offer: offer, myUserId: myUserId, other: other, onRun: onRun),
              const SizedBox(height: 16),
              _SellSafetySection(offer: offer, myUserId: myUserId, onRun: onRun),
              const SizedBox(height: 16),
              _ReportIssueRow(onTap: () => _reportIssue(context, ref, other.id)),
              const SizedBox(height: 12),
              _SellActionRow(offer: offer, myUserId: myUserId, onRun: onRun),
              const SizedBox(height: 16),
            ],
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

/// Antetul standard al unei secțiuni (icon + titlu + subtitlu, opțional cu
/// săgeată la final) - mirror al widget-ului din ready_to_exchange_screen.dart.
class _SectionHeaderRow extends StatelessWidget {
  const _SectionHeaderRow({
    required this.icon,
    required this.title,
    required this.subtitle,
    this.iconColor,
    this.trailing,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final Color? iconColor;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, color: iconColor ?? AppColors.foreground),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title, style: Theme.of(context).textTheme.titleSmall),
              const SizedBox(height: 2),
              Text(
                subtitle,
                style: Theme.of(context).textTheme.bodySmall?.copyWith(color: AppColors.mutedForeground),
              ),
            ],
          ),
        ),
        if (trailing != null) ...[const SizedBox(width: 8), trailing!],
      ],
    );
  }
}

/// Separator "sau" între partajarea telefonului și mesajul din aplicație.
class _OrDivider extends StatelessWidget {
  const _OrDivider();

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return Row(
      children: [
        const Expanded(child: Divider()),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 10),
          child: Text(l10n.commonOr, style: TextStyle(color: AppColors.mutedForeground, fontSize: 12)),
        ),
        const Expanded(child: Divider()),
      ],
    );
  }
}

class _ReportIssueRow extends StatelessWidget {
  const _ReportIssueRow({required this.onTap});
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return Card(
      margin: EdgeInsets.zero,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          child: Row(
            children: [
              Icon(Icons.flag_outlined, size: 20, color: AppColors.mutedForeground),
              const SizedBox(width: 12),
              Expanded(child: Text(l10n.readyReportIssue, style: Theme.of(context).textTheme.bodyMedium)),
              Icon(Icons.chevron_right, color: AppColors.mutedForeground),
            ],
          ),
        ),
      ),
    );
  }
}

class _SaleStatusBanner extends StatelessWidget {
  const _SaleStatusBanner({
    required this.status,
    required this.cancelledBy,
    required this.myUserId,
    required this.otherName,
  });
  final OfferStatus status;
  final String? cancelledBy;
  final String myUserId;
  final String otherName;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final isCancelledByParty =
        status == OfferStatus.cancelled && cancelledBy != null && cancelledBy != 'system';
    final (label, color, icon) = switch (status) {
      OfferStatus.completed => (l10n.dealFinalisedBanner, AppColors.success, Icons.check_circle),
      OfferStatus.cancelled when isCancelledByParty => (
          cancelledBy == myUserId
              ? l10n.dealCancelledByYouBanner
              : l10n.dealCancelledByOtherBanner(otherName),
          AppColors.destructive,
          Icons.cancel,
        ),
      OfferStatus.cancelled => (l10n.dealCancelledBanner, AppColors.destructive, Icons.cancel),
      OfferStatus.expired => (l10n.dealCancelledBanner, AppColors.destructive, Icons.cancel),
      OfferStatus.rejected => (l10n.dealCancelledBanner, AppColors.destructive, Icons.cancel),
      _ => (l10n.dealFinalisedBanner, AppColors.success, Icons.check_circle),
    };
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, color: color),
          const SizedBox(width: 8),
          Text(
            label,
            style: Theme.of(context)
                .textTheme
                .titleMedium
                ?.copyWith(color: color, fontWeight: FontWeight.bold, letterSpacing: 0.5),
          ),
        ],
      ),
    );
  }
}

class _OfferSummaryCard extends StatelessWidget {
  const _OfferSummaryCard({required this.offer, required this.other});
  final PriceOffer offer;
  final PublicUser other;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return Card(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Expanded(
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  BookCover(
                    url: offer.userBook.book.coverUrl,
                    fallbackUrl: offer.userBook.photos.isNotEmpty ? offer.userBook.photos.first : null,
                    title: offer.userBook.book.title,
                    width: 56,
                    height: 78,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          l10n.readyYouGive,
                          style: Theme.of(context).textTheme.labelSmall?.copyWith(color: AppColors.mutedForeground),
                        ),
                        Text(offer.userBook.book.title, style: Theme.of(context).textTheme.titleSmall),
                        if (offer.userBook.book.author != null)
                          Text(
                            offer.userBook.book.author!,
                            style: Theme.of(context).textTheme.bodySmall?.copyWith(color: AppColors.mutedForeground),
                          ),
                        Text(
                          l10n.priceLei(offer.amount.toStringAsFixed(0)),
                          style: Theme.of(context)
                              .textTheme
                              .bodyMedium
                              ?.copyWith(fontWeight: FontWeight.w600, color: AppColors.accent),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8),
              child: DecoratedBox(
                decoration: BoxDecoration(color: AppColors.muted, shape: BoxShape.circle),
                child: Padding(
                  padding: const EdgeInsets.all(6),
                  child: Icon(Icons.swap_horiz, size: 20, color: AppColors.mutedForeground),
                ),
              ),
            ),
            Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  l10n.readyYouReceive,
                  style: Theme.of(context).textTheme.labelSmall?.copyWith(color: AppColors.mutedForeground),
                ),
                const SizedBox(height: 4),
                CircleAvatar(
                  radius: 28,
                  backgroundImage: other.profileImage != null ? NetworkImage(other.profileImage!) : null,
                  child: other.profileImage == null ? const Icon(Icons.person, size: 28) : null,
                ),
                const SizedBox(height: 6),
                ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 90),
                  child: Text(
                    other.name ?? l10n.commonAnonymousUser,
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(fontWeight: FontWeight.w600),
                    textAlign: TextAlign.center,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                if (other.city != null)
                  Text(
                    l10n.readyFromCity(other.city!),
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(color: AppColors.mutedForeground),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _SellMeetingSection extends StatelessWidget {
  const _SellMeetingSection({
    required this.offer,
    required this.myUserId,
    required this.other,
    required this.onRun,
  });

  final PriceOffer offer;
  final String myUserId;
  final PublicUser other;
  final Future<void> Function(Future<PriceOffer> Function()) onRun;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final hasMeeting = offer.meetingTime != null;
    final awaitsMyResponse = offer.meetingAwaitsMyResponse(myUserId);
    final awaitsOtherResponse = offer.meetingAwaitsOtherResponse(myUserId);

    return Card(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Consumer(
          builder: (context, ref, _) {
            final notifier = ref.read(offersControllerProvider.notifier);
            final repository = ref.read(offersRepositoryProvider);

            if (!hasMeeting) {
              return InkWell(
                onTap: () => showSellMeetingSheet(context, offer),
                child: _SectionHeaderRow(
                  icon: Icons.calendar_today_outlined,
                  title: l10n.exchangeScheduleMeeting,
                  subtitle: l10n.readyMeetingSubtitle,
                  trailing: Icon(Icons.chevron_right, color: AppColors.mutedForeground),
                ),
              );
            }

            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _SectionHeaderRow(
                  icon: offer.isMeetingConfirmed ? Icons.event_available : Icons.event_note,
                  iconColor: offer.isMeetingConfirmed ? AppColors.success : AppColors.accent,
                  title: l10n.exchangeScheduleMeeting,
                  subtitle: '${formatMeetingDateTime(offer.meetingTime!.toLocal())} • ${offer.meetingLocation}',
                ),
                if (awaitsOtherResponse) ...[
                  const SizedBox(height: 4),
                  Text(
                    l10n.readyMeetingProposedByMe,
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(color: AppColors.mutedForeground),
                  ),
                ],
                if (awaitsMyResponse) ...[
                  const SizedBox(height: 12),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      OutlinedButton(
                        onPressed: () => onRun(() => repository.declineMeeting(offer.id)),
                        child: Text(l10n.readyMeetingDecline),
                      ),
                      const SizedBox(width: 8),
                      ElevatedButton(
                        onPressed: () => onRun(() => repository.acceptMeeting(offer.id)),
                        child: Text(l10n.readyMeetingAccept),
                      ),
                    ],
                  ),
                ],
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton(
                        onPressed: () => showSellMeetingSheet(context, offer),
                        child: Text(l10n.exchangeReschedule),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: OutlinedButton(
                        onPressed: () => _openCalendar(context, notifier, offer.id),
                        child: Text(l10n.exchangeAddToCalendar),
                      ),
                    ),
                  ],
                ),
              ],
            );
          },
        ),
      ),
    );
  }

  Future<void> _openCalendar(BuildContext context, OffersController notifier, String id) async {
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
}

class _SellContactSection extends ConsumerStatefulWidget {
  const _SellContactSection({
    required this.offer,
    required this.myUserId,
    required this.other,
    required this.onRun,
  });

  final PriceOffer offer;
  final String myUserId;
  final PublicUser other;
  final Future<void> Function(Future<PriceOffer> Function()) onRun;

  @override
  ConsumerState<_SellContactSection> createState() => _SellContactSectionState();
}

class _SellContactSectionState extends ConsumerState<_SellContactSection> {
  final _phoneController = TextEditingController();
  bool _editing = false;

  @override
  void dispose() {
    _phoneController.dispose();
    super.dispose();
  }

  void _startEditing() {
    _phoneController.text = widget.offer.myContactPhone(widget.myUserId) ?? '';
    setState(() => _editing = true);
  }

  Future<void> _share(String? phone) async {
    await widget.onRun(
      () => ref.read(offersRepositoryProvider).shareContact(widget.offer.id, phone: phone),
    );
    if (mounted) setState(() => _editing = false);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final offer = widget.offer;
    final myShared = offer.myContactShared(widget.myUserId);
    final otherPhone = offer.otherContactPhone(widget.myUserId);
    final otherShared = offer.otherContactShared(widget.myUserId);
    final showForm = !myShared || _editing;

    return Card(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _SectionHeaderRow(
              icon: Icons.call_outlined,
              title: l10n.readyContactTitle,
              subtitle: l10n.readyContactSubtitle,
            ),
            const SizedBox(height: 12),
            if (showForm) ...[
              TextField(
                controller: _phoneController,
                keyboardType: TextInputType.phone,
                textAlignVertical: TextAlignVertical.center,
                maxLength: 15,
                inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'[0-9+\-\s()]'))],
                decoration: InputDecoration(
                  hintText: l10n.readyContactPhoneLabel,
                  contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
                  counterText: '',
                ),
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      style: OutlinedButton.styleFrom(
                        foregroundColor: AppColors.destructive,
                        side: const BorderSide(color: AppColors.destructive),
                      ),
                      onPressed: () => _share(null),
                      child: Text(l10n.readyContactSkip),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: ElevatedButton.icon(
                      icon: const Icon(Icons.lock_outline, size: 16),
                      onPressed: () => _share(
                        _phoneController.text.trim().isEmpty ? null : _phoneController.text.trim(),
                      ),
                      label: Text(l10n.readyContactShare),
                    ),
                  ),
                ],
              ),
            ] else
              Row(
                children: [
                  Icon(Icons.check_circle, size: 16, color: AppColors.success),
                  const SizedBox(width: 6),
                  Expanded(child: Text(l10n.readyContactShared)),
                  TextButton(onPressed: _startEditing, child: Text(l10n.readyContactEdit)),
                ],
              ),
            const SizedBox(height: 16),
            const _OrDivider(),
            const SizedBox(height: 8),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
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
            ),
            if (otherShared) ...[
              const SizedBox(height: 12),
              Text(
                otherPhone != null
                    ? l10n.readyContactOtherPhone(otherPhone)
                    : l10n.readyContactSharedNoPhone,
              ),
            ],
            if (otherPhone != null) ...[
              const SizedBox(height: 8),
              SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                  icon: const Icon(Icons.call, size: 18),
                  label: Text(l10n.readyContactCall(widget.other.name ?? l10n.commonAnonymousUser)),
                  onPressed: () => launchUrl(Uri(scheme: 'tel', path: otherPhone)),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _SellSafetySection extends ConsumerWidget {
  const _SellSafetySection({required this.offer, required this.myUserId, required this.onRun});

  final PriceOffer offer;
  final String myUserId;
  final Future<void> Function(Future<PriceOffer> Function()) onRun;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final myAck = offer.mySafetyAck(myUserId);
    final otherAck = offer.otherSafetyAck(myUserId);

    return Card(
      margin: EdgeInsets.zero,
      color: myAck && otherAck ? AppColors.success.withValues(alpha: 0.08) : null,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            InkWell(
              onTap: () => openSupportPage(context, '/safety-center'),
              child: _SectionHeaderRow(
                icon: myAck && otherAck ? Icons.handshake : Icons.privacy_tip_outlined,
                iconColor: myAck && otherAck ? AppColors.success : AppColors.accent,
                title: l10n.readySafetyTitle,
                subtitle: l10n.readySafetySubtitle,
                trailing: Icon(Icons.chevron_right, color: AppColors.mutedForeground),
              ),
            ),
            const SizedBox(height: 8),
            if (!myAck)
              Align(
                alignment: Alignment.centerLeft,
                child: OutlinedButton(
                  style: OutlinedButton.styleFrom(
                    foregroundColor: AppColors.accent,
                    side: const BorderSide(color: AppColors.accent),
                  ),
                  onPressed: () => onRun(() => ref.read(offersRepositoryProvider).acknowledgeSafety(offer.id)),
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

class _SellActionRow extends StatelessWidget {
  const _SellActionRow({required this.offer, required this.myUserId, required this.onRun});

  final PriceOffer offer;
  final String myUserId;
  final Future<void> Function(Future<PriceOffer> Function()) onRun;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;

    if (offer.isAwaitingMyConfirmation(myUserId)) {
      return Consumer(builder: (context, ref, _) {
        final repository = ref.read(offersRepositoryProvider);
        return Column(
          children: [
            Text(l10n.readyOtherMarkedDone, textAlign: TextAlign.center),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: () => onRun(() => repository.disputeDone(offer.id)),
                    child: Text(l10n.readyDisputeDone),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: ElevatedButton(
                    onPressed: () => onRun(() => repository.markDone(offer.id)),
                    child: Text(l10n.readyConfirmDone),
                  ),
                ),
              ],
            ),
          ],
        );
      });
    }

    if (offer.isAwaitingOtherConfirmation(myUserId)) {
      return Text(l10n.readyWaitingConfirmation, textAlign: TextAlign.center);
    }

    return Consumer(builder: (context, ref, _) {
      final repository = ref.read(offersRepositoryProvider);
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
              onPressed: offer.meetingTime == null ? null : () => onRun(() => repository.postpone(offer.id)),
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

  Future<void> _markDone(BuildContext context, OffersRepository repository) async {
    final comment = await showModalBottomSheet<String?>(
      context: context,
      isScrollControlled: true,
      builder: (context) => const _SellDoneReviewSheet(),
    );
    if (comment == _cancelledSentinel) return;
    await onRun(() => repository.markDone(offer.id, comment: comment));
  }

  Future<void> _cancel(BuildContext context, OffersRepository repository) async {
    final result = await showModalBottomSheet<_SellCancelResult?>(
      context: context,
      isScrollControlled: true,
      builder: (context) => const _SellCancelReasonSheet(),
    );
    if (result == null) return;
    await onRun(() => repository.cancel(offer.id, reason: result.reason, details: result.details));
  }
}

const _cancelledSentinel = '__cancelled__';

class _SellDoneReviewSheet extends StatefulWidget {
  const _SellDoneReviewSheet();

  @override
  State<_SellDoneReviewSheet> createState() => _SellDoneReviewSheetState();
}

class _SellDoneReviewSheetState extends State<_SellDoneReviewSheet> {
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

class _SellCancelResult {
  const _SellCancelResult(this.reason, this.details);
  final String reason;
  final String? details;
}

class _SellCancelReasonSheet extends StatefulWidget {
  const _SellCancelReasonSheet();

  @override
  State<_SellCancelReasonSheet> createState() => _SellCancelReasonSheetState();
}

class _SellCancelReasonSheetState extends State<_SellCancelReasonSheet> {
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
              _SellCancelResult(
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
