import 'dart:io';

import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import '../network/api_client.dart';

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
  PushNotificationsService(this._apiClient);
  final ApiClient _apiClient;

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
    _ready = true;
  }

  Future<void> _initLocalNotifications() async {
    const androidInit = AndroidInitializationSettings('@mipmap/ic_launcher');
    await _localNotifications.initialize(
      settings: const InitializationSettings(android: androidInit),
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
    );
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
