import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';

class PushNotificationService {
  static const _vapidKey =
      'BOCHN-tiwZDqT-kWQ_DrLzIoVN8LFv8jaflGHIMxMtaWNMrkKozRWwwGS76sOW24EQXHT_w-__Pq0gLfSb-mndw';

  final FirebaseMessaging _messaging = FirebaseMessaging.instance;

  // The VAPID key only exists for web push; native Android/iOS identify the
  // app through google-services.json instead.
  String? get _webVapidKey => kIsWeb ? _vapidKey : null;

  Future<String?> requestPermissionAndGetToken() async {
    final settings = await _messaging.requestPermission();
    if (settings.authorizationStatus == AuthorizationStatus.denied) {
      debugPrint('Push notifications: permission denied.');
      return null;
    }

    final token = await _messaging.getToken(vapidKey: _webVapidKey);
    debugPrint('FCM token: $token');
    return token;
  }

  Future<String?> getToken() => _messaging.getToken(vapidKey: _webVapidKey);
}