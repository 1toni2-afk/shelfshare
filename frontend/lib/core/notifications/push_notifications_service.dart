import 'dart:convert';
import 'dart:io';

import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import '../../data/models/app_notification.dart';
import '../network/api_client.dart';
import 'notification_route.dart';

/// ID-ul canalului Android pentru notificările primite cât timp aplicația e
/// deschisă (foreground) - FCM nu le arată automat pe bara de notificări în
/// acest caz, spre deosebire de background/terminated, unde sistemul o face
/// singur din payload-ul `notification`. Trebuie să coincidă cu valoarea din
/// AndroidManifest.xml (`default_notification_channel_id`).
const _androidChannelId = 'shelfshare_default';

/// Handler pentru mesaje primite cât timp aplicația e complet închisă sau în
/// background. Trebuie să fie o funcție top-level (nu o metodă de instanță) -
/// Flutter o rulează într-un isolate separat, fără acces la starea din restul
/// aplicației. Payload-ul `notification` e deja afișat de sistem în acest caz
/// - nu mai trebuie randat manual aici, doar procesat dacă are nevoie de o
/// acțiune în fundal (nu e cazul acum).
@pragma('vm:entry-point')
Future<void> firebaseMessagingBackgroundHandler(RemoteMessage message) async {}

/// Inițializează Firebase + FCM și înregistrează tokenul dispozitivului la
/// backend, ca userul să primească push notifications (mesaje noi, cereri de
/// schimb). Degradează silențios dacă Firebase nu e configurat (fără
/// google-services.json, vezi android/app/build.gradle.kts) - restul
/// aplicației funcționează normal, doar fără push.
class PushNotificationsService {
  PushNotificationsService(this._apiClient, this._onRoute);
  final ApiClient _apiClient;

  /// Unde trimitem userul când apasă pe o notificare de sistem. Un callback,
  /// nu o navigare directă: serviciul ăsta poate rula înainte ca aplicația să
  /// aibă router (tap pe notificare cu aplicația închisă), deci decizia de
  /// „acum sau după ce se restaurează sesiunea" nu e a lui. Vezi
  /// `pendingNotificationRouteProvider`.
  final void Function(String route) _onRoute;

  final _localNotifications = FlutterLocalNotificationsPlugin();
  bool _ready = false;
  String? _registeredToken;

  /// Apelat o singură dată, la pornirea aplicației, înainte de runApp().
  Future<void> initialize() async {
    if (kIsWeb) return; // FCM pe web are un flux separat (service worker) - nu-l acoperim acum.

    try {
      await Firebase.initializeApp();
    } catch (error) {
      // Cel mai probabil: google-services.json lipsește. Nu blocăm restul
      // aplicației pentru o funcționalitate opțională.
      debugPrint('[push] Firebase.initializeApp a eșuat (probabil neconfigurat): $error');
      return;
    }

    FirebaseMessaging.onBackgroundMessage(firebaseMessagingBackgroundHandler);
    await _initLocalNotifications();
    FirebaseMessaging.onMessage.listen(_showForegroundNotification);

    // Tap pe o notificare de sistem cât timp aplicația era doar în background:
    // procesul trăiește, deci evenimentul ajunge pe stream.
    FirebaseMessaging.onMessageOpenedApp.listen(_openFromData);

    // Tap pe o notificare care a pornit aplicația din starea complet închisă:
    // nu există stream, mesajul se citește o singură dată, la pornire. Fără
    // asta, un tap pe „ai primit un mesaj" deschidea pur și simplu aplicația
    // pe ecranul de start.
    final initial = await FirebaseMessaging.instance.getInitialMessage();
    if (initial != null) _openFromData(initial);

    _ready = true;
  }

  Future<void> _initLocalNotifications() async {
    const androidInit = AndroidInitializationSettings('@mipmap/ic_launcher');
    await _localNotifications.initialize(
      settings: const InitializationSettings(android: androidInit),
      // Notificările afișate cât timp aplicația e în foreground sunt randate
      // de flutter_local_notifications, nu de FCM - deci tap-ul pe ele nu
      // trece prin `onMessageOpenedApp`, are nevoie de propriul callback.
      onDidReceiveNotificationResponse: (response) {
        final payload = response.payload;
        if (payload == null || payload.isEmpty) return;
        try {
          final decoded = jsonDecode(payload) as Map<String, dynamic>;
          _openFromData(null, decoded);
        } catch (error) {
          debugPrint('[push] Payload invalid la tap: $error');
        }
      },
    );
    await _localNotifications
        .resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>()
        ?.createNotificationChannel(
          const AndroidNotificationChannel(
            _androidChannelId,
            'ShelfShare',
            description: 'Mesaje și cereri de schimb noi',
            importance: Importance.high,
          ),
        );
  }

  void _showForegroundNotification(RemoteMessage message) {
    final notification = message.notification;
    if (notification == null) return;
    _localNotifications.show(
      id: notification.hashCode,
      title: notification.title,
      body: notification.body,
      notificationDetails: const NotificationDetails(
        android: AndroidNotificationDetails(
          _androidChannelId,
          'ShelfShare',
          importance: Importance.high,
          priority: Priority.high,
        ),
      ),
      // Fără payload, callback-ul de tap de mai sus n-ar avea din ce calcula
      // destinația - `message.data` e singurul loc unde vine tipul notificării
      // și id-ul conversației/schimbului.
      payload: jsonEncode(message.data),
    );
  }

  /// Traduce payload-ul unei notificări în rută și o predă mai departe.
  ///
  /// `data` din FCM e mereu `Map<String, String>` - backend-ul serializează
  /// acolo tipul notificării (`type`, în forma din API: `NEW_MESSAGE` etc.) și
  /// cheile de care depinde destinația (`conversationId`, `offerId`, ...).
  /// Vezi backend/src/notifications/notifications.service.ts.
  void _openFromData(RemoteMessage? message, [Map<String, dynamic>? raw]) {
    final data = raw ?? message?.data;
    final rawType = data?['type'];
    if (rawType == null) return;
    final route = routeForNotification(
      NotificationTypeX.fromJson(rawType.toString()),
      data,
    );
    // Un tip pe care clientul ăsta nu-l cunoaște, sau date insuficiente:
    // deschidem aplicația fără să sărim undeva la întâmplare.
    if (route != null) _onRoute(route);
  }

  /// Apelat după login/restaurare sesiune: cere permisiunea de notificări (pe
  /// Android 13+ e obligatorie explicit) și trimite tokenul curent la backend.
  /// Se re-abonează și la reînnoirea tokenului (FCM le rotește periodic).
  Future<void> registerForCurrentUser() async {
    if (!_ready) return;

    final settings = await FirebaseMessaging.instance.requestPermission();
    if (settings.authorizationStatus == AuthorizationStatus.denied) return;

    final token = await FirebaseMessaging.instance.getToken();
    if (token != null) await _sendTokenToBackend(token);

    FirebaseMessaging.instance.onTokenRefresh.listen(_sendTokenToBackend);
  }

  Future<void> _sendTokenToBackend(String token) async {
    if (token == _registeredToken) return;
    try {
      await _apiClient.dio.post(
        '/notifications/device-token',
        data: {
          'token': token,
          'platform': Platform.isIOS ? 'ios' : 'android',
        },
      );
      _registeredToken = token;
    } catch (error) {
      debugPrint('[push] Nu am putut înregistra tokenul la backend: $error');
    }
  }

  /// Apelat la logout: nu are sens ca dispozitivul să mai primească push-uri
  /// pentru contul de dinainte după ce userul s-a delogat.
  Future<void> unregisterCurrentDevice() async {
    if (!_ready || _registeredToken == null) return;
    try {
      await _apiClient.dio.delete('/notifications/device-token/$_registeredToken');
    } catch (_) {
      // Nesemnificativ - tokenul mort va fi curățat oricum la următorul push eșuat.
    }
    _registeredToken = null;
  }
}
