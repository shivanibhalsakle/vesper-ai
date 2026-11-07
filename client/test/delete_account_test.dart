import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:vesper/models/user_preferences.dart';
import 'package:vesper/models/user_profile.dart';
import 'package:vesper/screens/profile_screen.dart';
import 'package:vesper/services/api_client.dart';
import 'package:vesper/services/profile_photo_service.dart';

class _FakeApiClient extends ApiClient {
  Object? deleteError;
  int deletions = 0;

  @override
  Future<UserProfile?> fetchProfile() async => const UserProfile(displayName: 'Shivani');

  @override
  Future<UserPreferences?> fetchPreferences() async => null;

  @override
  Future<void> deleteAccount() async {
    deletions++;
    if (deleteError != null) throw deleteError!;
  }
}

class _FakePhotos implements ProfilePhotos {
  @override
  Future<Uint8List?> pick() async => null;

  @override
  Future<String> upload(Uint8List bytes) async => 'profiles/u1/1.jpg';

  @override
  Future<String?> urlFor(String path) async => null;

  @override
  Future<void> delete(String path) async {}
}

const _account = AccountInfo(email: 'shivani@example.com', displayName: 'Shivani B');

Future<void> _pump(WidgetTester tester, _FakeApiClient api, {Future<void> Function()? onSignOut}) async {
  tester.view.physicalSize = const Size(800, 4000);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(MaterialApp(
    home: ProfileScreen(
      account: _account,
      apiClient: api,
      photos: _FakePhotos(),
      onSignOut: onSignOut,
    ),
  ));
  await tester.pumpAndSettle();
}

Future<void> _tapDeleteAccount(WidgetTester tester) async {
  await tester.ensureVisible(find.text('Delete account'));
  await tester.tap(find.text('Delete account'));
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('the profile has a Delete account option', (tester) async {
    await _pump(tester, _FakeApiClient());

    expect(find.text('Delete account'), findsOneWidget);
    expect(find.text('Permanently remove your account and all your data'), findsOneWidget);
  });

  testWidgets('it asks before deleting, and keeping the account does nothing', (tester) async {
    final api = _FakeApiClient();
    var signedOut = false;
    await _pump(tester, api, onSignOut: () async => signedOut = true);

    await _tapDeleteAccount(tester);

    expect(find.text('Delete your account?'), findsOneWidget);
    expect(find.textContaining("can't be undone"), findsOneWidget);

    await tester.tap(find.text('Keep my account'));
    await tester.pumpAndSettle();

    expect(find.text('Delete your account?'), findsNothing);
    expect(api.deletions, 0);
    expect(signedOut, isFalse);
  });

  testWidgets('confirming deletes the account and then signs out', (tester) async {
    final api = _FakeApiClient();
    final order = <String>[];
    await _pump(tester, api, onSignOut: () async => order.add('signed out'));

    await _tapDeleteAccount(tester);
    await tester.tap(find.text('Delete everything'));
    // Not pumpAndSettle: the progress spinner keeps going until the sign-in
    // change replaces this screen (which the real app does by itself).
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    expect(api.deletions, 1);
    expect(order, ['signed out']);
    expect(find.byType(CircularProgressIndicator), findsOneWidget);
  });

  testWidgets('a failed deletion shows why and keeps the user signed in', (tester) async {
    final api = _FakeApiClient()..deleteError = ApiException('We could not finish. Try again.');
    var signedOut = false;
    await _pump(tester, api, onSignOut: () async => signedOut = true);

    await _tapDeleteAccount(tester);
    await tester.tap(find.text('Delete everything'));
    await tester.pumpAndSettle();

    expect(find.textContaining('We could not finish. Try again.'), findsOneWidget);
    expect(signedOut, isFalse);
    expect(find.text('Delete account'), findsOneWidget); // can try again
  });
}
