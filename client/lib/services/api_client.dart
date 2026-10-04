import 'dart:convert';
import '../models/trip_window.dart';

import 'package:http/http.dart' as http;

import '../models/feedback.dart';
import '../models/saved_profile.dart';
import '../models/session_request.dart';
import '../models/session_response.dart';
import '../models/simulation.dart';

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

  Future<SimulationResponse> fetchSimulation(SimulationRequest request, String idToken) async {
    final response = await http.post(
      Uri.parse('$baseUrl/simulate'),
      headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $idToken',
      },
      body: jsonEncode(request.toJson()),
    );

    if (response.statusCode != 200) {
      throw ApiException(_errorMessage(response));
    }

    return SimulationResponse.fromJson(jsonDecode(response.body) as Map<String, dynamic>);
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
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode(request.toJson()),
    );

    if (response.statusCode != 201) {
      throw ApiException('Request failed (${response.statusCode}): ${response.body}');
    }

    return SavedProfileRecord.fromJson(jsonDecode(response.body) as Map<String, dynamic>);
  }

  Future<List<SavedProfileRecord>> fetchSavedProfiles(String userId) async {
    final response = await http.get(Uri.parse('$baseUrl/profiles?user_id=$userId'));

    if (response.statusCode != 200) {
      throw ApiException('Request failed (${response.statusCode}): ${response.body}');
    }

    return (jsonDecode(response.body) as List)
        .map((item) => SavedProfileRecord.fromJson(item as Map<String, dynamic>))
        .toList();
  }

  Future<FeedbackRecord> createFeedback(FeedbackRequest request) async {
    final response = await http.post(
      Uri.parse('$baseUrl/feedback'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode(request.toJson()),
    );

    if (response.statusCode != 201) {
      throw ApiException('Request failed (${response.statusCode}): ${response.body}');
    }

    return FeedbackRecord.fromJson(jsonDecode(response.body) as Map<String, dynamic>);
  }
}
