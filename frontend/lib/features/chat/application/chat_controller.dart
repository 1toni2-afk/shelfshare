import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../data/models/message.dart';
import '../../auth/application/auth_controller.dart';
import '../../auth/application/auth_state.dart';
import '../data/chat_repository.dart';
import '../data/chat_socket_service.dart';

class ChatState {
  const ChatState({
    this.messages = const [],
    this.isLoading = true,
    this.isLoadingMore = false,
    this.hasMore = true,
    this.otherUserTyping = false,
    this.error,
  });

  final List<ChatMessage> messages;
  final bool isLoading;
  final bool isLoadingMore;
  final bool hasMore;
  final bool otherUserTyping;
  final String? error;

  ChatState copyWith({
    List<ChatMessage>? messages,
    bool? isLoading,
    bool? isLoadingMore,
    bool? hasMore,
    bool? otherUserTyping,
    String? error,
    bool clearError = false,
  }) {
    return ChatState(
      messages: messages ?? this.messages,
      isLoading: isLoading ?? this.isLoading,
      isLoadingMore: isLoadingMore ?? this.isLoadingMore,
      hasMore: hasMore ?? this.hasMore,
      otherUserTyping: otherUserTyping ?? this.otherUserTyping,
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
    } catch (_) {
      state = state.copyWith(isLoading: false, error: 'Nu am putut încărca mesajele.');
    }

    await _socketService.connect();
    _socketService.joinConversation(conversationId);
    _socketService.onNewMessage(_handleNewMessage);
    _socketService.onUserTyping(_handleUserTyping);
    unawaited(_repository.markAsRead(conversationId));
  }

  void _handleNewMessage(ChatMessage message) {
    if (message.conversationId != conversationId) return;
    state = state.copyWith(messages: [...state.messages, message]);

    final authState = ref.read(authControllerProvider);
    final currentUserId = authState is AuthAuthenticated ? authState.user.id : null;
    if (message.senderId != currentUserId) {
      unawaited(_repository.markAsRead(conversationId));
    }
  }

  void _handleUserTyping(String forConversationId) {
    if (forConversationId != conversationId) return;
    state = state.copyWith(otherUserTyping: true);
    _typingResetTimer?.cancel();
    _typingResetTimer = Timer(const Duration(seconds: 3), () {
      state = state.copyWith(otherUserTyping: false);
    });
  }

  void sendMessage(String content) {
    final trimmed = content.trim();
    if (trimmed.isEmpty) return;
    _socketService.sendMessage(conversationId: conversationId, content: trimmed);
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
  }
}

final chatControllerProvider = NotifierProvider.family<ChatController, ChatState, String>(
  ChatController.new,
);
