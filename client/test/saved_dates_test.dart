import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:vesper/models/saved_date.dart';
import 'package:vesper/models/session_request.dart';
import 'package:vesper/models/session_response.dart';
import 'package:vesper/models/sky_forecast.dart';
import 'package:vesper/models/user_preferences.dart';
import 'package:vesper/models/preference_profile.dart';
import 'package:vesper/screens/saved_screen.dart';
import 'package:vesper/services/api_client.dart';
import 'package:vesper/widgets/save_date_button.dart';
import 'package:vesper/widgets/saved_dates_calendar.dart';

final _today = DateTime(2026, 10, 5);

const _sky = SkyForecast(
  event: SunEvent.sunset,
  eventTime: '2026-10-07T18:08:00-04:00',
  eventPassed: false,
  recommendedArrivalOffsetMinutes: -20,
  bestViewingWindowStart: '2026-10-07T17:48:00-04:00',
  bestViewingWindowEnd: '2026-10-07T18:28:00-04:00',
  visibilityLikelihood: 0.9,
  cloudCoverSummary: 'mostly clear skies',
  colorProbabilities:
      ColorProbabilities(pink: 0.4, purple: 0.3, orange: 0.7, red: 0.2, golden: 0.8),
  skyProfile: SkyProfile(
    clearSky: 0.8,
    dramaticClouds: 0.3,
    pinkPurple: 0.35,
    goldenOrange: 0.75,
    redSky: 0.2,
  ),
  rainOrUnsafeAlert: null,
  preferenceMatchScore: 0.84,
  leadDays: 2,
  confidence: Confidence.medium,
);

SavedDate _saved(String id, DateTime date,
        {String label = 'Brooklyn Bridge Park',
        SunEvent event = SunEvent.sunset,
        bool notify = true,
        double? score = 0.8}) =>
    SavedDate(
      id: id,
      eventDate: date,
      event: event,
      lat: 40.7,
      lon: -73.99,
      label: label,
      savedScore: score,
      notificationEnabled: notify,
    );

class _FakeApiClient extends ApiClient {
  List<SavedDate> dates;
  Object? loadError;
  Object? saveError;
  Object? skyError;
  final List<SavedDateRequest> created = [];
  final List<SkyRequest> skyRequests = [];
  final List<String> deleted = [];
  final List<(String, bool)> toggled = [];

  _FakeApiClient([this.dates = const []]);

  @override
  Future<List<SavedDate>> fetchSavedDates() async {
    if (loadError != null) throw loadError!;
    return dates;
  }

  @override
  Future<UserPreferences?> fetchPreferences() async =>
      const UserPreferences(preferences: PreferenceProfile(goldenOrange: 0.9));

  @override
  Future<SavedDate> createSavedDate(SavedDateRequest request) async {
    created.add(request);
    if (saveError != null) throw saveError!;
    return _saved('new', request.eventDate);
  }

  @override
  Future<SkyForecast> fetchSky(SkyRequest request) async {
    skyRequests.add(request);
    if (skyError != null) throw skyError!;
    return _sky;
  }

  @override
  Future<void> deleteSavedDate(String id) async => deleted.add(id);

  @override
  Future<SavedDate> setSavedDateNotifications(String id, {required bool enabled}) async {
    toggled.add((id, enabled));
    return dates.firstWhere((d) => d.id == id).copyWith(notificationEnabled: enabled);
  }
}

Future<void> _pumpSaved(WidgetTester tester, _FakeApiClient api) async {
  tester.view.physicalSize = const Size(800, 6000);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(MaterialApp(home: SavedScreen(apiClient: api, today: _today)));
  await tester.pumpAndSettle();
}

void main() {
  group('SavedScreen', () {
    testWidgets('shows an empty state with no saved dates', (tester) async {
      await _pumpSaved(tester, _FakeApiClient());

      expect(find.textContaining('No saved dates yet'), findsOneWidget);
      expect(find.text('Saved searches'), findsOneWidget);
      expect(find.text('Photos & sky previews'), findsOneWidget);
    });

    testWidgets('splits upcoming and past dates', (tester) async {
      final api = _FakeApiClient([
        _saved('a', DateTime(2026, 10, 7)),
        _saved('b', DateTime(2026, 10, 1), label: 'Old Pier'),
      ]);
      await _pumpSaved(tester, api);

      expect(find.text('Upcoming'), findsOneWidget);
      expect(find.text('Past'), findsOneWidget);
      expect(find.text('Wednesday, October 7'), findsOneWidget);
      expect(find.text('Thursday, October 1'), findsOneWidget);
      expect(find.textContaining('80% when saved'), findsWidgets);
    });

    testWidgets('opening a date loads its forecast against your taste', (tester) async {
      final api = _FakeApiClient([_saved('a', DateTime(2026, 10, 7))]);
      await _pumpSaved(tester, api);

      expect(api.skyRequests, isEmpty); // nothing fetched until it's opened
      await tester.tap(find.text('Wednesday, October 7'));
      await tester.pumpAndSettle();

      expect(api.skyRequests.single.date, DateTime(2026, 10, 7));
      expect(api.skyRequests.single.preferences!.goldenOrange, 0.9);
      expect(find.text('Expected sky'), findsOneWidget);
      expect(find.byKey(const Key('preference-marker')), findsOneWidget);
    });

    testWidgets('a forecast failure is shown inside the tile', (tester) async {
      final api = _FakeApiClient([_saved('a', DateTime(2026, 10, 7))])
        ..skyError = ApiException('Weather data is temporarily unavailable.');
      await _pumpSaved(tester, api);

      await tester.tap(find.text('Wednesday, October 7'));
      await tester.pumpAndSettle();

      expect(find.text('Weather data is temporarily unavailable.'), findsOneWidget);
    });

    testWidgets('past dates and far-off dates do not fetch a forecast', (tester) async {
      final api = _FakeApiClient([
        _saved('past', DateTime(2026, 10, 1)),
        _saved('far', DateTime(2026, 12, 25), label: 'Winter Spot'),
      ]);
      await _pumpSaved(tester, api);

      await tester.tap(find.text('Thursday, October 1'));
      await tester.pumpAndSettle();
      expect(find.text('This date has passed.'), findsOneWidget);

      await tester.tap(find.text('Friday, December 25'));
      await tester.pumpAndSettle();
      expect(find.textContaining('Forecasts open up'), findsOneWidget);
      expect(api.skyRequests, isEmpty);
    });

    testWidgets('toggling the reminder calls the API', (tester) async {
      final api = _FakeApiClient([_saved('a', DateTime(2026, 10, 7))]);
      await _pumpSaved(tester, api);

      await tester.tap(find.text('Wednesday, October 7'));
      await tester.pumpAndSettle();
      await tester.tap(find.byType(Switch));
      await tester.pumpAndSettle();

      expect(api.toggled, [('a', false)]);
      expect(tester.widget<Switch>(find.byType(Switch)).value, isFalse);
    });

    testWidgets('removing asks first, then deletes', (tester) async {
      final api = _FakeApiClient([_saved('a', DateTime(2026, 10, 7))]);
      await _pumpSaved(tester, api);

      await tester.tap(find.text('Wednesday, October 7'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Remove'));
      await tester.pumpAndSettle();
      expect(find.text('Remove this saved date?'), findsOneWidget);

      await tester.tap(find.widgetWithText(TextButton, 'Cancel'));
      await tester.pumpAndSettle();
      expect(api.deleted, isEmpty);

      await tester.tap(find.text('Remove'));
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(FilledButton, 'Remove'));
      await tester.pumpAndSettle();

      expect(api.deleted, ['a']);
      expect(find.text('Wednesday, October 7'), findsNothing);
    });

    testWidgets('tapping a calendar day filters the list to it', (tester) async {
      final api = _FakeApiClient([
        _saved('a', DateTime(2026, 10, 7)),
        _saved('b', DateTime(2026, 10, 9), label: 'Pier 1'),
      ]);
      await _pumpSaved(tester, api);

      await tester.tap(find.byKey(calendarDayKey(DateTime(2026, 10, 9))));
      await tester.pumpAndSettle();

      expect(find.text('Friday, October 9'), findsWidgets);
      expect(find.text('Wednesday, October 7'), findsNothing);

      await tester.tap(find.byTooltip('Show all'));
      await tester.pumpAndSettle();
      expect(find.text('Wednesday, October 7'), findsOneWidget);
    });

    testWidgets('a load failure offers a retry', (tester) async {
      final api = _FakeApiClient()..loadError = ApiException('boom');
      await _pumpSaved(tester, api);

      expect(find.textContaining('Could not load your saved items'), findsOneWidget);

      api.loadError = null;
      await tester.tap(find.text('Retry'));
      await tester.pumpAndSettle();
      expect(find.textContaining('No saved dates yet'), findsOneWidget);
    });
  });

  group('SavedDatesCalendar', () {
    testWidgets('the selection circle is a full circle covering the whole number',
        (tester) async {
      for (final day in [DateTime(2026, 10, 7), DateTime(2026, 10, 28)]) {
        await tester.pumpWidget(MaterialApp(
          home: Scaffold(
            body: SavedDatesCalendar(
              today: _today,
              // Saved days carry a dot under the number; cover that case too.
              markedDates: {DateTime(2026, 10, 28)},
              selected: day,
              onSelected: (_) {},
            ),
          ),
        ));
        await tester.pumpAndSettle();

        final circle = tester.getRect(find.byKey(Key('day-circle-${day.day}')));
        final number = tester.getRect(find.descendant(
          of: find.byKey(calendarDayKey(day)),
          matching: find.text('${day.day}'),
        ));

        expect(circle.width, closeTo(circle.height, 0.01), reason: 'a circle, not an oval');
        expect(circle.width, greaterThan(number.width + 12));
        expect(circle.height, greaterThan(number.height));
        expect(circle.contains(number.topLeft), isTrue);
        expect(circle.contains(number.bottomRight), isTrue);
      }
    });

    testWidgets('marks saved days and navigates months', (tester) async {
      DateTime? picked;
      await tester.pumpWidget(MaterialApp(
        home: Scaffold(
          body: SavedDatesCalendar(
            today: _today,
            markedDates: {DateTime(2026, 10, 7), DateTime(2026, 11, 2)},
            selected: null,
            onSelected: (day) => picked = day,
          ),
        ),
      ));

      expect(find.text('October 2026'), findsOneWidget);
      expect(find.byKey(const Key('saved-dot')), findsOneWidget);

      await tester.tap(find.byKey(calendarDayKey(DateTime(2026, 10, 7))));
      expect(picked, DateTime(2026, 10, 7));

      await tester.tap(find.byTooltip('Next month'));
      await tester.pump();
      expect(find.text('November 2026'), findsOneWidget);
      expect(find.byKey(const Key('saved-dot')), findsOneWidget);
    });

    testWidgets('tapping the selected day clears the selection', (tester) async {
      DateTime? picked = DateTime(2026, 10, 7);
      await tester.pumpWidget(MaterialApp(
        home: Scaffold(
          body: SavedDatesCalendar(
            today: _today,
            markedDates: {DateTime(2026, 10, 7)},
            selected: DateTime(2026, 10, 7),
            onSelected: (day) => picked = day,
          ),
        ),
      ));

      await tester.tap(find.byKey(calendarDayKey(DateTime(2026, 10, 7))));

      expect(picked, isNull);
    });
  });

  group('SaveDateButton', () {
    Future<void> pump(WidgetTester tester, _FakeApiClient api, Future<String?> Function() token) {
      return tester.pumpWidget(MaterialApp(
        home: Scaffold(
          body: SaveDateButton(
            eventDate: DateTime(2026, 10, 7),
            event: SunEvent.sunset,
            lat: 40.7,
            lon: -73.99,
            label: 'Brooklyn Bridge Park',
            savedScore: 0.84,
            apiClient: api,
            getFcmToken: token,
          ),
        ),
      ));
    }

    testWidgets('saves the date with the device token and confirms', (tester) async {
      final api = _FakeApiClient();
      await pump(tester, api, () async => 'device-token');

      await tester.tap(find.text('Save this date'));
      await tester.pumpAndSettle();

      final request = api.created.single;
      expect(request.fcmToken, 'device-token');
      expect(request.savedScore, 0.84);
      expect(request.label, 'Brooklyn Bridge Park');
      expect(find.textContaining("we'll remind you"), findsOneWidget);
    });

    testWidgets('still saves when there is no push token, and says so', (tester) async {
      final api = _FakeApiClient();
      await pump(tester, api, () async => throw StateError('no firebase'));

      await tester.tap(find.text('Save this date'));
      await tester.pumpAndSettle();

      expect(api.created.single.fcmToken, isNull);
      expect(find.text('Saved'), findsOneWidget);
    });

    testWidgets('shows the error and lets the user retry', (tester) async {
      final api = _FakeApiClient()..saveError = ApiException('You can save up to 100 dates.');
      await pump(tester, api, () async => null);

      await tester.tap(find.text('Save this date'));
      await tester.pumpAndSettle();

      expect(find.text('You can save up to 100 dates.'), findsOneWidget);
      expect(find.text('Save this date'), findsOneWidget); // still tappable
    });
  });

  test('SavedDate parses the API response', () {
    final parsed = SavedDate.fromJson({
      'id': 'x',
      'event_date': '2026-10-07',
      'event': 'sunrise',
      'lat': 40.7,
      'lon': -73.99,
      'label': 'Pier 1',
      'saved_score': null,
      'notification_enabled': false,
      'created_at': '2026-10-05T12:00:00',
    });

    expect(parsed.eventDate, DateTime(2026, 10, 7));
    expect(parsed.event, SunEvent.sunrise);
    expect(parsed.savedScore, isNull);
    expect(parsed.notificationEnabled, isFalse);
  });
}
