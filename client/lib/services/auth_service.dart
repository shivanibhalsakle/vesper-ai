import 'package:firebase_auth/firebase_auth.dart';
import 'push_notification_service.dart';

class AuthService {
  final FirebaseAuth _auth = FirebaseAuth.instance;

  User? get currentUser => _auth.currentUser;

  Stream<User?> get authStateChanges => _auth.authStateChanges();

  Future<User?> signInWithGoogle() async {
    final credential = await _auth.signInWithPopup(GoogleAuthProvider());
    await PushNotificationService().requestPermissionAndGetToken();
    return credential.user;
  }

  Future<void> signOut() => _auth.signOut();
}