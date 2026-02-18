import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/foundation.dart';
import 'package:livekit_client/livekit_client.dart';
import '../unity_stub.dart';  // Temporarily replaces flutter_embed_unity for simulator testing

/// Agent state enum for UI updates
enum AgentState {
  disconnected,
  connecting,
  listening,
  thinking,
  speaking,
}

/// Check if agent is ready to accept messages
bool isAgentAvailable(AgentState state) {
  return state == AgentState.listening ||
      state == AgentState.thinking ||
      state == AgentState.speaking;
}

/// Service for managing LiveKit voice connections
/// Handles real-time voice communication with the Krishna AI agent
/// Streams PCM audio to Unity for lip-sync
class LiveKitService {
  Room? _room;
  LocalParticipant? _localParticipant;
  EventsListener<RoomEvent>? _roomListener;

  // Audio handling
  LocalAudioTrack? _localAudioTrack;
  bool _isMicrophoneEnabled = false;

  // Agent state tracking
  AgentState _currentState = AgentState.disconnected;
  bool _isAgentConnected = false;
  String? _agentIdentity;

  // Message buffering (like web frontend)
  final List<String> _messageBuffer = [];

  // Audio playback tracking
  int _totalAudioBytes = 0;
  Timer? _audioPlaybackTimer;
  String? _activeRespondingAgent;

  // Timeouts
  Timer? _thinkingTimeout;
  Timer? _connectingTimeout;
  static const Duration _thinkingTimeoutDuration = Duration(seconds: 30);
  static const Duration _connectingTimeoutDuration = Duration(seconds: 15);

  // Callbacks
  Function(Uint8List audioData)? onAudioReceived;
  Function(String state)? onConnectionStateChanged;
  Function(String error)? onError;
  Function()? onAgentConnected;
  Function()? onAgentDisconnected;
  Function(bool isSpeaking)? onAgentSpeakingChanged;
  Function(String message)? onMessageReceived;
  Function(String transcription)? onUserTranscription;
  Function(AgentState state)? onAgentStateChanged;

  // State getters
  bool get isConnected => _room?.connectionState == ConnectionState.connected;
  bool get isMicrophoneEnabled => _isMicrophoneEnabled;
  AgentState get currentState => _currentState;
  bool get isAgentConnected => _isAgentConnected;
  String? get agentIdentity => _agentIdentity;
  bool get isAgentReady => isAgentAvailable(_currentState);
  Room? get room => _room;

  /// Force audio output to speaker (not earpiece)
  /// This must be called AFTER LiveKit connects since LiveKit changes audio session
  Future<void> _forceSpeakerOutput() async {
    try {
      if (Platform.isIOS || Platform.isAndroid) {
        // Use LiveKit's Hardware class to set speaker output
        await Hardware.instance.setSpeakerphoneOn(true);
        debugPrint('🔊 Forced audio output to speaker');
      }
    } catch (e) {
      debugPrint('⚠️ Error forcing speaker output: $e');
    }
  }

  /// Connect to LiveKit room with the provided connection details
  Future<bool> connect({
    required String serverUrl,
    required String token,
    required String roomName,
    String? threadId,
    String? userId,
  }) async {
    try {
      _updateState(AgentState.connecting);
      onConnectionStateChanged?.call('connecting');

      // Create room with audio options
      _room = Room(
        roomOptions: const RoomOptions(
          adaptiveStream: true,
          dynacast: true,
          defaultAudioPublishOptions: AudioPublishOptions(
            name: 'user_audio',
          ),
          defaultAudioCaptureOptions: AudioCaptureOptions(
            echoCancellation: true,
            noiseSuppression: true,
            autoGainControl: true,
          ),
          defaultAudioOutputOptions: AudioOutputOptions(
            speakerOn: true,
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

      // Set participant attributes for thread/user tracking
      // Agent uses these to maintain conversation context
      if (threadId != null || userId != null) {
        final attributes = <String, String>{};
        if (threadId != null) attributes['thread_id'] = threadId;
        if (userId != null) attributes['user_id'] = userId;
        _localParticipant?.setAttributes(attributes);
        debugPrint('✅ Set participant attributes: $attributes');
      }

      // Mic defaults to disabled
      await setMicrophoneEnabled(false);

      debugPrint('✅ LiveKit: Connected to room $roomName');
      debugPrint('⏳ Waiting for agent to join the room...');

      // Force speaker output after connection (LiveKit defaults to earpiece)
      await _forceSpeakerOutput();

      // Log all remote participants for debugging
      debugPrint(
          '🔍 Remote participants in room: ${_room!.remoteParticipants.length}');
      for (final participant in _room!.remoteParticipants.values) {
        debugPrint('   👤 Participant: ${participant.identity}');
        debugPrint('      Attributes: ${participant.attributes}');
        debugPrint(
            '      Track publications: ${participant.trackPublications.length}');
        for (final pub in participant.trackPublications.values) {
          debugPrint(
              '         Track: ${pub.kind} - ${pub.source} - subscribed: ${pub.subscribed}');
        }
      }

      // Check if agent is already in room
      for (final participant in _room!.remoteParticipants.values) {
        if (_isAgent(participant)) {
          debugPrint('🤖 Agent already in room: ${participant.identity}');
          _isAgentConnected = true;
          _agentIdentity = participant.identity;
          _connectingTimeout?.cancel();
          _updateState(AgentState.listening);
          onConnectionStateChanged?.call('connected');
          onAgentConnected?.call();
          return true;
        }
      }

      // Start connecting timeout
      _connectingTimeout?.cancel();
      _connectingTimeout = Timer(_connectingTimeoutDuration, () {
        if (_currentState == AgentState.connecting && !_isAgentConnected) {
          debugPrint(
              '⏰ Connection timeout! Agent did not join in ${_connectingTimeoutDuration.inSeconds}s');
          onError?.call('Connection timeout - agent not available');
          _updateState(AgentState.disconnected);
          onConnectionStateChanged?.call('disconnected');
        }
      });

      return true;
    } catch (e) {
      debugPrint('❌ LiveKit connection error: $e');
      _connectingTimeout?.cancel();
      onError?.call('Failed to connect: $e');
      _updateState(AgentState.disconnected);
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
        _updateState(AgentState.disconnected);
        onConnectionStateChanged?.call('disconnected');
        _cleanup();
      })
      ..on<RoomReconnectingEvent>((event) {
        debugPrint('🔄 LiveKit: Reconnecting...');
        onConnectionStateChanged?.call('reconnecting');
      })
      ..on<RoomReconnectedEvent>((event) async {
        debugPrint('✅ LiveKit: Reconnected');
        onConnectionStateChanged?.call('connected');
        // Re-force speaker after reconnection
        await _forceSpeakerOutput();
      })
      ..on<ParticipantConnectedEvent>((event) async {
        debugPrint(
            '👤 LiveKit: Participant connected: ${event.participant.identity}');
        if (_isAgent(event.participant)) {
          debugPrint('🤖 Agent connected!');
          _isAgentConnected = true;
          _agentIdentity = event.participant.identity;
          _connectingTimeout?.cancel();
          _updateState(AgentState.listening);
          onConnectionStateChanged?.call('connected');
          onAgentConnected?.call();
          // Re-force speaker when agent connects
          await _forceSpeakerOutput();
        }
      })
      ..on<ParticipantDisconnectedEvent>((event) {
        debugPrint(
            '👤 LiveKit: Participant disconnected: ${event.participant.identity}');
        if (_isAgent(event.participant)) {
          _isAgentConnected = false;
          _agentIdentity = null;
          onAgentDisconnected?.call();
        }
      })
      ..on<ParticipantAttributesChanged>((event) {
        // Handle agent state changes via lk.agent.state attribute
        if (_isAgent(event.participant)) {
          final agentState = event.participant.attributes['lk.agent.state'];
          debugPrint(
              '🤖 Agent attribute changed: lk.agent.state = $agentState');
          if (agentState != null) {
            switch (agentState) {
              case 'thinking':
                _updateState(AgentState.thinking);
                break;
              case 'speaking':
                _updateState(AgentState.speaking);
                break;
              case 'listening':
                _updateState(AgentState.listening);
                break;
            }
          }
        }
      })
      ..on<DataReceivedEvent>((event) {
        _handleDataReceived(event);
      })
      ..on<TrackSubscribedEvent>((event) async {
        debugPrint(
            '🎵 LiveKit: Track subscribed: ${event.track.kind} from ${event.participant.identity}');
        debugPrint(
            '   Track details: source=${event.publication.source}, sid=${event.track.sid}');
        // Stop WebRTC audio playback - Unity plays audio via PCM data channel
        if (event.track is RemoteAudioTrack && _isAgent(event.participant)) {
          try {
            final audioTrack = event.track as RemoteAudioTrack;
            await audioTrack.stop();
            debugPrint(
                '✅ Stopped WebRTC audio track - Unity will play via PCM');
          } catch (e) {
            debugPrint('⚠️ Error stopping audio track: $e');
          }
        }
      })
      ..on<TrackPublishedEvent>((event) async {
        debugPrint(
            '📢 Track PUBLISHED: kind=${event.publication.kind}, source=${event.publication.source}, from=${event.participant.identity}');
        // Unsubscribe from audio tracks to prevent WebRTC audio
        if (event.publication.kind == TrackType.AUDIO) {
          debugPrint(
              '🔇 Audio track published - unsubscribing from WebRTC audio');
          try {
            await event.publication.unsubscribe();
          } catch (e) {
            debugPrint('⚠️ Error unsubscribing: $e');
          }
        }
      })
      ..on<TrackUnpublishedEvent>((event) {
        debugPrint(
            '📤 Track UNPUBLISHED: kind=${event.publication.kind}, from=${event.participant.identity}');
      })
      ..on<ActiveSpeakersChangedEvent>((event) {
        bool isAgentSpeaking = false;
        bool isUserSpeaking = false;

        for (final p in event.speakers) {
          if (p is RemoteParticipant && _isAgent(p)) {
            isAgentSpeaking = true;
          } else if (p is LocalParticipant) {
            isUserSpeaking = true;
          }
        }

        if (isAgentSpeaking && !isUserSpeaking) {
          _updateState(AgentState.speaking);
          onAgentSpeakingChanged?.call(true);
        } else if (isUserSpeaking && _currentState == AgentState.speaking) {
          // User interrupted - handle it
          debugPrint('🛑 User interruption detected');
          _handleInterruption();
        } else if (!isAgentSpeaking && !isUserSpeaking) {
          // Don't auto-transition to thinking here - rely on transcription events
          // This prevents false pondering after agent finishes speaking
          onAgentSpeakingChanged?.call(false);
        }
      })
      ..on<TranscriptionEvent>((event) {
        // Handle transcriptions from both user and agent
        if (event.participant is LocalParticipant) {
          // User's speech-to-text (show in input field)
          for (final segment in event.segments) {
            final text = segment.text.trim();
            if (text.isNotEmpty) {
              debugPrint(
                  '🎤 User transcription: "$text" (final: ${segment.isFinal})');
              onUserTranscription?.call(text);

              // When user's final transcription is received, transition to thinking/pondering
              if (segment.isFinal && _currentState != AgentState.speaking) {
                debugPrint(
                    '🤔 User finished speaking - showing pondering state');
                _updateState(AgentState.thinking);
              }
            }
          }
        } else if (event.participant is RemoteParticipant &&
            _isAgent(event.participant)) {
          // Agent's speech-to-text (for chat history)
          for (final segment in event.segments) {
            final text = segment.text.trim();
            if (text.isNotEmpty && segment.isFinal) {
              debugPrint('🤖 Agent transcription: "$text"');
              onMessageReceived?.call(text);
            }
          }
        }
      });

    // Check for existing participants
    for (final participant in _room!.remoteParticipants.values) {
      if (_isAgent(participant)) {
        _isAgentConnected = true;
        _agentIdentity = participant.identity;
        _connectingTimeout?.cancel();
        _updateState(AgentState.listening);
        onAgentConnected?.call();
        break;
      }
    }
  }

  /// Handle incoming data messages
  void _handleDataReceived(DataReceivedEvent event) {
    final topic = event.topic;
    final participantIdentity = event.participant?.identity ?? 'unknown';

    // Log ALL data received for debugging
    debugPrint(
        '📨 DATA RECEIVED - Topic: "$topic", From: $participantIdentity, Length: ${event.data.length} bytes');

    // Try to decode and log first 100 chars for debugging
    try {
      final decoded = utf8.decode(event.data);
      final preview =
          decoded.length > 100 ? '${decoded.substring(0, 100)}...' : decoded;
      debugPrint('📨 DATA CONTENT: $preview');
    } catch (_) {
      debugPrint('📨 DATA CONTENT: [binary data, ${event.data.length} bytes]');
    }

    // Handle chat messages (text responses)
    if (topic == 'lk.chat' || topic == 'chat') {
      try {
        final data = utf8.decode(event.data);
        debugPrint('📩 Chat message: $data');
        onMessageReceived?.call(data);
      } catch (e) {
        debugPrint('❌ Error decoding chat message: $e');
      }
    }
    // Handle PCM audio for Unity lip-sync
    else if (topic == 'audio_pcm') {
      debugPrint('🎵 AUDIO_PCM topic received! Processing...');
      final audioData = event.data is Uint8List
          ? event.data as Uint8List
          : Uint8List.fromList(event.data);
      _handleAudioPcm(audioData, participantIdentity);
    } else {
      debugPrint('⚠️ Unknown/unhandled topic: "$topic"');
    }
  }

  /// Handle PCM audio chunks for Unity lip-sync
  void _handleAudioPcm(Uint8List data, String senderIdentity) {
    try {
      final dataStr = utf8.decode(data);

      debugPrint(
          '🎵 Audio PCM from: $senderIdentity, data: ${dataStr.length > 20 ? dataStr.substring(0, 20) + "..." : dataStr}');

      // Only process from agents
      if (!senderIdentity.contains('agent') &&
          !senderIdentity.startsWith('turiya')) {
        debugPrint('⚠️ Ignoring audio from non-agent: $senderIdentity');
        return;
      }

      // Lock onto first responding agent
      if (dataStr == 'START') {
        if (_activeRespondingAgent == null) {
          _activeRespondingAgent = senderIdentity;
          debugPrint('🎯 Locked onto agent: $senderIdentity');
        } else if (_activeRespondingAgent != senderIdentity) {
          return; // Ignore other agents
        }
        _totalAudioBytes = 0;
        _audioPlaybackTimer?.cancel();
        if (_currentState != AgentState.speaking) {
          _updateState(AgentState.speaking);
        }
      } else if (_activeRespondingAgent != null &&
          senderIdentity != _activeRespondingAgent) {
        return; // Ignore other agents
      }

      // Forward to Unity for lip-sync
      sendToUnity("Flutter", "OnAudioChunk", dataStr);

      if (dataStr.startsWith('CHUNK|')) {
        final base64Data = dataStr.substring(6);
        try {
          final bytes = base64Decode(base64Data);
          _totalAudioBytes += bytes.length;
        } catch (_) {}
      } else if (dataStr.startsWith('END|') || dataStr == 'END') {
        final totalBytes = dataStr.startsWith('END|')
            ? int.tryParse(dataStr.substring(4)) ?? _totalAudioBytes
            : _totalAudioBytes;

        debugPrint('🏁 Audio END - $totalBytes bytes');

        // Calculate playback duration
        const int sampleRate = 22050;
        const int bytesPerSample = 2;
        final totalSamples = totalBytes ~/ bytesPerSample;
        final audioDurationSeconds = totalSamples / sampleRate;

        // Timer to transition to listening after playback
        final playbackDuration =
            Duration(milliseconds: (audioDurationSeconds * 1000).toInt() + 500);

        _audioPlaybackTimer = Timer(playbackDuration, () {
          debugPrint('🎵 Playback finished - transitioning to listening');
          _activeRespondingAgent = null;
          if (_currentState == AgentState.speaking) {
            _updateState(AgentState.listening);
          }
        });
      }
    } catch (e) {
      debugPrint('❌ Error processing PCM audio: $e');
    }
  }

  /// Check if participant is the AI agent
  bool _isAgent(Participant participant) {
    final identity = participant.identity;
    return identity.contains('agent') || identity.startsWith('turiya');
  }

  /// Enable/disable microphone
  Future<void> setMicrophoneEnabled(bool enabled) async {
    if (_room == null || _localParticipant == null) {
      debugPrint('⚠️ LiveKit: Cannot set mic - not connected');
      return;
    }

    try {
      debugPrint('🎤 LiveKit: Setting microphone to $enabled...');
      await _localParticipant!.setMicrophoneEnabled(enabled);
      _isMicrophoneEnabled = enabled;
      debugPrint('✅ LiveKit: Microphone ${enabled ? "enabled" : "disabled"}');
      debugPrint(
          '📊 LiveKit: Local tracks count: ${_localParticipant!.trackPublications.length}');

      // Log all local tracks
      for (final pub in _localParticipant!.trackPublications.values) {
        debugPrint(
            '   Track: ${pub.kind} - ${pub.source} - subscribed: ${pub.subscribed}');
      }

      // Re-force speaker output after mic change (mic can affect audio routing on iOS)
      await _forceSpeakerOutput();
    } catch (e) {
      debugPrint('❌ LiveKit: Microphone error: $e');
      onError?.call('Microphone error: $e');
    }
  }

  /// Toggle microphone on/off
  Future<void> toggleMicrophone() async {
    await setMicrophoneEnabled(!_isMicrophoneEnabled);
  }

  /// Send text message via LiveKit (for chat-audio mode)
  Future<void> sendMessage(String text) async {
    if (_room == null || !isConnected) {
      debugPrint('⚠️ LiveKit: Cannot send message - not connected');
      return;
    }

    if (isAgentReady) {
      await _sendMessageInternal(text);
    } else {
      debugPrint('⏳ Agent not ready, buffering message');
      _messageBuffer.add(text);
    }
  }

  Future<void> _sendMessageInternal(String text) async {
    try {
      debugPrint('📤 Sending text via LiveKit: "$text"');
      await _localParticipant?.sendText(
        text,
        options: SendTextOptions(topic: 'lk.chat'),
      );
      debugPrint('✅ Text sent via LiveKit');
    } catch (e) {
      debugPrint('❌ Error sending text: $e');
      rethrow;
    }
  }

  /// Process buffered messages when agent becomes ready
  Future<void> _processMessageBuffer() async {
    if (!isAgentReady || _messageBuffer.isEmpty) return;

    debugPrint(
        '📬 Agent ready! Processing ${_messageBuffer.length} buffered message(s)');
    final bufferedMessages = List<String>.from(_messageBuffer);
    _messageBuffer.clear();

    for (final message in bufferedMessages) {
      try {
        await _sendMessageInternal(message);
      } catch (e) {
        debugPrint('❌ Error sending buffered message: $e');
      }
    }
  }

  /// Send interrupt command to agent
  Future<void> sendInterrupt() async {
    if (_room == null || _localParticipant == null) return;

    try {
      await _localParticipant!.publishData(
        Uint8List.fromList(utf8.encode('interrupt')),
        topic: 'interrupt',
        reliable: true,
      );
      debugPrint('🛑 Sent interrupt command');
    } catch (e) {
      debugPrint('⚠️ Failed to send interrupt: $e');
    }
  }

  /// Handle user interruption
  Future<void> _handleInterruption() async {
    _audioPlaybackTimer?.cancel();
    _activeRespondingAgent = null;

    // Stop Unity audio
    sendToUnity("Flutter", "OnAudioChunk", "END");

    // Send interrupt to agent
    await sendInterrupt();

    _updateState(AgentState.listening);
    onAgentSpeakingChanged?.call(false);
  }

  /// Update agent state
  void _updateState(AgentState state) {
    final oldState = _currentState;
    _currentState = state;
    onAgentStateChanged?.call(state);

    debugPrint('🤖 Agent state: $oldState → $state');

    // Process buffered messages when agent becomes ready
    if (!isAgentAvailable(oldState) && isAgentAvailable(state)) {
      _processMessageBuffer();
    }

    // Handle timeouts
    _thinkingTimeout?.cancel();
    if (state == AgentState.thinking) {
      _thinkingTimeout = Timer(_thinkingTimeoutDuration, () {
        if (_currentState == AgentState.thinking) {
          debugPrint('⏰ Thinking timeout!');
          // Don't update state here - the error handler will disconnect
          onError?.call('Response timeout - please try again');
        }
      });
    }
  }

  /// Disconnect from the room
  Future<void> disconnect() async {
    debugPrint('🔌 LiveKit: Disconnecting...');
    _connectingTimeout?.cancel();
    _thinkingTimeout?.cancel();
    _audioPlaybackTimer?.cancel();
    await _cleanup();
    await _room?.disconnect();
    _room = null;
    _updateState(AgentState.disconnected);
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
    _isAgentConnected = false;
    _agentIdentity = null;
    _activeRespondingAgent = null;
    _messageBuffer.clear();
    _roomListener?.dispose();
    _roomListener = null;
  }

  /// Dispose the service
  void dispose() {
    _connectingTimeout?.cancel();
    _thinkingTimeout?.cancel();
    _audioPlaybackTimer?.cancel();
    disconnect();
  }
}
