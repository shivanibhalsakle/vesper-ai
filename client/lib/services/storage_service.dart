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
}