import 'dart:async';
import 'package:flutter_embed_unity/flutter_embed_unity.dart';
import 'elevenlabs_service.dart';
import 'models/alignment_data.dart';

class AudioStreamer {
  final ElevenLabsService elevenLabsService;

  AudioStreamer(this.elevenLabsService);

  /// Streams audio to Unity for lip-sync playback with real-time alignment data
  /// Uses time-based batching: accumulates 3 seconds worth of audio, sends batch every 2 seconds
  /// [onAlignmentUpdate] callback receives alignment data WHEN chunks are sent to Unity (synchronized)
  /// [onChunkSent] callback fires when each batch is sent (for subtitle sync)
  /// [onAudioStarted] callback fires when Unity ACTUALLY starts playing audio (for precise subtitle timing)
  Future<ConsolidatedAlignment> streamToUnity(
    String text, {
    void Function(AlignmentData)? onAlignmentUpdate,
    void Function()? onChunkSent, // Called when batch is sent to Unity
    void Function()? onAudioStarted, // Called when Unity starts playing (from Unity callback)
  }) async {
    final consolidated = ConsolidatedAlignment();
    
    try {
      // Send start signal to Unity
      print('🎬 Sending START signal to Unity at ${DateTime.now()}');
      sendToUnity("Flutter", "OnAudioChunk", "START");

      int totalChunks = 0;
      int chunksWithAlignment = 0;
      int chunksWithoutAlignment = 0;
      int batchNumber = 0;
      int totalAudioBytes = 0; // Track actual audio bytes for accurate duration
      
      // Batching parameters
      final List<String> currentBatch = [];
      final ConsolidatedAlignment currentBatchAlignment = ConsolidatedAlignment(); // Alignment for current batch
      const int chunksPerBatch = 5; // Send 5 chunks at a time (~1.25s per batch) - smaller, frequent batches
      const int minimumChunksForFirstBatch = 2;
      bool isFirstBatch = true;

      // Stream chunks and batch them based on audio duration
      await for (final audioChunk in elevenLabsService.streamTextToSpeechWithTimestamps(text)) {
        totalChunks++;

        // Store audio chunk in current batch and track total bytes
        if (audioChunk.audioBase64 != null && audioChunk.audioBase64!.isNotEmpty) {
          currentBatch.add(audioChunk.audioBase64!);
          // Calculate actual audio bytes from base64 (base64 is 4/3 the size of original)
          totalAudioBytes += (audioChunk.audioBase64!.length * 3) ~/ 4;
        }

        // Process alignment data
        // NOTE: ElevenLabs sends FULL alignment in FIRST chunk only (for entire message)
        // Subsequent chunks contain only audio - this is expected behavior
        final alignment = audioChunk.bestAlignment;
        if (alignment != null && alignment.isValid) {
          chunksWithAlignment++;
          
          // Add to BOTH consolidated and current batch alignment
          consolidated.addChunk(alignment);
          currentBatchAlignment.addChunk(alignment);
          
          print('📦 Buffered chunk $totalChunks (batch has ${currentBatch.length} chunks, ${alignment.characters.length} chars in this chunk)');
        } else {
          chunksWithoutAlignment++;
          
          // Only warn if first chunk has no alignment (unexpected - subtitles won't work)
          if (totalChunks == 1) {
            print('❌ FIRST chunk has NO alignment - subtitles will NOT work!');
          } else {
            print('📦 Buffered chunk $totalChunks (audio-only, batch has ${currentBatch.length} chunks)');
          }
        }

        // Send batch based on chunk count (not duration, since most chunks have no alignment)
        // For FIRST batch: ensure at least 2 chunks to match Unity's minimumChunksBeforePlaying
        final shouldSendBatch = currentBatch.length >= chunksPerBatch ||
                                (isFirstBatch && currentBatch.length >= minimumChunksForFirstBatch);
        
        if (shouldSendBatch) {
          // Send batches as soon as they're ready - Unity has its own buffering
          // No artificial delays - let Unity manage its buffer
          if (isFirstBatch) {
            print('🎯 First batch ready with ${currentBatch.length} chunks (matches Unity\'s minimum of $minimumChunksForFirstBatch)');
          }
          
          batchNumber++;
          // Calculate approximate duration from PCM bytes (24000 Hz, 16-bit mono = 48000 bytes/sec)
          final batchBytes = currentBatch.fold<int>(0, (sum, chunk) => sum + ((chunk.length * 3) ~/ 4));
          final approxDuration = batchBytes / 48000.0;
          print('📤 Sending batch $batchNumber with ${currentBatch.length} chunks (~${approxDuration.toStringAsFixed(2)}s of audio)');
          
          // THE VALVE: Send audio to Unity AND subtitles to Flutter SIMULTANEOUSLY
          // Both get the SAME data at the SAME time - no delays
          
          // Send all audio chunks in this batch to Unity
          for (int i = 0; i < currentBatch.length; i++) {
            sendToUnity("Flutter", "OnAudioChunk", "CHUNK|${currentBatch[i]}");
          }
          print('✅ Sent ${currentBatch.length} audio chunks to Unity for batch $batchNumber');
          
          // IMMEDIATELY notify Flutter with FULL CUMULATIVE alignment data
          // Subtitles use timestamps from playback start, so they need all data with correct timing
          if (onAlignmentUpdate != null && consolidated.isNotEmpty) {
            onAlignmentUpdate(consolidated.toAlignmentData());
            print('🎬 THE VALVE: Batch $batchNumber sent to Unity AND subtitles (total ${consolidated.characters.length} chars, batch had ${currentBatchAlignment.characters.length})');
          }
          
          // Notify that chunk was sent (optional callback)
          if (onChunkSent != null) {
            onChunkSent();
          }
          
          isFirstBatch = false;
          
          // Reset batch for next round
          currentBatch.clear();
          currentBatchAlignment.clear(); // Clear batch alignment
        }
      }

      // Send any remaining chunks in the final batch (THE VALVE applies here too)
      if (currentBatch.isNotEmpty) {
        batchNumber++;
        // Calculate ACTUAL audio duration from total PCM bytes (not alignment timestamps)
        // PCM 24kHz, mono, 16-bit: 24000 samples/sec * 2 bytes = 48000 bytes/sec
        final actualAudioDuration = totalAudioBytes / 48000.0;
        final alignmentDuration = consolidated.characterEndTimesSeconds.isNotEmpty 
            ? consolidated.characterEndTimesSeconds.last 
            : 0.0;
        final finalBatchBytes = currentBatch.fold<int>(0, (sum, chunk) => sum + ((chunk.length * 3) ~/ 4));
        final finalBatchDuration = finalBatchBytes / 48000.0;
        print('📤 Sending final batch $batchNumber with ${currentBatch.length} chunks (~${finalBatchDuration.toStringAsFixed(2)}s, total: ${actualAudioDuration.toStringAsFixed(2)}s actual PCM, ${alignmentDuration.toStringAsFixed(2)}s from alignment)');
        
        // Send all audio chunks to Unity
        for (int i = 0; i < currentBatch.length; i++) {
          sendToUnity("Flutter", "OnAudioChunk", "CHUNK|${currentBatch[i]}");
        }
        print('✅ Sent ${currentBatch.length} audio chunks to Unity for FINAL batch $batchNumber');
        
        // IMMEDIATELY notify Flutter with FULL CUMULATIVE alignment (final update)
        // Subtitles need all data with correct timestamps from playback start
        if (onAlignmentUpdate != null && consolidated.isNotEmpty) {
          onAlignmentUpdate(consolidated.toAlignmentData());
          print('🎬 THE VALVE: Final batch sent to Unity AND subtitles (total ${consolidated.characters.length} chars, final batch had ${currentBatchAlignment.characters.length})');
        }
        
        // Notify that chunk was sent
        if (onChunkSent != null) {
          onChunkSent();
        }
      }

      // Don't send END here - let main.dart send it after audio finishes playing
      // This prevents race conditions and ensures Unity has processed all chunks
      print('🏁 All chunks sent - $batchNumber batches total (END will be sent after audio finishes)');
      
      print('✅ Streamed $totalChunks chunks in $batchNumber batches, total ${consolidated.characters.length} characters');
      print('📊 Alignment stats: $chunksWithAlignment chunks WITH alignment, $chunksWithoutAlignment audio-only chunks');
      if (chunksWithAlignment == 0) {
        print('❌ WARNING: NO alignment data received - subtitles will NOT work!');
      } else if (chunksWithAlignment < totalChunks) {
        print('ℹ️  Note: ElevenLabs provides full alignment in first chunk(s) only - this is expected');
      }
      
      // Set actual audio duration from PCM bytes (more accurate than alignment timestamps)
      // PCM 24kHz, mono, 16-bit: 24000 samples/sec * 2 bytes = 48000 bytes/sec
      consolidated.actualAudioDurationSeconds = totalAudioBytes / 48000.0;
      final alignmentDuration = consolidated.characterEndTimesSeconds.isNotEmpty 
          ? consolidated.characterEndTimesSeconds.last 
          : 0.0;
      print('⏱️ Audio duration: ${consolidated.actualAudioDurationSeconds.toStringAsFixed(2)}s (actual PCM), ${alignmentDuration.toStringAsFixed(2)}s (from alignment)');
      
      return consolidated;
    } catch (e) {
      // Send error signal to Unity
      sendToUnity("Flutter", "OnAudioError", e.toString());
      rethrow;
    }
  }
}
