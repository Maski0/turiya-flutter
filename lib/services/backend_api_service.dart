import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:supabase_flutter/supabase_flutter.dart' as supabase;

class BackendApiService {
  static String get baseUrl => dotenv.env['BACKEND_URL']!;
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
    String model = 'claude-sonnet-4-0',
    String agentId = 'krsna-agent',
  }) async {
    print('🌐 invokeAgent called');
    print('   Message: "$message"');
    print('   Thread ID: $threadId');
    print('   Agent ID: $agentId');
    
    final token = getAccessToken();
    if (token == null) {
      print('❌ Not authenticated - no access token');
      throw Exception('Not authenticated');
    }

    final userId = getUserId();
    if (userId == null) {
      print('❌ User ID not found');
      throw Exception('User ID not found');
    }

    final url = '$baseUrl/$agentId/invoke';
    print('📡 Calling: $url');
    print('   User ID: $userId');

    final requestBody = {
      'message': message,
      'model': model,
      'thread_id': threadId,
      'user_id': userId,
      'agent_config': {
        'spicy_level': 0.8,
      },
    };

    print('📤 Request body: ${jsonEncode(requestBody)}');

    try {
      final response = await http.post(
        Uri.parse(url),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',  // Supabase JWT (same as web!)
        },
        body: jsonEncode(requestBody),
      ).timeout(
        const Duration(seconds: 60),
        onTimeout: () {
          print('⏰ HTTP request timed out after 60 seconds');
          throw Exception('Request timeout - server did not respond');
        },
      );

        print('📥 Response status: ${response.statusCode}');

      if (response.statusCode == 200) {
        print('✅ Response received: ${response.body.substring(0, response.body.length > 200 ? 200 : response.body.length)}...');
        return jsonDecode(response.body);
      } else if (response.statusCode == 401) {
        // Token expired, user needs to re-authenticate
        print('❌ 401 Authentication expired');
        throw Exception('Authentication expired');
      } else if (response.statusCode == 402) {
        print('❌ 402 Insufficient credits');
        throw Exception('Insufficient credits');
      } else if (response.statusCode == 422) {
        // Validation error - log details
        print('❌ 422 Validation Error');
        print('Request body: ${jsonEncode(requestBody)}');
        print('Response: ${response.body}');
        throw Exception('Validation error: ${response.body}');
      } else {
        print('❌ API call failed: ${response.statusCode}');
        print('   Response: ${response.body}');
        throw Exception('API call failed: ${response.statusCode} - ${response.body}');
      }
    } catch (e) {
      print('❌ HTTP request exception: $e');
      rethrow;
    }
  }

  /// Stream endpoint (for SSE)
  Stream<String> streamAgent({
    required String message,
    String? threadId,
    String model = 'claude-sonnet-4-0',
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

  /// Get conversation history
  Future<Map<String, dynamic>> getHistory(String threadId) async {
    final token = getAccessToken();
    if (token == null) throw Exception('Not authenticated');

    final response = await http.post(
      Uri.parse('$baseUrl/history'),
      headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $token',
      },
      body: jsonEncode({'thread_id': threadId}),
    );

    if (response.statusCode == 200) {
      return jsonDecode(response.body);
    } else {
      throw Exception('Failed to get history: ${response.statusCode}');
    }
  }

  /// Delete conversation history
  Future<void> deleteHistory(String threadId) async {
    final token = getAccessToken();
    if (token == null) throw Exception('Not authenticated');

    final response = await http.post(
      Uri.parse('$baseUrl/deletethread'),
      headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $token',
      },
      body: jsonEncode({'thread_id': threadId}),
    );

    if (response.statusCode != 200) {
      throw Exception('Failed to delete history: ${response.statusCode}');
    }
  }

  /// Get user credits status
  Future<Map<String, dynamic>> getCreditsStatus() async {
    final token = getAccessToken();
    if (token == null) throw Exception('Not authenticated');

    final response = await http.get(
      Uri.parse('$baseUrl/credits/status'),
      headers: {
        'Authorization': 'Bearer $token',
      },
    );

    if (response.statusCode == 200) {
      return jsonDecode(response.body);
    } else {
      throw Exception('Failed to get credits: ${response.statusCode}');
    }
  }

  /// List user memories
  Future<List<Map<String, dynamic>>> listMemories() async {
    final token = getAccessToken();
    if (token == null) throw Exception('Not authenticated');

    final userId = getUserId();
    if (userId == null) throw Exception('User ID not found');

    final response = await http.post(
      Uri.parse('$baseUrl/list-memories'),
      headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $token',
      },
      body: jsonEncode({'user_id': userId}),
    );

    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);
      return (data['memories'] as List).cast<Map<String, dynamic>>();
    } else {
      throw Exception('Failed to list memories: ${response.statusCode}');
    }
  }

  /// Delete a specific memory
  Future<void> deleteMemory(String memoryId) async {
    final token = getAccessToken();
    if (token == null) throw Exception('Not authenticated');

    final response = await http.post(
      Uri.parse('$baseUrl/delete-memory'),
      headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $token',
      },
      body: jsonEncode({'memory_id': memoryId}),
    );

    if (response.statusCode != 200) {
      throw Exception('Failed to delete memory: ${response.statusCode}');
    }
  }

  /// Delete all memories
  Future<void> deleteAllMemories() async {
    final token = getAccessToken();
    if (token == null) throw Exception('Not authenticated');

    final userId = getUserId();
    if (userId == null) throw Exception('User ID not found');

    final response = await http.post(
      Uri.parse('$baseUrl/delete-memories'),
      headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $token',
      },
      body: jsonEncode({'user_id': userId}),
    );

    if (response.statusCode != 200) {
      throw Exception('Failed to delete all memories: ${response.statusCode}');
    }
  }
}
