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
  final _transcriptionController = StreamController<String>.broadcast();
  
  Stream<String> get onMessageReceived => _messageController.stream;
  Stream<AgentState> get onAgentStateChanged => _agentStateController.stream;
  Stream<RemoteAudioTrack?> get onAudioTrackReceived => _audioTrackController.stream;
  Stream<String> get onTranscriptionReceived => _transcriptionController.stream;
  
  // Expose room and roomContext for UI components
  Room? get room => _room;
  components.RoomContext? get roomContext => _roomContext;

  AgentState _currentState = AgentState.disconnected;
  AgentState get currentState => _currentState;

  // Track if agent is connected (for message buffering like web frontend)
  bool _isAgentConnected = false;
  String? _agentIdentity;
  AgentState _agentState = AgentState.disconnected;
  final List<String> _messageBuffer = [];
  
  // Buffer for accumulating transcription segments
  final List<String> _transcriptionBuffer = [];
  bool _isProcessingTranscription = false;
  
  bool get isAgentConnected => _isAgentConnected;
  String? get agentIdentity => _agentIdentity;
  AgentState get agentState => _agentState;
  
  /// Check if agent is ready to accept messages (listening, thinking, or speaking)
  bool get isAgentReady => isAgentAvailable(_agentState);
  
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
  
  /// Update agent state and process buffer if agent becomes available
  void _updateAgentState(AgentState newState) {
    final oldState = _agentState;
    _agentState = newState;
    _agentStateController.add(newState);
    
    print('🤖 Agent state: $oldState → $newState');
    
    // If agent just became available, process buffered messages
    if (!isAgentAvailable(oldState) && isAgentAvailable(newState)) {
      _processMessageBuffer();
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
      
      _updateState(AgentState.listening);
      print('✅ Connected to LiveKit Room: ${_room!.name}');
      
      // 6. Enable speakerphone to route audio to loudspeaker (not earpiece)
      // IMPORTANT: Must be called AFTER room is fully connected
      print('🔊 Attempting to enable speakerphone...');
      try {
        // First, ensure audio output is set to speakerphone
        await Hardware.instance.setPreferSpeakerOutput(true);
        print('✅ Set prefer speaker output to true');
        
        // Then explicitly enable speakerphone
        await Hardware.instance.setSpeakerphoneOn(true);
        print('✅ Enabled speakerphone - audio will route to loudspeaker (not earpiece)');
        print('   This switches from VOICE_CALL (earpiece) to loudspeaker output');
      } catch (e) {
        print('⚠️ Failed to enable speakerphone: $e');
        print('   Audio may route to earpiece by default');
      }

    } catch (e) {
      print('❌ LiveKit Connection Error: $e');
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
          // Format: "CHUNK|base64_pcm_data" or "END"
          try {
            final data = utf8.decode(event.data);
            print('🎵 PCM Audio Chunk Received: ${data.substring(0, min(50, data.length))}... (for Unity lip-sync)');
            
            // Forward to Unity (same format as ElevenLabs)
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
          print('✅ Audio Track Subscribed');
          final audioTrack = event.track as RemoteAudioTrack;
          
          // Enable the audio track
          try {
            await audioTrack.enable();
            print('🔊 Enabled audio track for playback');
            
            // Re-ensure speakerphone is on when audio track arrives
            // Sometimes audio routing can change when new tracks are added
            await Hardware.instance.setSpeakerphoneOn(true);
            print('🔊 Re-confirmed speakerphone is ON for audio playback');
          } catch (e) {
            print('⚠️ Error configuring audio track: $e');
          }
          
          _audioTrackController.add(audioTrack);
          // On mobile, flutter_webrtc handles audio playback automatically
          // when the track is enabled.
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
          _updateAgentState(AgentState.connecting);
          
          // Wait a moment for agent to initialize, then mark as listening (ready)
          Future.delayed(const Duration(milliseconds: 1000), () {
            if (_isAgentConnected) {
              _updateAgentState(AgentState.listening);
            }
          });
        }
      })
      ..on<ParticipantDisconnectedEvent>((event) {
        print('👋 ParticipantDisconnectedEvent - Identity: ${event.participant.identity}');
      })
      ..on<TrackPublishedEvent>((event) {
        print('📡 TrackPublishedEvent - Track: ${event.publication.track?.runtimeType}, Sid: ${event.publication.sid}');
        print('   Participant: ${event.participant.identity}, Kind: ${event.publication.kind}');
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
        for (final p in event.speakers) {
          if (p is RemoteParticipant) {
            isAgentSpeaking = true;
            break;
          }
        }
        
        if (isAgentSpeaking) {
          // Agent started speaking - ensure speakerphone is still on
          try {
            await Hardware.instance.setSpeakerphoneOn(true);
            print('🔊 Speakerphone re-enabled for agent speech');
          } catch (e) {
            print('⚠️ Could not re-enable speakerphone: $e');
          }
          
          _updateState(AgentState.speaking);
        } else {
          // Agent stopped speaking - finalize transcription
          if (_currentState == AgentState.speaking && _isProcessingTranscription) {
            _finalizeTranscription();
          }
          
          // Revert to listening
          if (_currentState == AgentState.speaking) {
            _updateState(AgentState.listening);
          }
        }
      })
      ..on<TranscriptionEvent>((event) {
        // Handle agent transcriptions (subtitles + lip sync)
        print('📝 TranscriptionEvent received');
        print('   Participant: ${event.participant.identity}');
        print('   Segments: ${event.segments.length}');
        
        // Only process agent's transcriptions (not user's own)
        if (event.participant is RemoteParticipant) {
          // Mark that agent is responding (exit pondering state)
          if (!_isProcessingTranscription) {
            _isProcessingTranscription = true;
            _transcriptionBuffer.clear();
            _updateState(AgentState.speaking);
            
            // Send START marker to Unity when agent starts speaking
            // This prepares Unity to receive PCM audio chunks for lip-sync
            sendToUnity("Flutter", "OnAudioChunk", "START");
            print('🎬 Sent START marker to Unity for LiveKit audio playback');
          }
          
          for (final segment in event.segments) {
            print('   📝 Segment: "${segment.text}" (final: ${segment.isFinal})');
            
            // Extract plain text from JSON response (agent sends JSON-formatted text)
            String displayText = segment.text;
            try {
              // Try to parse as complete JSON first
              if (segment.text.contains('{"response":')) {
                final jsonData = jsonDecode(segment.text);
                if (jsonData is Map && jsonData.containsKey('response')) {
                  displayText = jsonData['response'] as String;
                }
              } else {
                // Partial JSON - extract text after "response":"
                final match = RegExp(r'"response":"([^"]*)"?').firstMatch(segment.text);
                if (match != null && match.group(1) != null) {
                  displayText = match.group(1)!;
                }
              }
            } catch (e) {
              // If JSON parsing fails, try regex extraction
              final match = RegExp(r'"response":"([^"]*)"?').firstMatch(segment.text);
              if (match != null && match.group(1) != null) {
                displayText = match.group(1)!;
              }
            }
            
            // Send extracted text to UI for live subtitles
            if (displayText.isNotEmpty && !displayText.startsWith('{')) {
              _transcriptionController.add(displayText);
              print('   📺 Subtitle: "$displayText"');
            }
            
            // Accumulate final segments for the complete message
            if (segment.isFinal) {
              _transcriptionBuffer.add(segment.text);
            }
          }
          
          // Check if transcription is complete (agent stopped speaking)
          // We'll detect this via ActiveSpeakersChangedEvent when speakers list is empty
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
      print('⏳ Agent not ready yet (state: $_agentState), buffering message');
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
      print('   Agent: $_agentIdentity (state: $_agentState)');
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
    _currentState = state;
    _agentStateController.add(state);
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
    _messageController.close();
    _agentStateController.close();
    _audioTrackController.close();
    _transcriptionController.close();
    _roomContext?.dispose();
  }
}
