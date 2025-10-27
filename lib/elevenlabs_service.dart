import 'dart:convert';
import 'package:http/http.dart' as http;
import 'models/alignment_data.dart';

class ElevenLabsService {
  final String backendUrl;
  final String? Function() getAuthToken; // Function to get token dynamically

  ElevenLabsService({
    required this.backendUrl,
    required this.getAuthToken,
  });

  /// Streams audio with timestamps from backend TTS proxy
  /// Backend handles ElevenLabs API call (API key stays secure on server)
  Stream<AudioChunk> streamTextToSpeechWithTimestamps(String text) async* {
    final url = Uri.parse('$backendUrl/tts-stream');

    final headers = {
      'Content-Type': 'application/json',
    };
    
    // Get auth token dynamically at call time
    final authToken = getAuthToken();
    if (authToken != null) {
      headers['Authorization'] = 'Bearer $authToken';
    }

    print('🎙️ TTS Request: $url with ${text.length} chars, auth=${authToken != null}');
    
    final response = await http.Client().send(
      http.Request('POST', url)
        ..headers.addAll(headers)
        ..body = jsonEncode({
          'text': text,
        }),
    );

    print('🎙️ TTS Response: ${response.statusCode}');
    
    if (response.statusCode != 200) {
      throw Exception('Failed to generate speech: ${response.statusCode}');
    }

    // Stream and parse JSON chunks
    String buffer = '';
    int totalBytes = 0;
    int chunksParsed = 0;
    await for (final chunk in response.stream) {
      totalBytes += chunk.length;
      buffer += utf8.decode(chunk);
      
      // Split by newlines to get individual JSON objects
      final lines = buffer.split('\n');
      // Keep the last incomplete line in buffer
      buffer = lines.removeLast();
      
      for (final line in lines) {
        final trimmed = line.trim();
        if (trimmed.isEmpty) continue;
        
        try {
          final json = jsonDecode(trimmed) as Map<String, dynamic>;
          chunksParsed++;
          print('📥 Parsed chunk $chunksParsed: ${json.keys}');
          final audioChunk = AudioChunk.fromJson(json);
          yield audioChunk;
        } catch (e) {
          print('⚠️ Failed to parse TTS chunk: $e');
          print('⚠️ Line was: ${trimmed.substring(0, 100)}...');
          // Continue processing other chunks
        }
      }
    }
    
    print('✅ TTS stream complete: $totalBytes bytes, $chunksParsed chunks');
    
    // Process any remaining data in buffer
    if (buffer.trim().isNotEmpty) {
      try {
        final json = jsonDecode(buffer.trim()) as Map<String, dynamic>;
        final audioChunk = AudioChunk.fromJson(json);
        yield audioChunk;
      } catch (e) {
        print('⚠️ Failed to parse final TTS chunk: $e');
      }
    }
  }
}
