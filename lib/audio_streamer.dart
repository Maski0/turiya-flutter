import 'package:flutter_embed_unity/flutter_embed_unity.dart';
import 'elevenlabs_service.dart';

class AudioStreamer {
  final ElevenLabsService elevenLabsService;

  AudioStreamer(this.elevenLabsService);

  /// Streams audio to Unity for lip-sync playback
  Future<void> streamToUnity(String text) async {
    try {
      // Send start signal to Unity
      sendToUnity("Flutter", "OnAudioChunk", "START");

      int chunkCount = 0;

      // Stream audio chunks from ElevenLabs
      await for (final base64Chunk in elevenLabsService.streamTextToSpeech(text)) {
        chunkCount++;

        // Send chunk to Unity with format: CHUNK|<base64-data>
        sendToUnity("Flutter", "OnAudioChunk", "CHUNK|$base64Chunk");

        // Optional: Add small delay to prevent overwhelming Unity
        // await Future.delayed(const Duration(milliseconds: 10));
      }

      // Send end signal to Unity
      sendToUnity("Flutter", "OnAudioChunk", "END");
    } catch (e) {
      // Send error signal to Unity
      sendToUnity("Flutter", "OnAudioError", e.toString());
      rethrow;
    }
  }
}
