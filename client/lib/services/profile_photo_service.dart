import 'dart:typed_data';

import 'package:image_picker/image_picker.dart';

import 'storage_service.dart';

/// Everything the profile screen needs to do with a photo: pick one from the
/// device, store it, find its URL, remove it. An interface so the screen can
/// be tested without a device, camera roll or Firebase.
abstract class ProfilePhotos {
  /// Lets the user choose an image; null if they back out.
  Future<Uint8List?> pick();

  /// Stores the image and returns its storage path.
  Future<String> upload(Uint8List bytes);

  /// A URL the app can display for a stored path, or null if it can't be had.
  Future<String?> urlFor(String path);

  Future<void> delete(String path);
}

class DeviceProfilePhotos implements ProfilePhotos {
  final StorageService _storage = StorageService();

  @override
  Future<Uint8List?> pick() async {
    // Profile pictures are shown small; downscaling at pick time keeps
    // uploads quick and storage/egress costs negligible.
    final picked = await ImagePicker().pickImage(
      source: ImageSource.gallery,
      maxWidth: 512,
      maxHeight: 512,
      imageQuality: 85,
    );
    return picked?.readAsBytes();
  }

  @override
  Future<String> upload(Uint8List bytes) => _storage.uploadProfilePhoto(bytes);

  @override
  Future<String?> urlFor(String path) async {
    try {
      return await _storage.downloadUrl(path);
    } catch (_) {
      return null;
    }
  }

  @override
  Future<void> delete(String path) => _storage.deletePath(path);
}
