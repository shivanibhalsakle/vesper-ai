import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import '../models/feedback.dart';
import '../models/location_type.dart';
import '../models/preference_profile.dart';
import '../models/session_request.dart';
import '../services/api_client.dart';
import '../services/auth_service.dart';
import '../services/storage_service.dart';

class FeedbackScreen extends StatefulWidget {
  final String locationId;
  final String locationName;
  final LocationType locationType;
  final SunEvent event;
  final DateTime eventDate;
  final PreferenceProfile preferenceProfile;
  final ForecastSnapshot forecastSnapshot;
  final ApiClient? apiClient;
  final String? Function()? getUserId;
  final Future<String> Function(Uint8List bytes, String fileName)? uploadPhoto;

  const FeedbackScreen({
    super.key,
    required this.locationId,
    required this.locationName,
    required this.locationType,
    required this.event,
    required this.eventDate,
    required this.preferenceProfile,
    required this.forecastSnapshot,
    this.apiClient,
    this.getUserId,
    this.uploadPhoto,
  });

  @override
  State<FeedbackScreen> createState() => _FeedbackScreenState();
}

class _FeedbackScreenState extends State<FeedbackScreen> {
  late final ApiClient _apiClient = widget.apiClient ?? ApiClient();
  late final String? Function() _getUserId =
      widget.getUserId ?? (() => AuthService().currentUser?.uid);
  late final Future<String> Function(Uint8List bytes, String fileName) _uploadPhoto =
      widget.uploadPhoto ?? StorageService().uploadFeedbackPhoto;

  XFile? _photo;
  Uint8List? _photoBytes;
  bool _loading = false;

  Future<void> _pickPhoto() async {
    final picked = await ImagePicker().pickImage(source: ImageSource.gallery);
    if (picked == null) return;

    final bytes = await picked.readAsBytes();
    setState(() {
      _photo = picked;
      _photoBytes = bytes;
    });
  }

  Future<void> _submit() async {
    if (_photo == null || _photoBytes == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Add a photo before submitting.')),
      );
      return;
    }

    setState(() => _loading = true);
    try {
      final fileName = '${DateTime.now().millisecondsSinceEpoch}_${_photo!.name}';
      final photoStoragePath = await _uploadPhoto(_photoBytes!, fileName);

      final request = FeedbackRequest(
        locationId: widget.locationId,
        locationName: widget.locationName,
        locationType: widget.locationType,
        event: widget.event,
        eventDate: widget.eventDate,
        photoStoragePath: photoStoragePath,
        preferenceProfile: widget.preferenceProfile,
        forecastSnapshot: widget.forecastSnapshot,
        userId: _getUserId(),
      );

      await _apiClient.createFeedback(request);
      if (!mounted) return;
      Navigator.of(context).pop(true);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Could not submit feedback: $e')),
      );
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('How was ${widget.locationName}?')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Share a photo of what you actually saw — this helps improve '
              'future predictions for this spot.',
              style: Theme.of(context).textTheme.bodyMedium,
            ),
            const SizedBox(height: 16),
            GestureDetector(
              onTap: _pickPhoto,
              child: Container(
                width: double.infinity,
                height: 220,
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.surfaceContainerHighest,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: _photoBytes == null
                    ? Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            Icons.add_a_photo_outlined,
                            size: 48,
                            color: Theme.of(context).colorScheme.onSurfaceVariant,
                          ),
                          const SizedBox(height: 8),
                          const Text('Tap to add a photo'),
                        ],
                      )
                    : ClipRRect(
                        borderRadius: BorderRadius.circular(12),
                        child: Image.memory(_photoBytes!, fit: BoxFit.cover),
                      ),
              ),
            ),
            const SizedBox(height: 24),
            SizedBox(
              width: double.infinity,
              child: FilledButton(
                onPressed: _loading ? null : _submit,
                child: _loading
                    ? const SizedBox(
                        height: 20,
                        width: 20,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Text('Submit feedback'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
