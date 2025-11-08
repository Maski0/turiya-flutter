import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_screen_recording/flutter_screen_recording.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:path_provider/path_provider.dart';

/// Service for managing screen recording functionality
/// Uses native screen recording to capture full screen with audio in MP4 format
class ScreenRecordingService {
  static final ScreenRecordingService _instance = ScreenRecordingService._internal();
  factory ScreenRecordingService() => _instance;
  ScreenRecordingService._internal();

  bool _isRecording = false;
  String? _lastRecordingPath;

  /// Get recording status
  bool get isRecording => _isRecording;

  /// Get the path of the last recorded video
  String? get lastRecordingPath => _lastRecordingPath;

  /// Request necessary permissions for screen recording
  Future<bool> requestPermissions() async {
    if (Platform.isAndroid) {
      // Request microphone permission for audio recording
      final micStatus = await Permission.microphone.request();
      
      if (!micStatus.isGranted) {
        debugPrint('Microphone permission denied');
        debugPrint('Note: Recording will continue without audio');
      }
      
      // Return true - screen recording will handle its own permission dialog
      return true;
    } else if (Platform.isIOS) {
      // iOS handles permissions differently
      return true;
    }
    return true;
  }

  /// Start screen recording
  /// 
  /// Returns true if recording started successfully
  Future<bool> startRecording() async {
    if (_isRecording) {
      debugPrint('Recording is already in progress');
      return false;
    }

    try {
      // Request permissions first
      bool hasPermissions = await requestPermissions();
      if (!hasPermissions) {
        debugPrint('Required permissions not granted');
        return false;
      }

      // Get recordings directory
      Directory? dir = await getRecordingsDirectory();
      if (dir == null) {
        debugPrint('ERROR: Failed to get recordings directory');
        return false;
      }

      // Generate filename
      String fileName = 'turiya_recording_${DateTime.now().millisecondsSinceEpoch}';
      String filePath = '${dir.path}/$fileName.mp4';

      debugPrint('Starting screen recording...');
      debugPrint('File path: $filePath');

      // Start recording - this will show system permission dialog on first use
      bool started = await FlutterScreenRecording.startRecordScreen(
        fileName, 
        titleNotification: "Turiya Recording",
        messageNotification: "Recording in progress..."
      );
      
      if (started) {
        _isRecording = true;
        _lastRecordingPath = filePath;
        debugPrint('Screen recording started successfully');
        return true;
      } else {
        debugPrint('ERROR: Failed to start recording');
        return false;
      }
    } catch (e) {
      debugPrint('ERROR starting screen recording: $e');
      return false;
    }
  }

  /// Stop screen recording and save to file
  /// 
  /// Returns the path to the recorded video file, or null if failed
  Future<String?> stopRecording() async {
    debugPrint('stopRecording called, _isRecording=$_isRecording');
    
    if (!_isRecording) {
      debugPrint('ERROR: No recording in progress');
      return null;
    }

    try {
      debugPrint('Stopping screen recording...');
      
      // Stop recording
      String path = await FlutterScreenRecording.stopRecordScreen;
      _isRecording = false;
      
      if (path.isNotEmpty) {
        // Verify file exists
        final file = File(path);
        if (await file.exists()) {
          _lastRecordingPath = path;
          final fileSize = await file.length();
          debugPrint('Screen recording stopped successfully');
          debugPrint('File saved to: $path');
          debugPrint('File size: ${(fileSize / 1024 / 1024).toStringAsFixed(2)} MB');
          return path;
        } else {
          debugPrint('ERROR: Recording file does not exist at: $path');
          return null;
        }
      } else {
        debugPrint('ERROR: Failed to get recording path from plugin');
        return null;
      }
    } catch (e, stackTrace) {
      debugPrint('ERROR stopping screen recording: $e');
      debugPrint('Stack trace: $stackTrace');
      _isRecording = false;
      return null;
    }
  }

  /// Get the directory where recordings are saved
  Future<Directory?> getRecordingsDirectory() async {
    try {
      if (Platform.isAndroid) {
        // On Android, recordings are saved in app's external directory
        Directory? externalDir = await getExternalStorageDirectory();
        if (externalDir != null) {
          Directory recordingsDir = Directory('${externalDir.path}/Recordings');
          if (!await recordingsDir.exists()) {
            await recordingsDir.create(recursive: true);
          }
          return recordingsDir;
        }
      } else if (Platform.isIOS) {
        // On iOS, use the documents directory
        Directory appDocDir = await getApplicationDocumentsDirectory();
        Directory recordingsDir = Directory('${appDocDir.path}/Recordings');
        if (!await recordingsDir.exists()) {
          await recordingsDir.create(recursive: true);
        }
        return recordingsDir;
      }
    } catch (e) {
      debugPrint('ERROR getting recordings directory: $e');
    }
    return null;
  }

  /// Delete a recording file
  Future<bool> deleteRecording(String path) async {
    try {
      File file = File(path);
      if (await file.exists()) {
        await file.delete();
        if (_lastRecordingPath == path) {
          _lastRecordingPath = null;
        }
        debugPrint('Recording deleted: $path');
        return true;
      }
      return false;
    } catch (e) {
      debugPrint('ERROR deleting recording: $e');
      return false;
    }
  }

  /// Get all recordings in the recordings directory
  Future<List<File>> getAllRecordings() async {
    try {
      Directory? recordingsDir = await getRecordingsDirectory();
      if (recordingsDir != null && await recordingsDir.exists()) {
        List<FileSystemEntity> files = recordingsDir.listSync();
        return files
            .whereType<File>()
            .where((file) => file.path.endsWith('.mp4'))
            .toList();
      }
    } catch (e) {
      debugPrint('ERROR getting recordings: $e');
    }
    return [];
  }
}
