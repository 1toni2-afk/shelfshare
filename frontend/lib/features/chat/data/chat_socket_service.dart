import 'dart:async';

import 'package:flutter/foundation.dart';
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

  /// Pornește conexiunea fără ca apelantul să aștepte handshake-ul și fără ca
  /// un eșec să se propage mai departe.
  ///
  /// Controller-ele de listă (conversații, notificări, schimburi, oferte)
  /// făceau `await connect()` ÎNAINTE de fetch-ul HTTP. Socketul e însă doar
  /// pentru actualizări live - datele vin pe HTTP, care merge independent de
  /// el. Cu await, un handshake care nu se stabilea ținea lista în „se
  /// încarcă" cele 15 secunde de `_connectTimeout` și apoi o arunca în eroare,
  /// deși API-ul răspundea perfect. Și fiindcă toate patru așteaptă ACELAȘI
  /// `_connecting`, un singur handshake căzut le strica pe toate deodată:
  /// clopoțelul rămânea fără buletă și lista de conversații se învârtea la
  /// nesfârșit. Pe web socketul se stabilește practic mereu, de aceea se
  /// vedea doar pe telefon (rețea mobilă, tunel, app trecut prin background).
  ///
  /// Apelanții pot lega listener-ii imediat după acest apel: `_doConnect`
  /// atribuie `_socket` sincron, înainte de primul `await`, deci `_socket?.on`
  /// de pe linia următoare prinde socketul nou, nu un null.
  void connectInBackground() {
    connect().then(
      (_) {},
      onError: (Object error) {
        // Nimic de făcut aici: socket.io reîncearcă singur, iar lista s-a
        // încărcat deja pe HTTP. Doar notăm, ca să nu ajungă eroare neprinsă.
        debugPrint('[socket] conectare eșuată (actualizările live sunt oprite): $error');
      },
    );
  }

  /// Cât așteptăm handshake-ul inițial de conectare (deschidere transport +
  /// autentificare) înainte să renunțăm. Suficient de generos cât să acopere
  /// câteva reîncercări automate socket.io (backoff intern), nu doar prima
  /// tentativă - vezi de ce mai jos, la `onConnectError`.
  static const _connectTimeout = Duration(seconds: 15);

  Future<io.Socket> _doConnect() async {
    // Fără token, gateway-ul respinge conexiunea și nu emite niciodată
    // 'ready' (vezi handleConnection din chat.gateway.ts), deci am aștepta
    // degeaba cele 15 secunde de timeout. Se întâmpla la fiecare pornire, cât
    // timp userul era pe ecranul de login.
    final token = await _ref.read(tokenStorageProvider).getAccessToken();
    if (token == null) {
      throw StateError('Socket fără sesiune: nu există access token.');
    }

    // Socketul anterior trebuie desființat EXPLICIT, nu doar abandonat.
    // `io.Socket` are reconectare automată proprie: un socket respins înainte
    // de login continua să reîncerce în fundal și, fiindcă `setAuthFn` cere
    // token proaspăt la fiecare tentativă, ajungea să se conecteze cu succes
    // DUPĂ login - server-side apărea „Client conectat", dar ascultătorul de
    // 'ready' îi fusese deja scos (vezi `finally` de mai jos), deci aplicația
    // nu afla niciodată. Între timp se crea un al doilea socket, care aștepta
    // un 'ready' pe care serverul îl trimisese pe primul. Rezultat: bulina și
    // actualizările live rămâneau moarte, deși conexiunea exista.
    _socket?.dispose();
    _notificationBoundSocket = null;

    final socket = io.io(
      '${ApiConfig.baseUrl}/chat',
      io.OptionBuilder()
          // Transportul diferă pe web față de mobil, și NU e o preferință -
          // e o constrângere a bibliotecii.
          //
          // Pe web, engine.io chiar suportă ambele transporturi, iar polling
          // trebuie să fie PRIMUL: cu websocket primul, dacă acel transport
          // eșuează (exact ce face un proxy/tunel care blochează upgrade-ul
          // WS), engine.io NU mai încearcă polling (`tryAllTransports` e false
          // implicit) și socketul rămâne mort, fără eroare vizibilă.
          //
          // Pe mobil/desktop însă, `Transports.newInstance` din
          // socket_io_client întoarce MEREU un WebSocketTransport, indiferent
          // ce nume i se cere („Native only supports websocket"). Cu 'polling'
          // pe prima poziție, motorul cerea polling, primea un socket
          // WebSocket, iar cererea pleca cu `?transport=polling` - serverul o
          // închidea imediat („transport close"). Nu se emitea nici măcar
          // `connect_error`: aplicația aștepta mut până la timeout, iar
          // backendul nu logea absolut nimic, fiindcă pachetul CONNECT nu
          // ajungea niciodată la namespace. De aici veneau bulina care nu se
          // aprindea și mesajele care nu soseau live - doar pe telefon.
          .setTransports(kIsWeb ? ['polling', 'websocket'] : ['websocket'])
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

    // Diagnostic: fără el, un handshake eșuat arată identic indiferent de
    // cauză - același TimeoutException de 15s, fie că transportul n-a pornit,
    // fie că serverul a respins namespace-ul, fie că 'ready' s-a pierdut.
    // Cele patru linii de mai jos separă cazurile în logurile de pe telefon.
    socket.onConnect((_) => debugPrint('[socket] transport deschis, aștept ready de la server'));
    socket.onConnectError((data) => debugPrint('[socket] connect_error: $data'));
    socket.onError((data) => debugPrint('[socket] error: $data'));
    socket.onDisconnect((reason) => debugPrint('[socket] deconectat: $reason'));

    socket.on('ready', onReady);
    socket.connect();

    try {
      return await completer.future.timeout(_connectTimeout);
    } catch (_) {
      // Altfel socketul ratat rămâne în fundal reîncercând la nesfârșit - exact
      // zombie-ul descris mai sus. `dispose` oprește și reconectarea automată.
      socket.dispose();
      if (identical(_socket, socket)) {
        _socket = null;
        _notificationBoundSocket = null;
      }
      rethrow;
    } finally {
      // Fără argument de handler, la fel ca restul clasei (ex. `offNewMessage`)
      // - sigur aici, fiindcă doar `_doConnect` ascultă vreodată acest eveniment.
      socket.off('ready');
      _connecting = null;
    }
  }

  Future<void> _provideFreshAuth(void Function(Map<String, dynamic>) callback) async {
    // Reîmprospătează token-ul doar dacă chiar a expirat - vezi
    // `ApiClient.ensureFreshToken`. Înainte se cerea `/profile/me` la fiecare
    // (re)conectare a socket-ului, doar ca efect secundar, ceea ce însemna
    // profilul complet descărcat de mai multe ori la pornirea aplicației.
    //
    // `callback` TREBUIE apelat, orice s-ar întâmpla mai sus. socket.io trimite
    // pachetul CONNECT către namespace doar din interiorul lui (vezi
    // Socket.onopen din socket_io_client): dacă nu-l apelăm, transportul se
    // deschide dar namespace-ul `/chat` nu e contactat niciodată. Serverul nu
    // logează nimic - nici conectare, nici respingere - iar clientul așteaptă
    // `ready` până la timeout. Exact așa arăta bug-ul: „conexiune eșuată" pe
    // telefon, tăcere totală în logurile backendului.
    String? token;
    try {
      await _ref
          .read(apiClientProvider)
          .ensureFreshToken()
          .timeout(const Duration(seconds: 8));
    } catch (error) {
      debugPrint('[socket] token neîmprospătat, încerc cu cel existent: $error');
    }
    try {
      token = await _ref
          .read(tokenStorageProvider)
          .getAccessToken()
          .timeout(const Duration(seconds: 5));
    } catch (error) {
      debugPrint('[socket] nu am putut citi tokenul: $error');
    }
    // Chiar și cu token null: serverul respinge explicit și logează motivul,
    // ceea ce e mult mai ușor de diagnosticat decât o așteptare mută.
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
