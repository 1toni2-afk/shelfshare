import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../data/models/message.dart';
import '../../auth/application/auth_controller.dart';
import '../../auth/application/auth_state.dart';
import 'conversations_controller.dart';
import '../data/chat_repository.dart';
import '../data/chat_socket_service.dart';

class ChatState {
  const ChatState({
    this.messages = const [],
    this.isLoading = true,
    this.isLoadingMore = false,
    this.hasMore = true,
    this.otherUserTyping = false,
    this.otherUserOnline = false,
    this.otherUserLastSeenAt,
    this.replyTo,
    this.isSendingPhoto = false,
    this.sendFailed = false,
    this.error,
  });

  final List<ChatMessage> messages;
  final bool isLoading;
  final bool isLoadingMore;
  final bool hasMore;
  final bool otherUserTyping;
  final bool otherUserOnline;
  final DateTime? otherUserLastSeenAt;

  /// Mesajul citat în bara de deasupra câmpului de scris, cât timp userul
  /// compune un răspuns. Se golește după trimitere sau la anulare.
  final ChatMessage? replyTo;
  final bool isSendingPhoto;

  /// Ultima trimitere nu a fost confirmată de server. Ecranul îl anunță pe
  /// user, ca mesajul să nu pară plecat când de fapt s-a pierdut.
  final bool sendFailed;
  final String? error;

  ChatState copyWith({
    List<ChatMessage>? messages,
    bool? isLoading,
    bool? isLoadingMore,
    bool? hasMore,
    bool? otherUserTyping,
    bool? otherUserOnline,
    DateTime? otherUserLastSeenAt,
    ChatMessage? replyTo,
    bool clearReplyTo = false,
    bool? isSendingPhoto,
    bool? sendFailed,
    String? error,
    bool clearError = false,
  }) {
    return ChatState(
      messages: messages ?? this.messages,
      isLoading: isLoading ?? this.isLoading,
      isLoadingMore: isLoadingMore ?? this.isLoadingMore,
      hasMore: hasMore ?? this.hasMore,
      otherUserTyping: otherUserTyping ?? this.otherUserTyping,
      otherUserOnline: otherUserOnline ?? this.otherUserOnline,
      otherUserLastSeenAt: otherUserLastSeenAt ?? this.otherUserLastSeenAt,
      replyTo: clearReplyTo ? null : (replyTo ?? this.replyTo),
      isSendingPhoto: isSendingPhoto ?? this.isSendingPhoto,
      sendFailed: sendFailed ?? this.sendFailed,
      error: clearError ? null : (error ?? this.error),
    );
  }
}

class ChatController extends Notifier<ChatState> {
  ChatController(this.conversationId);
  final String conversationId;

  static const _pageSize = 50;

  late final ChatRepository _repository;
  late final ChatSocketService _socketService;
  Timer? _typingResetTimer;

  /// Setat de ecran imediat după build, ca prezența primită pe socket să fie
  /// filtrată după persoana potrivită (aceeași cameră `user:<id>` primește
  /// prezența tuturor partenerilor de discuție).
  String? otherUserId;

  @override
  ChatState build() {
    _repository = ref.read(chatRepositoryProvider);
    _socketService = ref.read(chatSocketServiceProvider);
    ref.onDispose(_cleanup);
    _init();
    return const ChatState();
  }

  Future<void> _init() async {
    try {
      final messages = await _repository.getMessages(conversationId);
      state = state.copyWith(messages: messages, isLoading: false, hasMore: messages.length >= _pageSize);
    } catch (e) {
      // Logăm cauza reală - „Nu am putut încărca mesajele" e prea generic ca să
      // ne dăm seama dacă e rețea, 401 sau un mesaj neparsabil.
      // ignore: avoid_print
      print('[chat] getMessages a eșuat pentru $conversationId: $e');
      state = state.copyWith(isLoading: false, error: 'Nu am putut încărca mesajele.');
    }

    // Un handshake eșuat nu trebuie să sară peste legarea listener-ilor de mai
    // jos: dacă socket.io reușește o reconectare ulterioară, conversația
    // trebuie să primească mesajele live pe ACELAȘI socket. Înainte, excepția
    // ieșea din `_init` (apelat fără await din `build`) și rămânea neprinsă.
    try {
      await _socketService.connect();
    } catch (error) {
      // ignore: avoid_print
      print('[chat] socketul nu s-a conectat pentru $conversationId: $error');
    }
    _socketService.joinConversation(
      conversationId,
      onJoined: (online) => state = state.copyWith(otherUserOnline: online),
    );
    _socketService.onNewMessage(_handleNewMessage);
    _socketService.onUserTyping(_handleUserTyping);
    _socketService.onMessagesRead(_handleMessagesRead);
    _socketService.onUserPresence(_handlePresence);
    _socketService.onPriceOfferUpdated(_handlePriceOfferUpdated);
    _socketService.onExchangeRequestUpdated(_handleExchangeRequestUpdated);
    _markRead();
  }

  void _handleNewMessage(ChatMessage message) {
    if (message.conversationId != conversationId) return;
    // Pozele proprii sunt deja adăugate optimist la finalul upload-ului, deci
    // difuzarea de pe server ar produce un duplicat.
    if (state.messages.any((m) => m.id == message.id)) return;
    state = state.copyWith(messages: [...state.messages, message]);

    if (message.senderId != _currentUserId) _markRead();
  }

  void _handleUserTyping(String forConversationId) {
    if (forConversationId != conversationId) return;
    state = state.copyWith(otherUserTyping: true);
    _typingResetTimer?.cancel();
    _typingResetTimer = Timer(const Duration(seconds: 3), () {
      state = state.copyWith(otherUserTyping: false);
    });
  }

  /// Celălalt a deschis conversația: toate mesajele mele de până acum sunt
  /// citite, deci bifa „Văzut" de sub ultimul mesaj propriu devine activă.
  void _handleMessagesRead(String forConversationId) {
    if (forConversationId != conversationId) return;
    final me = _currentUserId;
    state = state.copyWith(
      messages: [
        for (final m in state.messages)
          m.senderId == me && !m.isRead ? m.copyWith(isRead: true) : m,
      ],
    );
  }

  void _handlePresence(String userId, bool isOnline, DateTime? lastSeenAt) {
    if (userId != otherUserId) return;
    state = state.copyWith(otherUserOnline: isOnline, otherUserLastSeenAt: lastSeenAt);
  }

  String? get _currentUserId {
    final authState = ref.read(authControllerProvider);
    return authState is AuthAuthenticated ? authState.user.id : null;
  }

  /// Marcăm și pe socket (pentru bifa instantanee a expeditorului), și pe HTTP
  /// (sursa de adevăr pentru badge-ul din lista de conversații). Lista de
  /// conversații ține propria copie a `unreadCount` - fără invalidarea ei,
  /// badge-ul de necitite rămâne cu valoarea veche până la un refresh
  /// independent, deși mesajele sunt deja marcate citite pe server.
  void _markRead() {
    _socketService.markRead(conversationId);
    unawaited(
      _repository.markAsRead(conversationId).then((_) {
        ref.invalidate(conversationsControllerProvider(false));
        ref.invalidate(conversationsControllerProvider(true));
      }),
    );
  }

  void setReplyTo(ChatMessage? message) {
    state = message == null
        ? state.copyWith(clearReplyTo: true)
        : state.copyWith(replyTo: message);
  }

  void sendMessage(String content) {
    final trimmed = content.trim();
    if (trimmed.isEmpty) return;
    _socketService.sendMessage(
      conversationId: conversationId,
      content: trimmed,
      replyToId: state.replyTo?.id,
      onFailed: _markSendFailed,
      onSent: _appendSentMessage,
    );
    state = state.copyWith(clearReplyTo: true, sendFailed: false);
  }

  /// Adaugă local mesajul confirmat de server, ca expeditorul să-l vadă
  /// imediat (nu doar destinatarul, prin ecoul de pe cameră). Vezi comentariul
  /// din ChatSocketService.sendMessage.
  void _appendSentMessage(ChatMessage message) {
    if (message.conversationId != conversationId) return;
    if (state.messages.any((m) => m.id == message.id)) return;
    state = state.copyWith(messages: [...state.messages, message]);
  }

  void _markSendFailed([String? reason]) {
    // Loghez motivul primit de la server, ca să avem o urmă când user
    // raportează „nu s-a trimis" - snackbar-ul generic se afișează în
    // conversation_screen.dart în funcție de flagul `sendFailed`.
    if (reason != null && reason.isNotEmpty) {
      // ignore: avoid_print
      print('[chat] send_message respins de server: $reason');
    }
    state = state.copyWith(sendFailed: true);
  }

  void clearSendFailed() {
    if (state.sendFailed) state = state.copyWith(sendFailed: false);
  }

  Future<bool> sendPhoto(List<int> bytes, String filename) async {
    state = state.copyWith(isSendingPhoto: true);
    try {
      final message = await _repository.sendPhoto(
        conversationId,
        bytes: bytes,
        filename: filename,
        replyToId: state.replyTo?.id,
      );
      state = state.copyWith(
        messages: [...state.messages, message],
        isSendingPhoto: false,
        clearReplyTo: true,
      );
      return true;
    } catch (_) {
      state = state.copyWith(isSendingPhoto: false);
      return false;
    }
  }

  void sendLocation(
    String location, {
    required double lat,
    required double lng,
    required DateTime meetingAt,
  }) {
    final trimmed = location.trim();
    // Un rezultat de căutare de loc cu nume gol nu ar trebui să existe, dar
    // dacă totuși se întâmplă, tratăm ca eșec vizibil - altfel userul crede
    // că punctul de întâlnire a fost trimis, când de fapt n-a plecat nimic.
    if (trimmed.isEmpty) {
      _markSendFailed('Locație fără nume');
      return;
    }
    _socketService.sendMessage(
      conversationId: conversationId,
      location: trimmed,
      locationLat: lat,
      locationLng: lng,
      meetingAt: meetingAt.toIso8601String(),
      replyToId: state.replyTo?.id,
      onFailed: _markSendFailed,
      onSent: _appendSentMessage,
    );
    state = state.copyWith(clearReplyTo: true, sendFailed: false);
  }

  /// Refresh mesajelor din conversație (Batch 11) - folosit după acțiuni
  /// care postează mesaje noi în chat pe backend (ex. contra-ofertă), unde
  /// nu trecem prin socket-ul WebSocket și deci nu primim `new_message`.
  Future<void> reload() async {
    try {
      final messages = await _repository.getMessages(conversationId);
      state = state.copyWith(
        messages: messages,
        hasMore: messages.length >= _pageSize,
      );
    } catch (_) {
      // Silent - dacă rețeaua pică, mesajele curente rămân vizibile.
    }
  }

  /// Actualizare optimistă imediat după accept/refuz dintr-un card de ofertă
  /// afișat în chat - celălalt participant vede starea corectă oricum la
  /// următorul fetch de mesaje (vezi ConversationsService#getMessages).
  void updatePriceOfferStatus(String messageId, String newStatus) {
    state = state.copyWith(
      messages: [
        for (final m in state.messages)
          if (m.id == messageId && m.priceOffer != null)
            m.copyWith(
              priceOffer: PriceOfferSummary(
                id: m.priceOffer!.id,
                amount: m.priceOffer!.amount,
                status: newStatus,
                bookTitle: m.priceOffer!.bookTitle,
                bookAuthor: m.priceOffer!.bookAuthor,
                bookCoverUrl: m.priceOffer!.bookCoverUrl,
              ),
            )
          else
            m,
      ],
    );
  }

  /// Actualizare live pentru CELĂLALT participant când oferta e acceptată/
  /// respinsă/contra-ofertată - `updatePriceOfferStatus` de mai sus e doar
  /// optimistă, pentru cel care apasă butonul; acest handler acoperă partea
  /// care nu a apăsat nimic și altfel ar vedea starea veche până la reload.
  void _handlePriceOfferUpdated(String priceOfferId, String status) {
    for (final m in state.messages) {
      if (m.priceOffer?.id == priceOfferId) {
        updatePriceOfferStatus(m.id, status);
        return;
      }
    }
  }

  void _handleExchangeRequestUpdated(String exchangeRequestId, String status) {
    for (final m in state.messages) {
      if (m.exchangeRequest?.id == exchangeRequestId) {
        updateExchangeRequestStatus(m.id, status);
        return;
      }
    }
  }

  /// Actualizare optimistă/live pentru un card de cerere de schimb - analog
  /// cu updatePriceOfferStatus.
  void updateExchangeRequestStatus(String messageId, String newStatus) {
    state = state.copyWith(
      messages: [
        for (final m in state.messages)
          if (m.id == messageId && m.exchangeRequest != null)
            m.copyWith(
              exchangeRequest: ExchangeRequestSummary(
                id: m.exchangeRequest!.id,
                status: newStatus,
                offeredAmount: m.exchangeRequest!.offeredAmount,
                requestedBookTitle: m.exchangeRequest!.requestedBookTitle,
                requestedBookAuthor: m.exchangeRequest!.requestedBookAuthor,
                requestedBookCoverUrl: m.exchangeRequest!.requestedBookCoverUrl,
                offeredBookTitle: m.exchangeRequest!.offeredBookTitle,
                offeredBookAuthor: m.exchangeRequest!.offeredBookAuthor,
                offeredBookCoverUrl: m.exchangeRequest!.offeredBookCoverUrl,
              ),
            )
          else
            m,
      ],
    );
  }

  void notifyTyping() {
    _socketService.notifyTyping(conversationId);
  }

  Future<void> loadMore() async {
    if (state.isLoadingMore || !state.hasMore || state.messages.isEmpty) return;
    state = state.copyWith(isLoadingMore: true);
    try {
      final oldest = state.messages.first;
      final more = await _repository.getMessages(
        conversationId,
        before: oldest.createdAt.toIso8601String(),
      );
      state = state.copyWith(
        messages: [...more, ...state.messages],
        isLoadingMore: false,
        hasMore: more.length >= _pageSize,
      );
    } catch (_) {
      state = state.copyWith(isLoadingMore: false);
    }
  }

  void _cleanup() {
    _typingResetTimer?.cancel();
    _socketService.offNewMessage();
    _socketService.offUserTyping();
    _socketService.offMessagesRead();
    _socketService.offUserPresence();
    _socketService.offPriceOfferUpdated();
    _socketService.offExchangeRequestUpdated();
  }
}

final chatControllerProvider = NotifierProvider.family<ChatController, ChatState, String>(
  ChatController.new,
);
