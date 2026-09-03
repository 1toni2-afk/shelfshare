import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../core/locale/l10n_extensions.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/utils/support_pages.dart';
import '../../../data/models/exchange_request.dart';
import '../../../data/models/user.dart';
import '../../../shared/widgets/book_cover.dart';
import '../../../shared/widgets/centered_scrollable.dart';
import '../../../shared/widgets/report_reason_dialog.dart';
import '../../auth/application/auth_controller.dart';
import '../../auth/application/auth_state.dart';
import '../../chat/data/chat_repository.dart';
import '../../safety/data/safety_repository.dart';
import '../application/exchanges_controller.dart';
import '../data/exchanges_repository.dart';
import 'meeting_sheet.dart';
import '../../../shared/utils/image_upload.dart';

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

    // exchangesControllerProvider primește un reload silențios pe orice
    // notificare live (vezi ExchangesController.build) - dacă cealaltă parte
    // anulează/finalizează/reprogramează din altă sesiune, ne aliniem la noua
    // stare fără să fie nevoie de refresh manual (bug raportat: bannerul de
    // "waiting" rămânea vechi pe ecran până la refresh).
    ref.listen(exchangesControllerProvider, (previous, next) {
      final data = next.value;
      if (data == null) return;
      for (final request in [...data.received, ...data.sent]) {
        if (request.id == widget.exchangeId) {
          if (mounted) setState(() => _exchange = request);
          break;
        }
      }
    });

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
            : RefreshIndicator(
                onRefresh: _fetch,
                child: _ReadyBody(
                  exchange: exchange,
                  myUserId: myUserId,
                  onApply: _apply,
                  onRun: _run,
                ),
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
    final isTerminal = exchange.status != ExchangeStatus.accepted;

    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 640),
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.all(16),
          children: [
            if (isTerminal) ...[
              _DealStatusBanner(
                status: exchange.status,
                cancelledBy: exchange.cancelledBy,
                myUserId: myUserId,
                otherName: other.name ?? l10n.commonAnonymousUser,
              ),
              const SizedBox(height: 16),
            ],
            _BookSummaryCard(exchange: exchange, other: other),
            if (!isTerminal) ...[
              const SizedBox(height: 16),
              _MeetingSection(exchange: exchange, myUserId: myUserId, other: other, onRun: onRun),
              const SizedBox(height: 16),
              _ContactSection(exchange: exchange, myUserId: myUserId, other: other, onRun: onRun),
              const SizedBox(height: 16),
              _SafetySection(exchange: exchange, myUserId: myUserId, onRun: onRun),
              const SizedBox(height: 16),
              _ConditionPhotosSection(exchange: exchange, myUserId: myUserId, onRun: onRun),
              const SizedBox(height: 16),
              _ReportIssueRow(onTap: () => _reportIssue(context, ref, other.id)),
              const SizedBox(height: 12),
              _ActionRow(exchange: exchange, myUserId: myUserId, onRun: onRun),
              const SizedBox(height: 16),
            ] else if (exchange.status == ExchangeStatus.completed) ...[
              const SizedBox(height: 16),
              Align(
                alignment: Alignment.center,
                child: exchange.myRatingGiven(myUserId)
                    ? Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.check_circle, size: 16, color: AppColors.success),
                          const SizedBox(width: 6),
                          Text(l10n.exchangeRated, style: TextStyle(color: AppColors.success)),
                        ],
                      )
                    : OutlinedButton.icon(
                        icon: const Icon(Icons.star_border, size: 18),
                        label: Text(l10n.exchangeRate),
                        onPressed: () => context.push('/exchanges'),
                      ),
              ),
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
      builder: (context) => ReportReasonDialog(target: ReportTargetKind.user),
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
/// săgeată la final) - reutilizat de Schedule meeting/Safety/Contact ca toate
/// secțiunile paginii să arate la fel, indiferent dacă antetul e doar
/// informativ sau și un link de navigare (ex. spre safety-center).
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

/// Rând de navigare stil listă (icon + titlu + săgeată) - folosit pentru
/// "Report an issue", consistent cu restul secțiunilor din pagină.
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

/// Bandă de status pentru schimburile care nu mai sunt "în desfășurare" -
/// singurul lucru afișat pe pagină pe lângă cartea/cartea implicată, ca să
/// nu mai apară butoane moarte (care dădeau eroare la apăsare) după ce
/// schimbul e deja finalizat sau anulat.
class _DealStatusBanner extends StatelessWidget {
  const _DealStatusBanner({
    required this.status,
    required this.cancelledBy,
    required this.myUserId,
    required this.otherName,
  });
  final ExchangeStatus status;
  // Cine a anulat schimbul - 'system' pentru anularea automată la timeout,
  // altfel id-ul unei părți. Folosit ca să afișăm "Anulat de tine" vs
  // "Anulat de <nume>" în loc de un banner generic, identic pe ambele părți.
  final String? cancelledBy;
  final String myUserId;
  final String otherName;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final isCompleted = status == ExchangeStatus.completed;
    final isCancelledByParty =
        status == ExchangeStatus.cancelled && cancelledBy != null && cancelledBy != 'system';
    final (label, color, icon) = switch (status) {
      ExchangeStatus.completed => (l10n.dealFinalisedBanner, AppColors.success, Icons.check_circle),
      ExchangeStatus.cancelled when isCancelledByParty => (
          cancelledBy == myUserId
              ? l10n.dealCancelledByYouBanner
              : l10n.dealCancelledByOtherBanner(otherName),
          AppColors.destructive,
          Icons.cancel,
        ),
      ExchangeStatus.cancelled => (l10n.dealCancelledBanner, AppColors.destructive, Icons.cancel),
      ExchangeStatus.expired => (l10n.dealCancelledBanner, AppColors.destructive, Icons.cancel),
      ExchangeStatus.rejected => (l10n.dealCancelledBanner, AppColors.destructive, Icons.cancel),
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
          if (isCompleted) const SizedBox.shrink(),
        ],
      ),
    );
  }
}

/// Rezumatul schimbului: ce dai (coperți + titlu) vs. cui dai (avatar + nume).
///
/// Titlul stă SUB coperți, nu lângă ele: pe un telefon îngust coloana din
/// dreapta („You receive" + numele + orașul) își lua lățimea din textul
/// orașului, iar ce rămânea pentru titlu erau ~30px - suficient pentru o
/// literă pe rând, deci titlul se afișa vertical, literă cu literă. Acum
/// coloana din dreapta are lățime fixă, iar titlul primește toată lățimea
/// coloanei din stânga.
class _BookSummaryCard extends StatelessWidget {
  const _BookSummaryCard({required this.exchange, required this.other});
  final ExchangeRequest exchange;
  final PublicUser other;

  /// Lățimea coloanei „You receive" - cât să încapă avatarul de 56px plus un
  /// nume pe două rânduri, fără ca orașul să o poată lăți oricât.
  static const double _receiverColumnWidth = 96;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final theme = Theme.of(context);
    final offeredBook = exchange.offeredBook;
    return Card(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    l10n.readyYouGive,
                    style: theme.textTheme.labelSmall?.copyWith(color: AppColors.mutedForeground),
                  ),
                  const SizedBox(height: 6),
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      BookCover(
                        url: exchange.requestedBook.book.coverUrl,
                        fallbackUrl: exchange.requestedBook.photos.isNotEmpty
                            ? exchange.requestedBook.photos.first
                            : null,
                        title: exchange.requestedBook.book.title,
                        width: 56,
                        height: 78,
                      ),
                      if (offeredBook != null) ...[
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 6),
                          child: Icon(Icons.swap_horiz, size: 18, color: AppColors.mutedForeground),
                        ),
                        Column(
                          children: [
                            BookCover(
                              url: offeredBook.book.coverUrl,
                              fallbackUrl: offeredBook.photos.isNotEmpty ? offeredBook.photos.first : null,
                              title: offeredBook.book.title,
                              width: 56,
                              height: 78,
                            ),
                            if (exchange.additionalOfferedBooks.isNotEmpty)
                              Text(
                                '+${exchange.additionalOfferedBooks.length}',
                                style: theme.textTheme.labelSmall
                                    ?.copyWith(color: AppColors.mutedForeground),
                              ),
                          ],
                        ),
                      ],
                    ],
                  ),
                  const SizedBox(height: 10),
                  Text(
                    exchange.requestedBook.book.title,
                    style: theme.textTheme.titleSmall,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  if (exchange.requestedBook.book.author != null)
                    Text(
                      exchange.requestedBook.book.author!,
                      style: theme.textTheme.bodySmall?.copyWith(color: AppColors.mutedForeground),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  if (exchange.offeredAmount != null)
                    Text(
                      l10n.exchangeOffersAmount(exchange.offeredAmount!.toStringAsFixed(0)),
                      style: theme.textTheme.bodySmall,
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
            SizedBox(
              width: _receiverColumnWidth,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    l10n.readyYouReceive,
                    style: theme.textTheme.labelSmall?.copyWith(color: AppColors.mutedForeground),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 4),
                  CircleAvatar(
                    radius: 28,
                    backgroundImage:
                        other.profileImage != null ? NetworkImage(other.profileImage!) : null,
                    child: other.profileImage == null ? const Icon(Icons.person, size: 28) : null,
                  ),
                  const SizedBox(height: 6),
                  Text(
                    other.name ?? l10n.commonAnonymousUser,
                    style: theme.textTheme.bodySmall?.copyWith(fontWeight: FontWeight.w600),
                    textAlign: TextAlign.center,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  if (other.city != null)
                    Text(
                      l10n.readyFromCity(other.city!),
                      style: theme.textTheme.bodySmall?.copyWith(color: AppColors.mutedForeground),
                      textAlign: TextAlign.center,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                ],
              ),
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
    final hasMeeting = exchange.meetingTime != null;
    final awaitsMyResponse = exchange.meetingAwaitsMyResponse(myUserId);
    final awaitsOtherResponse = exchange.meetingAwaitsOtherResponse(myUserId);

    return Card(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Consumer(
          builder: (context, ref, _) {
            final notifier = ref.read(exchangesControllerProvider.notifier);
            final repository = ref.read(exchangesRepositoryProvider);

            if (!hasMeeting) {
              return InkWell(
                onTap: () => showMeetingSheet(context, exchange),
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
                  icon: exchange.isMeetingConfirmed ? Icons.event_available : Icons.event_note,
                  iconColor: exchange.isMeetingConfirmed ? AppColors.success : AppColors.accent,
                  title: l10n.exchangeScheduleMeeting,
                  subtitle:
                      '${formatMeetingDateTime(exchange.meetingTime!.toLocal())} • ${exchange.meetingLocation}',
                ),
                // Cel care a propus ora vede același text ca înainte; cel care
                // trebuie să răspundă vede în plus Accept/Decline. Butoanele de
                // reprogramare/calendar/QR de mai jos rămân disponibile pentru
                // AMÂNDOI cât timp există o oră setată - înainte erau vizibile
                // doar după confirmare, doar pentru unul din cei doi.
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
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton(
                        onPressed: () => showMeetingSheet(context, exchange),
                        child: Text(l10n.exchangeReschedule),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: OutlinedButton(
                        onPressed: () => _openCalendar(context, notifier, exchange.id),
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
  /// Înălțimea comună a perechii „Mai bine nu" / „Trimite numărul" - fixată
  /// ca butoanele să rămână identice indiferent pe câte rânduri cade textul.
  static const double _contactButtonHeight = 52;

  final _phoneController = TextEditingController();
  bool _editing = false;

  /// Etichetă de buton îngustă: text mai mic, centrat, maxim două rânduri.
  Widget _contactButtonLabel(String text) {
    return Text(
      text,
      textAlign: TextAlign.center,
      maxLines: 2,
      overflow: TextOverflow.ellipsis,
      style: const TextStyle(fontSize: 13, height: 1.15),
    );
  }

  @override
  void dispose() {
    _phoneController.dispose();
    super.dispose();
  }

  void _startEditing() {
    _phoneController.text = widget.exchange.myContactPhone(widget.myUserId) ?? '';
    setState(() => _editing = true);
  }

  Future<void> _share(String? phone) async {
    await widget.onRun(
      () => ref.read(exchangesRepositoryProvider).shareContact(widget.exchange.id, phone: phone),
    );
    if (mounted) setState(() => _editing = false);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final exchange = widget.exchange;
    final myShared = exchange.myContactShared(widget.myUserId);
    final otherPhone = exchange.otherContactPhone(widget.myUserId);
    final otherShared = exchange.otherContactShared(widget.myUserId);
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
              // Ambele butoane pe aceeași înălțime fixă, cu eticheta la un
              // corp de literă mai mic: „Trimite numărul de telefon" e lung
              // și, lăsat la stilul implicit, se rupea pe trei rânduri, iar
              // butonul creștea de trei ori față de „Mai bine nu" de lângă el.
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      style: OutlinedButton.styleFrom(
                        foregroundColor: AppColors.destructive,
                        side: const BorderSide(color: AppColors.destructive),
                        minimumSize: const Size.fromHeight(_contactButtonHeight),
                        padding: const EdgeInsets.symmetric(horizontal: 8),
                      ),
                      onPressed: () => _share(null),
                      child: _contactButtonLabel(l10n.readyContactSkip),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: ElevatedButton.icon(
                      icon: const Icon(Icons.lock_outline, size: 16),
                      style: ElevatedButton.styleFrom(
                        minimumSize: const Size.fromHeight(_contactButtonHeight),
                        padding: const EdgeInsets.symmetric(horizontal: 8),
                      ),
                      onPressed: () => _share(
                        _phoneController.text.trim().isEmpty ? null : _phoneController.text.trim(),
                      ),
                      label: _contactButtonLabel(l10n.readyContactShare),
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
              // Pe toată lățimea, nu lipit de marginea din stânga: era
              // singurul buton din pagină aliniat altfel decât restul.
              SizedBox(
                width: double.infinity,
                child: OutlinedButton(
                  style: OutlinedButton.styleFrom(
                    foregroundColor: AppColors.accent,
                    side: const BorderSide(color: AppColors.accent),
                    minimumSize: const Size.fromHeight(48),
                  ),
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

/// "Condition Photos" (feature backlog #14) - fiecare parte fotografiază
/// cartea înainte de predare, ca dovadă a stării ei - vezi
/// ExchangeRequest.requesterConditionPhotos/ownerConditionPhotos.
class _ConditionPhotosSection extends ConsumerStatefulWidget {
  const _ConditionPhotosSection({required this.exchange, required this.myUserId, required this.onRun});

  final ExchangeRequest exchange;
  final String myUserId;
  final Future<void> Function(Future<ExchangeRequest> Function()) onRun;

  @override
  ConsumerState<_ConditionPhotosSection> createState() => _ConditionPhotosSectionState();
}

class _ConditionPhotosSectionState extends ConsumerState<_ConditionPhotosSection> {
  static const _maxPhotos = 4;
  bool _uploading = false;

  Future<void> _pickAndUpload() async {
    final picked = await ImagePicker().pickImage(
      source: ImageSource.gallery,
      maxWidth: kContentPhotoMaxDimension.toDouble(),
      maxHeight: kContentPhotoMaxDimension.toDouble(),
      imageQuality: kContentPhotoQuality,
    );
    if (picked == null) return;
    setState(() => _uploading = true);
    try {
      await widget.onRun(
        () async => ref.read(exchangesRepositoryProvider).addConditionPhoto(
              widget.exchange.id,
              bytes: await picked.readAsBytes(),
              filename: picked.name,
            ),
      );
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(context.l10n.readyConditionPhotosError)));
      }
    } finally {
      if (mounted) setState(() => _uploading = false);
    }
  }

  Widget _thumb(String url) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(8),
      child: Image.network(url, width: 64, height: 64, fit: BoxFit.cover),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final mine = widget.exchange.myConditionPhotos(widget.myUserId);
    final theirs = widget.exchange.otherConditionPhotos(widget.myUserId);

    return Card(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _SectionHeaderRow(
              icon: Icons.photo_camera_outlined,
              title: l10n.readyConditionPhotosTitle,
              subtitle: l10n.readyConditionPhotosSubtitle,
            ),
            const SizedBox(height: 12),
            if (mine.isNotEmpty) ...[
              Wrap(
                spacing: 8,
                runSpacing: 8,
                alignment: WrapAlignment.center,
                children: [for (final url in mine) _thumb(url)],
              ),
              const SizedBox(height: 12),
            ],
            // Buton pe toată lățimea, în accentul temei - înainte era un
            // pătrat de 64px lipit de marginea din stânga, care nu semăna cu
            // niciun alt buton din pagină și nu se citea ca acțiune.
            if (mine.length < _maxPhotos)
              SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                  onPressed: _uploading ? null : _pickAndUpload,
                  style: OutlinedButton.styleFrom(
                    foregroundColor: AppColors.accent,
                    side: BorderSide(
                      color: _uploading ? AppColors.border : AppColors.accent,
                    ),
                    minimumSize: const Size.fromHeight(48),
                  ),
                  icon: _uploading
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.add_a_photo_outlined, size: 18),
                  label: Text(l10n.readyConditionPhotosAdd),
                ),
              ),
            if (theirs.isNotEmpty) ...[
              const SizedBox(height: 12),
              Text(l10n.readyConditionPhotosOther, style: Theme.of(context).textTheme.bodySmall),
              const SizedBox(height: 8),
              Wrap(spacing: 8, runSpacing: 8, children: [for (final url in theirs) _thumb(url)]),
            ],
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
