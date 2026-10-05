import 'dart:typed_data';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';

class StorageService {
  final FirebaseStorage _storage = FirebaseStorage.instance;

  Future<String> uploadFeedbackPhoto(Uint8List bytes, String fileName) async {
    final uid = FirebaseAuth.instance.currentUser!.uid;
    final ref = _storage.ref('feedback/$uid/$fileName');
    await ref.putData(bytes);
    return ref.fullPath;
  }

  /// Stores a profile picture under the user's own folder. Each upload gets
  /// a new name so a changed picture is never served from a stale cache.
  Future<String> uploadProfilePhoto(Uint8List bytes) async {
    final uid = FirebaseAuth.instance.currentUser!.uid;
    final ref = _storage.ref('profiles/$uid/${DateTime.now().millisecondsSinceEpoch}.jpg');
    await ref.putData(bytes, SettableMetadata(contentType: 'image/jpeg'));
    return ref.fullPath;
  }

  Future<String> downloadUrl(String path) => _storage.ref(path).getDownloadURL();

  Future<void> deletePath(String path) => _storage.ref(path).delete();
}
