import 'package:flutter/foundation.dart' show debugPrint, kIsWeb;
import 'package:firebase_auth/firebase_auth.dart';
import '../models/user_profile.dart';
import 'push_notification_service.dart';

class AuthService {
  final FirebaseAuth _auth = FirebaseAuth.instance;

  User? get currentUser => _auth.currentUser;

  static AccountInfo accountInfoFor(User? user) => AccountInfo(
        email: user?.email,
        displayName: user?.displayName,
        photoUrl: user?.photoURL,
      );

  Stream<User?> get authStateChanges => _auth.authStateChanges();

  Future<User?> signInWithGoogle() async {
    final provider = GoogleAuthProvider();
    final credential = kIsWeb
        ? await _auth.signInWithPopup(provider)
        : await _auth.signInWithProvider(provider);
    // Notification setup is a nice-to-have — a failure here must never make a
    // successful sign-in look like a failed one.
    try {
      await PushNotificationService().requestPermissionAndGetToken();
    } catch (e) {
      debugPrint('Push notification setup failed: $e');
    }
    return credential.user;
  }

  Future<void> signOut() => _auth.signOut();

  Future<String?> getIdToken() => _auth.currentUser?.getIdToken() ?? Future.value(null);
}