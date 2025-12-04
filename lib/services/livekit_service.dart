import 'dart:async';
import 'dart:convert';
import 'dart:math';
import 'package:http/http.dart' as http;
import 'package:livekit_client/livekit_client.dart';
import 'package:livekit_components/livekit_components.dart' as components;
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_embed_unity/flutter_embed_unity.dart';

enum AgentState {
  disconnected,
  connecting,
  listening,
  thinking,
  speaking,
}

// Helper function to check if agent is ready to accept messages
bool isAgentAvailable(AgentState state) {
  return state == AgentState.listening || 
         state == AgentState.thinking || 
         state == AgentState.speaking;
}

class LiveKitService {
  Room? _room;
  EventsListener<RoomEvent>? _listener;
  components.RoomContext? _roomContext;
  
  // Streams for UI updates
  final _messageController = StreamController<String>.broadcast();
  final _agentStateController = StreamController<AgentState>.broadcast();
  final _audioTrackController = StreamController<RemoteAudioTrack?>.broadcast();
  final _userTranscriptionController = StreamController<String>.broadcast();
  
  Stream<String> get onMessageReceived => _messageController.stream;
  Stream<AgentState> get onAgentStateChanged => _agentStateController.stream;
  Stream<RemoteAudioTrack?> get onAudioTrackReceived => _audioTrackController.stream;
  /// Stream of user's speech transcription (for showing in input box)
  Stream<String> get onUserTranscription => _userTranscriptionController.stream;
  
  // Expose room and roomContext for UI components
  Room? get room => _room;
  components.RoomContext? get roomContext => _roomContext;

  AgentState _currentState = AgentState.disconnected;
  AgentState get currentState => _currentState;

  // Track if agent is connected (for message buffering like web frontend)
  bool _isAgentConnected = false;
  String? _agentIdentity;
  final List<String> _messageBuffer = [];
  
  // Buffer for accumulating transcription segments
  final List<String> _transcriptionBuffer = [];
  bool _isProcessingTranscription = false;
  
  // Track the active responding agent for current interaction
  // This prevents multiple agents from interfering with each other
  String? _activeRespondingAgent;
  
  // Audio playback tracking - calculate duration from PCM bytes
  int _totalAudioBytes = 0;
  Timer? _audioPlaybackTimer;
  
  // Timeout handling for stuck states
  Timer? _thinkingTimeout;
  Timer? _connectingTimeout;
  static const Duration _thinkingTimeoutDuration = Duration(seconds: 30);
  static const Duration _connectingTimeoutDuration = Duration(seconds: 15);
  
  // Error state stream
  final _errorController = StreamController<String>.broadcast();
  Stream<String> get onError => _errorController.stream;
  
  bool get isAgentConnected => _isAgentConnected;
  String? get agentIdentity => _agentIdentity;
  AgentState get agentState => _currentState;
  
  /// Check if agent is ready to accept messages (listening, thinking, or speaking)
  bool get isAgentReady => isAgentAvailable(_currentState);
  
  /// Process buffered messages when agent becomes available
  Future<void> _processMessageBuffer() async {
    if (!isAgentReady || _messageBuffer.isEmpty) return;
    
    print('📬 Agent is ready! Processing ${_messageBuffer.length} buffered message(s)');
    final bufferedMessages = List<String>.from(_messageBuffer);
    _messageBuffer.clear();
    
    for (final message in bufferedMessages) {
      try {
        await _sendMessageInternal(message);
      } catch (e) {
        print('❌ Error sending buffered message: $e');
      }
    }
  }
  

  Future<void> connect(String threadId, String userId, {String? authToken}) async {
    try {
      _updateState(AgentState.connecting);

      // 1. Fetch connection details from Next.js API
      final tokenData = await _fetchConnectionDetails(threadId, userId, authToken);
      
      // 2. Connect to LiveKit Room
      _room = Room();
      
      // Create listener before connecting
      _listener = _room!.createListener();
      
      _setupListeners();

      final options = RoomOptions(
        adaptiveStream: true,
        dynacast: true,
        defaultAudioPublishOptions: const AudioPublishOptions(
          name: 'user_audio',
        ),
        defaultAudioCaptureOptions: const AudioCaptureOptions(
          echoCancellation: true,
          noiseSuppression: true,
          autoGainControl: true,
        ),
        // Enable speaker output - Unity plays audio but LiveKit controls device audio routing
        // Setting speakerOn: true ensures audio routes to speaker, not earpiece
        defaultAudioOutputOptions: const AudioOutputOptions(
          speakerOn: true, // Route audio to speaker (Unity audio respects this)
        ),
      );
      
      print('🔊 Room options configured with audio processing enabled');
      print('   - Echo cancellation: true');
      print('   - Noise suppression: true');
      print('   - Auto gain control: true');

      await _room!.connect(
        tokenData['serverUrl'],
        tokenData['participantToken'],
        roomOptions: options,
      );
      
      _room!.localParticipant?.setAttributes({
        'thread_id': threadId,
        'user_id': userId,
      });
      print('✅ Set participant attributes - thread_id: $threadId, user_id: $userId');
      
      // 4. Create RoomContext (provides UI widgets access to room state and transcriptions)
      _roomContext = components.RoomContext(room: _room!);
      print('✅ Created RoomContext - UI can now use TranscriptionBuilder');
      
      // 5. Microphone defaults to disabled (user must toggle it)
      await _room!.localParticipant?.setMicrophoneEnabled(false);
      
      // Stay in "connecting" state - will transition to "listening" when agent joins
      // This ensures the text box remains disabled until agent is truly ready
      print('✅ Connected to LiveKit Room: ${_room!.name}');
      print('⏳ Waiting for agent to join the room...');
      
      // Check if agent is already in the room (might have joined before us)
      for (final participant in _room!.remoteParticipants.values) {
        if (participant.identity.startsWith('agent-')) {
          print('🤖 Agent already in room: ${participant.identity}');
          _isAgentConnected = true;
          _agentIdentity = participant.identity;
          _connectingTimeout?.cancel();
          _updateState(AgentState.listening);
          return;
        }
      }
      
      // Agent not in room yet - stay in connecting state
      // ParticipantConnectedEvent will handle the transition to listening
      
      // Start a timeout - if agent doesn't join in time, show error
      _connectingTimeout?.cancel();
      _connectingTimeout = Timer(_connectingTimeoutDuration, () {
        if (_currentState == AgentState.connecting && !_isAgentConnected) {
          print('⏰ Connection timeout! Agent did not join in ${_connectingTimeoutDuration.inSeconds}s');
          _errorController.add('Connection timeout - agent not available. Please try again.');
          _updateState(AgentState.disconnected);
        }
      });

    } catch (e) {
      print('❌ LiveKit Connection Error: $e');
      _connectingTimeout?.cancel();
      _updateState(AgentState.disconnected);
      rethrow;
    }
  }

  Future<Map<String, dynamic>> _fetchConnectionDetails(String threadId, String userId, String? authToken) async {
    final baseUrl = dotenv.env['BACKEND_URL']!; 
    final url = Uri.parse('$baseUrl/api/connection-details');
    
    final headers = {'Content-Type': 'application/json'};
    if (authToken != null) {
      headers['Authorization'] = 'Bearer $authToken';
    }
    
    final response = await http.post(
      url,
      headers: headers,
      body: jsonEncode({
        'thread_id': threadId,
        'user_id': userId,
        'room_config': {
          'agents': [
            {'agent_name': 'krsna-agent'}
          ]
        }
      }),
    );

    if (response.statusCode == 200) {
      return jsonDecode(response.body);
    } else {
      throw Exception('Failed to fetch connection details: ${response.body}');
    }
  }

  void _setupListeners() {
    if (_listener == null) return;

    // Log all room events for debugging (catches all event types)
    _listener!.on<RoomEvent>((event) {
      print('🔔 Room Event: ${event.runtimeType}');
      print('   Event: $event');
    });
    
    _listener!
      ..on<DataReceivedEvent>((event) {
        print('📨 DataReceivedEvent - Topic: ${event.topic ?? "null"}, Data length: ${event.data.length}');
        print('   Participant: ${event.participant?.identity ?? "null"}');
        
        // Handle chat messages - match web frontend behavior
        // Web frontend receives messages via useChat hook which uses 'lk.chat' topic
        // Accept messages with 'lk.chat' topic or other variants for backward compatibility
        if (event.topic == 'lk.chat' || event.topic == 'chat' || event.topic == 'lk-chat-topic') {
          try {
            final data = utf8.decode(event.data);
            print('📩 Chat Message Received: $data (topic: ${event.topic ?? "default"})');
            _messageController.add(data);
          } catch (e) {
            print('❌ Error decoding chat message: $e');
          }
        } else if (event.topic == 'audio_pcm') {
          // Handle PCM audio chunks from LiveKit agent for Unity lip-sync
          // Format: "START", "CHUNK|base64_pcm_data", or "END|total_bytes"
          try {
            final data = utf8.decode(event.data);
            final senderIdentity = event.participant?.identity ?? 'unknown';
            
            // Only process messages from agents
            if (!senderIdentity.startsWith('agent-')) {
              return;
            }
            
            // Lock onto the first agent that sends START for this interaction
            // Ignore all other agents until END is received
            if (data == 'START') {
              if (_activeRespondingAgent == null) {
                _activeRespondingAgent = senderIdentity;
                print('🎯 Locked onto agent: $senderIdentity for this response');
              } else if (_activeRespondingAgent != senderIdentity) {
                print('⚠️ IGNORING START from $senderIdentity (locked to $_activeRespondingAgent)');
                return;
              }
            } else if (_activeRespondingAgent != null && senderIdentity != _activeRespondingAgent) {
              // Ignore messages from other agents while we're locked onto one
              return;
            }
            
            print('🎵 audio_pcm from $senderIdentity: ${data.length > 50 ? data.substring(0, 50) + "..." : data}');
            
            if (data == 'START') {
              // Audio starting
              print('🎬 [${senderIdentity}] START marker received');
              _totalAudioBytes = 0;
              _audioPlaybackTimer?.cancel();
              
              // Ensure we're in speaking state
              if (_currentState != AgentState.speaking) {
                _updateState(AgentState.speaking);
              }
            } else if (data.startsWith('CHUNK|')) {
              // CHUNK|base64_audio - track bytes for duration
              final base64Data = data.substring(6);
              try {
                final bytes = base64Decode(base64Data);
                _totalAudioBytes += bytes.length;
              } catch (e) {
                // Ignore decode errors
              }
            } else if (data.startsWith('END|')) {
              // END|total_bytes - TTS complete
              final totalBytes = int.tryParse(data.substring(4)) ?? _totalAudioBytes;
              
              print('🏁 [${senderIdentity}] END received - $totalBytes bytes');
              
              // Calculate audio duration
              const int sampleRate = 22050;
              const int bytesPerSample = 2;
              final int totalSamples = totalBytes ~/ bytesPerSample;
              final double audioDurationSeconds = totalSamples / sampleRate;
              
              print('📊 Audio: ${audioDurationSeconds.toStringAsFixed(2)}s');
              
              // Timer to transition to listening after playback
              final playbackDuration = Duration(milliseconds: (audioDurationSeconds * 1000).toInt() + 500);
              
              _audioPlaybackTimer = Timer(playbackDuration, () {
                print('🎵 Playback finished - transitioning to listening');
                _activeRespondingAgent = null;
                
                if (_currentState == AgentState.speaking) {
                  _updateState(AgentState.listening);
                }
              });
            } else if (data == 'END') {
              // Legacy END without bytes
              print('🏁 [${senderIdentity}] Legacy END');
              const int sampleRate = 22050;
              const int bytesPerSample = 2;
              final int totalSamples = _totalAudioBytes ~/ bytesPerSample;
              final double audioDurationSeconds = totalSamples / sampleRate;
              
              final playbackDuration = Duration(milliseconds: (audioDurationSeconds * 1000).toInt() + 500);
              _audioPlaybackTimer = Timer(playbackDuration, () {
                _activeRespondingAgent = null;
                if (_currentState == AgentState.speaking) {
                  _updateState(AgentState.listening);
                }
              });
            }
            
            // Forward all data to Unity (START, CHUNK|..., END)
            sendToUnity("Flutter", "OnAudioChunk", data);
          } catch (e) {
            print('❌ Error processing PCM audio chunk: $e');
          }
        } else {
          // Log other data messages for debugging
          print('📦 Non-chat data received on topic: ${event.topic ?? "null"}');
          try {
            final data = utf8.decode(event.data);
            print('   Data content: $data');
          } catch (e) {
            print('   Data (binary): ${event.data.length} bytes');
          }
        }
      })
      ..on<TrackSubscribedEvent>((event) async {
        print('🎤 TrackSubscribedEvent - Track: ${event.track.runtimeType}, Sid: ${event.track.sid}');
        print('   Participant: ${event.participant.identity}, Kind: ${event.track.kind}');
        if (event.track is RemoteAudioTrack) {
          print('🔇 Audio Track Subscribed - STOPPING to prevent WebRTC playback');
          
          try {
            // Stop the audio track completely to prevent WebRTC audio
            final audioTrack = event.track as RemoteAudioTrack;
            await audioTrack.stop();
            print('✅ Stopped audio track ${audioTrack.sid} - WebRTC audio disabled');
          } catch (e) {
            print('⚠️ Error stopping audio track: $e');
          }
        }
      })
      ..on<TrackUnsubscribedEvent>((event) {
        print('🔇 TrackUnsubscribedEvent - Track: ${event.track.runtimeType}, Sid: ${event.track.sid}');
        print('   Participant: ${event.participant.identity}');
        if (event.track is RemoteAudioTrack) {
          _audioTrackController.add(null);
        }
      })
      ..on<RoomDisconnectedEvent>((event) {
        print('🔌 RoomDisconnectedEvent - Reason: ${event.reason}');
        _updateState(AgentState.disconnected);
      })
      ..on<RoomConnectedEvent>((event) {
        print('✅ RoomConnectedEvent - transcriptions auto-wired via RoomContext');
      })
      ..on<ParticipantConnectedEvent>((event) {
        print('👤 ParticipantConnectedEvent - Identity: ${event.participant.identity}');
        
        if (event.participant.identity.startsWith('agent-')) {
          print('🤖 Agent connected!');
          _isAgentConnected = true;
          _agentIdentity = event.participant.identity;
          
          // Cancel connecting timeout - agent is here!
          _connectingTimeout?.cancel();
          _connectingTimeout = null;
          
          // Agent connected - mark as listening (ready to receive messages)
          // This will also process any buffered messages
          _updateState(AgentState.listening);
        }
      })
      ..on<TrackPublishedEvent>((event) async {
        print('📢 TrackPublishedEvent - Kind: ${event.publication.kind}, Sid: ${event.publication.sid}');
        print('   Participant: ${event.participant.identity}');
        
        // CRITICAL: Unsubscribe from audio tracks to prevent WebRTC audio playback
        // We play audio through Unity via PCM data channel instead
        if (event.publication.kind == TrackType.AUDIO) {
          print('🔇 Audio track published - UNSUBSCRIBING to prevent WebRTC playback');
          try {
            await event.publication.unsubscribe();
            print('✅ Unsubscribed from WebRTC audio track: ${event.publication.sid}');
          } catch (e) {
            print('⚠️ Error unsubscribing from audio track: $e');
          }
        }
      })
      ..on<ParticipantDisconnectedEvent>((event) {
        print('👋 ParticipantDisconnectedEvent - Identity: ${event.participant.identity}');
      })
      ..on<TrackUnpublishedEvent>((event) {
        print('📴 TrackUnpublishedEvent - Sid: ${event.publication.sid}');
        print('   Participant: ${event.participant.identity}');
      })
      ..on<LocalTrackPublishedEvent>((event) {
        print('📡 LocalTrackPublishedEvent - Track: ${event.publication.track?.runtimeType}, Sid: ${event.publication.sid}');
      })
      ..on<LocalTrackUnpublishedEvent>((event) {
        print('📴 LocalTrackUnpublishedEvent - Sid: ${event.publication.sid}');
      })
      ..on<TrackMutedEvent>((event) {
        print('🔇 TrackMutedEvent - Sid: ${event.publication.sid}');
        print('   Participant: ${event.participant.identity}');
      })
      ..on<TrackUnmutedEvent>((event) {
        print('🔊 TrackUnmutedEvent - Sid: ${event.publication.sid}');
        print('   Participant: ${event.participant.identity}');
      })
      ..on<ActiveSpeakersChangedEvent>((event) async {
        print('🗣️ ActiveSpeakersChangedEvent - Speakers: ${event.speakers.length}');
        for (final speaker in event.speakers) {
          print('   Speaker: ${speaker.identity}');
        }
        
        bool isAgentSpeaking = false;
        bool isUserSpeaking = false;
        
        for (final p in event.speakers) {
          if (p is RemoteParticipant) {
            isAgentSpeaking = true;
          } else if (p is LocalParticipant) {
            isUserSpeaking = true;
          }
        }
        
        if (isAgentSpeaking && !isUserSpeaking) {
          // Agent started speaking (and user is not speaking)
          // NOTE: WebRTC audio is disabled - audio plays through Unity via PCM data channel
          _updateState(AgentState.speaking);
        } else if (isUserSpeaking) {
          // User is speaking - handle interruption or state change
          if (_currentState == AgentState.speaking) {
            // INTERRUPTION: User started speaking while agent was speaking
            print('🛑 INTERRUPTION: User started speaking while agent was speaking - stopping audio');
            _handleInterruption();
          } else if (_currentState == AgentState.thinking) {
            // User started talking again while we were thinking - back to listening
            print('🎤 User started speaking again - back to listening');
            _updateState(AgentState.listening);
          }
        } else {
          // No one is speaking
          final micEnabled = _room?.localParticipant?.isMicrophoneEnabled() ?? false;
          
          if (micEnabled && _currentState == AgentState.listening) {
            // User just stopped speaking in voice mode - agent is processing
            print('🤔 User stopped speaking - agent is thinking...');
            _updateState(AgentState.thinking);
          } else if (_currentState == AgentState.speaking && _isProcessingTranscription) {
            // Agent stopped speaking - finalize transcription
            _finalizeTranscription();
            // NOTE: State transition to listening is handled by audio_pcm END marker
            print('🔇 Agent voice activity stopped (waiting for audio END marker)');
          }
        }
      })
      ..on<TranscriptionEvent>((event) {
        // Handle transcriptions from both agent and user
        print('📝 TranscriptionEvent received');
        print('   Participant: ${event.participant.identity}');
        print('   Segments: ${event.segments.length}');
        
        if (event.participant is RemoteParticipant) {
          // Agent's transcription - for state management
          if (!_isProcessingTranscription) {
            _isProcessingTranscription = true;
            _transcriptionBuffer.clear();
            _updateState(AgentState.speaking);
            
            print('🎙️ Agent started speaking (transcription received)');
          }
          
          for (final segment in event.segments) {
            print('   📝 Agent: "${segment.text.substring(0, min(50, segment.text.length))}..." (final: ${segment.isFinal})');
            
            // Accumulate final segments for the complete message
            if (segment.isFinal) {
              _transcriptionBuffer.add(segment.text);
            }
          }
        } else if (event.participant is LocalParticipant) {
          // User's transcription - show in input box
          for (final segment in event.segments) {
            final text = segment.text.trim();
            if (text.isNotEmpty) {
              print('   🎤 User: "$text" (final: ${segment.isFinal})');
              // Send user's transcription to UI
              _userTranscriptionController.add(text);
            }
          }
        }
      });
  }
  
  // NOTE: This method sends via LiveKit Data Channel, but the agent doesn't support text input via LiveKit.
  // For text messages, use the HTTP API (BackendApiService.invokeAgent) instead.
  // This method is kept for potential future use or voice transcription display.
  // The web frontend sends text messages to /api/lang HTTP endpoint, not via LiveKit chat.
  /// Send text message via LiveKit (like web frontend)
  /// Buffers messages if agent is not ready (connecting state)
  Future<void> sendMessage(String text) async {
    if (_room == null) {
      print('❌ Cannot send message: Room is null');
      return;
    }
    
    final roomState = _room!.connectionState;
    if (roomState != ConnectionState.connected) {
      print('❌ Cannot send message: Room is not connected (state: $roomState)');
      return;
    }
    
    // If agent is ready (listening/thinking/speaking), send immediately
    if (isAgentReady) {
      print('✅ Agent is ready, sending message immediately');
      await _sendMessageInternal(text);
    } else {
      // Buffer message until agent is ready (matches web frontend behavior)
      print('⏳ Agent not ready yet (state: $_currentState), buffering message');
      _messageBuffer.add(text);
      print('   Buffered messages: ${_messageBuffer.length}');
    }
  }
  
  /// Internal method that actually sends the message to LiveKit
  Future<void> _sendMessageInternal(String text) async {
    try {
      // Use LiveKit's sendText() method - official example uses 'lk.chat' topic
      // See: https://github.com/livekit-examples/agent-starter-flutter
      print('📤 Sending text to LiveKit (topic: lk.chat): "$text"');
      print('   Room: ${_room!.name}');
      print('   Agent: $_agentIdentity (state: $_currentState)');
      print('   Local Participant: ${_room!.localParticipant?.identity}');
      
      // Send via sendText() with 'lk.chat' topic (official LiveKit agent protocol)
      await _room!.localParticipant?.sendText(
        text,
        options: SendTextOptions(
          topic: 'lk.chat',
        ),
      );
      
      print('✅ Text sent via LiveKit on lk.chat topic');
    } catch (e, stackTrace) {
      print('❌ Error sending text via LiveKit: $e');
      print('   Stack trace: $stackTrace');
      rethrow;
    }
  }

  Future<void> setMicrophoneEnabled(bool enabled) async {
    if (_room == null) return;
    await _room!.localParticipant?.setMicrophoneEnabled(enabled);
  }

  /// Toggle agent input mode (audio on/off)
  /// Flutter SDK doesn't support RPC, so we use data messages to send commands
  /// The agent backend needs to handle these data messages on 'toggle_input' topic
  Future<void> toggleAgentInput(bool audioEnabled) async {
    if (_room == null) {
      print('❌ Cannot toggle agent input: Room is null');
      return;
    }

    final agentIdentity = _getAgentIdentity();
    if (agentIdentity == null) {
      print('❌ Agent not found in room to toggle input');
      return;
    }

    final payload = audioEnabled ? 'audio_on' : 'audio_off';
    print('🔄 Sending toggle_input command via data message: $payload to agent: $agentIdentity');

    try {
      // Send as data message with topic 'toggle_input'
      final data = utf8.encode(payload);
      await _room!.localParticipant!.publishData(
        data,
        topic: 'toggle_input',
        reliable: true,
      );
      print('✅ toggle_input command sent via data message');
    } catch (e) {
      print('❌ Error sending toggle_input command: $e');
    }
  }

  /// Toggle agent output mode (audio on/off)
  /// Flutter SDK doesn't support RPC, so we use data messages to send commands
  /// The agent backend needs to handle these data messages on 'toggle_output' topic
  Future<void> toggleAgentOutput(bool audioEnabled) async {
    if (_room == null) {
      print('❌ Cannot toggle agent output: Room is null');
      return;
    }

    final agentIdentity = _getAgentIdentity();
    if (agentIdentity == null) {
      print('❌ Agent not found in room to toggle output');
      return;
    }

    final payload = audioEnabled ? 'audio_on' : 'audio_off';
    print('🔄 Sending toggle_output command via data message: $payload to agent: $agentIdentity');

    try {
      // Send as data message with topic 'toggle_output'
      final data = utf8.encode(payload);
      await _room!.localParticipant!.publishData(
        data,
        topic: 'toggle_output',
        reliable: true,
      );
      print('✅ toggle_output command sent via data message');
    } catch (e) {
      print('❌ Error sending toggle_output command: $e');
    }
  }

  /// Get agent's participant identity
  String? _getAgentIdentity() {
    if (_room == null) return null;
    
    for (final participant in _room!.remoteParticipants.values) {
      if (participant.identity.startsWith('agent-')) {
        return participant.identity;
      }
    }
    return null;
  }

  void _updateState(AgentState state) {
    final oldState = _currentState;
    _currentState = state;
    _agentStateController.add(state);
    
    print('🤖 Agent state: $oldState → $state');
    
    // If agent just became available, process buffered messages
    if (!isAgentAvailable(oldState) && isAgentAvailable(state)) {
      _processMessageBuffer();
    }
    
    // Cancel any existing timeout
    _thinkingTimeout?.cancel();
    _thinkingTimeout = null;
    
    // Start timeout for thinking state
    if (state == AgentState.thinking) {
      print('⏱️ Starting thinking timeout (${_thinkingTimeoutDuration.inSeconds}s)');
      _thinkingTimeout = Timer(_thinkingTimeoutDuration, () {
        if (_currentState == AgentState.thinking) {
          print('⏰ Thinking timeout! Resetting to listening state');
          _errorController.add('Response timeout - please try again');
          _updateState(AgentState.listening);
        }
      });
    }
  }
  
  /// Handle user interruption - stop audio playback and reset state
  Future<void> _handleInterruption() async {
    // Cancel any pending audio playback timer
    _audioPlaybackTimer?.cancel();
    _audioPlaybackTimer = null;
    
    // Clear the active responding agent
    _activeRespondingAgent = null;
    
    // Reset transcription state
    _transcriptionBuffer.clear();
    _isProcessingTranscription = false;
    _totalAudioBytes = 0;
    
    // Send END signal to Unity to stop audio playback immediately
    sendToUnity("Flutter", "OnAudioChunk", "END");
    print('🛑 Sent END signal to Unity (interruption - stopping audio)');
    
    // Send interrupt command to the agent backend via data channel
    // The agent has an RPC method "interrupt" but Flutter SDK doesn't support RPC,
    // so we use data channel with topic "interrupt"
    try {
      if (_room != null && _room!.localParticipant != null) {
        await _room!.localParticipant!.publishData(
          utf8.encode('interrupt'),
          topic: 'interrupt',
          reliable: true,
        );
        print('🛑 Sent interrupt command to agent backend');
      }
    } catch (e) {
      print('⚠️ Failed to send interrupt command: $e');
    }
    
    // Transition to listening state (ready for new input)
    _updateState(AgentState.listening);
  }
  
  /// Finalize transcription when agent stops speaking
  void _finalizeTranscription() {
    if (_transcriptionBuffer.isEmpty) {
      print('⚠️ No transcription segments to finalize');
      _isProcessingTranscription = false;
      return;
    }
    
    // Combine all transcription segments into final message
    final completeTranscription = _transcriptionBuffer.join(' ');
    print('✅ Transcription complete: "$completeTranscription"');
    
    // Send complete message to ChatBloc (exits "pondering" state)
    _messageController.add(completeTranscription);
    
    // Reset for next transcription
    _transcriptionBuffer.clear();
    _isProcessingTranscription = false;
  }

  Future<void> disconnect() async {
    await _room?.disconnect();
    _room = null;
    _listener?.dispose();
    _roomContext?.dispose();
    _roomContext = null;
    _updateState(AgentState.disconnected);
  }
  
  void dispose() {
    _thinkingTimeout?.cancel();
    _connectingTimeout?.cancel();
    _audioPlaybackTimer?.cancel();
    _messageController.close();
    _agentStateController.close();
    _audioTrackController.close();
    _errorController.close();
    _userTranscriptionController.close();
    _roomContext?.dispose();
  }
}
