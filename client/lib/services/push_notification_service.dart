import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';

class PushNotificationService {
  static const _vapidKey =
      'BOCHN-tiwZDqT-kWQ_DrLzIoVN8LFv8jaflGHIMxMtaWNMrkKozRWwwGS76sOW24EQXHT_w-__Pq0gLfSb-mndw';

  final FirebaseMessaging _messaging = FirebaseMessaging.instance;

  Future<String?> requestPermissionAndGetToken() async {
    final settings = await _messaging.requestPermission();
    if (settings.authorizationStatus == AuthorizationStatus.denied) {
      debugPrint('Push notifications: permission denied.');
      return null;
    }

    final token = await _messaging.getToken(vapidKey: _vapidKey);
    debugPrint('FCM token: $token');
    return token;
  }

  Future<String?> getToken() => _messaging.getToken(vapidKey: _vapidKey);
}