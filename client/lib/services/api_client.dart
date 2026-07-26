import 'dart:convert';

import 'package:http/http.dart' as http;

import '../models/session_request.dart';
import '../models/session_response.dart';

class ApiException implements Exception {
  final String message;
  ApiException(this.message);

  @override
  String toString() => message;
}

class ApiClient {
  // Points at the local Docker Compose backend (see backend/README.md).
  // Android emulators must use 10.0.2.2 instead of localhost to reach the
  // host machine — revisit this when Android builds are wired up.
  static const String baseUrl = 'http://localhost:8010';

  Future<SessionResponse> fetchSession(SessionRequest request) async {
    final response = await http.post(
      Uri.parse('$baseUrl/session'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode(request.toJson()),
    );

    if (response.statusCode != 200) {
      throw ApiException('Request failed (${response.statusCode}): ${response.body}');
    }

    return SessionResponse.fromJson(jsonDecode(response.body) as Map<String, dynamic>);
  }
}
