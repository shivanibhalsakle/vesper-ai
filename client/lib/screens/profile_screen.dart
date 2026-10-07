import 'dart:typed_data';

import 'package:flutter/material.dart';

import '../models/avatars.dart';
import '../models/user_profile.dart';
import '../services/api_client.dart';
import '../services/auth_service.dart';
import '../services/profile_photo_service.dart';
import '../widgets/profile_avatar.dart';
import '../widgets/star_rating.dart';
import 'settings_screen.dart';

// Same shape the backend accepts: digits with the usual separators.
final _phonePattern = RegExp(r'^\+?[0-9 ()\-]{7,20}$');

/// The user's profile. With [onboarding] set it is the first-run version:
/// just the essentials, and saving moves on via [onSaved].
class ProfileScreen extends StatefulWidget {
  final AccountInfo account;
  final bool onboarding;
  final VoidCallback? onSaved;
  final ApiClient? apiClient;
  final ProfilePhotos? photos;
  final Future<void> Function()? onSignOut;

  const ProfileScreen({
    super.key,
    this.account = const AccountInfo(),
    this.onboarding = false,
    this.onSaved,
    this.apiClient,
    this.photos,
    this.onSignOut,
  });

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  late final ApiClient _apiClient = widget.apiClient ?? ApiClient();
  late final ProfilePhotos _photos = widget.photos ?? DeviceProfilePhotos();

  final _nameController = TextEditingController();
  final _phoneController = TextEditingController();

  bool _loading = true;
  String? _loadError;
  bool _saving = false;
  String? _nameError;
  String? _phoneError;

  // The picture: a freshly picked photo (not uploaded yet), the saved photo,
  // or a built-in avatar. Choosing one clears the others.
  Uint8List? _newPhoto;
  String? _savedPhotoPath;
  // The photo stored on the server right now, so a replaced or removed one
  // can be deleted after the new profile is saved.
  String? _storedPhotoPath;
  String? _savedPhotoUrl;
  String? _avatarId;

  int _rating = 0;

  @override
  void initState() {
    super.initState();
    if (widget.onboarding) {
      _nameController.text = widget.account.displayName ?? '';
      _loading = false;
    } else {
      _load();
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _phoneController.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _loadError = null;
    });
    try {
      final profile = await _apiClient.fetchProfile();
      String? url;
      if (profile?.photoStoragePath != null) {
        url = await _photos.urlFor(profile!.photoStoragePath!);
      }
      if (!mounted) return;
      setState(() {
        _nameController.text = profile?.displayName ?? widget.account.displayName ?? '';
        _phoneController.text = profile?.phone ?? '';
        _savedPhotoPath = profile?.photoStoragePath;
        _storedPhotoPath = profile?.photoStoragePath;
        _savedPhotoUrl = url;
        _avatarId = profile?.avatarId;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _loadError = '$e');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  void _toast(String message) =>
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));

  ImageProvider? get _image {
    if (_newPhoto != null) return MemoryImage(_newPhoto!);
    if (_savedPhotoUrl != null) return NetworkImage(_savedPhotoUrl!);
    // Fall back to the Google picture only when the user hasn't chosen
    // anything of their own.
    if (_savedPhotoPath == null && _avatarId == null && widget.account.photoUrl != null) {
      return NetworkImage(widget.account.photoUrl!);
    }
    return null;
  }

  Future<void> _pickPhoto() async {
    Navigator.of(context).pop(); // close the picture sheet
    try {
      final bytes = await _photos.pick();
      if (bytes == null || !mounted) return;
      setState(() {
        _newPhoto = bytes;
        _savedPhotoPath = null;
        _savedPhotoUrl = null;
        _avatarId = null;
      });
    } catch (e) {
      if (!mounted) return;
      _toast('Could not open your photos: $e');
    }
  }

  void _chooseAvatar(String id) {
    Navigator.of(context).pop();
    setState(() {
      _avatarId = id;
      _newPhoto = null;
      _savedPhotoPath = null;
      _savedPhotoUrl = null;
    });
  }

  void _clearPicture() {
    Navigator.of(context).pop();
    setState(() {
      _avatarId = null;
      _newPhoto = null;
      _savedPhotoPath = null;
      _savedPhotoUrl = null;
    });
  }

  void _showPictureSheet() {
    showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      builder: (context) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              ListTile(
                leading: const Icon(Icons.photo_library_outlined),
                title: const Text('Upload a photo'),
                onTap: _pickPhoto,
              ),
              ListTile(
                leading: const Icon(Icons.hide_image_outlined),
                title: const Text('Remove picture'),
                onTap: _clearPicture,
              ),
              const Padding(
                padding: EdgeInsets.fromLTRB(16, 8, 16, 8),
                child: Text('Or choose an avatar'),
              ),
              Wrap(
                spacing: 12,
                runSpacing: 12,
                children: [
                  for (final id in kAvatars.keys)
                    InkWell(
                      key: Key('avatar-$id'),
                      customBorder: const CircleBorder(),
                      onTap: () => _chooseAvatar(id),
                      child: ProfileAvatar(radius: 26, avatarId: id),
                    ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  bool _validate() {
    final name = _nameController.text.trim();
    final phone = _phoneController.text.trim();
    setState(() {
      _nameError = name.isEmpty ? 'Please tell us what to call you.' : null;
      _phoneError = phone.isNotEmpty && !_phonePattern.hasMatch(phone)
          ? 'Enter a valid phone number, or leave it blank.'
          : null;
    });
    return _nameError == null && _phoneError == null;
  }

  Future<void> _save() async {
    if (!_validate()) return;
    setState(() => _saving = true);
    try {
      var photoPath = _savedPhotoPath;
      if (_newPhoto != null) {
        photoPath = await _photos.upload(_newPhoto!);
      }
      final phone = _phoneController.text.trim();
      final saved = await _apiClient.saveProfile(UserProfile(
        displayName: _nameController.text.trim(),
        phone: phone.isEmpty ? null : phone,
        photoStoragePath: photoPath,
        avatarId: photoPath == null ? _avatarId : null,
      ));
      // The old photo is only garbage once the new profile is saved; failing
      // to remove it is harmless.
      final stale = _storedPhotoPath;
      if (stale != null && stale != saved.photoStoragePath) {
        try {
          await _photos.delete(stale);
        } catch (_) {}
      }
      if (!mounted) return;
      setState(() {
        _newPhoto = null;
        _savedPhotoPath = saved.photoStoragePath;
        _storedPhotoPath = saved.photoStoragePath;
      });
      if (widget.onboarding) {
        widget.onSaved?.call();
      } else {
        _toast('Profile saved');
      }
    } catch (e) {
      if (!mounted) return;
      _toast('Could not save your profile: $e');
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _signOut() async {
    final navigator = Navigator.of(context);
    try {
      await (widget.onSignOut ?? AuthService().signOut)();
    } catch (e) {
      if (!mounted) return;
      _toast('Could not sign out: $e');
      return;
    }
    // The sign-in screen replaces the app's home; drop any screens above it.
    navigator.popUntil((route) => route.isFirst);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(widget.onboarding ? 'Welcome to Vesper' : 'Profile')),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _loadError != null
              ? Center(
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text('Could not load your profile: $_loadError',
                            textAlign: TextAlign.center),
                        const SizedBox(height: 12),
                        FilledButton(onPressed: _load, child: const Text('Retry')),
                      ],
                    ),
                  ),
                )
              : _form(context),
    );
  }

  Widget _form(BuildContext context) {
    final theme = Theme.of(context);
    final onboarding = widget.onboarding;

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        if (onboarding) ...[
          Text('Let\'s set up your profile', style: theme.textTheme.titleLarge),
          const SizedBox(height: 4),
          const Text('Just the basics - you can change any of this later.'),
          const SizedBox(height: 16),
        ],
        Center(
          child: Stack(
            children: [
              ProfileAvatar(
                radius: 48,
                image: _image,
                avatarId: _avatarId,
                name: _nameController.text,
              ),
              Positioned(
                right: 0,
                bottom: 0,
                child: IconButton.filled(
                  tooltip: 'Change picture',
                  iconSize: 18,
                  onPressed: _showPictureSheet,
                  icon: const Icon(Icons.edit),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 24),
        TextField(
          controller: _nameController,
          textCapitalization: TextCapitalization.words,
          onChanged: (_) => setState(() {}),
          decoration: InputDecoration(
            labelText: 'Name',
            border: const OutlineInputBorder(),
            errorText: _nameError,
          ),
        ),
        const SizedBox(height: 16),
        if (widget.account.email != null) ...[
          TextFormField(
            initialValue: widget.account.email,
            enabled: false,
            decoration: const InputDecoration(
              labelText: 'Email',
              border: OutlineInputBorder(),
              helperText: 'From your Google account',
            ),
          ),
          const SizedBox(height: 16),
        ],
        TextField(
          controller: _phoneController,
          keyboardType: TextInputType.phone,
          decoration: InputDecoration(
            labelText: 'Phone (optional)',
            border: const OutlineInputBorder(),
            errorText: _phoneError,
          ),
        ),
        const SizedBox(height: 24),
        FilledButton(
          onPressed: _saving ? null : _save,
          child: _saving
              ? const SizedBox(
                  height: 20,
                  width: 20,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : Text(onboarding ? 'Save and continue' : 'Save profile'),
        ),
        if (!onboarding) ...[
          const Divider(height: 40),
          ListTile(
            contentPadding: EdgeInsets.zero,
            leading: const Icon(Icons.tune),
            title: const Text('Manage preferences'),
            subtitle: const Text('Home spot, place types and sky taste'),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => Navigator.of(context).push(
              MaterialPageRoute(builder: (_) => SettingsScreen(apiClient: _apiClient)),
            ),
          ),
          const SizedBox(height: 8),
          Card(
            margin: EdgeInsets.zero,
            child: ListTile(
              leading: const Icon(Icons.workspace_premium_outlined),
              title: const Text('Billing'),
              subtitle: const Text(
                'Plan: Free. Paid plans with extra sky previews may come later - '
                'nothing is charged today.',
              ),
            ),
          ),
          const ListTile(
            contentPadding: EdgeInsets.zero,
            enabled: false,
            leading: Icon(Icons.photo_camera_outlined),
            title: Text('Share your sky photos'),
            subtitle: Text('Coming soon'),
          ),
          ListTile(
            contentPadding: EdgeInsets.zero,
            leading: const Icon(Icons.logout),
            title: const Text('Sign out'),
            onTap: _signOut,
          ),
          const Divider(height: 40),
          Center(
            child: Text('Enjoying Vesper?', style: theme.textTheme.titleMedium),
          ),
          StarRating(
            value: _rating,
            onChanged: (star) {
              setState(() => _rating = star);
              // Placeholder: once the app is on the Play Store this opens
              // the real in-app review.
              _toast('Thanks! Rating will connect to the Play Store at launch.');
            },
          ),
        ],
      ],
    );
  }
}
