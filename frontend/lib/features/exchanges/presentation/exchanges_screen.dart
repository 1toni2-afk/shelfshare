import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../../core/theme/app_theme.dart';
import '../../../data/models/exchange_request.dart';
import '../../../shared/widgets/book_cover.dart';
import '../../../shared/widgets/centered_scrollable.dart';
import '../application/exchanges_controller.dart';

String _formatDateTime(DateTime dateTime) {
  final local = dateTime.toLocal();
  String two(int n) => n.toString().padLeft(2, '0');
  return '${two(local.day)}.${two(local.month)}.${local.year}, ${two(local.hour)}:${two(local.minute)}';
}

class ExchangesScreen extends ConsumerWidget {
  const ExchangesScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(exchangesControllerProvider);

    return DefaultTabController(
      length: 2,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Schimburile mele'),
          bottom: const TabBar(
            tabs: [Tab(text: 'Primite'), Tab(text: 'Trimise')],
          ),
        ),
        body: SafeArea(
          child: state.when(
            data: (data) => TabBarView(
              children: [
                _ExchangeList(requests: data.received, isReceived: true),
                _ExchangeList(requests: data.sent, isReceived: false),
              ],
            ),
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (error, _) => CenteredScrollable(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text('Nu am putut încărca schimburile.'),
                  const SizedBox(height: 8),
                  OutlinedButton(
                    onPressed: () => ref.read(exchangesControllerProvider.notifier).refresh(),
                    child: const Text('Încearcă din nou'),
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

class _ExchangeList extends ConsumerWidget {
  const _ExchangeList({required this.requests, required this.isReceived});
  final List<ExchangeRequest> requests;
  final bool isReceived;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return RefreshIndicator(
      onRefresh: () => ref.read(exchangesControllerProvider.notifier).refresh(),
      child: requests.isEmpty
          ? CenteredScrollable(
              child: Text(isReceived
                  ? 'Nu ai primit nicio cerere de schimb.'
                  : 'Nu ai trimis nicio cerere de schimb.'),
            )
          : ListView.separated(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.all(16),
              itemCount: requests.length,
              separatorBuilder: (_, _) => const SizedBox(height: 12),
              itemBuilder: (context, index) =>
                  _ExchangeCard(request: requests[index], isReceived: isReceived),
            ),
    );
  }
}

class _ExchangeCard extends ConsumerStatefulWidget {
  const _ExchangeCard({required this.request, required this.isReceived});
  final ExchangeRequest request;
  final bool isReceived;

  @override
  ConsumerState<_ExchangeCard> createState() => _ExchangeCardState();
}

class _ExchangeCardState extends ConsumerState<_ExchangeCard> {
  bool _busy = false;
  bool _sheetOpen = false;

  Future<void> _run(Future<void> Function() action) async {
    if (_busy) return;
    setState(() => _busy = true);
    try {
      await action();
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(const SnackBar(content: Text('Acțiunea nu a putut fi efectuată.')));
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _openMeetingSheet(ExchangeRequest request) async {
    if (_sheetOpen) return;
    _sheetOpen = true;
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      builder: (context) => _MeetingSheet(request: request),
    );
    _sheetOpen = false;
  }

  Future<void> _openCalendar(String id) async {
    if (_busy) return;
    setState(() => _busy = true);
    try {
      final notifier = ref.read(exchangesControllerProvider.notifier);
      final url = await notifier.calendarUrl(id);
      final launched = await launchUrl(Uri.parse(url), mode: LaunchMode.externalApplication);
      if (!launched && mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(const SnackBar(content: Text('Nu am putut deschide calendarul.')));
      }
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(const SnackBar(content: Text('Nu am putut deschide calendarul.')));
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final request = widget.request;
    final notifier = ref.read(exchangesControllerProvider.notifier);
    final otherUser = widget.isReceived ? request.requester : request.owner;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                BookCover(url: request.requestedBook.book.coverUrl, width: 56, height: 78, borderRadius: 8),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        request.requestedBook.book.title,
                        style: Theme.of(context)
                            .textTheme
                            .bodyLarge
                            ?.copyWith(fontWeight: FontWeight.w600),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 4),
                      Text(
                        widget.isReceived
                            ? 'Cerută de ${otherUser.name ?? 'Utilizator'}'
                            : 'De la ${otherUser.name ?? 'Utilizator'}',
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                      if (request.offeredBook != null)
                        Text(
                          'Oferă: ${request.offeredBook!.book.title}',
                          style: Theme.of(context).textTheme.bodySmall,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                    ],
                  ),
                ),
                _StatusChip(status: request.status),
              ],
            ),
            if (request.message != null && request.message!.isNotEmpty) ...[
              const SizedBox(height: 12),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: AppColors.muted,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text('„${request.message!}"', style: Theme.of(context).textTheme.bodySmall),
              ),
            ],
            ..._actionsFor(request, notifier),
          ],
        ),
      ),
    );
  }

  List<Widget> _actionsFor(ExchangeRequest request, ExchangesController notifier) {
    if (request.status == ExchangeStatus.pending && widget.isReceived) {
      return [
        const SizedBox(height: 12),
        Row(mainAxisAlignment: MainAxisAlignment.end, children: [
          OutlinedButton(
            onPressed: _busy ? null : () => _run(() => notifier.reject(request.id)),
            child: const Text('Refuză'),
          ),
          const SizedBox(width: 8),
          ElevatedButton(
            onPressed: _busy ? null : () => _run(() => notifier.accept(request.id)),
            child: const Text('Acceptă'),
          ),
        ]),
      ];
    }
    if (request.status == ExchangeStatus.pending && !widget.isReceived) {
      return [
        const SizedBox(height: 12),
        Row(mainAxisAlignment: MainAxisAlignment.end, children: [
          OutlinedButton(
            onPressed: _busy ? null : () => _run(() => notifier.cancel(request.id)),
            child: const Text('Anulează cererea'),
          ),
        ]),
      ];
    }
    if (request.status == ExchangeStatus.accepted) {
      return [
        const SizedBox(height: 12),
        if (request.meetingTime != null) ...[
          _MeetingInfo(request: request),
          const SizedBox(height: 12),
        ],
        Wrap(
          alignment: WrapAlignment.end,
          spacing: 8,
          runSpacing: 8,
          children: [
            OutlinedButton(
              onPressed: _busy ? null : () => _openMeetingSheet(request),
              child: Text(request.meetingTime == null ? 'Programează întâlnirea' : 'Reprogramează'),
            ),
            if (request.meetingTime != null)
              OutlinedButton(
                onPressed: _busy ? null : () => _openCalendar(request.id),
                child: const Text('Adaugă în calendar'),
              ),
            ElevatedButton(
              onPressed: _busy ? null : () => _run(() => notifier.complete(request.id)),
              child: const Text('Marchează finalizat'),
            ),
          ],
        ),
      ];
    }
    return const [];
  }
}

class _StatusChip extends StatelessWidget {
  const _StatusChip({required this.status});
  final ExchangeStatus status;

  @override
  Widget build(BuildContext context) {
    final (color, background) = switch (status) {
      ExchangeStatus.pending => (AppColors.accent, AppColors.accent.withValues(alpha: 0.15)),
      ExchangeStatus.accepted => (AppColors.primary, AppColors.primary.withValues(alpha: 0.12)),
      ExchangeStatus.completed => (AppColors.foreground, AppColors.secondary),
      ExchangeStatus.rejected ||
      ExchangeStatus.cancelled =>
        (AppColors.mutedForeground, AppColors.muted),
    };
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(color: background, borderRadius: BorderRadius.circular(8)),
      child: Text(
        status.label,
        style: Theme.of(context)
            .textTheme
            .bodySmall
            ?.copyWith(color: color, fontWeight: FontWeight.w600),
      ),
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
            .showSnackBar(const SnackBar(content: Text('Nu am putut salva întâlnirea.')));
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
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text('Programează întâlnirea', style: Theme.of(context).textTheme.titleLarge),
          const SizedBox(height: 20),
          OutlinedButton.icon(
            onPressed: _pickDateTime,
            icon: const Icon(Icons.calendar_today),
            label: Text(_dateTime == null ? 'Alege data și ora' : _formatDateTime(_dateTime!)),
          ),
          const SizedBox(height: 16),
          TextField(
            controller: _locationController,
            maxLength: 200,
            decoration: const InputDecoration(labelText: 'Locație'),
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
                : const Text('Salvează'),
          ),
        ],
      ),
    );
  }
}
