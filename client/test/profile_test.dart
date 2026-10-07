import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:vesper/models/user_preferences.dart';
import 'package:vesper/models/user_profile.dart';
import 'package:vesper/screens/onboarding_gate.dart';
import 'package:vesper/screens/profile_screen.dart';
import 'package:vesper/services/api_client.dart';
import 'package:vesper/services/profile_photo_service.dart';

class _FakeApiClient extends ApiClient {
  UserProfile? stored;
  Object? loadError;
  Object? saveError;
  final List<UserProfile> saved = [];
  int fetches = 0;

  _FakeApiClient({this.stored});

  @override
  Future<UserProfile?> fetchProfile() async {
    fetches++;
    if (loadError != null) throw loadError!;
    return stored;
  }

  @override
  Future<UserProfile> saveProfile(UserProfile profile) async {
    if (saveError != null) throw saveError!;
    saved.add(profile);
    stored = profile;
    return profile;
  }

  @override
  Future<UserPreferences?> fetchPreferences() async => null;
}

class _FakePhotos implements ProfilePhotos {
  Uint8List? picked;
  final List<String> uploaded = [];
  final List<String> deleted = [];
  bool failDelete = false;

  @override
  Future<Uint8List?> pick() async => picked;

  @override
  Future<String> upload(Uint8List bytes) async {
    final path = 'profiles/u1/${uploaded.length + 1}.jpg';
    uploaded.add(path);
    return path;
  }

  @override
  Future<String?> urlFor(String path) async => null; // no network in tests

  @override
  Future<void> delete(String path) async {
    if (failDelete) throw StateError('already gone');
    deleted.add(path);
  }
}

const _account = AccountInfo(email: 'shivani@example.com', displayName: 'Shivani B');

Future<void> _pump(WidgetTester tester, Widget home) async {
  tester.view.physicalSize = const Size(800, 4000);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(MaterialApp(home: home));
  await tester.pumpAndSettle();
}

Finder get _nameField => find.widgetWithText(TextField, 'Name');
Finder get _phoneField => find.widgetWithText(TextField, 'Phone (optional)');

// A valid 1x1 PNG, so MemoryImage can decode it if it is ever rendered.
final _png = Uint8List.fromList(const [
  0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A, 0x00, 0x00, 0x00, 0x0D, 0x49, 0x48, 0x44, 0x52,
  0x00, 0x00, 0x00, 0x01, 0x00, 0x00, 0x00, 0x01, 0x08, 0x06, 0x00, 0x00, 0x00, 0x1F, 0x15, 0xC4,
  0x89, 0x00, 0x00, 0x00, 0x0D, 0x49, 0x44, 0x41, 0x54, 0x78, 0x9C, 0x63, 0xF8, 0xFF, 0xFF, 0x3F,
  0x00, 0x05, 0xFE, 0x02, 0xFE, 0xA7, 0x35, 0x81, 0x84, 0x00, 0x00, 0x00, 0x00, 0x49, 0x45, 0x4E,
  0x44, 0xAE, 0x42, 0x60, 0x82,
]);

void main() {
  group('ProfileScreen', () {
    testWidgets('loads the saved profile and shows the account email', (tester) async {
      final api = _FakeApiClient(
        stored: const UserProfile(displayName: 'Shivani', phone: '+1 555 010 2030', avatarId: 'wilderness_wolf'),
      );
      await _pump(tester, ProfileScreen(account: _account, apiClient: api, photos: _FakePhotos()));

      expect(tester.widget<TextField>(_nameField).controller!.text, 'Shivani');
      expect(tester.widget<TextField>(_phoneField).controller!.text, '+1 555 010 2030');
      expect(find.text('shivani@example.com'), findsOneWidget);
    });

    testWidgets('has billing, preferences, rating and sign out sections', (tester) async {
      final api = _FakeApiClient(stored: const UserProfile(displayName: 'S'));
      await _pump(tester, ProfileScreen(account: _account, apiClient: api, photos: _FakePhotos()));

      expect(find.text('Manage preferences'), findsOneWidget);
      expect(find.text('Billing'), findsOneWidget);
      expect(find.textContaining('nothing is charged'), findsOneWidget);
      expect(find.text('Sign out'), findsOneWidget);
      expect(find.byKey(const Key('rate-5')), findsOneWidget);
    });

    testWidgets('rating stars fill up to the tapped one', (tester) async {
      final api = _FakeApiClient(stored: const UserProfile(displayName: 'S'));
      await _pump(tester, ProfileScreen(account: _account, apiClient: api, photos: _FakePhotos()));

      await tester.ensureVisible(find.byKey(const Key('rate-4')));
      await tester.tap(find.byKey(const Key('rate-4')));
      await tester.pump();

      expect(find.byIcon(Icons.star), findsNWidgets(4));
      expect(find.byIcon(Icons.star_border), findsNWidgets(1));
    });

    testWidgets('saving needs a name', (tester) async {
      final api = _FakeApiClient(stored: const UserProfile(displayName: 'S'));
      await _pump(tester, ProfileScreen(account: _account, apiClient: api, photos: _FakePhotos()));

      await tester.enterText(_nameField, '   ');
      await tester.tap(find.text('Save profile'));
      await tester.pump();

      expect(find.text('Please tell us what to call you.'), findsOneWidget);
      expect(api.saved, isEmpty);
    });

    testWidgets('rejects a junk phone number but accepts a blank one', (tester) async {
      final api = _FakeApiClient(stored: const UserProfile(displayName: 'S'));
      await _pump(tester, ProfileScreen(account: _account, apiClient: api, photos: _FakePhotos()));

      await tester.enterText(_phoneField, 'call me');
      await tester.tap(find.text('Save profile'));
      await tester.pump();
      expect(find.textContaining('valid phone number'), findsOneWidget);
      expect(api.saved, isEmpty);

      await tester.enterText(_phoneField, '');
      await tester.tap(find.text('Save profile'));
      await tester.pumpAndSettle();
      expect(api.saved.single.phone, isNull);
      expect(find.text('Profile saved'), findsOneWidget);
    });

    testWidgets('choosing an avatar saves it', (tester) async {
      final api = _FakeApiClient(stored: const UserProfile(displayName: 'S'));
      await _pump(tester, ProfileScreen(account: _account, apiClient: api, photos: _FakePhotos()));

      await tester.tap(find.byTooltip('Change picture'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Choose an avatar'));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('avatar-wilderness_wolf')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('confirm-avatar')));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Save profile'));
      await tester.pumpAndSettle();

      expect(api.saved.single.avatarId, 'wilderness_wolf');
      expect(api.saved.single.photoStoragePath, isNull);
    });

    testWidgets('a new photo is uploaded, saved, and replaces the old one', (tester) async {
      final api = _FakeApiClient(
        stored: const UserProfile(displayName: 'S', photoStoragePath: 'profiles/u1/old.jpg'),
      );
      final photos = _FakePhotos()..picked = _png;
      await _pump(tester, ProfileScreen(account: _account, apiClient: api, photos: photos));

      await tester.tap(find.byTooltip('Change picture'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Upload from device'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Save profile'));
      await tester.pumpAndSettle();

      expect(photos.uploaded, ['profiles/u1/1.jpg']);
      expect(api.saved.single.photoStoragePath, 'profiles/u1/1.jpg');
      expect(api.saved.single.avatarId, isNull);
      expect(photos.deleted, ['profiles/u1/old.jpg']);
    });

    testWidgets('failing to delete the old photo does not fail the save', (tester) async {
      final api = _FakeApiClient(
        stored: const UserProfile(displayName: 'S', photoStoragePath: 'profiles/u1/old.jpg'),
      );
      final photos = _FakePhotos()
        ..picked = _png
        ..failDelete = true;
      await _pump(tester, ProfileScreen(account: _account, apiClient: api, photos: photos));

      await tester.tap(find.byTooltip('Change picture'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Upload from device'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Save profile'));
      await tester.pumpAndSettle();

      expect(find.text('Profile saved'), findsOneWidget);
    });

    testWidgets('removing the picture deletes the stored photo', (tester) async {
      final api = _FakeApiClient(
        stored: const UserProfile(displayName: 'S', photoStoragePath: 'profiles/u1/old.jpg'),
      );
      final photos = _FakePhotos();
      await _pump(tester, ProfileScreen(account: _account, apiClient: api, photos: photos));

      await tester.tap(find.byTooltip('Change picture'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Remove picture'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Save profile'));
      await tester.pumpAndSettle();

      expect(api.saved.single.photoStoragePath, isNull);
      expect(photos.deleted, ['profiles/u1/old.jpg']);
    });

    testWidgets('a save failure is reported', (tester) async {
      final api = _FakeApiClient(stored: const UserProfile(displayName: 'S'))
        ..saveError = ApiException('Server said no.');
      await _pump(tester, ProfileScreen(account: _account, apiClient: api, photos: _FakePhotos()));

      await tester.tap(find.text('Save profile'));
      await tester.pumpAndSettle();

      expect(find.textContaining('Server said no.'), findsOneWidget);
    });

    testWidgets('sign out calls the handler', (tester) async {
      final api = _FakeApiClient(stored: const UserProfile(displayName: 'S'));
      var signedOut = false;
      await _pump(
        tester,
        ProfileScreen(
          account: _account,
          apiClient: api,
          photos: _FakePhotos(),
          onSignOut: () async => signedOut = true,
        ),
      );

      await tester.ensureVisible(find.text('Sign out'));
      await tester.tap(find.text('Sign out'));
      await tester.pumpAndSettle();

      expect(signedOut, isTrue);
    });

    testWidgets('a load failure offers a retry', (tester) async {
      final api = _FakeApiClient()..loadError = ApiException('boom');
      await _pump(tester, ProfileScreen(account: _account, apiClient: api, photos: _FakePhotos()));

      expect(find.textContaining('Could not load your profile'), findsOneWidget);

      api.loadError = null;
      await tester.tap(find.text('Retry'));
      await tester.pumpAndSettle();
      expect(find.text('Save profile'), findsOneWidget);
    });

    testWidgets('onboarding mode is the short version, prefilled from Google', (tester) async {
      final api = _FakeApiClient();
      var done = false;
      await _pump(
        tester,
        ProfileScreen(
          account: _account,
          onboarding: true,
          onSaved: () => done = true,
          apiClient: api,
          photos: _FakePhotos(),
        ),
      );

      expect(find.text('Welcome to Vesper'), findsOneWidget);
      expect(tester.widget<TextField>(_nameField).controller!.text, 'Shivani B');
      expect(find.text('Billing'), findsNothing);
      expect(find.text('Sign out'), findsNothing);
      expect(api.fetches, 0); // nothing to load on first run

      await tester.tap(find.text('Save and continue'));
      await tester.pumpAndSettle();

      expect(api.saved.single.displayName, 'Shivani B');
      expect(done, isTrue);
    });
  });

  group('OnboardingGate', () {
    testWidgets('a user with a profile goes straight home', (tester) async {
      final api = _FakeApiClient(stored: const UserProfile(displayName: 'S'));
      await _pump(tester, OnboardingGate(account: _account, apiClient: api, photos: _FakePhotos()));

      expect(find.text('What would you like to do?'), findsOneWidget);
    });

    testWidgets('a new user does profile, then the preferences offer, then home (skipped)',
        (tester) async {
      final api = _FakeApiClient();
      await _pump(tester, OnboardingGate(account: _account, apiClient: api, photos: _FakePhotos()));

      expect(find.text('Welcome to Vesper'), findsOneWidget);
      await tester.tap(find.text('Save and continue'));
      await tester.pumpAndSettle();

      expect(find.text('What kind of sky do you love?'), findsOneWidget);
      await tester.tap(find.text('Skip for now'));
      await tester.pumpAndSettle();

      expect(find.text('What would you like to do?'), findsOneWidget);
    });

    testWidgets('choosing to set preferences opens Settings, then home after saving',
        (tester) async {
      final api = _FakeApiClient();
      await _pump(tester, OnboardingGate(account: _account, apiClient: api, photos: _FakePhotos()));

      await tester.tap(find.text('Save and continue'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Set my preferences'));
      await tester.pumpAndSettle();

      expect(find.text('Settings'), findsOneWidget);
      expect(find.text('Skip'), findsOneWidget);
    });

    testWidgets('skipping from Settings goes home', (tester) async {
      final api = _FakeApiClient();
      await _pump(tester, OnboardingGate(account: _account, apiClient: api, photos: _FakePhotos()));

      await tester.tap(find.text('Save and continue'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Set my preferences'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Skip'));
      await tester.pumpAndSettle();

      expect(find.text('What would you like to do?'), findsOneWidget);
    });

    testWidgets('a backend failure shows a retry instead of onboarding', (tester) async {
      final api = _FakeApiClient()..loadError = ApiException('down');
      await _pump(tester, OnboardingGate(account: _account, apiClient: api, photos: _FakePhotos()));

      expect(find.textContaining('Could not reach Vesper'), findsOneWidget);
      expect(find.text('Welcome to Vesper'), findsNothing);

      api.loadError = null;
      api.stored = const UserProfile(displayName: 'S');
      await tester.tap(find.text('Retry'));
      await tester.pumpAndSettle();
      expect(find.text('What would you like to do?'), findsOneWidget);
    });
  });

  test('UserProfile survives a JSON round trip', () {
    const original = UserProfile(
      displayName: 'Shivani',
      phone: '+1 555 010 2030',
      photoStoragePath: 'profiles/u1/1.jpg',
    );

    final restored = UserProfile.fromJson(original.toJson());

    expect(restored.displayName, 'Shivani');
    expect(restored.phone, '+1 555 010 2030');
    expect(restored.photoStoragePath, 'profiles/u1/1.jpg');
    expect(restored.avatarId, isNull);
  });
}
