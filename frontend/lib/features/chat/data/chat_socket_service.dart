import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:socket_io_client/socket_io_client.dart' as io;
import '../../../core/network/api_client.dart';
import '../../../core/network/providers.dart';
import '../../../data/models/message.dart';

/// Wrapper peste socket.io pentru namespace-ul /chat al backend-ului.
/// Un singur socket e păstrat pentru toată aplicația (Provider, nu autoDispose).
class ChatSocketService {
  ChatSocketService(this._ref);
  final Ref _ref;
  io.Socket? _socket;
  Future<io.Socket>? _connecting;

  Future<io.Socket> connect() {
    final existing = _socket;
    if (existing != null && existing.connected) return Future.value(existing);
    return _connecting ??= _doConnect();
  }

  Future<io.Socket> _doConnect() async {
    final token = await _ref.read(tokenStorageProvider).getAccessToken();
    final socket = io.io(
      '${ApiConfig.baseUrl}/chat',
      io.OptionBuilder()
          .setTransports(['websocket'])
          .setAuth({'token': token})
          .disableAutoConnect()
          .build(),
    );
    socket.connect();
    _socket = socket;
    _connecting = null;
    return socket;
  }

  void joinConversation(String conversationId) {
    _socket?.emit('join_conversation', conversationId);
  }

  void sendMessage({required String conversationId, String? content}) {
    _socket?.emit('send_message', {
      'conversationId': conversationId,
      'content': ?content,
    });
  }

  void notifyTyping(String conversationId) {
    _socket?.emit('typing', conversationId);
  }

  void onNewMessage(void Function(ChatMessage) handler) {
    _socket?.on(
      'new_message',
      (data) => handler(ChatMessage.fromJson(Map<String, dynamic>.from(data as Map))),
    );
  }

  // Un singur ecran de conversație e activ simultan, deci off() fără handler
  // (care șterge toți listenerii evenimentului) e sigur aici.
  void offNewMessage() => _socket?.off('new_message');

  void onUserTyping(void Function(String conversationId) handler) {
    _socket?.on('user_typing', (data) {
      final map = Map<String, dynamic>.from(data as Map);
      handler(map['conversationId'] as String);
    });
  }

  void offUserTyping() => _socket?.off('user_typing');

  void onMessageNotification(void Function(String conversationId) handler) {
    _socket?.on('message_notification', (data) {
      final map = Map<String, dynamic>.from(data as Map);
      handler(map['conversationId'] as String);
    });
  }

  void offMessageNotification() => _socket?.off('message_notification');
}

final chatSocketServiceProvider = Provider<ChatSocketService>((ref) {
  return ChatSocketService(ref);
});
