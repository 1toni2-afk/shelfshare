import 'dart:async';

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

  /// Cât așteptăm confirmarea serverului înainte să considerăm mesajul pierdut.
  static const _ackTimeout = Duration(seconds: 8);

  io.Socket? _socket;
  Future<io.Socket>? _connecting;

  Future<io.Socket> connect() {
    final existing = _socket;
    if (existing != null && existing.connected) return Future.value(existing);
    return _connecting ??= _doConnect();
  }

  Future<io.Socket> _doConnect() async {
    final socket = io.io(
      '${ApiConfig.baseUrl}/chat',
      io.OptionBuilder()
          // Polling ca rezervă, nu doar websocket: pe date mobile și în
          // spatele unor proxy-uri (inclusiv Cloudflare Tunnel) upgrade-ul la
          // websocket poate fi blocat, iar cu o listă doar-websocket socket.io
          // nu are unde să cadă înapoi - chatul pur și simplu nu se conectează,
          // fără nicio eroare vizibilă în aplicație.
          .setTransports(['websocket', 'polling'])
          // Funcție, nu un Map static - se apelează din nou la fiecare
          // (re)conectare, inclusiv reconectările automate ale socket.io.
          // Cu un token static, dacă access token-ul expiră (15 minute)
          // cât conversația rămâne deschisă, orice reconectare ulterioară
          // ar retrimite același token expirat la infinit, fără nicio
          // eroare vizibilă - mesajele pur și simplu nu ar mai ajunge.
          .setAuthFn(_provideFreshAuth)
          .disableAutoConnect()
          .build(),
    );
    socket.connect();
    _socket = socket;
    _connecting = null;
    return socket;
  }

  Future<void> _provideFreshAuth(void Function(Map<String, dynamic>) callback) async {
    // Declanșează același mecanism de refresh ca la cererile HTTP obișnuite
    // (interceptorul din ApiClient reîmprospătează automat la un 401) -
    // dacă token-ul curent a expirat, avem unul nou în storage după acest apel.
    try {
      await _ref.read(apiClientProvider).dio.get('/profile/me');
    } catch (_) {}
    final token = await _ref.read(tokenStorageProvider).getAccessToken();
    callback({'token': token});
  }

  /// Serverul răspunde cu starea curentă de prezență a celuilalt participant,
  /// ca antetul să nu aștepte până la următorul lui connect/disconnect.
  void joinConversation(
    String conversationId, {
    void Function(bool otherUserOnline)? onJoined,
  }) {
    _socket?.emitWithAck(
      'join_conversation',
      conversationId,
      ack: (data) {
        if (onJoined == null || data is! Map) return;
        onJoined(data['otherUserOnline'] as bool? ?? false);
      },
    );
  }

  /// [onFailed] se apelează dacă serverul nu confirmă mesajul: fie nu există
  /// socket, fie a răspuns cu o eroare, fie n-a răspuns deloc în [_ackTimeout].
  /// Fără el, un `emit` pe un socket mort dispare în tăcere, iar userul crede
  /// că a trimis mesajul. `onFailed` primește mesajul de eroare de la server
  /// când e disponibil; null pentru „timeout / fără conexiune".
  void sendMessage({
    required String conversationId,
    String? content,
    String? location,
    double? locationLat,
    double? locationLng,
    String? meetingAt,
    String? replyToId,
    void Function([String? reason])? onFailed,
  }) {
    final socket = _socket;
    if (socket == null) {
      onFailed?.call();
      return;
    }

    var acknowledged = false;
    socket.emitWithAck(
      'send_message',
      {
        'conversationId': conversationId,
        'content': ?content,
        'location': ?location,
        'locationLat': ?locationLat,
        'locationLng': ?locationLng,
        'meetingAt': ?meetingAt,
        'replyToId': ?replyToId,
      },
      ack: (data) {
        acknowledged = true;
        // Gateway-ul întoarce mesajul salvat; orice altceva (inclusiv forma
        // `{error: '…'}` a validării noastre) înseamnă eșec.
        final isMessage = data is Map && data['id'] != null;
        if (!isMessage) {
          final reason = data is Map ? data['error']?.toString() : null;
          onFailed?.call(reason);
        }
      },
    );

    Timer(_ackTimeout, () {
      if (!acknowledged) onFailed?.call();
    });
  }

  /// Dublează POST /read, dar pe socket - expeditorul vede „Văzut" imediat.
  void markRead(String conversationId) {
    _socket?.emit('mark_read', conversationId);
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

  void onMessagesRead(void Function(String conversationId) handler) {
    _socket?.on('messages_read', (data) {
      final map = Map<String, dynamic>.from(data as Map);
      handler(map['conversationId'] as String);
    });
  }

  void offMessagesRead() => _socket?.off('messages_read');

  /// Prezența vine pe camera personală (`user:<id>`), nu pe cea a conversației -
  /// e utilă și în lista de conversații, nu doar în chatul deschis.
  void onUserPresence(
    void Function(String userId, bool isOnline, DateTime? lastSeenAt) handler,
  ) {
    _socket?.on('user_presence', (data) {
      final map = Map<String, dynamic>.from(data as Map);
      final lastSeen = map['lastSeenAt'] as String?;
      handler(
        map['userId'] as String,
        map['isOnline'] as bool? ?? false,
        lastSeen != null ? DateTime.parse(lastSeen) : null,
      );
    });
  }

  void offUserPresence() => _socket?.off('user_presence');

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
