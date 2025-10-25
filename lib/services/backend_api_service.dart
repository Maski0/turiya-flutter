import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:supabase_flutter/supabase_flutter.dart' as supabase;

class BackendApiService {
  static String get baseUrl => dotenv.env['BACKEND_URL'] ?? 'http://10.0.2.2:8080';
  final supabase.SupabaseClient _supabase = supabase.Supabase.instance.client;
  
  /// Get current Supabase access token (JWT)
  /// This is the token that the backend expects (same as web!)
  String? getAccessToken() {
    return _supabase.auth.currentSession?.accessToken;
  }

  /// Check if authenticated (has Supabase session)
  bool isAuthenticated() {
    return _supabase.auth.currentSession != null;
  }

  /// Get current user ID
  String? getUserId() {
    return _supabase.auth.currentUser?.id;
  }

  /// Call backend with Supabase JWT auth
  Future<Map<String, dynamic>> invokeAgent({
    required String message,
    String? threadId,
    String model = 'claude-3-5-sonnet-latest',
    String agentId = 'krsna-agent',
  }) async {
    final token = getAccessToken();
    if (token == null) throw Exception('Not authenticated');

    final userId = getUserId();
    if (userId == null) throw Exception('User ID not found');

    final response = await http.post(
      Uri.parse('$baseUrl/$agentId/invoke'),
      headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $token',  // Supabase JWT (same as web!)
      },
      body: jsonEncode({
        'message': message,
        'model': model,
        'thread_id': threadId,
        'user_id': userId,
      }),
    );

    if (response.statusCode == 200) {
      return jsonDecode(response.body);
    } else if (response.statusCode == 401) {
      // Token expired, user needs to re-authenticate
      throw Exception('Authentication expired');
    } else if (response.statusCode == 402) {
      throw Exception('Insufficient credits');
    } else {
      throw Exception('API call failed: ${response.statusCode} - ${response.body}');
    }
  }

  /// Stream endpoint (for SSE)
  Stream<String> streamAgent({
    required String message,
    String? threadId,
    String model = 'claude-3-5-sonnet-latest',
    String agentId = 'krsna-agent',
  }) async* {
    final token = getAccessToken();
    if (token == null) throw Exception('Not authenticated');

    final userId = getUserId();
    if (userId == null) throw Exception('User ID not found');

    final request = http.Request(
      'POST',
      Uri.parse('$baseUrl/$agentId/stream'),
    )
      ..headers.addAll({
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $token',  // Supabase JWT
      })
      ..body = jsonEncode({
        'message': message,
        'model': model,
        'thread_id': threadId,
        'user_id': userId,
      });

    final response = await http.Client().send(request);

    if (response.statusCode == 401) {
      throw Exception('Authentication expired');
    } else if (response.statusCode == 402) {
      throw Exception('Insufficient credits');
    } else if (response.statusCode != 200) {
      throw Exception('Stream API call failed: ${response.statusCode}');
    }

    await for (final chunk in response.stream.transform(utf8.decoder)) {
      yield chunk;
    }
  }

  /// Sign out (handled by AuthService, but keeping for compatibility)
  Future<void> signOut() async {
    await _supabase.auth.signOut();
  }
}
