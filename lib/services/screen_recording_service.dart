import 'dart:async';
import 'dart:io';
import 'dart:isolate';
import 'dart:typed_data';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:path_provider/path_provider.dart';
import 'package:ffmpeg_kit_flutter_new/ffmpeg_kit.dart';
import 'package:ffmpeg_kit_flutter_new/return_code.dart';
import 'package:flutter_sound/flutter_sound.dart';
import 'package:permission_handler/permission_handler.dart';

/// Top-level function for isolate to process frames
/// Must be top-level (not a class method) for isolates
Future<void> _frameProcessingIsolateEntryPoint(SendPort sendPort) async {
  final receivePort = ReceivePort();
  sendPort.send(receivePort.sendPort);
  
  await for (final message in receivePort) {
    if (message == 'stop') {
      break;
    }
    
    if (message is Map<String, dynamic>) {
      try {
        final Uint8List imageBytes = message['imageBytes'] as Uint8List;
        final String framePath = message['framePath'] as String;
        
        // Save PNG file (expensive I/O operation, done in background)
        final file = File(framePath);
        await file.writeAsBytes(imageBytes);
        
        // Notify completion
        sendPort.send({'success': true, 'path': framePath});
      } catch (e) {
        sendPort.send({'success': false, 'error': e.toString()});
      }
    }
  }
}

/// Service for managing widget recording functionality
/// Captures widget frames + audio, then uses FFmpeg to create MP4
class ScreenRecordingService {
  static final ScreenRecordingService _instance = ScreenRecordingService._internal();
  factory ScreenRecordingService() => _instance;
  ScreenRecordingService._internal();

  bool _isRecording = false;
  String? _lastRecordingPath;
  GlobalKey? _repaintBoundaryKey;
  Timer? _frameTimer;
  List<String> _framePaths = [];
  int _frameCount = 0;
  final FlutterSoundRecorder _audioRecorder = FlutterSoundRecorder();
  String? _audioPath;
  bool _isRecorderInitialized = false;
  static const int _targetFps = 24; // Target 24 FPS (good balance of speed and smoothness)
  bool _isCapturingFrame = false; // Prevent overlapping frame captures
  String? _framesDirPath; // Store frames directory path
  DateTime? _recordingStartTime; // Track actual recording duration
  DateTime? _audioStartTime; // Track when audio playback actually begins
  int _skippedFrames = 0; // Count skipped frames for diagnostics
  
  // Isolate for parallel frame processing
  Isolate? _frameProcessingIsolate;
  SendPort? _frameProcessingSendPort;
  ReceivePort? _frameProcessingReceivePort;
  int _pendingFrames = 0; // Track frames being processed in isolate
  
  // Processing callback for UI progress indicator
  void Function(String message)? _onProcessingUpdate;

  /// Get recording status
  bool get isRecording => _isRecording;

  /// Get the path of the last recorded video
  String? get lastRecordingPath => _lastRecordingPath;

  /// Set the repaint boundary key for widget capture
  void setRepaintBoundaryKey(GlobalKey key) {
    _repaintBoundaryKey = key;
  }
  
  /// Set processing update callback for UI progress indicator
  /// [callback] - Called with status messages like "Encoding video..." or "Converting audio..."
  void setProcessingCallback(void Function(String message)? callback) {
    _onProcessingUpdate = callback;
  }

  /// Start the frame processing isolate for parallel frame encoding
  Future<void> _startFrameProcessingIsolate() async {
    _frameProcessingReceivePort = ReceivePort();
    _frameProcessingIsolate = await Isolate.spawn(
      _frameProcessingIsolateEntryPoint,
      _frameProcessingReceivePort!.sendPort,
    );
    
    // Get the SendPort from the isolate
    final completer = Completer<SendPort>();
    _frameProcessingReceivePort!.listen((message) {
      if (message is SendPort) {
        completer.complete(message);
      } else if (message is Map<String, dynamic>) {
        // Frame processing completed
        _pendingFrames--;
        if (message['success'] == true) {
          // Frame saved successfully
        } else {
          debugPrint('❌ Frame processing error: ${message['error']}');
        }
      }
    });
    
    _frameProcessingSendPort = await completer.future;
    debugPrint('🚀 Frame processing isolate started');
  }
  
  /// Stop the frame processing isolate
  Future<void> _stopFrameProcessingIsolate() async {
    if (_frameProcessingSendPort != null) {
      _frameProcessingSendPort!.send('stop');
      _frameProcessingSendPort = null;
    }
    
    if (_frameProcessingIsolate != null) {
      _frameProcessingIsolate!.kill(priority: Isolate.immediate);
      _frameProcessingIsolate = null;
    }
    
    if (_frameProcessingReceivePort != null) {
      _frameProcessingReceivePort!.close();
      _frameProcessingReceivePort = null;
    }
    
    debugPrint('🛑 Frame processing isolate stopped');
  }

  /// Start widget recording (captures frames + audio)
  Future<bool> startRecording() async {
    if (_isRecording) {
      debugPrint('Recording is already in progress');
      return false;
    }

    if (_repaintBoundaryKey == null) {
      debugPrint('ERROR: RepaintBoundary key not set');
      return false;
    }

    try {
      debugPrint('Starting widget recording at $_targetFps FPS...');
      
      // Clear previous recording data
      _framePaths.clear();
      _frameCount = 0;
      _skippedFrames = 0;
      _pendingFrames = 0;
      _recordingStartTime = DateTime.now();
      _audioStartTime = null;
      
      // Start frame processing isolate for parallel encoding
      await _startFrameProcessingIsolate();
      
      // Get temp directory for frames
      Directory? tempDir = await getTemporaryDirectory();
      String sessionId = DateTime.now().millisecondsSinceEpoch.toString();
      Directory framesDir = Directory('${tempDir.path}/frames_$sessionId');
      await framesDir.create(recursive: true);
      
      // Initialize and start audio recording (microphone)
      if (!_isRecorderInitialized) {
        await _audioRecorder.openRecorder();
        _isRecorderInitialized = true;
      }
      
      var status = await Permission.microphone.request();
      if (status.isGranted) {
        Directory? recordingsDir = await getRecordingsDirectory();
        _audioPath = '${recordingsDir!.path}/audio_$sessionId.aac';
        await _audioRecorder.startRecorder(
          toFile: _audioPath,
          codec: Codec.aacADTS,
        );
        debugPrint('🎤 Microphone recording started: $_audioPath');
      } else {
        debugPrint('⚠️  WARNING: No microphone permission, recording without audio');
      }
      
      _isRecording = true;
      _framesDirPath = framesDir.path;
      
      // Start capturing frames (non-blocking to prevent overlapping captures)
      int timerIntervalMs = (1000 / _targetFps).round();
      debugPrint('⏱️  Starting frame timer: ${timerIntervalMs}ms interval ($_targetFps FPS target)');
      _frameTimer = Timer.periodic(Duration(milliseconds: timerIntervalMs), (timer) {
        // Skip if previous frame is still being captured
        if (_isCapturingFrame) {
          _skippedFrames++;
          return;
        }
        
        // Start frame capture without blocking timer
        _captureFrameNonBlocking();
      });
      
      debugPrint('✅ Widget recording started successfully');
      return true;
    } catch (e) {
      debugPrint('ERROR starting widget recording: $e');
      _isRecording = false;
      return false;
    }
  }

  /// Non-blocking frame capture (called by timer)
  void _captureFrameNonBlocking() {
    if (_framesDirPath == null) return;
    
    _isCapturingFrame = true;
    _captureFrame(_framesDirPath!).then((_) {
      _isCapturingFrame = false;
      
      // Log progress every 24 frames (once per second at 24 FPS)
      if (_frameCount % 24 == 0 && _frameCount > 0) {
        double elapsedSec = DateTime.now().difference(_recordingStartTime!).inMilliseconds / 1000.0;
        double actualFps = _frameCount / elapsedSec;
        debugPrint('📹 Recording... $_frameCount frames in ${elapsedSec.toStringAsFixed(1)}s (${actualFps.toStringAsFixed(1)} FPS actual, $_skippedFrames skipped)');
      }
    }).catchError((e) {
      _isCapturingFrame = false;
      debugPrint('❌ Error in frame capture: $e');
    });
  }

  /// Capture a single frame from the widget
  Future<void> _captureFrame(String framesDir) async {
    try {
      RenderRepaintBoundary? boundary = _repaintBoundaryKey!.currentContext
          ?.findRenderObject() as RenderRepaintBoundary?;
      
      if (boundary == null) return;
      ui.Image image = await boundary.toImage(pixelRatio: 0.9);
      
      // Convert to PNG bytes (done on UI thread, but quick)
      var byteData = await image.toByteData(format: ui.ImageByteFormat.png);
      image.dispose(); // Free memory immediately
      
      if (byteData == null) return;

      String framePath = '$framesDir/frame_${_frameCount.toString().padLeft(5, '0')}.png';
      
      // Send frame data to isolate for file I/O (expensive operation)
      // This prevents blocking the UI thread
      if (_frameProcessingSendPort != null) {
        _pendingFrames++;
        _frameProcessingSendPort!.send({
          'imageBytes': byteData.buffer.asUint8List(),
          'framePath': framePath,
        });
        
        _framePaths.add(framePath);
        _frameCount++;
      }
    } catch (e) {
      debugPrint('Error capturing frame: $e');
    }
  }

  /// Stop recording and create MP4 video
  Future<String?> stopRecording() async {
    debugPrint('stopRecording called, _isRecording=$_isRecording');
    
    if (!_isRecording) {
      debugPrint('ERROR: No recording in progress');
      return null;
    }

    try {
      debugPrint('Stopping widget recording...');
      
      // Stop frame capture
      _frameTimer?.cancel();
      _frameTimer = null;
      _isRecording = false;
      
      // Wait for any in-progress frame capture to complete
      int waitCount = 0;
      while (_isCapturingFrame && waitCount < 50) {
        await Future.delayed(Duration(milliseconds: 10));
        waitCount++;
      }
      if (_isCapturingFrame) {
        debugPrint('⚠️  WARNING: Frame capture still in progress after 500ms wait');
      }
      
      // Wait for isolate to finish processing all pending frames
      _onProcessingUpdate?.call('Processing frames...');
      debugPrint('⏳ Waiting for ${_pendingFrames} pending frames to be processed...');
      waitCount = 0;
      while (_pendingFrames > 0 && waitCount < 300) { // Max 3 seconds
        await Future.delayed(Duration(milliseconds: 10));
        waitCount++;
      }
      if (_pendingFrames > 0) {
        debugPrint('⚠️  WARNING: ${_pendingFrames} frames still pending after 3s wait');
      } else {
        debugPrint('✅ All frames processed by isolate');
      }
      
      // Stop the frame processing isolate
      await _stopFrameProcessingIsolate();
      
      // Stop audio recording (microphone)
      if (_isRecorderInitialized) {
        await _audioRecorder.stopRecorder();
        debugPrint('🎤 Microphone recording stopped: $_audioPath');
        
        // Check audio file size/duration
        if (_audioPath != null && File(_audioPath!).existsSync()) {
          final audioSize = await File(_audioPath!).length();
          debugPrint('📦 Audio file size: ${(audioSize / 1024).toStringAsFixed(2)} KB');
        } else {
          debugPrint('⚠️  WARNING: Audio file does not exist or path is null');
        }
      }
      
      // Calculate actual recording duration and FPS
      if (_recordingStartTime == null) {
        debugPrint('❌ ERROR: Recording start time not set');
        return null;
      }
      
      double actualDurationSec = DateTime.now().difference(_recordingStartTime!).inMilliseconds / 1000.0;
      double actualFps = _frameCount / actualDurationSec;
      
      debugPrint('📹 Recording stats:');
      debugPrint('   • Captured: $_frameCount frames');
      debugPrint('   • Duration: ${actualDurationSec.toStringAsFixed(2)}s');
      debugPrint('   • Actual FPS: ${actualFps.toStringAsFixed(2)} (target was $_targetFps)');
      debugPrint('   • Skipped: $_skippedFrames frames (${(_skippedFrames / (_frameCount + _skippedFrames) * 100).toStringAsFixed(1)}%)');
      
      if (_frameCount < 2) {
        debugPrint('❌ ERROR: Not enough frames captured ($_frameCount frames)');
        return null;
      }
      
      // Create video using FFmpeg with ACTUAL fps achieved
      _onProcessingUpdate?.call('Encoding video (high quality)...');
      String? videoPath = await _createVideoFromFrames(actualFps);
      
      // Cleanup frame files
      _onProcessingUpdate?.call('Cleaning up...');
      await _cleanupFrames();
      
      if (videoPath != null) {
        _lastRecordingPath = videoPath;
        _onProcessingUpdate?.call('Done! Video saved');
        debugPrint('Video created successfully: $videoPath');
      } else {
        _onProcessingUpdate?.call('Failed to create video');
      }
      
      return videoPath;
    } catch (e, stackTrace) {
      debugPrint('❌ ERROR stopping widget recording: $e');
      debugPrint('Stack trace: $stackTrace');
      _isRecording = false;
      
      // Ensure cleanup happens even on error
      try {
        await _stopFrameProcessingIsolate();
        await _cleanupFrames();
      } catch (cleanupError) {
        debugPrint('❌ Error during error cleanup: $cleanupError');
      }
      
      return null;
    }
  }

  /// Create MP4 video from captured frames and audio using FFmpeg
  /// [actualFps] - The actual frame rate achieved during recording
  Future<String?> _createVideoFromFrames(double actualFps) async {
    try {
      if (_framePaths.isEmpty) return null;
      
      Directory? recordingsDir = await getRecordingsDirectory();
      if (recordingsDir == null) return null;
      
      String outputPath = '${recordingsDir.path}/turiya_recording_${DateTime.now().millisecondsSinceEpoch}.mp4';
      String firstFramePath = _framePaths.first;
      String framePattern = firstFramePath.replaceAll(RegExp(r'frame_\d+\.png'), 'frame_%05d.png');
      
      String ffmpegCommand;
      
      // Check audio file status
      if (_audioPath != null) {
        bool audioExists = File(_audioPath!).existsSync();
        debugPrint('🎬 Audio file path: $_audioPath');
        debugPrint('🎬 Audio file exists: $audioExists');
        if (audioExists) {
          final audioSize = await File(_audioPath!).length();
          debugPrint('🎬 Audio file size: ${(audioSize / 1024).toStringAsFixed(2)} KB');
        }
      } else {
        debugPrint('🎬 No audio file - creating video without audio');
      }
      
      if (_audioPath != null && File(_audioPath!).existsSync()) {
        // Calculate audio delay for sync
        double audioDelaySeconds = 0.0;
        if (_audioStartTime != null && _recordingStartTime != null) {
          audioDelaySeconds = _audioStartTime!.difference(_recordingStartTime!).inMilliseconds / 1000.0;
          debugPrint('📊 Audio started ${audioDelaySeconds.toStringAsFixed(2)}s after recording - will delay audio by this amount');
        }
        
        // Combine frames + audio with HIGH QUALITY and PROPER SYNC
        // -framerate: input frame rate (actual FPS achieved)
        // -i: input video frames
        // -itsoffset: POSITIVE value delays the audio stream to sync with video
        //             If audio started 1.5s late, we delay it by +1.5s in the final video
        // -i: input audio file
        // -vf: video filters - pad to even dimensions + slight sharpening for crisp output
        // -c:v libx264: H.264 video codec
        // -preset slow: higher quality encoding (trades processing time for quality)
        // -crf 15: near-lossless quality (lower = better, 18 = high, 23 = default, 15 = near-lossless)
        // -pix_fmt yuv420p: compatibility with all players
        // -c:a aac: AAC audio codec
        // -b:a 256k: high audio bitrate
        // -fps_mode cfr: constant frame rate (replaces deprecated -vsync)
        // -r: output frame rate
        String audioOffset = audioDelaySeconds.toStringAsFixed(2);
        ffmpegCommand = '-framerate $actualFps -i "$framePattern" -itsoffset $audioOffset -i "$_audioPath" -vf "pad=ceil(iw/2)*2:ceil(ih/2)*2,unsharp=5:5:0.5:5:5:0.0" -c:v libx264 -preset slow -crf 15 -pix_fmt yuv420p -c:a aac -b:a 256k -fps_mode cfr -r $actualFps "$outputPath"';
      } else {
        // Video only (no audio) - high quality with even dimensions + sharpening
        ffmpegCommand = '-framerate $actualFps -i "$framePattern" -vf "pad=ceil(iw/2)*2:ceil(ih/2)*2,unsharp=5:5:0.5:5:5:0.0" -c:v libx264 -preset slow -crf 15 -pix_fmt yuv420p -r $actualFps -fps_mode cfr "$outputPath"';
      }
      
      debugPrint('Running FFmpeg command: $ffmpegCommand');
      
      final session = await FFmpegKit.execute(ffmpegCommand);
      final returnCode = await session.getReturnCode();
      
      if (ReturnCode.isSuccess(returnCode)) {
        final fileSize = await File(outputPath).length();
        debugPrint('Video created: $outputPath (${(fileSize / 1024 / 1024).toStringAsFixed(2)} MB)');
        return outputPath;
      } else {
        final output = await session.getOutput();
        debugPrint('FFmpeg failed: $output');
        return null;
      }
    } catch (e) {
      debugPrint('ERROR creating video: $e');
      return null;
    }
  }

  /// Cleanup temporary frame files
  Future<void> _cleanupFrames() async {
    try {
      // Delete individual frame files
      for (String framePath in _framePaths) {
        File file = File(framePath);
        if (await file.exists()) {
          await file.delete();
        }
      }
      
      // Delete audio file if it exists
      if (_audioPath != null) {
        File audioFile = File(_audioPath!);
        if (await audioFile.exists()) {
          await audioFile.delete();
        }
      }
      
      // Delete the frames directory itself
      if (_framesDirPath != null) {
        Directory framesDir = Directory(_framesDirPath!);
        if (await framesDir.exists()) {
          await framesDir.delete(recursive: true);
          debugPrint('🗑️  Deleted frames directory: $_framesDirPath');
        }
      }
      
      // Clear all state variables to prevent memory leaks
      _framePaths.clear();
      _frameCount = 0;
      _skippedFrames = 0;
      _pendingFrames = 0;
      _recordingStartTime = null;
      _audioStartTime = null;
      _audioPath = null;
      _framesDirPath = null;
      _isCapturingFrame = false;
      
      debugPrint('✅ Cleanup completed - all state reset');
    } catch (e) {
      debugPrint('❌ Error during cleanup: $e');
    }
  }

  /// Called when recording completes with the file path
  void onRecordingComplete(String filePath) {
    _lastRecordingPath = filePath;
    debugPrint('Recording saved to: $filePath');
  }
  
  /// Dispose of the service and cleanup all resources
  Future<void> dispose() async {
    debugPrint('🧹 Disposing ScreenRecordingService...');
    
    // Stop any active recording
    if (_isRecording) {
      _frameTimer?.cancel();
      _frameTimer = null;
      _isRecording = false;
    }
    
    // Stop isolate
    await _stopFrameProcessingIsolate();
    
    // Close audio recorder
    if (_isRecorderInitialized) {
      try {
        await _audioRecorder.closeRecorder();
        _isRecorderInitialized = false;
        debugPrint('🎤 Audio recorder closed');
      } catch (e) {
        debugPrint('⚠️  Error closing audio recorder: $e');
      }
    }
    
    // Cleanup any remaining files
    await _cleanupFrames();
    
    debugPrint('✅ ScreenRecordingService disposed');
  }

  /// Get the directory where recordings are saved
  Future<Directory?> getRecordingsDirectory() async {
    try {
      if (Platform.isAndroid) {
        Directory? externalDir = await getExternalStorageDirectory();
        if (externalDir != null) {
          Directory recordingsDir = Directory('${externalDir.path}/Recordings');
          if (!await recordingsDir.exists()) {
            await recordingsDir.create(recursive: true);
          }
          return recordingsDir;
        }
      } else if (Platform.isIOS) {
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
