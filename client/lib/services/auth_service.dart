import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:firebase_auth/firebase_auth.dart';
import 'push_notification_service.dart';

class AuthService {
  final FirebaseAuth _auth = FirebaseAuth.instance;

  User? get currentUser => _auth.currentUser;

  Stream<User?> get authStateChanges => _auth.authStateChanges();

  Future<User?> signInWithGoogle() async {
    final provider = GoogleAuthProvider();
    final credential = kIsWeb
        ? await _auth.signInWithPopup(provider)
        : await _auth.signInWithProvider(provider);
    await PushNotificationService().requestPermissionAndGetToken();
    return credential.user;
  }

  Future<void> signOut() => _auth.signOut();

  Future<String?> getIdToken() => _auth.currentUser?.getIdToken() ?? Future.value(null);
}