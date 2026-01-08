import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_screen_recording/flutter_screen_recording.dart';
import 'package:path_provider/path_provider.dart';

/// Service for managing native screen recording using iOS ReplayKit / Android MediaProjection
/// This captures the actual screen content including platform views like Unity
/// Note: Video only - iOS cannot capture app audio without a Broadcast Extension
class ScreenRecordingService {
  static final ScreenRecordingService _instance =
      ScreenRecordingService._internal();
  factory ScreenRecordingService() => _instance;
  ScreenRecordingService._internal();

  bool _isRecording = false;
  String? _lastRecordingPath;

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
    // Not used - video only recording
  }

  /// Set processing update callback for UI progress indicator
  void setProcessingCallback(void Function(String message)? callback) {
    _onProcessingUpdate = callback;
  }

  /// Capture audio chunk - kept for API compatibility
  void captureAudioChunk(String base64AudioChunk) {
    // Not used - video only recording
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

  /// Start native screen recording (video only)
  Future<bool> startRecording() async {
    if (_isRecording) {
      debugPrint('⚠️ Already recording');
      return false;
    }

    try {
      debugPrint('🎬 Starting native screen recording (video only)...');

      final timestamp = DateTime.now().millisecondsSinceEpoch;
      final videoName = 'turiya_recording_$timestamp';

      final started = await FlutterScreenRecording.startRecordScreen(videoName);
      debugPrint('🎬 startRecordScreen returned: $started');

      if (started) {
        _isRecording = true;
        debugPrint('✅ Native screen recording started');
        return true;
      }

      debugPrint('❌ Failed to start native recording');
      return false;
    } catch (e, stack) {
      debugPrint('❌ Error starting screen recording: $e');
      debugPrint('Stack trace: $stack');
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

  /// Stop native screen recording and return the video path
  Future<String?> stopRecording() async {
    if (!_isRecording) {
      debugPrint('⚠️ Not recording');
      return null;
    }

    try {
      debugPrint('🛑 Stopping native screen recording...');
      _safeProcessingUpdate('Saving...');

      final path = await FlutterScreenRecording.stopRecordScreen;

      _isRecording = false;

      if (path.isNotEmpty) {
        _lastRecordingPath = path;
        _safeProcessingUpdate('Saved!');
        debugPrint('✅ Recording saved: $path');
        return path;
      } else {
        _safeProcessingUpdate('Failed');
        debugPrint('❌ No recording path returned');
        return null;
      }
    } catch (e) {
      _isRecording = false;
      debugPrint('❌ Error stopping screen recording: $e');
      _safeProcessingUpdate('Error');
      return null;
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
