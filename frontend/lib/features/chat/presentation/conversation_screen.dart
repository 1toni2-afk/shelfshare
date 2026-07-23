import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:web/web.dart' as web;
import '../../../core/locale/l10n_extensions.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/utils/browser_download.dart';
import '../../../data/models/message.dart';
import '../../../data/models/price_offer.dart';
import '../../../data/models/user.dart';
import '../../auth/application/auth_controller.dart';
import '../../auth/application/auth_state.dart';
import '../../../shared/widgets/report_reason_dialog.dart';
import '../../offers/data/offers_repository.dart';
import '../../safety/data/safety_repository.dart';
import '../application/chat_controller.dart';
import '../data/places_repository.dart';
import '../../../l10n/app_localizations.dart';

class ConversationScreen extends ConsumerStatefulWidget {
  const ConversationScreen({super.key, required this.conversationId, this.otherUser});
  final String conversationId;
  final PublicUser? otherUser;

  @override
  ConsumerState<ConversationScreen> createState() => _ConversationScreenState();
}

class _ConversationScreenState extends ConsumerState<ConversationScreen> {
  final _messageController = TextEditingController();
  final _scrollController = ScrollController();
  bool _safetyBannerDismissed = false;
  BlockStatus? _blockStatus;

  @override
  void initState() {
    super.initState();
    _loadBlockStatus();
  }

  @override
  void dispose() {
    _messageController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> _loadBlockStatus() async {
    final otherUser = widget.otherUser;
    if (otherUser == null) return;
    try {
      final status = await ref.read(safetyRepositoryProvider).getBlockStatus(otherUser.id);
      if (mounted) setState(() => _blockStatus = status);
    } catch (_) {
      // Nesemnificativ dacă eșuează - banner-ul de blocare rămâne ascuns.
    }
  }

  Future<void> _toggleBlock() async {
    final otherUser = widget.otherUser;
    if (otherUser == null) return;
    final repository = ref.read(safetyRepositoryProvider);
    final isBlocked = _blockStatus?.blockedByMe ?? false;
    try {
      if (isBlocked) {
        await repository.unblockUser(otherUser.id);
      } else {
        await repository.blockUser(otherUser.id);
      }
      await _loadBlockStatus();
      if (mounted) {
        final l10n = context.l10n;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(isBlocked ? l10n.chatUserUnblocked : l10n.chatUserBlocked)),
        );
      }
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(context.l10n.chatBlockUpdateError)));
      }
    }
  }

  Future<void> _reportUser() async {
    final otherUser = widget.otherUser;
    if (otherUser == null) return;
    final result = await showDialog<ReportReason>(
      context: context,
      builder: (context) => const ReportReasonDialog(),
    );
    if (result == null) return;
    try {
      await ref.read(safetyRepositoryProvider).reportUser(otherUser.id, reason: result);
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(context.l10n.bookDetailReportSent)));
      }
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(context.l10n.bookDetailReportError)));
      }
    }
  }

  void _send() {
    final text = _messageController.text;
    if (text.trim().isEmpty) return;
    ref.read(chatControllerProvider(widget.conversationId).notifier).sendMessage(text);
    _messageController.clear();
  }

  Future<void> _shareLocation() async {
    final result = await showModalBottomSheet<_LocationShareResult>(
      context: context,
      isScrollControlled: true,
      builder: (context) => const _ShareLocationSheet(),
    );
    if (result != null) {
      ref.read(chatControllerProvider(widget.conversationId).notifier).sendLocation(
            result.place.displayName,
            lat: result.place.lat,
            lng: result.place.lng,
            meetingAt: result.meetingAt,
          );
    }
  }

  Future<void> _handleOfferAction(ChatMessage message, {required bool accept}) async {
    final offerId = message.priceOffer?.id;
    if (offerId == null) return;
    try {
      if (accept) {
        await ref.read(offersRepositoryProvider).accept(offerId);
      } else {
        await ref.read(offersRepositoryProvider).reject(offerId);
      }
      ref.read(chatControllerProvider(widget.conversationId).notifier).updatePriceOfferStatus(
            message.id,
            accept ? 'ACCEPTED' : 'REJECTED',
          );
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(context.l10n.chatOfferActionError)));
      }
    }
  }

  void _scrollToBottom() {
    if (!_scrollController.hasClients) return;
    _scrollController.animateTo(
      _scrollController.position.maxScrollExtent,
      duration: const Duration(milliseconds: 250),
      curve: Curves.easeOut,
    );
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(chatControllerProvider(widget.conversationId));
    final authState = ref.watch(authControllerProvider);
    final currentUserId = authState is AuthAuthenticated ? authState.user.id : null;

    ref.listen(chatControllerProvider(widget.conversationId), (previous, next) {
      final previousLastId = previous?.messages.isNotEmpty == true ? previous!.messages.last.id : null;
      final nextLastId = next.messages.isNotEmpty ? next.messages.last.id : null;
      if (nextLastId != null && nextLastId != previousLastId) {
        WidgetsBinding.instance.addPostFrameCallback((_) => _scrollToBottom());
      }
    });

    final isBlocked = (_blockStatus?.blockedByMe ?? false) || (_blockStatus?.blockedByThem ?? false);
    final l10n = context.l10n;

    return Scaffold(
      appBar: AppBar(
        title: Text(widget.otherUser?.name ?? l10n.chatConversationFallbackTitle),
        actions: [
          if (widget.otherUser != null)
            PopupMenuButton<String>(
              onSelected: (value) {
                if (value == 'block') _toggleBlock();
                if (value == 'report') _reportUser();
              },
              itemBuilder: (context) => [
                PopupMenuItem(
                  value: 'block',
                  child: Text((_blockStatus?.blockedByMe ?? false) ? l10n.chatUnblock : l10n.chatBlock),
                ),
                PopupMenuItem(value: 'report', child: Text(l10n.reportDialogTitle)),
              ],
            ),
        ],
      ),
      body: SafeArea(
        child: Column(
          children: [
            if (!_safetyBannerDismissed) _SafetyBanner(onDismiss: () => setState(() => _safetyBannerDismissed = true)),
            Expanded(
              child: state.isLoading
                  ? const Center(child: CircularProgressIndicator())
                  : state.error != null
                      ? Center(child: Text(state.error!))
                      : _MessageList(
                          messages: state.messages,
                          currentUserId: currentUserId,
                          scrollController: _scrollController,
                          isLoadingMore: state.isLoadingMore,
                          hasMore: state.hasMore,
                          onLoadMore: () =>
                              ref.read(chatControllerProvider(widget.conversationId).notifier).loadMore(),
                          onOfferAction: _handleOfferAction,
                        ),
            ),
            if (state.otherUserTyping)
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                child: Align(
                  alignment: Alignment.centerLeft,
                  child: Text(
                    l10n.chatTyping,
                    style: Theme.of(context)
                        .textTheme
                        .bodySmall
                        ?.copyWith(color: AppColors.mutedForeground),
                  ),
                ),
              ),
            if (isBlocked)
              Padding(
                padding: const EdgeInsets.all(16),
                child: Text(
                  l10n.chatBlockedNotice,
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(color: AppColors.mutedForeground),
                  textAlign: TextAlign.center,
                ),
              )
            else
              Padding(
                padding: const EdgeInsets.all(12),
                child: Row(
                  children: [
                    IconButton(
                      icon: const Icon(Icons.location_on_outlined),
                      tooltip: l10n.chatShareLocationTooltip,
                      onPressed: _shareLocation,
                    ),
                    Expanded(
                      child: TextField(
                        controller: _messageController,
                        onChanged: (_) =>
                            ref.read(chatControllerProvider(widget.conversationId).notifier).notifyTyping(),
                        decoration: InputDecoration(hintText: l10n.chatMessageHint),
                        onSubmitted: (_) => _send(),
                      ),
                    ),
                    const SizedBox(width: 8),
                    IconButton.filled(onPressed: _send, icon: const Icon(Icons.send)),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _SafetyBanner extends StatelessWidget {
  const _SafetyBanner({required this.onDismiss});
  final VoidCallback onDismiss;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return Container(
      margin: const EdgeInsets.fromLTRB(12, 12, 12, 0),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.accent.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.shield_outlined, color: AppColors.accent, size: 20),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  l10n.chatSafetyBannerBody,
                  style: Theme.of(context).textTheme.bodySmall,
                ),
                GestureDetector(
                  onTap: () => context.push('/safety-center'),
                  child: Text(
                    l10n.chatSafetyBannerLearnMore,
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: AppColors.accent,
                          fontWeight: FontWeight.w600,
                          decoration: TextDecoration.underline,
                        ),
                  ),
                ),
              ],
            ),
          ),
          IconButton(
            icon: const Icon(Icons.close, size: 16),
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(),
            onPressed: onDismiss,
          ),
        ],
      ),
    );
  }
}

/// Marchează locul unde apare cardul "safety advisor", imediat după orice
/// mesaj de locație cu întâlnire programată - vezi _MessageList._buildItems.
class _SafetyAdvisoryMarker {
  const _SafetyAdvisoryMarker();
}

class _MessageList extends StatelessWidget {
  const _MessageList({
    required this.messages,
    required this.currentUserId,
    required this.scrollController,
    required this.isLoadingMore,
    required this.hasMore,
    required this.onLoadMore,
    required this.onOfferAction,
  });

  final List<ChatMessage> messages;
  final String? currentUserId;
  final ScrollController scrollController;
  final bool isLoadingMore;
  final bool hasMore;
  final VoidCallback onLoadMore;
  final Future<void> Function(ChatMessage message, {required bool accept}) onOfferAction;

  List<Object> _buildItems() {
    final items = <Object>[];
    for (final message in messages) {
      items.add(message);
      if (message.location != null && message.meetingAt != null) {
        items.add(const _SafetyAdvisoryMarker());
      }
    }
    return items;
  }

  @override
  Widget build(BuildContext context) {
    if (messages.isEmpty) {
      return Center(child: Text(context.l10n.chatEmptyMessages));
    }
    final items = _buildItems();
    return NotificationListener<ScrollNotification>(
      onNotification: (notification) {
        if (hasMore && !isLoadingMore && notification.metrics.pixels <= 100) {
          onLoadMore();
        }
        return false;
      },
      child: ListView.builder(
        controller: scrollController,
        padding: const EdgeInsets.all(16),
        itemCount: items.length + (isLoadingMore ? 1 : 0),
        itemBuilder: (context, index) {
          if (isLoadingMore && index == 0) {
            return const Padding(
              padding: EdgeInsets.symmetric(vertical: 8),
              child: Center(child: SizedBox(height: 20, width: 20, child: CircularProgressIndicator(strokeWidth: 2))),
            );
          }
          final itemIndex = isLoadingMore ? index - 1 : index;
          final item = items[itemIndex];
          if (item is _SafetyAdvisoryMarker) {
            return const Padding(
              padding: EdgeInsets.symmetric(vertical: 8),
              child: _SafetyAdvisoryCard(),
            );
          }
          final message = item as ChatMessage;
          final isMine = message.senderId == currentUserId;
          return Align(
            alignment: isMine ? Alignment.centerRight : Alignment.centerLeft,
            child: Container(
              margin: const EdgeInsets.symmetric(vertical: 4),
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              constraints: BoxConstraints(maxWidth: MediaQuery.of(context).size.width * 0.75),
              decoration: BoxDecoration(
                color: isMine ? AppColors.primary : AppColors.muted,
                borderRadius: BorderRadius.circular(16),
              ),
              child: _MessageContent(
                message: message,
                isMine: isMine,
                onOfferAction: onOfferAction,
              ),
            ),
          );
        },
      ),
    );
  }
}

class _SafetyAdvisoryCard extends StatelessWidget {
  const _SafetyAdvisoryCard();

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return Center(
      child: Container(
        constraints: const BoxConstraints(maxWidth: 320),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          color: AppColors.accent.withValues(alpha: 0.12),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.shield_outlined, color: AppColors.accent, size: 18),
                const SizedBox(width: 8),
                Flexible(
                  child: Text(
                    l10n.chatSafetyAdvisorLabel,
                    style: Theme.of(context)
                        .textTheme
                        .bodySmall
                        ?.copyWith(fontWeight: FontWeight.w600, color: AppColors.accent),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 4),
            Text(
              l10n.chatSafetyAdvisorBody,
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodySmall,
            ),
            const SizedBox(height: 8),
            OutlinedButton(
              onPressed: () => context.push('/safety-center'),
              child: Text(l10n.chatSafetyBannerLearnMore),
            ),
          ],
        ),
      ),
    );
  }
}

class _MessageContent extends StatelessWidget {
  const _MessageContent({required this.message, required this.isMine, required this.onOfferAction});
  final ChatMessage message;
  final bool isMine;
  final Future<void> Function(ChatMessage message, {required bool accept}) onOfferAction;

  @override
  Widget build(BuildContext context) {
    final textColor = isMine ? AppColors.primaryForeground : AppColors.foreground;
    final l10n = context.l10n;
    if (message.photo != null) {
      return ClipRRect(
        borderRadius: BorderRadius.circular(8),
        child: Image.network(message.photo!, width: 180, height: 180, fit: BoxFit.cover),
      );
    }
    if (message.priceOffer != null) {
      final offer = message.priceOffer!;
      final status = OfferStatusX.fromJson(offer.status);
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.sell_outlined, size: 16, color: textColor),
              const SizedBox(width: 4),
              Flexible(
                child: Text(
                  l10n.chatOfferCardLabel(offer.amount.toStringAsFixed(0), offer.bookTitle),
                  style: TextStyle(color: textColor, fontWeight: FontWeight.bold),
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(status.label, style: TextStyle(color: textColor, fontSize: 13)),
          if (!isMine && status == OfferStatus.pending) ...[
            const SizedBox(height: 8),
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                OutlinedButton(
                  onPressed: () => onOfferAction(message, accept: false),
                  child: Text(l10n.exchangeReject),
                ),
                const SizedBox(width: 8),
                ElevatedButton(
                  onPressed: () => onOfferAction(message, accept: true),
                  child: Text(l10n.exchangeAccept),
                ),
              ],
            ),
          ],
        ],
      );
    }
    if (message.location != null) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.location_on, size: 16, color: textColor),
              const SizedBox(width: 4),
              Flexible(child: Text(message.location!, style: TextStyle(color: textColor))),
            ],
          ),
          if (message.meetingAt != null) ...[
            const SizedBox(height: 4),
            Text(_formatMeetingDate(l10n, message.meetingAt!), style: TextStyle(color: textColor, fontSize: 13)),
          ],
          const SizedBox(height: 6),
          Wrap(
            spacing: 8,
            children: [
              if (message.locationLat != null && message.locationLng != null)
                _MessageActionButton(
                  icon: Icons.map_outlined,
                  label: l10n.chatMapLabel,
                  textColor: textColor,
                  onTap: () => web.window.open(
                    'https://www.openstreetmap.org/?mlat=${message.locationLat}&mlon=${message.locationLng}#map=17/${message.locationLat}/${message.locationLng}',
                    '_blank',
                  ),
                ),
              if (message.meetingAt != null)
                _MessageActionButton(
                  icon: Icons.calendar_month_outlined,
                  label: l10n.chatCalendarLabel,
                  textColor: textColor,
                  onTap: () => _downloadMeetingIcs(l10n, message),
                ),
            ],
          ),
        ],
      );
    }
    return Text(message.content ?? '', style: TextStyle(color: textColor));
  }

  String _formatMeetingDate(AppLocalizations l10n, DateTime date) {
    final local = date.toLocal();
    final h = local.hour.toString().padLeft(2, '0');
    final m = local.minute.toString().padLeft(2, '0');
    return l10n.chatMeetingAt('${local.day}.${local.month}.${local.year}', '$h:$m');
  }

  void _downloadMeetingIcs(AppLocalizations l10n, ChatMessage message) {
    final start = message.meetingAt!.toUtc();
    final end = start.add(const Duration(hours: 1));
    String formatIcs(DateTime d) =>
        '${d.year.toString().padLeft(4, '0')}${d.month.toString().padLeft(2, '0')}${d.day.toString().padLeft(2, '0')}'
        'T${d.hour.toString().padLeft(2, '0')}${d.minute.toString().padLeft(2, '0')}${d.second.toString().padLeft(2, '0')}Z';

    final ics = [
      'BEGIN:VCALENDAR',
      'VERSION:2.0',
      'PRODID:-//ShelfShare//Chat//RO',
      'BEGIN:VEVENT',
      'UID:${message.id}@shelfshare.demo',
      'DTSTAMP:${formatIcs(DateTime.now().toUtc())}',
      'DTSTART:${formatIcs(start)}',
      'DTEND:${formatIcs(end)}',
      'SUMMARY:Schimb de carte',
      'LOCATION:${message.location}',
      'END:VEVENT',
      'END:VCALENDAR',
    ].join('\r\n');

    downloadTextFile(filename: 'intalnire-shelfshare.ics', content: ics, mimeType: 'text/calendar');
  }
}

class _MessageActionButton extends StatelessWidget {
  const _MessageActionButton({
    required this.icon,
    required this.label,
    required this.textColor,
    required this.onTap,
  });
  final IconData icon;
  final String label;
  final Color textColor;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        decoration: BoxDecoration(
          border: Border.all(color: textColor.withValues(alpha: 0.4)),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 14, color: textColor),
            const SizedBox(width: 4),
            Text(label, style: TextStyle(color: textColor, fontSize: 12)),
          ],
        ),
      ),
    );
  }
}

class _LocationShareResult {
  const _LocationShareResult({required this.place, required this.meetingAt});
  final PlaceResult place;
  final DateTime meetingAt;
}

class _ShareLocationSheet extends ConsumerStatefulWidget {
  const _ShareLocationSheet();

  @override
  ConsumerState<_ShareLocationSheet> createState() => _ShareLocationSheetState();
}

class _ShareLocationSheetState extends ConsumerState<_ShareLocationSheet> {
  final _searchController = TextEditingController();
  Timer? _debounce;
  bool _isSearching = false;
  List<PlaceResult>? _results;
  PlaceResult? _selected;
  DateTime? _date;
  TimeOfDay? _time;
  List<PlaceResult>? _meetingPoints;
  bool _loadingMeetingPoints = false;

  @override
  void dispose() {
    _debounce?.cancel();
    _searchController.dispose();
    super.dispose();
  }

  void _onSearchChanged(String value) {
    _debounce?.cancel();
    if (value.trim().length < 3) {
      setState(() => _results = null);
      return;
    }
    _debounce = Timer(const Duration(milliseconds: 400), () async {
      setState(() => _isSearching = true);
      try {
        final results = await ref.read(placesRepositoryProvider).search(value.trim());
        if (mounted) setState(() => _results = results);
      } finally {
        if (mounted) setState(() => _isSearching = false);
      }
    });
  }

  Future<void> _selectPlace(PlaceResult place) async {
    setState(() {
      _selected = place;
      _meetingPoints = null;
      _loadingMeetingPoints = true;
    });
    try {
      final points = await ref.read(placesRepositoryProvider).meetingPoints(place.lat, place.lng);
      if (mounted) setState(() => _meetingPoints = points);
    } finally {
      if (mounted) setState(() => _loadingMeetingPoints = false);
    }
  }

  IconData _categoryIcon(String? category) {
    switch (category) {
      case 'library':
        return Icons.local_library_outlined;
      case 'cafe':
        return Icons.local_cafe_outlined;
      case 'mall':
        return Icons.shopping_bag_outlined;
      default:
        return Icons.place_outlined;
    }
  }

  Future<void> _pickDate() async {
    final now = DateTime.now();
    final date = await showDatePicker(
      context: context,
      initialDate: _date ?? now,
      firstDate: now,
      lastDate: DateTime(now.year + 1),
    );
    if (date != null) setState(() => _date = date);
  }

  Future<void> _pickTime() async {
    final time = await showTimePicker(context: context, initialTime: _time ?? TimeOfDay.now());
    if (time != null) setState(() => _time = time);
  }

  void _submit() {
    if (_selected == null || _date == null || _time == null) return;
    final meetingAt = DateTime(_date!.year, _date!.month, _date!.day, _time!.hour, _time!.minute);
    Navigator.of(context).pop(_LocationShareResult(place: _selected!, meetingAt: meetingAt));
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
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(l10n.chatShareLocationTooltip, style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: 16),
            if (_selected == null) ...[
              TextField(
                controller: _searchController,
                autofocus: true,
                onChanged: _onSearchChanged,
                decoration: InputDecoration(
                  hintText: l10n.chatSearchPlaceHint,
                  prefixIcon: const Icon(Icons.search),
                ),
              ),
              const SizedBox(height: 8),
              if (_isSearching)
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 16),
                  child: Center(child: CircularProgressIndicator()),
                )
              else if (_results != null)
                ConstrainedBox(
                  constraints: const BoxConstraints(maxHeight: 260),
                  child: _results!.isEmpty
                      ? Padding(
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          child: Text(l10n.chatNoResults),
                        )
                      : ListView.separated(
                          shrinkWrap: true,
                          itemCount: _results!.length,
                          separatorBuilder: (_, _) => const Divider(height: 1),
                          itemBuilder: (context, index) {
                            final place = _results![index];
                            return ListTile(
                              contentPadding: EdgeInsets.zero,
                              leading: const Icon(Icons.place_outlined),
                              title: Text(place.displayName, maxLines: 2, overflow: TextOverflow.ellipsis),
                              onTap: () => _selectPlace(place),
                            );
                          },
                        ),
                ),
            ] else ...[
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: const Icon(Icons.place, color: AppColors.accent),
                title: Text(_selected!.displayName),
                trailing: TextButton(
                  onPressed: () => setState(() {
                    _selected = null;
                    _meetingPoints = null;
                  }),
                  child: Text(l10n.addBookChange),
                ),
              ),
              const SizedBox(height: 12),
              if (_loadingMeetingPoints)
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 8),
                  child: Center(child: CircularProgressIndicator()),
                )
              else if (_meetingPoints != null && _meetingPoints!.isNotEmpty) ...[
                Text(
                  l10n.chatSuggestedMeetingPoints,
                  style: Theme.of(context).textTheme.labelLarge,
                ),
                const SizedBox(height: 8),
                SizedBox(
                  height: 88,
                  child: ListView.separated(
                    scrollDirection: Axis.horizontal,
                    itemCount: _meetingPoints!.length,
                    separatorBuilder: (_, _) => const SizedBox(width: 8),
                    itemBuilder: (context, index) {
                      final point = _meetingPoints![index];
                      return SizedBox(
                        width: 140,
                        child: OutlinedButton.icon(
                          onPressed: () => setState(() => _selected = point),
                          icon: Icon(_categoryIcon(point.category), size: 18),
                          label: Text(
                            point.displayName,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            textAlign: TextAlign.left,
                            style: Theme.of(context).textTheme.bodySmall,
                          ),
                        ),
                      );
                    },
                  ),
                ),
                const SizedBox(height: 12),
              ],
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: _pickDate,
                      child: Text(_date == null ? l10n.chatPickDate : '${_date!.day}.${_date!.month}.${_date!.year}'),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: OutlinedButton(
                      onPressed: _pickTime,
                      child: Text(_time == null ? l10n.chatPickTime : _time!.format(context)),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 20),
              ElevatedButton(
                onPressed: (_date != null && _time != null) ? _submit : null,
                child: Text(l10n.commonSubmit),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
