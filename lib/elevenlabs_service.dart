import 'dart:convert';
import 'package:http/http.dart' as http;

class ElevenLabsService {
  final String apiKey;
  final String voiceId;

  ElevenLabsService({
    required this.apiKey,
    required this.voiceId,
  });

  /// Streams audio from ElevenLabs API in PCM format
  /// Returns a stream of base64-encoded PCM audio chunks
  Stream<String> streamTextToSpeech(String text) async* {
    final url = Uri.parse(
      'https://api.elevenlabs.io/v1/text-to-speech/$voiceId/stream?output_format=pcm_24000',
    );

    final response = await http.Client().send(
      http.Request('POST', url)
        ..headers.addAll({
          'xi-api-key': apiKey,
          'Content-Type': 'application/json',
        })
        ..body = jsonEncode({
          'text': text,
          'model_id': 'eleven_turbo_v2_5',
          'voice_settings': {
            'stability': 0.5,
            'similarity_boost': 0.75,
          },
        }),
    );

    if (response.statusCode != 200) {
      throw Exception('Failed to generate speech: ${response.statusCode}');
    }

    // Stream the response in chunks
    await for (final chunk in response.stream) {
      // Encode chunk to base64
      final base64Chunk = base64Encode(chunk);
      yield base64Chunk;
    }
  }
}
