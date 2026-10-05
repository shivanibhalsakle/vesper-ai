import 'dart:convert';
import '../models/trip_window.dart';

import 'package:http/http.dart' as http;

import '../models/best_date.dart';
import '../models/feedback.dart';
import '../models/geocode_result.dart';
import '../models/location_type.dart';
import '../models/nearby_spot.dart';
import '../models/user_preferences.dart';
import '../models/saved_profile.dart';
import '../models/session_request.dart';
import '../models/session_response.dart';
import '../models/saved_date.dart';
import '../models/simulation.dart';
import '../models/sky_forecast.dart';
import 'auth_service.dart';

class ApiException implements Exception {
  final String message;
  ApiException(this.message);

  @override
  String toString() => message;
}

class ApiClient {
  // Defaults to the local Docker Compose backend (see backend/README.md).
  // Override at build time for deployed environments, e.g.:
  //   flutter build web --dart-define=API_BASE_URL=https://vesper-backend.onrender.com
  // Android emulators must use 10.0.2.2 instead of localhost to reach the
  // host machine — revisit this when Android builds are wired up.
  static const String baseUrl = String.fromEnvironment(
    'API_BASE_URL',
    defaultValue: 'http://localhost:8010',
  );

  Future<SessionResponse> fetchSession(SessionRequest request) async {
    final response = await http.post(
      Uri.parse('$baseUrl/session'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode(request.toJson()),
    );

    if (response.statusCode != 200) {
      throw ApiException(_errorMessage(response));
    }

    return SessionResponse.fromJson(jsonDecode(response.body) as Map<String, dynamic>);
  }

  Future<TripWindowResponse> fetchTripWindow(TripWindowRequest request) async {
  final response = await http.post(
    Uri.parse('$baseUrl/trip-window'),
    headers: {'Content-Type': 'application/json'},
    body: jsonEncode(request.toJson()),
  );

  if (response.statusCode != 200) {
    throw ApiException(_errorMessage(response));
  }

  return TripWindowResponse.fromJson(jsonDecode(response.body) as Map<String, dynamic>);
}

  Future<SimulationResponse> fetchSimulation(SimulationRequest request) async {
    final response = await http.post(
      Uri.parse('$baseUrl/simulate'),
      headers: await _authHeaders(),
      body: jsonEncode(request.toJson()),
    );

    if (response.statusCode != 200) {
      throw ApiException(_errorMessage(response));
    }

    return SimulationResponse.fromJson(jsonDecode(response.body) as Map<String, dynamic>);
  }

  // The backend identifies the user from this Firebase ID token — the app
  // never sends a user id itself. getIdToken() refreshes expired tokens.
  Future<Map<String, String>> _authHeaders() async {
    final idToken = await AuthService().getIdToken();
    if (idToken == null) {
      throw ApiException('You need to be signed in to do that.');
    }
    return {
      'Content-Type': 'application/json',
      'Authorization': 'Bearer $idToken',
    };
  }

  // The backend returns {"detail": "..."} for auth/rate-limit errors — show
  // that human-readable message instead of the raw response body.
  String _errorMessage(http.Response response) {
    try {
      final body = jsonDecode(response.body);
      if (body is Map && body['detail'] is String) {
        return body['detail'] as String;
      }
    } catch (_) {
      // Fall through to the generic message below.
    }
    return 'Request failed (${response.statusCode}): ${response.body}';
  }

  Future<SavedProfileRecord> createSavedProfile(SavedProfileRequest request) async {
    final response = await http.post(
      Uri.parse('$baseUrl/profiles'),
      headers: await _authHeaders(),
      body: jsonEncode(request.toJson()),
    );

    if (response.statusCode != 201) {
      throw ApiException(_errorMessage(response));
    }

    return SavedProfileRecord.fromJson(jsonDecode(response.body) as Map<String, dynamic>);
  }

  Future<List<SavedProfileRecord>> fetchSavedProfiles() async {
    final response = await http.get(
      Uri.parse('$baseUrl/profiles'),
      headers: await _authHeaders(),
    );

    if (response.statusCode != 200) {
      throw ApiException(_errorMessage(response));
    }

    return (jsonDecode(response.body) as List)
        .map((item) => SavedProfileRecord.fromJson(item as Map<String, dynamic>))
        .toList();
  }

  /// The user's saved Settings, or null if they've never saved any.
  Future<UserPreferences?> fetchPreferences() async {
    final response = await http.get(
      Uri.parse('$baseUrl/me/preferences'),
      headers: await _authHeaders(),
    );

    if (response.statusCode == 404) return null;
    if (response.statusCode != 200) {
      throw ApiException(_errorMessage(response));
    }

    return UserPreferences.fromJson(jsonDecode(response.body) as Map<String, dynamic>);
  }

  Future<UserPreferences> savePreferences(UserPreferences preferences) async {
    final response = await http.put(
      Uri.parse('$baseUrl/me/preferences'),
      headers: await _authHeaders(),
      body: jsonEncode(preferences.toJson()),
    );

    if (response.statusCode != 200) {
      throw ApiException(_errorMessage(response));
    }

    return UserPreferences.fromJson(jsonDecode(response.body) as Map<String, dynamic>);
  }

  /// Address / place-name search (Geoapify, via our backend's cached proxy).
  Future<List<PickedLocation>> geocode(String query) async {
    final response = await http.get(
      Uri.parse('$baseUrl/geocode').replace(queryParameters: {'q': query}),
      headers: await _authHeaders(),
    );

    if (response.statusCode != 200) {
      throw ApiException(_errorMessage(response));
    }

    return (jsonDecode(response.body) as List)
        .map((item) => PickedLocation.fromJson(item as Map<String, dynamic>))
        .toList();
  }

  /// Saves a date (idempotent: saving the same place and day again returns
  /// the existing one).
  Future<SavedDate> createSavedDate(SavedDateRequest request) async {
    final response = await http.post(
      Uri.parse('$baseUrl/me/saved-dates'),
      headers: await _authHeaders(),
      body: jsonEncode(request.toJson()),
    );

    if (response.statusCode != 201) {
      throw ApiException(_errorMessage(response));
    }

    return SavedDate.fromJson(jsonDecode(response.body) as Map<String, dynamic>);
  }

  Future<List<SavedDate>> fetchSavedDates() async {
    final response = await http.get(
      Uri.parse('$baseUrl/me/saved-dates'),
      headers: await _authHeaders(),
    );

    if (response.statusCode != 200) {
      throw ApiException(_errorMessage(response));
    }

    return (jsonDecode(response.body) as List)
        .map((item) => SavedDate.fromJson(item as Map<String, dynamic>))
        .toList();
  }

  Future<SavedDate> setSavedDateNotifications(String id, {required bool enabled}) async {
    final response = await http.patch(
      Uri.parse('$baseUrl/me/saved-dates/$id'),
      headers: await _authHeaders(),
      body: jsonEncode({'notification_enabled': enabled}),
    );

    if (response.statusCode != 200) {
      throw ApiException(_errorMessage(response));
    }

    return SavedDate.fromJson(jsonDecode(response.body) as Map<String, dynamic>);
  }

  Future<void> deleteSavedDate(String id) async {
    final response = await http.delete(
      Uri.parse('$baseUrl/me/saved-dates/$id'),
      headers: await _authHeaders(),
    );

    if (response.statusCode != 204) {
      throw ApiException(_errorMessage(response));
    }
  }

  /// Scores the next few days against the user's sky preferences and
  /// returns the earliest best one.
  Future<BestDateResponse> fetchBestDate(BestDateRequest request) async {
    final response = await http.post(
      Uri.parse('$baseUrl/best-date'),
      headers: await _authHeaders(),
      body: jsonEncode(request.toJson()),
    );

    if (response.statusCode != 200) {
      throw ApiException(_errorMessage(response));
    }

    return BestDateResponse.fromJson(jsonDecode(response.body) as Map<String, dynamic>);
  }

  /// The predicted sky at one point on one day.
  Future<SkyForecast> fetchSky(SkyRequest request) async {
    final response = await http.post(
      Uri.parse('$baseUrl/sky'),
      headers: await _authHeaders(),
      body: jsonEncode(request.toJson()),
    );

    if (response.statusCode != 200) {
      throw ApiException(_errorMessage(response));
    }

    return SkyForecast.fromJson(jsonDecode(response.body) as Map<String, dynamic>);
  }

  /// Viewing spots around a point, nearest first. An empty [placeTypes]
  /// list means all types.
  Future<List<NearbySpot>> fetchNearbySpots({
    required double lat,
    required double lon,
    required double radiusKm,
    List<LocationType> placeTypes = const [],
  }) async {
    final uri = Uri.parse('$baseUrl/places/nearby').replace(queryParameters: {
      'lat': '$lat',
      'lon': '$lon',
      'radius_km': '$radiusKm',
      if (placeTypes.isNotEmpty) 'place_types': placeTypes.map((t) => t.apiValue).toList(),
    });
    final response = await http.get(uri, headers: await _authHeaders());

    if (response.statusCode != 200) {
      throw ApiException(_errorMessage(response));
    }

    return (jsonDecode(response.body) as List)
        .map((item) => NearbySpot.fromJson(item as Map<String, dynamic>))
        .toList();
  }

  Future<FeedbackRecord> createFeedback(FeedbackRequest request) async {
    final response = await http.post(
      Uri.parse('$baseUrl/feedback'),
      headers: await _authHeaders(),
      body: jsonEncode(request.toJson()),
    );

    if (response.statusCode != 201) {
      throw ApiException(_errorMessage(response));
    }

    return FeedbackRecord.fromJson(jsonDecode(response.body) as Map<String, dynamic>);
  }
}
