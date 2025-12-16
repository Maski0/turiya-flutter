import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/foundation.dart';

/// Service to manage background music playback
class BackgroundAudioService {
  static final BackgroundAudioService _instance =
      BackgroundAudioService._internal();
  factory BackgroundAudioService() => _instance;
  BackgroundAudioService._internal();

  final AudioPlayer _audioPlayer = AudioPlayer();
  bool _isInitialized = false;
  bool _isEnabled = true;
  bool _isPlaying = false;

  bool get isEnabled => _isEnabled;
  bool get isPlaying => _isPlaying;

  /// Initialize and start playing background music
  Future<void> initialize() async {
    if (_isInitialized) return;

    try {
      // Set to loop
      await _audioPlayer.setReleaseMode(ReleaseMode.loop);

      // Set volume to 15% (matching web)
      await _audioPlayer.setVolume(0.15);

      // Set source from assets
      await _audioPlayer.setSource(AssetSource('audio/background-music.mp3'));

      _isInitialized = true;

      // Auto-play if enabled
      if (_isEnabled) {
        await play();
      }
    } catch (e) {
      // Handle MissingPluginException gracefully (happens during hot reload)
      debugPrint('❌ Background audio init error: $e');
      // Don't crash the app, just disable background audio
      _isEnabled = false;
    }
  }

  /// Play background music
  Future<void> play() async {
    if (!_isInitialized) {
      await initialize();
    }

    try {
      await _audioPlayer.resume();
      _isPlaying = true;
      _isEnabled = true;
    } catch (e) {
      debugPrint('❌ Background audio play error: $e');
    }
  }

  /// Pause background music
  Future<void> pause() async {
    try {
      await _audioPlayer.pause();
      _isPlaying = false;
    } catch (e) {
      debugPrint('❌ Background audio pause error: $e');
    }
  }

  /// Toggle background music on/off
  Future<void> toggle() async {
    if (_isPlaying) {
      await pause();
      _isEnabled = false;
    } else {
      await play();
      _isEnabled = true;
    }
  }

  /// Lower volume when avatar is speaking (to 5%)
  Future<void> lowerVolume() async {
    try {
      await _audioPlayer.setVolume(0.05);
    } catch (e) {
      debugPrint('❌ Background audio volume error: $e');
    }
  }

  /// Restore normal volume (15%)
  Future<void> restoreVolume() async {
    try {
      await _audioPlayer.setVolume(0.15);
    } catch (e) {
      debugPrint('❌ Background audio volume error: $e');
    }
  }

  /// Dispose the audio player
  Future<void> dispose() async {
    await _audioPlayer.dispose();
    _isInitialized = false;
    _isPlaying = false;
  }
}
