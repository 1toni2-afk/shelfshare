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

  /// Cât așteptăm handshake-ul inițial de conectare (deschidere transport +
  /// autentificare) înainte să renunțăm. Suficient de generos cât să acopere
  /// câteva reîncercări automate socket.io (backoff intern), nu doar prima
  /// tentativă - vezi de ce mai jos, la `onConnectError`.
  static const _connectTimeout = Duration(seconds: 15);

  Future<io.Socket> _doConnect() async {
    final socket = io.io(
      '${ApiConfig.baseUrl}/chat',
      io.OptionBuilder()
          // Polling PRIMUL, websocket ca upgrade opțional - nu invers.
          // Cu websocket primul, engine.io deschide conexiunea pe websocket și,
          // dacă acel prim transport eșuează (exact ce face un proxy/tunel care
          // blochează upgrade-ul WS - inclusiv Cloudflare Tunnel), NU mai încearcă
          // polling (tryAllTransports e false implicit): socket-ul pur și simplu
          // nu se conectează, fără eroare vizibilă, iar tot ce depinde de el
          // (trimitere text, notificări live, actualizarea listei de conversații)
          // pică în tăcere, deși pozele - care merg pe HTTP - se trimit normal.
          // Local websocket merge, deci nu se vede; în producție, în spatele
          // tunelului, cade. Cu polling primul, handshake-ul se face pe HTTP
          // simplu (care sigur trece prin tunel) și abia apoi se face upgrade la
          // websocket dacă tunelul îl permite; dacă nu, rămâne pe polling și
          // totul funcționează oricum.
          .setTransports(['polling', 'websocket'])
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
    _socket = socket;
    // Un `io.Socket` nou-creat nu moștenește listener-ii 'notification' legați
    // pe cel vechi (abandonat) - relegăm imediat dacă exista deja un consumator
    // înregistrat, altfel notificările live rămân moarte pe acest socket până
    // la următorul apel `onNotification` (care poate să nu mai vină niciodată,
    // dacă toate provider-ele relevante s-au montat deja o singură dată).
    _bindNotificationForwarding();

    // `socket.connect()` întoarce imediat, indiferent dacă handshake-ul chiar
    // a reușit - fără să așteptăm evenimentul `connect`, un `sendMessage`
    // apelat imediat după `connect()` (ex. primul mesaj dintr-o sesiune nouă,
    // înainte ca `_init()` să fi apucat să stabilească efectiv conexiunea)
    // emitea pe un socket încă neconectat, care pierde evenimentul în tăcere.
    final completer = Completer<io.Socket>();
    // Așteptăm 'ready' (emis de server DUPĂ ce a terminat client.join() pe
    // camera user:<id>), nu simplul 'connect' al socket.io - 'connect' se
    // declanșează la finalul handshake-ului, înainte ca handler-ul async de
    // pe server să apuce să termine join()-ul. Dacă am rezolva conexiunea pe
    // 'connect', un event emis chiar în acea fereastră (ex. o notificare de
    // schimb primită imediat după login/reload) ar fi pierdut în tăcere de
    // RealtimeService, fiindcă socketul încă nu era în camera lui.
    void onReady(dynamic _) {
      if (!completer.isCompleted) completer.complete(socket);
    }

    // NU respingem completer-ul la primul `connect_error`: socket.io are
    // propria reîncercare automată cu backoff (2-3 tentative în intervalul de
    // mai jos sunt normale, mai ales pe primul handshake printr-un tunel).
    // Prima versiune a acestui fix trata orice eroare ca eșec definitiv -
    // exact ce cădea înainte fără eroare vizibilă acum cădea CU eroare
    // vizibilă, la prima reîncercare eșuată, chiar dacă a doua ar fi reușit.
    // Singura cale de eșec rămâne timeout-ul de mai jos, care lasă loc pentru
    // reîncercările interne să-și facă treaba.

    socket.on('ready', onReady);
    socket.connect();

    try {
      return await completer.future.timeout(_connectTimeout);
    } finally {
      // Fără argument de handler, la fel ca restul clasei (ex. `offNewMessage`)
      // - sigur aici, fiindcă doar `_doConnect` ascultă vreodată acest eveniment.
      socket.off('ready');
      _connecting = null;
    }
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
  ///
  /// Așteaptă mereu o conexiune activă înainte de emit - fără asta, primul
  /// mesaj dintr-o sesiune complet nouă (cache șters) putea nimeri exact în
  /// fereastra în care `connect()` din `_init()` încă nu terminase
  /// handshake-ul: socket-ul exista deja (non-null) dar nu era `connected`,
  /// `emitWithAck` pe el se pierdea în tăcere, iar userul trebuia să dea
  /// refresh la toată pagina (care repornea conexiunea de la zero, de data
  /// asta cu timp să se stabilească înainte de următoarea încercare).
  /// [onSent] primește mesajul salvat direct din ack-ul serverului, ca
  /// expeditorul să-l vadă imediat în listă fără să aștepte ecoul de pe
  /// camera conversației (`new_message`) - acel ecou poate întârzia sau, dacă
  /// join_conversation nu a apucat încă să se termine (rasă la deschiderea
  /// unui chat nou), să nu ajungă deloc la acest socket, lăsând mesajul
  /// „trimis" invizibil până la un refresh de pagină. `_handleNewMessage`
  /// deduplică după id, deci un ecou ulterior pentru același mesaj e ignorat.
  Future<void> sendMessage({
    required String conversationId,
    String? content,
    String? location,
    double? locationLat,
    double? locationLng,
    String? meetingAt,
    String? replyToId,
    void Function([String? reason])? onFailed,
    void Function(ChatMessage)? onSent,
  }) async {
    io.Socket socket;
    try {
      socket = await connect();
    } catch (_) {
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
          return;
        }
        try {
          onSent?.call(ChatMessage.fromJson(Map<String, dynamic>.from(data)));
        } catch (_) {
          // Ecoul de pe cameră tot poate aduce mesajul mai târziu; nu tratăm
          // ca eșec de trimitere doar fiindcă parsarea locală a picat.
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

  /// Accept/Respinge/Contra-ofertă schimbă statusul unei oferte deja postate
  /// în chat, fără mesaj nou - fără acest eveniment, celălalt participant
  /// vede cardul vechi (Pending, cu butoane) până reîncarcă manual conversația.
  void onPriceOfferUpdated(void Function(String priceOfferId, String status) handler) {
    _socket?.on('price_offer_updated', (data) {
      final map = Map<String, dynamic>.from(data as Map);
      handler(map['priceOfferId'] as String, map['status'] as String);
    });
  }

  void offPriceOfferUpdated() => _socket?.off('price_offer_updated');

  /// Analog cu onPriceOfferUpdated, pentru cereri de schimb carte-contra-carte.
  void onExchangeRequestUpdated(
    void Function(String exchangeRequestId, String status) handler,
  ) {
    _socket?.on('exchange_request_updated', (data) {
      final map = Map<String, dynamic>.from(data as Map);
      handler(map['exchangeRequestId'] as String, map['status'] as String);
    });
  }

  void offExchangeRequestUpdated() => _socket?.off('exchange_request_updated');

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

  /// Notificare din clopoțel (ofertă, schimb, follow etc.) creată în orice
  /// modul de backend și împinsă live pe camera personală `user:<id>`. Payload-ul
  /// e notificarea salvată; nu ne interesează conținutul aici - doar declanșăm
  /// un refetch al listei, ca badge-ul și lista să fie la zi fără refresh.
  ///
  /// Mai mulți consumatori (badge-ul de notificări ȘI ecranul "Schimburile
  /// mele") ascultă acest eveniment în paralel - `socket.off('notification')`
  /// fără argument de handler ar șterge TOȚI ascultătorii, nu doar pe al
  /// apelantului curent, deci ținem noi lista și facem un singur `on` real.
  final _notificationHandlers = <void Function()>{};
  // Socket-ul pe care sunt legați efectiv listener-ii 'notification'/
  // 'notification_read' - NU același lucru cu "am legat vreodată". `connect()`
  // creează un `io.Socket` NOU (`_doConnect`) de fiecare dată când reconectarea
  // automată a socket.io eșuează complet și cererea următoare (send/build)
  // găsește `_socket` neconectat. Cu un simplu flag "bound o dată", legătura
  // rămânea pe obiectul VECHI, abandonat - noul socket nu mai primea niciodată
  // 'notification', deci userul nu mai vedea live schimburi/oferte acceptate
  // de partener (bug: doar cel care apasă Accept vede rezultatul, fiindcă la
  // el se actualizează local starea, nu prin acest eveniment) până la un
  // restart complet al aplicației. Ținem referința socket-ului legat curent
  // și relegăm explicit dacă `_socket` s-a schimbat între timp.
  io.Socket? _notificationBoundSocket;

  void onNotification(void Function() handler) {
    _notificationHandlers.add(handler);
    _bindNotificationForwarding();
  }

  /// Leagă `forward` pe `_socket` curent dacă nu e deja legat pe EL (nu doar
  /// "legat vreodată") - apelată atât din `onNotification`, cât și din
  /// `_doConnect` de fiecare dată când se creează un socket nou.
  void _bindNotificationForwarding() {
    if (_notificationBoundSocket == _socket || _socket == null) return;
    _notificationBoundSocket = _socket;
    void forward(dynamic _) {
      for (final h in List.of(_notificationHandlers)) {
        h();
      }
    }

    _socket?.on('notification', forward);
    // O notificare din clopoțel poate fi rezolvată indirect (ex. deschiderea
    // conversației marchează ca citită notificarea „mesaj nou" aferentă) -
    // badge-ul are nevoie de același refetch și pentru acest caz.
    _socket?.on('notification_read', forward);
  }

  void offNotification(void Function() handler) {
    _notificationHandlers.remove(handler);
  }
}

final chatSocketServiceProvider = Provider<ChatSocketService>((ref) {
  return ChatSocketService(ref);
});
