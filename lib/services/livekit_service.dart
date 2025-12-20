import 'dart:async';
import 'dart:typed_data';
import 'package:flutter/foundation.dart';
import 'package:livekit_client/livekit_client.dart';

/// Service for managing LiveKit voice connections
/// Handles real-time voice communication with the Krishna AI agent
class LiveKitService {
  Room? _room;
  LocalParticipant? _localParticipant;
  RemoteParticipant? _remoteParticipant;
  EventsListener<RoomEvent>? _roomListener;

  // Audio handling
  LocalAudioTrack? _localAudioTrack;
  bool _isMicrophoneEnabled = false;

  // Callbacks
  Function(Uint8List audioData)? onAudioReceived;
  Function(String state)? onConnectionStateChanged;
  Function(String error)? onError;
  Function()? onAgentConnected;
  Function()? onAgentDisconnected;
  Function(bool isSpeaking)? onAgentSpeakingChanged;

  // State
  bool get isConnected => _room?.connectionState == ConnectionState.connected;
  bool get isMicrophoneEnabled => _isMicrophoneEnabled;
  String? _currentRoomName;

  /// Connect to LiveKit room with the provided connection details
  Future<bool> connect({
    required String serverUrl,
    required String token,
    required String roomName,
  }) async {
    try {
      onConnectionStateChanged?.call('connecting');

      // Create room with options
      _room = Room(
        roomOptions: const RoomOptions(
          adaptiveStream: true,
          dynacast: true,
          defaultAudioPublishOptions: AudioPublishOptions(
            audioBitrate: AudioPresets.music.maxBitrate,
          ),
        ),
      );

      // Set up room event listener
      _setupRoomListener();

      // Connect to room
      await _room!.connect(
        serverUrl,
        token,
        connectOptions: const ConnectOptions(
          autoSubscribe: true,
        ),
      );

      _localParticipant = _room!.localParticipant;
      _currentRoomName = roomName;

      onConnectionStateChanged?.call('connected');
      debugPrint('🎤 LiveKit: Connected to room $roomName');

      return true;
    } catch (e) {
      debugPrint('❌ LiveKit connection error: $e');
      onError?.call('Failed to connect: $e');
      onConnectionStateChanged?.call('disconnected');
      return false;
    }
  }

  /// Set up room event listeners
  void _setupRoomListener() {
    _roomListener = _room!.createListener();

    _roomListener!
      ..on<RoomDisconnectedEvent>((event) {
        debugPrint('🔌 LiveKit: Disconnected from room');
        onConnectionStateChanged?.call('disconnected');
        _cleanup();
      })
      ..on<ParticipantConnectedEvent>((event) {
        debugPrint(
            '👤 LiveKit: Participant connected: ${event.participant.identity}');
        // Check if this is the agent
        if (_isAgent(event.participant)) {
          _remoteParticipant = event.participant;
          onAgentConnected?.call();
          _subscribeToAgentTracks(event.participant);
        }
      })
      ..on<ParticipantDisconnectedEvent>((event) {
        debugPrint(
            '👤 LiveKit: Participant disconnected: ${event.participant.identity}');
        if (_isAgent(event.participant)) {
          _remoteParticipant = null;
          onAgentDisconnected?.call();
        }
      })
      ..on<TrackSubscribedEvent>((event) {
        debugPrint('🎵 LiveKit: Track subscribed: ${event.track.kind}');
        if (event.track.kind == TrackType.AUDIO &&
            _isAgent(event.participant)) {
          _handleAgentAudioTrack(event.track as RemoteAudioTrack);
        }
      })
      ..on<TrackUnsubscribedEvent>((event) {
        debugPrint('🎵 LiveKit: Track unsubscribed: ${event.track.kind}');
      })
      ..on<ActiveSpeakersChangedEvent>((event) {
        // Check if agent is speaking
        final agentSpeaking = event.speakers.any((p) => _isAgent(p));
        onAgentSpeakingChanged?.call(agentSpeaking);
      })
      ..on<RoomReconnectingEvent>((event) {
        debugPrint('🔄 LiveKit: Reconnecting...');
        onConnectionStateChanged?.call('reconnecting');
      })
      ..on<RoomReconnectedEvent>((event) {
        debugPrint('✅ LiveKit: Reconnected');
        onConnectionStateChanged?.call('connected');
      });

    // Check for existing participants (agent might already be in room)
    for (final participant in _room!.remoteParticipants.values) {
      if (_isAgent(participant)) {
        _remoteParticipant = participant;
        onAgentConnected?.call();
        _subscribeToAgentTracks(participant);
        break;
      }
    }
  }

  /// Check if participant is the AI agent
  bool _isAgent(Participant participant) {
    // Agent identity usually contains 'agent' or is not a UUID
    final identity = participant.identity;
    return identity.contains('agent') ||
        identity.startsWith('turiya') ||
        !_isUuid(identity);
  }

  bool _isUuid(String str) {
    final uuidRegex = RegExp(
      r'^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$',
      caseSensitive: false,
    );
    return uuidRegex.hasMatch(str);
  }

  /// Subscribe to agent's audio tracks
  void _subscribeToAgentTracks(RemoteParticipant participant) {
    for (final trackPub in participant.audioTrackPublications) {
      if (trackPub.track != null) {
        _handleAgentAudioTrack(trackPub.track as RemoteAudioTrack);
      }
    }
  }

  /// Handle incoming audio from agent
  void _handleAgentAudioTrack(RemoteAudioTrack track) {
    debugPrint('🔊 LiveKit: Handling agent audio track');
    // The audio will be played automatically by LiveKit
    // For Unity integration, we need to capture the raw audio
    // This is handled by the AudioFrame listener
  }

  /// Enable/disable microphone
  Future<void> setMicrophoneEnabled(bool enabled) async {
    if (_localParticipant == null) {
      debugPrint('⚠️ LiveKit: Cannot set mic - not connected');
      return;
    }

    try {
      if (enabled && _localAudioTrack == null) {
        // Create and publish audio track
        _localAudioTrack = await LocalAudioTrack.create(
          AudioCaptureOptions(
            echoCancellation: true,
            noiseSuppression: true,
            autoGainControl: true,
          ),
        );
        await _localParticipant!.publishAudioTrack(_localAudioTrack!);
        debugPrint('🎤 LiveKit: Microphone enabled and published');
      } else if (!enabled && _localAudioTrack != null) {
        // Unpublish and dispose audio track
        await _localParticipant!.unpublishTrack(_localAudioTrack!.sid);
        await _localAudioTrack!.dispose();
        _localAudioTrack = null;
        debugPrint('🎤 LiveKit: Microphone disabled');
      }

      _isMicrophoneEnabled = enabled;
    } catch (e) {
      debugPrint('❌ LiveKit: Microphone error: $e');
      onError?.call('Microphone error: $e');
    }
  }

  /// Toggle microphone on/off
  Future<void> toggleMicrophone() async {
    await setMicrophoneEnabled(!_isMicrophoneEnabled);
  }

  /// Send data to the agent via data channel
  Future<void> sendData(String data) async {
    if (_room == null || !isConnected) {
      debugPrint('⚠️ LiveKit: Cannot send data - not connected');
      return;
    }

    try {
      await _localParticipant?.publishData(
        Uint8List.fromList(data.codeUnits),
        reliable: true,
      );
      debugPrint('📤 LiveKit: Sent data to room');
    } catch (e) {
      debugPrint('❌ LiveKit: Send data error: $e');
    }
  }

  /// Disconnect from the room
  Future<void> disconnect() async {
    debugPrint('🔌 LiveKit: Disconnecting...');
    await _cleanup();
    await _room?.disconnect();
    _room = null;
    onConnectionStateChanged?.call('disconnected');
  }

  /// Clean up resources
  Future<void> _cleanup() async {
    if (_localAudioTrack != null) {
      await _localAudioTrack!.dispose();
      _localAudioTrack = null;
    }
    _isMicrophoneEnabled = false;
    _localParticipant = null;
    _remoteParticipant = null;
    _roomListener?.dispose();
    _roomListener = null;
  }

  /// Dispose the service
  void dispose() {
    disconnect();
  }
}
