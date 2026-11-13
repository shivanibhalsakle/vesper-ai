import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:vesper/models/session_request.dart';
import 'package:vesper/models/shared_preview.dart';
import 'package:vesper/services/api_client.dart';
import 'package:vesper/widgets/shared_previews_link.dart';

// A 1x1 PNG, so Image.memory has something real to decode.
const _pixel =
    'data:image/png;base64,iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAADUlEQVR42mNkYPhfDwAChwGA60e6kgAAAABJRU5ErkJggg==';

SharedPreview _preview(String id, {DateTime? eventDate, SunEvent event = SunEvent.sunset}) =>
    SharedPreview(
      id: id,
      imageUrl: _pixel,
      thumbUrl: _pixel,
      placeName: 'Test Park',
      event: event,
      eventDate: eventDate,
      disclaimer: 'An AI-generated illustration.',
      createdAt: DateTime(2026, 11, 20),
    );

class _Api extends ApiClient {
  Map<String, PlacePreviewCount> counts = {};
  List<SharedPreview> previews = [];
  Object? previewsError;
  final List<List<String>> countRequests = [];
  final List<String> previewRequests = [];

  @override
  Future<Map<String, PlacePreviewCount>> fetchSharedPreviewCounts(List<String> placeIds) async {
    countRequests.add(placeIds);
    return counts;
  }

  @override
  Future<List<SharedPreview>> fetchSharedPreviews(String placeId) async {
    previewRequests.add(placeId);
    if (previewsError != null) throw previewsError!;
    return previews;
  }
}

Future<void> _pump(WidgetTester tester, Widget child) async {
  tester.view.physicalSize = const Size(800, 1600);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(MaterialApp(home: Scaffold(body: Center(child: child))));
  await tester.pumpAndSettle();
}

Widget _link(PlacePreviewCount? info, {_Api? api}) => SharedPreviewsLink(
      placeId: 'osm:way/1',
      placeName: 'Test Park',
      info: info,
      apiClient: api ?? _Api(),
    );

const _linkText = 'See previews for this location from other users';

void main() {
  group('SharedPreviewsLink', () {
    testWidgets('shows nothing for a place nobody has previewed', (tester) async {
      await _pump(tester, _link(null));
      expect(find.textContaining(_linkText), findsNothing);
      expect(find.byKey(const Key('popular-place')), findsNothing);

      await _pump(
        tester,
        _link(const PlacePreviewCount(placeId: 'osm:way/1', count: 0, popular: false)),
      );
      expect(find.textContaining(_linkText), findsNothing);
    });

    testWidgets('offers the previews from other users, with how many', (tester) async {
      await _pump(
        tester,
        _link(const PlacePreviewCount(placeId: 'osm:way/1', count: 3, popular: false)),
      );

      expect(find.text('$_linkText (3)'), findsOneWidget);
      expect(find.byKey(const Key('popular-place')), findsNothing);
    });

    testWidgets('labels a popular place', (tester) async {
      await _pump(
        tester,
        _link(const PlacePreviewCount(placeId: 'osm:way/1', count: 9, popular: true)),
      );

      expect(find.text('Popular place'), findsOneWidget);
      expect(find.text('$_linkText (9)'), findsOneWidget);
    });

    testWidgets('a popular place with only your own previews shows the label alone', (tester) async {
      await _pump(
        tester,
        _link(const PlacePreviewCount(placeId: 'osm:way/1', count: 0, popular: true)),
      );

      expect(find.text('Popular place'), findsOneWidget);
      expect(find.textContaining(_linkText), findsNothing);
    });

    testWidgets('tapping the link opens the previews sheet for that place', (tester) async {
      final api = _Api()..previews = [_preview('a', eventDate: DateTime(2026, 12, 2))];
      await _pump(
        tester,
        _link(const PlacePreviewCount(placeId: 'osm:way/1', count: 1, popular: false), api: api),
      );

      await tester.tap(find.byKey(const Key('shared-previews-link-osm:way/1')));
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('shared-previews-sheet')), findsOneWidget);
      expect(api.previewRequests, ['osm:way/1']);
      expect(find.text('Previews of Test Park'), findsOneWidget);
      expect(find.byKey(const Key('shared-preview-a')), findsOneWidget);
      expect(find.text('Sunset · Wednesday, December 2'), findsOneWidget);
    });
  });

  group('the previews sheet', () {
    Future<void> openSheet(WidgetTester tester, _Api api) async {
      await _pump(
        tester,
        _link(const PlacePreviewCount(placeId: 'osm:way/1', count: 1, popular: false), api: api),
      );
      await tester.tap(find.byKey(const Key('shared-previews-link-osm:way/1')));
      await tester.pumpAndSettle();
    }

    testWidgets('covers three quarters of the page', (tester) async {
      await openSheet(tester, _Api()..previews = [_preview('a')]);

      final sheet = tester.getRect(find.byKey(const Key('shared-previews-sheet')));
      final page = tester.view.physicalSize / tester.view.devicePixelRatio;
      expect(sheet.height / page.height, closeTo(0.75, 0.02));
    });

    testWidgets('can be dragged up to fill the page', (tester) async {
      await openSheet(tester, _Api()..previews = [_preview('a')]);

      await tester.drag(find.byKey(const Key('shared-previews-sheet')), const Offset(0, -600));
      await tester.pumpAndSettle();

      final sheet = tester.getRect(find.byKey(const Key('shared-previews-sheet')));
      final page = tester.view.physicalSize / tester.view.devicePixelRatio;
      expect(sheet.height / page.height, closeTo(1.0, 0.02));
    });

    testWidgets('lists the previews newest first, with no mention of who made them',
        (tester) async {
      final api = _Api()
        ..previews = [
          _preview('new', event: SunEvent.sunrise, eventDate: DateTime(2026, 12, 2)),
          _preview('old', eventDate: DateTime(2026, 11, 3)),
        ];
      await openSheet(tester, api);

      expect(find.text('Sunrise · Wednesday, December 2'), findsOneWidget);
      expect(find.text('Sunset · Tuesday, November 3'), findsOneWidget);
      final top = tester.getTopLeft(find.byKey(const Key('shared-preview-new')));
      final other = tester.getTopLeft(find.byKey(const Key('shared-preview-old')));
      // Reading order in a two-column grid: same row left to right, then down.
      expect(top.dy < other.dy || (top.dy == other.dy && top.dx < other.dx), isTrue);
      expect(find.textContaining('AI-generated illustrations'), findsOneWidget);
    });

    testWidgets('says so when there is nothing to show', (tester) async {
      await openSheet(tester, _Api());

      expect(find.byKey(const Key('shared-previews-empty')), findsOneWidget);
    });

    testWidgets('shows a failure and can retry', (tester) async {
      final api = _Api()..previewsError = ApiException('Network down');
      await openSheet(tester, api);

      expect(find.textContaining('Network down'), findsOneWidget);

      api
        ..previewsError = null
        ..previews = [_preview('a')];
      await tester.tap(find.text('Retry'));
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('shared-preview-a')), findsOneWidget);
    });

    testWidgets('the back arrow returns to the page', (tester) async {
      await openSheet(tester, _Api()..previews = [_preview('a')]);

      await tester.tap(find.byKey(const Key('shared-previews-back')));
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('shared-previews-sheet')), findsNothing);
    });
  });

  group('SharedPreviewsForPlace', () {
    testWidgets('looks up its own place and shows the link', (tester) async {
      final api = _Api()
        ..counts = {
          'osm:way/1': const PlacePreviewCount(placeId: 'osm:way/1', count: 2, popular: false),
        };
      await _pump(
        tester,
        SharedPreviewsForPlace(placeId: 'osm:way/1', placeName: 'Test Park', apiClient: api),
      );

      expect(api.countRequests, [
        ['osm:way/1'],
      ]);
      expect(find.text('$_linkText (2)'), findsOneWidget);
    });

    testWidgets('shows nothing when the place has no previews', (tester) async {
      await _pump(
        tester,
        SharedPreviewsForPlace(placeId: 'osm:way/1', placeName: 'Test Park', apiClient: _Api()),
      );

      expect(find.textContaining(_linkText), findsNothing);
    });
  });

  group('PlacePreviewCount and SharedPreview', () {
    test('read what the server sends', () {
      final count = PlacePreviewCount.fromJson(
        {'place_id': 'osm:way/1', 'count': 4, 'popular': true},
      );
      expect((count.placeId, count.count, count.popular), ('osm:way/1', 4, true));

      final preview = SharedPreview.fromJson({
        'id': 'p1',
        'image_url': 'https://x/full.webp',
        'thumb_url': 'https://x/thumb.webp',
        'place_name': 'Test Park',
        'event': 'sunrise',
        'event_date': '2026-12-02',
        'disclaimer': 'AI.',
        'created_at': '2026-11-20T10:00:00',
      });
      expect(preview.event, SunEvent.sunrise);
      expect(preview.displayDate, DateTime(2026, 12, 2));
    });

    test('a preview without a day falls back to when it was made', () {
      final preview = SharedPreview.fromJson({
        'id': 'p1',
        'image_url': 'a',
        'thumb_url': 'b',
        'place_name': 'Test Park',
        'event': 'sunset',
        'event_date': null,
        'disclaimer': 'AI.',
        'created_at': '2026-11-20T10:00:00',
      });

      expect(preview.displayDate, DateTime(2026, 11, 20, 10));
    });
  });
}
