import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

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
  double _volume = 0.15; // Default 15%

  static const String _volumeKey = 'background_music_volume';

  bool get isEnabled => _isEnabled;
  bool get isPlaying => _isPlaying;
  double get volume => _volume;

  /// Initialize and start playing background music
  Future<void> initialize() async {
    if (_isInitialized) return;

    try {
      // Load saved volume preference
      final prefs = await SharedPreferences.getInstance();
      _volume = prefs.getDouble(_volumeKey) ?? 0.15;

      // Set to loop
      await _audioPlayer.setReleaseMode(ReleaseMode.loop);

      // Set volume from saved preference
      await _audioPlayer.setVolume(_volume);

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
      debugPrint('🎵 Background music playing');
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

  /// Set volume (0.0 to 1.0)
  Future<void> setVolume(double value) async {
    _volume = value.clamp(0.0, 1.0);
    try {
      await _audioPlayer.setVolume(_volume);
      // Save to preferences
      final prefs = await SharedPreferences.getInstance();
      await prefs.setDouble(_volumeKey, _volume);
      debugPrint(
          '🎵 Background music volume set to: ${(_volume * 100).round()}%');
    } catch (e) {
      debugPrint('❌ Background audio volume error: $e');
    }
  }

  /// Lower volume when avatar is speaking (to 1/3 of current)
  Future<void> lowerVolume() async {
    try {
      await _audioPlayer.setVolume(_volume * 0.33);
    } catch (e) {
      debugPrint('❌ Background audio volume error: $e');
    }
  }

  /// Restore normal volume
  Future<void> restoreVolume() async {
    try {
      await _audioPlayer.setVolume(_volume);
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
