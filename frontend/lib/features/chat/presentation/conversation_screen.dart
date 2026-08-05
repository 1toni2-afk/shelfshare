import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
import 'package:url_launcher/url_launcher.dart';
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
import '../application/conversations_controller.dart';
import '../data/chat_repository.dart';
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

  /// ID-ul mesajului evidențiat scurt după ce se sare la el dintr-un rezultat
  /// de căutare - altfel e greu de găsit cu ochiul în mijlocul listei.
  String? _highlightedMessageId;
  Timer? _highlightTimer;

  @override
  void initState() {
    super.initState();
    _loadBlockStatus();
    // Prezența ajunge pe socket fără să spună la ce conversație se referă, așa
    // că i se dă controller-ului cu cine vorbim.
    final otherUserId = widget.otherUser?.id;
    if (otherUserId != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        ref.read(chatControllerProvider(widget.conversationId).notifier).otherUserId =
            otherUserId;
      });
    }
  }

  @override
  void dispose() {
    _highlightTimer?.cancel();
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

  /// Raportarea conversației exportă transcriptul integral și trimite un email
  /// de moderare - vezi ConversationsService#reportConversation.
  Future<void> _reportConversation() async {
    final result = await showDialog<ReportReason>(
      context: context,
      builder: (context) => const ReportReasonDialog(),
    );
    if (result == null) return;
    try {
      await ref
          .read(chatRepositoryProvider)
          .reportConversation(widget.conversationId, reason: result);
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(context.l10n.chatConversationReported)));
      }
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(context.l10n.bookDetailReportError)));
      }
    }
  }

  Future<void> _archiveConversation() async {
    try {
      await ref
          .read(conversationsControllerProvider(false).notifier)
          .setArchived(widget.conversationId, true);
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(context.l10n.chatArchived)));
        context.pop();
      }
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(context.l10n.chatActionError)));
      }
    }
  }

  Future<void> _deleteConversation() async {
    final l10n = context.l10n;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(l10n.chatDeleteTitle),
        content: Text(l10n.chatDeleteConfirm),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: Text(l10n.commonCancel),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: Text(l10n.commonDelete),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    try {
      await ref
          .read(conversationsControllerProvider(false).notifier)
          .delete(widget.conversationId);
      if (mounted) context.pop();
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(l10n.chatActionError)));
      }
    }
  }

  Future<void> _openSearch() async {
    final target = await showSearch<ChatMessage?>(
      context: context,
      delegate: _ConversationSearchDelegate(
        conversationId: widget.conversationId,
        hint: context.l10n.chatSearchInConversation,
        emptyLabel: context.l10n.chatSearchNoResults,
      ),
    );
    if (target != null) _jumpToMessage(target);
  }

  /// Sare la un mesaj găsit în căutare. Dacă e mai vechi decât ce e încărcat
  /// momentan, îl deschidem în context prin paginare succesivă - fără asta,
  /// rezultatul ar duce într-un gol.
  Future<void> _jumpToMessage(ChatMessage target) async {
    final notifier = ref.read(chatControllerProvider(widget.conversationId).notifier);
    var attempts = 0;
    while (mounted &&
        attempts < 10 &&
        !ref
            .read(chatControllerProvider(widget.conversationId))
            .messages
            .any((m) => m.id == target.id) &&
        ref.read(chatControllerProvider(widget.conversationId)).hasMore) {
      await notifier.loadMore();
      attempts++;
    }
    if (!mounted) return;

    setState(() => _highlightedMessageId = target.id);
    _highlightTimer?.cancel();
    _highlightTimer = Timer(const Duration(seconds: 4), () {
      if (mounted) setState(() => _highlightedMessageId = null);
    });

    // Poziționare în doi pași: bulele au înălțimi diferite, deci un salt
    // proporțional doar aproximează locul. După ce cadrul se așază, mesajul e
    // construit și îl putem centra exact cu ensureVisible.
    final messages = ref.read(chatControllerProvider(widget.conversationId)).messages;
    final index = messages.indexWhere((m) => m.id == target.id);
    if (index < 0 || !_scrollController.hasClients) return;

    final ratio = messages.length <= 1 ? 0.0 : index / (messages.length - 1);
    _scrollController.jumpTo(_scrollController.position.maxScrollExtent * ratio);

    await WidgetsBinding.instance.endOfFrame;
    if (!mounted) return;
    final targetContext = GlobalObjectKey(target.id).currentContext;
    // `currentContext` e chiar contextul mesajului, nu al ecranului - dacă
    // există, elementul e montat în arbore acum.
    if (targetContext != null && targetContext.mounted) {
      await Scrollable.ensureVisible(
        targetContext,
        alignment: 0.4,
        duration: const Duration(milliseconds: 250),
      );
    }
  }

  Future<void> _attachPhoto() async {
    final picked = await ImagePicker().pickImage(source: ImageSource.gallery);
    if (picked == null) return;
    final bytes = await picked.readAsBytes();
    final ok = await ref
        .read(chatControllerProvider(widget.conversationId).notifier)
        .sendPhoto(bytes, picked.name);
    if (!ok && mounted) {
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(context.l10n.chatPhotoSendError)));
    }
  }

  /// Meniul de pe long-press al unei bule: răspuns și copiere.
  Future<void> _showMessageActions(ChatMessage message) async {
    final l10n = context.l10n;
    final copyable = message.content ?? message.location;

    await showModalBottomSheet<void>(
      context: context,
      builder: (sheetContext) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.reply),
              title: Text(l10n.chatReply),
              onTap: () {
                Navigator.of(sheetContext).pop();
                ref
                    .read(chatControllerProvider(widget.conversationId).notifier)
                    .setReplyTo(message);
              },
            ),
            if (copyable != null)
              ListTile(
                leading: const Icon(Icons.copy),
                title: Text(l10n.chatCopyMessage),
                onTap: () async {
                  Navigator.of(sheetContext).pop();
                  await Clipboard.setData(ClipboardData(text: copyable));
                  if (mounted) {
                    ScaffoldMessenger.of(context)
                        .showSnackBar(SnackBar(content: Text(l10n.chatMessageCopied)));
                  }
                },
              ),
          ],
        ),
      ),
    );
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

  /// Contra-ofertă (Batch 11): deschide un dialog cu preț nou, apoi cheamă
  /// POST /offers/:id/counter. Backend-ul postează un mesaj nou în chat,
  /// deci după succes reîncărcăm conversația ca să apară imediat.
  Future<void> _handleCounterOffer(ChatMessage message) async {
    final offerId = message.priceOffer?.id;
    if (offerId == null) return;
    final currentAmount = message.priceOffer?.amount ?? 0;
    final result = await showDialog<double>(
      context: context,
      builder: (_) => _CounterOfferDialog(initialAmount: currentAmount),
    );
    if (result == null) return;
    try {
      await ref.read(offersRepositoryProvider).counter(offerId, amount: result);
      // Backendul a marcat original ca REJECTED - update local ca să nu mai
      // afișeze butoanele Accept/Respinge pe cardul vechi cât timp încarcă.
      ref
          .read(chatControllerProvider(widget.conversationId).notifier)
          .updatePriceOfferStatus(message.id, 'REJECTED');
      await ref.read(chatControllerProvider(widget.conversationId).notifier).reload();
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(context.l10n.chatOfferActionError)));
      }
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

    // Un mesaj neconfirmat de server e cea mai enervantă formă de eșec: pare
    // trimis, dar nu a ajuns nicăieri. Îl semnalăm explicit.
    ref.listen(
      chatControllerProvider(widget.conversationId).select((s) => s.sendFailed),
      (previous, next) {
        if (!next) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(context.l10n.chatSendFailed),
            backgroundColor: AppColors.destructive,
          ),
        );
        ref.read(chatControllerProvider(widget.conversationId).notifier).clearSendFailed();
      },
    );

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
        titleSpacing: 0,
        title: _ConversationTitle(
          otherUser: widget.otherUser,
          isOnline: state.otherUserOnline,
          lastSeenAt: state.otherUserLastSeenAt ?? widget.otherUser?.lastSeenAt,
          isTyping: state.otherUserTyping,
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.search),
            tooltip: l10n.chatSearchInConversation,
            onPressed: _openSearch,
          ),
          PopupMenuButton<String>(
            onSelected: (value) {
              switch (value) {
                case 'block':
                  _toggleBlock();
                case 'report-user':
                  _reportUser();
                case 'report-chat':
                  _reportConversation();
                case 'archive':
                  _archiveConversation();
                case 'delete':
                  _deleteConversation();
              }
            },
            itemBuilder: (context) => [
              if (widget.otherUser != null) ...[
                PopupMenuItem(
                  value: 'block',
                  child: Text(
                    (_blockStatus?.blockedByMe ?? false) ? l10n.chatUnblock : l10n.chatBlock,
                  ),
                ),
                PopupMenuItem(value: 'report-user', child: Text(l10n.reportDialogTitle)),
              ],
              PopupMenuItem(value: 'report-chat', child: Text(l10n.chatReportConversation)),
              PopupMenuItem(value: 'archive', child: Text(l10n.chatArchive)),
              PopupMenuItem(value: 'delete', child: Text(l10n.chatDeleteTitle)),
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
                          highlightedMessageId: _highlightedMessageId,
                          onLoadMore: () =>
                              ref.read(chatControllerProvider(widget.conversationId).notifier).loadMore(),
                          onOfferAction: _handleOfferAction,
                          onCounterOffer: _handleCounterOffer,
                          onMessageLongPress: _showMessageActions,
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
            if (state.replyTo != null && !isBlocked)
              _ReplyComposerBar(
                message: state.replyTo!,
                isMine: state.replyTo!.senderId == currentUserId,
                otherUserName: widget.otherUser?.name,
                onCancel: () => ref
                    .read(chatControllerProvider(widget.conversationId).notifier)
                    .setReplyTo(null),
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
                      icon: state.isSendingPhoto
                          ? const SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Icon(Icons.photo_camera_outlined),
                      tooltip: l10n.chatAttachPhoto,
                      onPressed: state.isSendingPhoto ? null : _attachPhoto,
                    ),
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
    required this.highlightedMessageId,
    required this.onLoadMore,
    required this.onOfferAction,
    required this.onCounterOffer,
    required this.onMessageLongPress,
  });

  final List<ChatMessage> messages;
  final String? currentUserId;
  final ScrollController scrollController;
  final bool isLoadingMore;
  final bool hasMore;
  final String? highlightedMessageId;
  final VoidCallback onLoadMore;
  final Future<void> Function(ChatMessage message, {required bool accept}) onOfferAction;
  final Future<void> Function(ChatMessage message) onCounterOffer;
  final Future<void> Function(ChatMessage message) onMessageLongPress;

  /// Ultimul mesaj trimis de mine - singurul sub care se afișează „Văzut",
  /// ca în orice aplicație de chat (bifă pe conversație, nu pe fiecare bulă).
  String? get _lastOwnMessageId {
    for (final message in messages.reversed) {
      if (message.senderId == currentUserId) return message.id;
    }
    return null;
  }

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
          final isHighlighted = message.id == highlightedMessageId;
          final showSeen = isMine && message.id == _lastOwnMessageId;

          return Column(
            // Cheia permite centrarea exactă pe mesaj după o căutare, vezi
            // _jumpToMessage.
            key: GlobalObjectKey(message.id),
            crossAxisAlignment:
                isMine ? CrossAxisAlignment.end : CrossAxisAlignment.start,
            children: [
              GestureDetector(
                onLongPress: () => onMessageLongPress(message),
                child: Container(
                  margin: const EdgeInsets.symmetric(vertical: 4),
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                  constraints:
                      BoxConstraints(maxWidth: MediaQuery.of(context).size.width * 0.75),
                  decoration: BoxDecoration(
                    color: isMine ? AppColors.primary : AppColors.muted,
                    borderRadius: BorderRadius.circular(16),
                    border: isHighlighted
                        ? Border.all(color: AppColors.accent, width: 2)
                        : null,
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      if (message.replyTo != null) ...[
                        _ReplyQuote(
                          reply: message.replyTo!,
                          isMine: isMine,
                          quotedIsMine: message.replyTo!.senderId == currentUserId,
                        ),
                        const SizedBox(height: 6),
                      ],
                      _MessageContent(
                        message: message,
                        isMine: isMine,
                        onOfferAction: onOfferAction,
                        onCounterOffer: onCounterOffer,
                      ),
                    ],
                  ),
                ),
              ),
              if (showSeen)
                Padding(
                  padding: const EdgeInsets.only(right: 4, bottom: 4),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        message.isRead ? Icons.done_all : Icons.done,
                        size: 14,
                        color: message.isRead ? AppColors.accent : AppColors.mutedForeground,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        message.isRead ? context.l10n.chatSeen : context.l10n.chatSent,
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                              color: message.isRead
                                  ? AppColors.accent
                                  : AppColors.mutedForeground,
                              fontSize: 11,
                            ),
                      ),
                    ],
                  ),
                ),
            ],
          );
        },
      ),
    );
  }
}

/// Citatul din interiorul unei bule de răspuns.
class _ReplyQuote extends StatelessWidget {
  const _ReplyQuote({
    required this.reply,
    required this.isMine,
    required this.quotedIsMine,
  });

  final ReplyPreview reply;
  final bool isMine;
  final bool quotedIsMine;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final textColor = isMine ? AppColors.primaryForeground : AppColors.foreground;
    final preview = reply.content ??
        (reply.photo != null ? l10n.chatPhotoPreview : l10n.chatLocationPreview);

    // Bara verticală e un Container separat, nu un Border(left:) - BoxDecoration
    // acceptă borderRadius doar cu un chenar uniform, altfel dă assert la runtime.
    return Container(
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        color: textColor.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(6),
      ),
      child: IntrinsicHeight(
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(width: 3, color: textColor.withValues(alpha: 0.6)),
            Flexible(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      quotedIsMine ? l10n.chatReplyToYou : l10n.chatReplyToThem,
                      style: TextStyle(
                        color: textColor,
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    Text(
                      preview,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: textColor.withValues(alpha: 0.85),
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Bara de deasupra câmpului de scris, cât timp se compune un răspuns.
class _ReplyComposerBar extends StatelessWidget {
  const _ReplyComposerBar({
    required this.message,
    required this.isMine,
    required this.otherUserName,
    required this.onCancel,
  });

  final ChatMessage message;
  final bool isMine;
  final String? otherUserName;
  final VoidCallback onCancel;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final preview = message.content ??
        (message.photo != null ? l10n.chatPhotoPreview : l10n.chatLocationPreview);

    return Container(
      margin: const EdgeInsets.fromLTRB(12, 0, 12, 4),
      padding: const EdgeInsets.only(right: 12, top: 8, bottom: 8),
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        color: AppColors.muted,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          // Bară verticală ca Container, nu Border(left:) - vezi _ReplyQuote.
          Container(width: 3, height: 36, color: AppColors.accent),
          const SizedBox(width: 9),
          const Icon(Icons.reply, size: 16, color: AppColors.accent),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  isMine
                      ? l10n.chatReplyToYou
                      : (otherUserName ?? l10n.chatReplyToThem),
                  style: Theme.of(context)
                      .textTheme
                      .bodySmall
                      ?.copyWith(fontWeight: FontWeight.w700, color: AppColors.accent),
                ),
                Text(preview, maxLines: 1, overflow: TextOverflow.ellipsis),
              ],
            ),
          ),
          IconButton(
            icon: const Icon(Icons.close, size: 18),
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(),
            onPressed: onCancel,
          ),
        ],
      ),
    );
  }
}

/// Antetul cu numele celuilalt: tap pe el duce la profilul public, iar sub el
/// stă starea „online" / „văzut ultima dată".
class _ConversationTitle extends StatelessWidget {
  const _ConversationTitle({
    required this.otherUser,
    required this.isOnline,
    required this.lastSeenAt,
    required this.isTyping,
  });

  final PublicUser? otherUser;
  final bool isOnline;
  final DateTime? lastSeenAt;
  final bool isTyping;

  String _statusLabel(AppLocalizations l10n) {
    if (isTyping) return l10n.chatTyping;
    if (isOnline) return l10n.chatOnline;
    final seen = lastSeenAt;
    if (seen == null) return l10n.chatOffline;

    final diff = DateTime.now().difference(seen);
    if (diff.inMinutes < 1) return l10n.chatLastSeenJustNow;
    if (diff.inHours < 1) return l10n.chatLastSeenMinutes(diff.inMinutes);
    if (diff.inDays < 1) return l10n.chatLastSeenHours(diff.inHours);
    return l10n.chatLastSeenDays(diff.inDays);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final user = otherUser;
    if (user == null) {
      return Text(l10n.chatConversationFallbackTitle);
    }

    return InkWell(
      onTap: () => context.push('/users/${user.id}', extra: user),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            CircleAvatar(
              radius: 18,
              backgroundImage:
                  user.profileImage != null ? NetworkImage(user.profileImage!) : null,
              child: user.profileImage == null ? const Icon(Icons.person, size: 18) : null,
            ),
            const SizedBox(width: 10),
            Flexible(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    user.name ?? l10n.commonUnknownUser,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      if (isOnline) ...[
                        Container(
                          width: 8,
                          height: 8,
                          decoration: BoxDecoration(
                            color: AppColors.success,
                            shape: BoxShape.circle,
                          ),
                        ),
                        const SizedBox(width: 5),
                      ],
                      Flexible(
                        child: Text(
                          _statusLabel(l10n),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: Theme.of(context)
                              .textTheme
                              .bodySmall
                              ?.copyWith(color: AppColors.mutedForeground),
                        ),
                      ),
                    ],
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

/// Căutare în conversația deschisă. Întoarce mesajul ales, ca ecranul să sară
/// la el în firul principal.
class _ConversationSearchDelegate extends SearchDelegate<ChatMessage?> {
  _ConversationSearchDelegate({
    required this.conversationId,
    required this.hint,
    required this.emptyLabel,
  });

  final String conversationId;
  final String hint;
  final String emptyLabel;

  // SearchDelegate reconstruiește rezultatele la fiecare rebuild, nu doar când
  // se schimbă textul - fără memoizare, un simplu redraw ar retrimite cererea.
  String? _cachedQuery;
  Future<List<ChatMessage>>? _cachedResults;

  Future<List<ChatMessage>> _search(WidgetRef ref, String query) {
    if (_cachedQuery != query || _cachedResults == null) {
      _cachedQuery = query;
      _cachedResults =
          ref.read(chatRepositoryProvider).searchMessages(conversationId, query);
    }
    return _cachedResults!;
  }

  @override
  String get searchFieldLabel => hint;

  @override
  List<Widget> buildActions(BuildContext context) => [
        if (query.isNotEmpty)
          IconButton(icon: const Icon(Icons.clear), onPressed: () => query = ''),
      ];

  @override
  Widget buildLeading(BuildContext context) => IconButton(
        icon: const Icon(Icons.arrow_back),
        onPressed: () => close(context, null),
      );

  // Serverul cere minim 2 caractere, deci nu are rost să întrebăm mai devreme;
  // până atunci ecranul rămâne gol în loc să arate „niciun rezultat".
  @override
  Widget buildSuggestions(BuildContext context) => buildResults(context);

  @override
  Widget buildResults(BuildContext context) {
    if (query.trim().length < 2) return const SizedBox.shrink();

    return Consumer(
      builder: (context, ref, _) {
        return FutureBuilder<List<ChatMessage>>(
          future: _search(ref, query.trim()),
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const Center(child: CircularProgressIndicator());
            }
            final results = snapshot.data ?? const <ChatMessage>[];
            if (results.isEmpty) return Center(child: Text(emptyLabel));

            return ListView.separated(
              itemCount: results.length,
              separatorBuilder: (_, _) => const Divider(height: 1),
              itemBuilder: (context, index) {
                final message = results[index];
                final date = message.createdAt.toLocal();
                return ListTile(
                  title: Text(
                    message.content ?? message.location ?? '',
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  subtitle: Text(
                    '${date.day}.${date.month}.${date.year} '
                    '${date.hour.toString().padLeft(2, '0')}:'
                    '${date.minute.toString().padLeft(2, '0')}',
                  ),
                  onTap: () => close(context, message),
                );
              },
            );
          },
        );
      },
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
  const _MessageContent({
    required this.message,
    required this.isMine,
    required this.onOfferAction,
    required this.onCounterOffer,
  });
  final ChatMessage message;
  final bool isMine;
  final Future<void> Function(ChatMessage message, {required bool accept}) onOfferAction;
  final Future<void> Function(ChatMessage message) onCounterOffer;

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
            Wrap(
              spacing: 8,
              runSpacing: 4,
              children: [
                OutlinedButton(
                  onPressed: () => onOfferAction(message, accept: false),
                  child: Text(l10n.exchangeReject),
                ),
                // Contra-ofertă (Batch 11) - deschide dialog cu preț nou.
                TextButton(
                  onPressed: () => onCounterOffer(message),
                  child: Text(l10n.chatOfferCounterAction),
                ),
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
                  onTap: () => launchUrl(
                    Uri.parse(
                      'https://www.openstreetmap.org/?mlat=${message.locationLat}&mlon=${message.locationLng}#map=17/${message.locationLat}/${message.locationLng}',
                    ),
                    mode: LaunchMode.externalApplication,
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

/// Dialog pentru contra-ofertă (Batch 11). Preț nou cu validare (>0),
/// prepopulate cu valoarea curentă ca punct de plecare pentru negociere.
/// Returnează suma sau null dacă user a anulat.
class _CounterOfferDialog extends StatefulWidget {
  const _CounterOfferDialog({required this.initialAmount});
  final double initialAmount;

  @override
  State<_CounterOfferDialog> createState() => _CounterOfferDialogState();
}

class _CounterOfferDialogState extends State<_CounterOfferDialog> {
  late final TextEditingController _controller;
  String? _error;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(
      text: widget.initialAmount > 0
          ? widget.initialAmount.toStringAsFixed(0)
          : '',
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _submit() {
    final raw = _controller.text.trim().replaceAll(',', '.');
    final value = double.tryParse(raw);
    if (value == null || value <= 0) {
      setState(() => _error = context.l10n.addBookInvalidPrice);
      return;
    }
    Navigator.of(context).pop(value);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return AlertDialog(
      title: Text(l10n.chatOfferCounterTitle),
      content: TextField(
        controller: _controller,
        keyboardType: const TextInputType.numberWithOptions(decimal: true),
        autofocus: true,
        decoration: InputDecoration(
          labelText: l10n.addBookPriceLabel,
          suffixText: 'lei',
          errorText: _error,
        ),
        onSubmitted: (_) => _submit(),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: Text(l10n.commonCancel),
        ),
        ElevatedButton(
          onPressed: _submit,
          child: Text(l10n.chatOfferCounterAction),
        ),
      ],
    );
  }
}
