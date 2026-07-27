// Hand-written from the Firebase Console's Web app config, following the
// same shape the FlutterFire CLI generates. Web-only for now — when Android
// is wired up later, this needs an Android FirebaseOptions block too (either
// added by hand or by running `flutterfire configure`).
import 'package:firebase_core/firebase_core.dart' show FirebaseOptions;
import 'package:flutter/foundation.dart' show kIsWeb;

class DefaultFirebaseOptions {
  static FirebaseOptions get currentPlatform {
    if (kIsWeb) {
      return web;
    }
    throw UnsupportedError(
      'DefaultFirebaseOptions have only been configured for web so far.',
    );
  }

  static const FirebaseOptions web = FirebaseOptions(
    apiKey: 'AIzaSyAVMxzD2fxQPX2DIaYQOdb1offXp0wxTEQ',
    authDomain: 'vesper-ai-37d6f.firebaseapp.com',
    projectId: 'vesper-ai-37d6f',
    storageBucket: 'vesper-ai-37d6f.firebasestorage.app',
    messagingSenderId: '862600156615',
    appId: '1:862600156615:web:9a657a00d2a80b6475b5e2',
  );
}