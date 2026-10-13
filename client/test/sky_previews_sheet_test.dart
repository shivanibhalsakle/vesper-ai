import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:vesper/models/location_type.dart';
import 'package:vesper/models/saved_date.dart';
import 'package:vesper/models/session_request.dart';
import 'package:vesper/models/simulation.dart';
import 'package:vesper/models/user_preferences.dart';
import 'package:vesper/screens/saved_screen.dart';
import 'package:vesper/services/api_client.dart';
import 'package:vesper/theme/app_theme.dart';

// A 1x1 PNG, so Image.memory has something real to decode.
const _pixel =
    'data:image/png;base64,iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAADUlEQVR42mNkYPhfDwAChwGA60e6kgAAAABJRU5ErkJggg==';

SkyPreviewRecord _record(String id, String name, DateTime made) => SkyPreviewRecord(
      id: id,
      imageUrl: _pixel,
      locationName: name,
      locationType: LocationType.beach,
      event: SunEvent.sunset,
      prompt: 'p',
      disclaimer: 'An AI-generated illustration.',
      createdAt: made,
    );

class _FakeApi extends ApiClient {
  List<SkyPreviewRecord> previews;
  Object? previewsError;
  final List<String> deleted = [];
  int previewFetches = 0;

  _FakeApi(this.previews);

  @override
  Future<List<SavedDate>> fetchSavedDates() async => const [];

  @override
  Future<UserPreferences?> fetchPreferences() async => null;

  @override
  Future<List<SkyPreviewRecord>> fetchPreviews() async {
    previewFetches++;
    if (previewsError != null) throw previewsError!;
    return List.of(previews);
  }

  @override
  Future<void> deletePreview(String id) async {
    deleted.add(id);
  }
}

const _screen = Size(800, 2400);

Future<void> _pumpSaved(WidgetTester tester, _FakeApi api) async {
  tester.view.physicalSize = _screen;
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(MaterialApp(
    theme: buildAppTheme(),
    home: SavedScreen(apiClient: api, today: DateTime(2026, 10, 13)),
  ));
  await tester.pumpAndSettle();
}

Future<void> _openSheet(WidgetTester tester) async {
  await tester.tap(find.text('Sky previews'));
  await tester.pumpAndSettle();
}

void main() {
  final older = _record('a', 'Older spot', DateTime(2026, 10, 10, 18));
  final newer = _record('b', 'Newer spot', DateTime(2026, 10, 12, 18));

  testWidgets('the Saved page has a Sky previews tab; nothing loads until it is opened',
      (tester) async {
    final api = _FakeApi([older, newer]);
    await _pumpSaved(tester, api);

    expect(find.byKey(const Key('saved-view-tabs')), findsOneWidget);
    expect(api.previewFetches, 0);
    expect(find.byKey(const Key('sky-previews-sheet')), findsNothing);
  });

  testWidgets('opening it slides up a sheet covering three quarters of the page', (tester) async {
    await _pumpSaved(tester, _FakeApi([older, newer]));

    await _openSheet(tester);

    final sheet = find.byKey(const Key('sky-previews-sheet'));
    expect(sheet, findsOneWidget);
    expect(tester.getSize(sheet).height, closeTo(_screen.height * 0.75, 2));
  });

  testWidgets('shows the previews as a grid, newest first', (tester) async {
    await _pumpSaved(tester, _FakeApi([older, newer]));

    await _openSheet(tester);

    final newest = tester.getTopLeft(find.byKey(const Key('preview-tile-b')));
    final oldest = tester.getTopLeft(find.byKey(const Key('preview-tile-a')));
    expect(newest.dy, oldest.dy, reason: 'three to a row, so both are on the first row');
    expect(newest.dx, lessThan(oldest.dx));
  });

  testWidgets('dragging the sheet up makes it full height', (tester) async {
    await _pumpSaved(tester, _FakeApi([older, newer]));
    await _openSheet(tester);

    await tester.fling(find.byKey(const Key('sky-previews-back')), const Offset(0, -700), 1500);
    await tester.pumpAndSettle();

    expect(
      tester.getSize(find.byKey(const Key('sky-previews-sheet'))).height,
      closeTo(_screen.height, 2),
    );
  });

  testWidgets('the back arrow returns to the Saved page', (tester) async {
    await _pumpSaved(tester, _FakeApi([older]));
    await _openSheet(tester);

    await tester.tap(find.byKey(const Key('sky-previews-back')));
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('sky-previews-sheet')), findsNothing);
    expect(find.byKey(const Key('saved-view-tabs')), findsOneWidget);
  });

  testWidgets('the system back gesture closes it too', (tester) async {
    await _pumpSaved(tester, _FakeApi([older]));
    await _openSheet(tester);

    await tester.binding.handlePopRoute();
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('sky-previews-sheet')), findsNothing);
  });

  testWidgets('says so when there are no previews yet', (tester) async {
    await _pumpSaved(tester, _FakeApi(const []));

    await _openSheet(tester);

    expect(find.byKey(const Key('sky-previews-empty')), findsOneWidget);
  });

  testWidgets('a failure offers a retry', (tester) async {
    final api = _FakeApi([older])..previewsError = ApiException('Server unavailable.');
    await _pumpSaved(tester, api);
    await _openSheet(tester);

    expect(find.textContaining('Could not load your previews'), findsOneWidget);

    api.previewsError = null;
    await tester.tap(find.text('Retry'));
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('preview-tile-a')), findsOneWidget);
  });

  testWidgets('tapping a preview shows it large, and it can be deleted', (tester) async {
    final api = _FakeApi([older, newer]);
    await _pumpSaved(tester, api);
    await _openSheet(tester);

    await tester.tap(find.byKey(const Key('preview-tile-b')));
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('preview-detail-image')), findsOneWidget);
    expect(find.text('Newer spot'), findsOneWidget);
    expect(find.text('An AI-generated illustration.'), findsOneWidget);

    await tester.tap(find.byKey(const Key('delete-preview')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('confirm-delete-preview')));
    await tester.pumpAndSettle();

    expect(api.deleted, ['b']);
    expect(find.byKey(const Key('preview-tile-b')), findsNothing);
    expect(find.byKey(const Key('preview-tile-a')), findsOneWidget);
  });
}
