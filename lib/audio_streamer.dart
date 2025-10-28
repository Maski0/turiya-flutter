import 'package:flutter_embed_unity/flutter_embed_unity.dart';
import 'elevenlabs_service.dart';
import 'models/alignment_data.dart';

class AudioStreamer {
  final ElevenLabsService elevenLabsService;

  AudioStreamer(this.elevenLabsService);

  /// Streams audio to Unity for lip-sync playback with real-time alignment data
  /// [onAlignmentUpdate] callback receives consolidated alignment data as chunks arrive
  Future<ConsolidatedAlignment> streamToUnity(
    String text, {
    void Function(AlignmentData)? onAlignmentUpdate,
  }) async {
    final consolidated = ConsolidatedAlignment();
    
    try {
      // Send start signal to Unity
      print('🎬 Sending START signal to Unity at ${DateTime.now()}');
      sendToUnity("Flutter", "OnAudioChunk", "START");

      int chunkCount = 0;

      // Stream audio chunks with timestamps from ElevenLabs
      await for (final audioChunk in elevenLabsService.streamTextToSpeechWithTimestamps(text)) {
        chunkCount++;
        print('📦 Chunk $chunkCount received at ${DateTime.now()}: audioBase64=${audioChunk.audioBase64?.substring(0, 50)}..., hasAlignment=${audioChunk.bestAlignment != null}');

        // Send audio to Unity immediately as it arrives
        if (audioChunk.audioBase64 != null && audioChunk.audioBase64!.isNotEmpty) {
          print('🔊 Sending audio chunk $chunkCount to Unity at ${DateTime.now()} (${audioChunk.audioBase64!.length} bytes)');
          sendToUnity("Flutter", "OnAudioChunk", "CHUNK|${audioChunk.audioBase64}");
          if (chunkCount == 2) {
            print('🎵 Unity should start playing after chunk 2');
          }
        } else {
          print('⚠️ Chunk $chunkCount has no audio data');
        }

        // Process alignment data if available
        final alignment = audioChunk.bestAlignment;
        if (alignment != null && alignment.isValid) {
          // Add to consolidated alignment (normalizes timestamps)
          consolidated.addChunk(alignment);
          
          // Notify callback with updated alignment data
          if (onAlignmentUpdate != null && consolidated.isNotEmpty) {
            onAlignmentUpdate(consolidated.toAlignmentData());
          }
        }
      }

      // Send end signal to Unity
      sendToUnity("Flutter", "OnAudioChunk", "END");
      
      print('✅ Streamed $chunkCount chunks with ${consolidated.characters.length} characters');
      
      return consolidated;
    } catch (e) {
      // Send error signal to Unity
      sendToUnity("Flutter", "OnAudioError", e.toString());
      rethrow;
    }
  }
}
