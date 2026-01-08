import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_screen_recording/flutter_screen_recording.dart';
import 'package:path_provider/path_provider.dart';

/// Service for managing native screen recording using iOS ReplayKit / Android MediaProjection
/// This captures the actual screen content including platform views like Unity
/// Also buffers audio to merge with video after recording stops
class ScreenRecordingService {
  static final ScreenRecordingService _instance =
      ScreenRecordingService._internal();
  factory ScreenRecordingService() => _instance;
  ScreenRecordingService._internal();

  bool _isRecording = false;
  String? _lastRecordingPath;

  // Audio buffering for merge
  final List<Uint8List> _audioBuffer = [];
  bool _isCapturingAudio = false;

  // Method channel for native audio/video merge
  static const _mergeChannel = MethodChannel('com.turiya/av_merge');

  // Processing callback for UI progress indicator
  void Function(String message)? _onProcessingUpdate;

  /// Get recording status
  bool get isRecording => _isRecording;

  /// Get the path of the last recorded video
  String? get lastRecordingPath => _lastRecordingPath;

  /// These methods are kept for API compatibility but no longer needed
  void setRepaintBoundaryKey(GlobalKey key) {
    // No longer needed - native recording captures entire screen
  }

  void setAudioCaptureMode({required bool internalOnly}) {
    // Native recording handles audio automatically
  }

  /// Set processing update callback for UI progress indicator
  void setProcessingCallback(void Function(String message)? callback) {
    _onProcessingUpdate = callback;
  }

  /// Capture audio chunk for later merging with video
  /// Called from AudioStreamer with base64-encoded PCM data
  void captureAudioChunk(String base64AudioChunk) {
    if (!_isCapturingAudio) return;

    try {
      final bytes = base64Decode(base64AudioChunk);
      _audioBuffer.add(bytes);
      debugPrint(
          '🎵 Captured audio chunk: ${bytes.length} bytes (total chunks: ${_audioBuffer.length})');
    } catch (e) {
      debugPrint('⚠️ Error capturing audio chunk: $e');
    }
  }

  /// Start capturing audio (call before recording starts)
  void startAudioCapture() {
    _audioBuffer.clear();
    _isCapturingAudio = true;
    debugPrint('🎵 Audio capture started');
  }

  /// Stop capturing audio and return total bytes
  int stopAudioCapture() {
    _isCapturingAudio = false;
    final totalBytes =
        _audioBuffer.fold<int>(0, (sum, chunk) => sum + chunk.length);
    debugPrint(
        '🎵 Audio capture stopped. Total: ${_audioBuffer.length} chunks, $totalBytes bytes');
    return totalBytes;
  }

  /// Save buffered audio to a WAV file
  Future<String?> _saveAudioToWav() async {
    if (_audioBuffer.isEmpty) {
      debugPrint('⚠️ No audio to save');
      return null;
    }

    try {
      // Concatenate all audio chunks
      final totalBytes =
          _audioBuffer.fold<int>(0, (sum, chunk) => sum + chunk.length);
      final audioData = Uint8List(totalBytes);
      var offset = 0;
      for (final chunk in _audioBuffer) {
        audioData.setRange(offset, offset + chunk.length, chunk);
        offset += chunk.length;
      }

      // Create WAV header for PCM 24kHz, 16-bit, mono
      final wavHeader = _createWavHeader(audioData.length);

      // Save to temp file
      final tempDir = await getTemporaryDirectory();
      final timestamp = DateTime.now().millisecondsSinceEpoch;
      final wavPath = '${tempDir.path}/audio_$timestamp.wav';

      final file = File(wavPath);
      final wavData = Uint8List(wavHeader.length + audioData.length);
      wavData.setRange(0, wavHeader.length, wavHeader);
      wavData.setRange(wavHeader.length, wavData.length, audioData);
      await file.writeAsBytes(wavData);

      debugPrint('🎵 Audio saved to WAV: $wavPath (${wavData.length} bytes)');
      return wavPath;
    } catch (e) {
      debugPrint('❌ Error saving audio to WAV: $e');
      return null;
    }
  }

  /// Create WAV header for PCM 24kHz, 16-bit, mono
  Uint8List _createWavHeader(int dataSize) {
    const sampleRate = 24000;
    const bitsPerSample = 16;
    const channels = 1;
    const byteRate = sampleRate * channels * bitsPerSample ~/ 8;
    const blockAlign = channels * bitsPerSample ~/ 8;

    final header = ByteData(44);

    // RIFF header
    header.setUint8(0, 0x52); // 'R'
    header.setUint8(1, 0x49); // 'I'
    header.setUint8(2, 0x46); // 'F'
    header.setUint8(3, 0x46); // 'F'
    header.setUint32(4, 36 + dataSize, Endian.little); // File size - 8
    header.setUint8(8, 0x57); // 'W'
    header.setUint8(9, 0x41); // 'A'
    header.setUint8(10, 0x56); // 'V'
    header.setUint8(11, 0x45); // 'E'

    // fmt chunk
    header.setUint8(12, 0x66); // 'f'
    header.setUint8(13, 0x6D); // 'm'
    header.setUint8(14, 0x74); // 't'
    header.setUint8(15, 0x20); // ' '
    header.setUint32(16, 16, Endian.little); // Chunk size
    header.setUint16(20, 1, Endian.little); // Audio format (1 = PCM)
    header.setUint16(22, channels, Endian.little);
    header.setUint32(24, sampleRate, Endian.little);
    header.setUint32(28, byteRate, Endian.little);
    header.setUint16(32, blockAlign, Endian.little);
    header.setUint16(34, bitsPerSample, Endian.little);

    // data chunk
    header.setUint8(36, 0x64); // 'd'
    header.setUint8(37, 0x61); // 'a'
    header.setUint8(38, 0x74); // 't'
    header.setUint8(39, 0x61); // 'a'
    header.setUint32(40, dataSize, Endian.little);

    return header.buffer.asUint8List();
  }

  /// Clear audio buffer
  void clearAudioBuffer() {
    _audioBuffer.clear();
    _isCapturingAudio = false;
    debugPrint('🎵 Audio buffer cleared');
  }

  /// Get documents directory for saving recordings
  Future<Directory?> getRecordingsDirectory() async {
    final Directory appDocDir = await getApplicationDocumentsDirectory();
    final recordingsDir = Directory('${appDocDir.path}/Recordings');
    if (!await recordingsDir.exists()) {
      await recordingsDir.create(recursive: true);
    }
    return recordingsDir;
  }

  /// Start native screen recording (video only) + audio capture
  /// Audio is captured separately and merged after recording stops
  Future<bool> startRecording() async {
    if (_isRecording) {
      debugPrint('⚠️ Already recording');
      return false;
    }

    try {
      debugPrint('🎬 Starting native screen recording + audio capture...');

      // Start audio capture FIRST
      startAudioCapture();

      final timestamp = DateTime.now().millisecondsSinceEpoch;
      final videoName = 'turiya_recording_$timestamp';

      // Record VIDEO ONLY (audio captured separately to avoid earpiece issue)
      final started = await FlutterScreenRecording.startRecordScreen(videoName);
      debugPrint('🎬 startRecordScreen returned: $started');

      if (started) {
        _isRecording = true;
        debugPrint('✅ Native screen recording started (video + audio capture)');
        return true;
      }

      // If video failed, stop audio capture
      stopAudioCapture();
      clearAudioBuffer();
      debugPrint('❌ Failed to start native recording');
      return false;
    } catch (e, stack) {
      debugPrint('❌ Error starting screen recording: $e');
      debugPrint('Stack trace: $stack');
      stopAudioCapture();
      clearAudioBuffer();
      return false;
    }
  }

  /// Safely call the processing update callback
  void _safeProcessingUpdate(String message) {
    try {
      _onProcessingUpdate?.call(message);
    } catch (e) {
      // Ignore errors if widget is disposed
      debugPrint(
          '⚠️ Processing update callback failed (widget may be disposed)');
    }
  }

  /// Stop native screen recording, merge with audio, and return the final video path
  Future<String?> stopRecording() async {
    if (!_isRecording) {
      debugPrint('⚠️ Not recording');
      return null;
    }

    try {
      debugPrint('🛑 Stopping native screen recording...');
      _safeProcessingUpdate('Saving video...');

      // Stop audio capture
      final audioBytes = stopAudioCapture();

      // Stop video recording
      final videoPath = await FlutterScreenRecording.stopRecordScreen;
      _isRecording = false;

      if (videoPath.isEmpty) {
        _safeProcessingUpdate('Failed to save recording');
        debugPrint('❌ No video path returned');
        clearAudioBuffer();
        return null;
      }

      debugPrint('✅ Video saved: $videoPath');

      // If we have audio, merge it with video
      if (audioBytes > 0) {
        _safeProcessingUpdate('Merging audio...');
        debugPrint(
            '🎵 Attempting to merge audio ($audioBytes bytes) with video');

        // Save audio to WAV
        final audioPath = await _saveAudioToWav();
        if (audioPath != null) {
          // Merge using native iOS AVFoundation
          final mergedPath = await _mergeAudioVideo(audioPath, videoPath);
          clearAudioBuffer();

          if (mergedPath != null) {
            _lastRecordingPath = mergedPath;
            _safeProcessingUpdate('Recording saved!');
            debugPrint('✅ Merged recording saved: $mergedPath');

            // Clean up temp files
            _cleanupTempFile(audioPath);
            _cleanupTempFile(videoPath);

            return mergedPath;
          } else {
            debugPrint('⚠️ Merge failed, returning video only');
          }
        }
      } else {
        debugPrint('⚠️ No audio captured, returning video only');
      }

      // Fallback: return video without audio
      _lastRecordingPath = videoPath;
      _safeProcessingUpdate('Recording saved!');
      clearAudioBuffer();
      return videoPath;
    } catch (e) {
      _isRecording = false;
      debugPrint('❌ Error stopping screen recording: $e');
      _safeProcessingUpdate('Error saving recording');
      clearAudioBuffer();
      return null;
    }
  }

  /// Merge audio and video using native iOS AVFoundation
  Future<String?> _mergeAudioVideo(String audioPath, String videoPath) async {
    try {
      debugPrint('🎬 Calling native merge: audio=$audioPath, video=$videoPath');

      final result =
          await _mergeChannel.invokeMethod<String>('mergeAudioVideo', {
        'audioPath': audioPath,
        'videoPath': videoPath,
      });

      if (result != null && result.isNotEmpty) {
        debugPrint('✅ Native merge successful: $result');
        return result;
      } else {
        debugPrint('❌ Native merge returned empty result');
        return null;
      }
    } on PlatformException catch (e) {
      debugPrint('❌ Native merge error: ${e.message}');
      return null;
    } catch (e) {
      debugPrint('❌ Merge error: $e');
      return null;
    }
  }

  /// Clean up temporary file
  void _cleanupTempFile(String path) {
    try {
      final file = File(path);
      if (file.existsSync()) {
        file.deleteSync();
        debugPrint('🗑️ Cleaned up temp file: $path');
      }
    } catch (e) {
      debugPrint('⚠️ Failed to cleanup: $path');
    }
  }

  /// Delete a recording file
  Future<bool> deleteRecording(String path) async {
    try {
      final file = File(path);
      if (await file.exists()) {
        await file.delete();
        debugPrint('🗑️ Recording deleted: $path');
        return true;
      }
      return false;
    } catch (e) {
      debugPrint('❌ Error deleting recording: $e');
      return false;
    }
  }
}
