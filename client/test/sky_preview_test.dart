import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:vesper/models/location_type.dart';
import 'package:vesper/models/session_request.dart';
import 'package:vesper/models/session_response.dart';
import 'package:vesper/models/simulation.dart';
import 'package:vesper/screens/sky_preview_screen.dart';
import 'package:vesper/services/api_client.dart';
import 'package:vesper/theme/app_theme.dart';
import 'package:vesper/widgets/preview_sky_button.dart';

// A 1x1 PNG, so Image.memory has something real to decode.
const _pixel =
    'data:image/png;base64,iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAADUlEQVR42mNkYPhfDwAChwGA60e6kgAAAABJRU5ErkJggg==';

const _request = SimulationRequest(
  locationName: 'Brooklyn Bridge Park',
  locationType: LocationType.waterfront,
  event: SunEvent.sunset,
  cloudCoverSummary: 'light cloud cover',
  visibilityLikelihood: 0.9,
  colorProbabilities:
      ColorProbabilities(pink: 0.4, purple: 0.3, orange: 0.7, red: 0.2, golden: 0.8),
);

class _FakeApi extends ApiClient {
  int remaining;
  int simulateCalls = 0;
  SimulationResponse? response;
  Object? simulateError;
  Object? remainingError;

  _FakeApi({this.remaining = 5});

  @override
  Future<RemainingPreviews> fetchRemainingPreviews() async {
    if (remainingError != null) throw remainingError!;
    return RemainingPreviews(remainingToday: remaining, dailyLimit: 5);
  }

  @override
  Future<SimulationResponse> fetchSimulation(SimulationRequest request) async {
    simulateCalls++;
    if (simulateError != null) throw simulateError!;
    return response ??
        SimulationResponse(
          prompt: 'A sunset at ${request.locationName}',
          imageUrl: _pixel,
          disclaimer: 'An AI-generated illustration.',
          providerStatus: 'generated',
          remainingToday: remaining - 1,
          previewId: 'p1',
          saved: true,
        );
  }
}

Future<void> _pumpButton(WidgetTester tester, _FakeApi api) async {
  tester.view.physicalSize = const Size(800, 1600);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(MaterialApp(
    theme: buildAppTheme(),
    home: Scaffold(body: Center(child: PreviewSkyButton(request: _request, apiClient: api))),
  ));
  await tester.pumpAndSettle();
}

Future<void> _pumpScreen(WidgetTester tester, _FakeApi api) async {
  tester.view.physicalSize = const Size(800, 2400);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(MaterialApp(
    theme: buildAppTheme(),
    home: SkyPreviewScreen(request: _request, apiClient: api),
  ));
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('the button on its own never generates anything', (tester) async {
    final api = _FakeApi();
    await _pumpButton(tester, api);

    expect(find.text('Preview this sky'), findsOneWidget);
    expect(api.simulateCalls, 0);
  });

  testWidgets('tapping asks first, showing how many previews are left', (tester) async {
    final api = _FakeApi(remaining: 3);
    await _pumpButton(tester, api);

    await tester.tap(find.byKey(const Key('preview-sky')));
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('preview-confirm-dialog')), findsOneWidget);
    expect(find.textContaining('3 of 5 previews left today'), findsOneWidget);
    expect(find.byKey(const Key('preview-sun-4')), findsOneWidget);
    expect(api.simulateCalls, 0);
  });

  testWidgets('cancelling generates nothing', (tester) async {
    final api = _FakeApi();
    await _pumpButton(tester, api);

    await tester.tap(find.byKey(const Key('preview-sky')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('preview-cancel')));
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('preview-confirm-dialog')), findsNothing);
    expect(find.byType(SkyPreviewScreen), findsNothing);
    expect(api.simulateCalls, 0);
  });

  testWidgets('confirming generates once and develops the picture', (tester) async {
    final api = _FakeApi(remaining: 5);
    await _pumpButton(tester, api);

    await tester.tap(find.byKey(const Key('preview-sky')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('preview-generate')));
    await tester.pumpAndSettle();

    expect(api.simulateCalls, 1);
    expect(find.byType(SkyPreviewScreen), findsOneWidget);
    expect(find.byKey(const Key('preview-image')), findsOneWidget);
    expect(find.text('Brooklyn Bridge Park'), findsOneWidget);
    expect(find.text('Sunset'), findsOneWidget);
    expect(find.byKey(const Key('preview-saved-note')), findsOneWidget);
    expect(find.text('4 of 5 previews left today'), findsOneWidget);
    expect(find.text('An AI-generated illustration.'), findsOneWidget);
  });

  testWidgets('with none left it says so and offers no way to generate', (tester) async {
    final api = _FakeApi(remaining: 0);
    await _pumpButton(tester, api);

    await tester.tap(find.byKey(const Key('preview-sky')));
    await tester.pumpAndSettle();

    expect(find.text('No previews left today'), findsOneWidget);
    expect(find.byKey(const Key('preview-generate')), findsNothing);

    await tester.tap(find.byKey(const Key('preview-ok')));
    await tester.pumpAndSettle();
    expect(api.simulateCalls, 0);
    expect(find.byType(SkyPreviewScreen), findsNothing);
  });

  testWidgets('if the allowance cannot be checked it says so and opens nothing', (tester) async {
    final api = _FakeApi()..remainingError = ApiException('You need to be signed in to do that.');
    await _pumpButton(tester, api);

    await tester.tap(find.byKey(const Key('preview-sky')));
    await tester.pumpAndSettle();

    expect(find.textContaining('Could not check your previews'), findsOneWidget);
    expect(find.byKey(const Key('preview-confirm-dialog')), findsNothing);
  });

  testWidgets('a rejected generation shows the reason and offers another try', (tester) async {
    final api = _FakeApi()..simulateError = ApiException('You have used all 5 sky previews.');
    await _pumpScreen(tester, api);

    expect(find.text('You have used all 5 sky previews.'), findsOneWidget);
    expect(find.byKey(const Key('preview-retry')), findsOneWidget);
    expect(api.simulateCalls, 1);
  });

  testWidgets('an image that could not be kept says it was not saved', (tester) async {
    final api = _FakeApi()
      ..response = const SimulationResponse(
        prompt: 'p',
        imageUrl: _pixel,
        disclaimer: 'AI-generated.',
        providerStatus: 'generated',
        remainingToday: 2,
      );
    await _pumpScreen(tester, api);

    expect(find.byKey(const Key('preview-not-saved-note')), findsOneWidget);
    expect(find.byKey(const Key('preview-saved-note')), findsNothing);
  });

  testWidgets('a provider failure explains that no preview was used', (tester) async {
    final api = _FakeApi()
      ..response = const SimulationResponse(
        prompt: 'p',
        imageUrl: null,
        disclaimer: 'AI-generated.',
        providerStatus: 'error',
        remainingToday: 5,
      );
    await _pumpScreen(tester, api);

    expect(find.textContaining('did not use one of your previews'), findsOneWidget);
  });

  test('a request for a place with no spot type leaves the type out', () {
    const request = SimulationRequest(
      locationName: 'Somewhere',
      event: SunEvent.sunrise,
      cloudCoverSummary: 'clear',
      visibilityLikelihood: 0.5,
      colorProbabilities:
          ColorProbabilities(pink: 0, purple: 0, orange: 0, red: 0, golden: 0),
    );

    expect(request.toJson().containsKey('location_type'), isFalse);
    expect(_request.toJson()['location_type'], 'waterfront');
  });
}
