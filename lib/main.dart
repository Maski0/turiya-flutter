import 'dart:async';
import 'dart:math';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_embed_unity/flutter_embed_unity.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:supabase_flutter/supabase_flutter.dart' as supabase;
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:isar/isar.dart';
import 'package:path_provider/path_provider.dart';
import 'services/livekit_service.dart';
import 'services/backend_api_service.dart';
import 'services/cache_service.dart';
import 'onboarding/onboarding_gate.dart';
import 'models/cached_message.dart';
import 'models/conversation_mode.dart';
import 'widgets/glass_button.dart';
import 'widgets/bottom_input_bar.dart';
import 'widgets/login_modal.dart';
import 'widgets/chat_sidebar.dart';
import 'widgets/menu_drawer.dart';
import 'widgets/profile_avatar_widget.dart';
import 'widgets/recording_indicator.dart';
import 'widgets/recording_preview_overlay.dart';
import 'services/screen_recording_service.dart';
import 'blocs/auth/auth_bloc_export.dart';
import 'blocs/chat/chat_bloc_export.dart';
import 'blocs/credits/credits_bloc.dart';
import 'blocs/memory/memory_bloc.dart';
import 'package:permission_handler/permission_handler.dart';
import 'utils/toast_utils.dart';

// Global cache service
late final CacheService cacheService;
late final LiveKitService liveKitService;

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  // Set fullscreen mode - hide status bar and navigation bar
  SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);
  
  // Load environment variables first
  await dotenv.load(fileName: ".env");
  
  // Initialize Supabase (same as web does)
  await supabase.Supabase.initialize(
    url: dotenv.env['SUPABASE_URL']!,
    anonKey: dotenv.env['SUPABASE_ANON_KEY']!,
  );
  
  // Initialize Isar for local caching
  final dir = await getApplicationDocumentsDirectory();
  final isar = await Isar.open(
    [CachedMessageSchema, CachedThreadSchema],
    directory: dir.path,
  );
  cacheService = CacheService(isar);
  liveKitService = LiveKitService();
  
  runApp(const ExampleApp());
}

class ExampleApp extends StatelessWidget {
  const ExampleApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiBlocProvider(
      providers: [
        BlocProvider(create: (context) => AuthBloc()),
        BlocProvider(create: (context) => ChatBloc(
          cacheService: cacheService,
          liveKitService: liveKitService,
        )),
        BlocProvider(create: (context) => CreditsBloc()),
        BlocProvider(create: (context) => MemoryBloc()),
      ],
      child: MaterialApp(
        debugShowCheckedModeBanner: false,
        theme: ThemeData(
          fontFamily: 'Alegreya',
          brightness: Brightness.dark,
        ),
        home: const OnboardingGate(
          child: _MainScreen(),
        ),
      ),
    );
  }
}

class _MainScreen extends StatefulWidget {
  const _MainScreen();

  @override
  State<_MainScreen> createState() => _MainScreenState();
}

class _MainScreenState extends State<_MainScreen> with SingleTickerProviderStateMixin {
  final TextEditingController _textController = TextEditingController();
  final FocusNode _textFocusNode = FocusNode();
  final BackendApiService _backendApi = BackendApiService();
  final ScrollController _scrollController = ScrollController();
  late LiveKitService _liveKitService;
  bool _isConnecting = false; // LiveKit connecting state - only true when actively connecting
  bool _isGenerating = false;
  Timer? _generatingTimeout; // Timeout for stuck pondering state
  static const Duration _generatingTimeoutDuration = Duration(seconds: 30);
  bool _showLoginModal = false;
  bool _showChatSidebar = false;
  bool _showMenuDrawer = false;
  bool _showChip = false; // Hidden by default, shows when chat opens
  bool _isInInitialGracePeriod = false; // First 3s after opening chat
  bool _isRecording = false;
  bool _isScreenRecording = false; // For screen recording feature
  Timer? _chipAutoHideTimer; // Timer for auto-hiding the chip
  Timer? _recordingAutoStopTimer; // Timer for auto-stopping recording
  DateTime? _recordingStartTime; // When recording started
  OverlayEntry? _recordingIndicatorOverlay;
  final _screenRecordingService = ScreenRecordingService();
  final _repaintBoundaryKey = GlobalKey();
  static const int _maxRecordingDurationMinutes = 5; // Max 5 minutes
  late AnimationController _animationController;
  late Animation<double> _fadeAnimation;
  String? _threadId; // Conversation thread ID
  List<String> _previousFollowUps = []; // Track previous follow-ups for animation
  bool _showFollowUps = false; // Control fade-in animation
  String? _lastUserMessage; // Track last sent message
  bool _showUserMessageBubble = false; // Control user message bubble visibility
  
  // Audio playback state
  bool _isAudioPlaying = false;
  
  // Track currently playing message to prevent duplicates
  String? _currentlyPlayingMessageId;
  
  // Conversation mode state
  ConversationMode _conversationMode = ConversationMode.chatAudio;

  @override
  void initState() {
    super.initState();
    
    _liveKitService = liveKitService;
    
    // Listen to agent state changes to drive Unity animation and UI state
    _liveKitService.onAgentStateChanged.listen((state) {
      if (state == AgentState.connecting) {
        // Still connecting to LiveKit
        if (mounted) {
          setState(() {
            _isConnecting = true;
          });
        }
      } else if (state == AgentState.listening) {
        // Agent is ready and listening - connection complete or speaking finished
        if (mounted) {
          setState(() {
            _isConnecting = false;
            _isGenerating = false; // Reset pondering state
            _isAudioPlaying = false;
            _showUserMessageBubble = false; // Hide user message when agent is done speaking
            _lastUserMessage = null; // Clear the message
          });
          // Clear input box (voice transcription or pending text)
          _textController.clear();
          print('✅ Agent ready - cleared user message bubble and input box');
        }
        
        // Note: END marker is automatically sent by the backend agent
        print('🛑 LiveKit audio stream ended');
      } else if (state == AgentState.thinking) {
        // User finished speaking - agent is processing (pondering state)
        if (mounted) {
          setState(() {
            _isConnecting = false;
            _isGenerating = true; // Enter pondering/loading state
            _isAudioPlaying = false;
          });
          print('🤔 Agent is thinking - showing pondering state');
        }
        
        // Start timeout for stuck pondering state
        _generatingTimeout?.cancel();
        _generatingTimeout = Timer(_generatingTimeoutDuration, () {
          if (mounted && _isGenerating) {
            print('⏰ Pondering timeout! Resetting state');
            setState(() {
              _isGenerating = false;
            });
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: const Text('Response timeout - please try again'),
                backgroundColor: Colors.orange.shade700,
                duration: const Duration(seconds: 3),
              ),
            );
          }
        });
      } else if (state == AgentState.speaking) {
        // Exit "pondering" state and enter "narrating" state
        _generatingTimeout?.cancel(); // Cancel timeout - we got a response!
        if (mounted) {
          setState(() {
            _isConnecting = false;
            _isGenerating = false; // Exit pondering/loading state
            _isAudioPlaying = true; // Enter narrating/speaking state
          });
          print('🎙️ Agent started speaking - switched to narrating state');
        }
        
        // Note: PCM audio chunks are now sent directly from the backend agent
        // via data channel and automatically forwarded to Unity by LiveKitService
        print('🎵 LiveKit audio will be streamed from backend to Unity for lip-sync');
      } else if (state == AgentState.disconnected) {
        // Disconnected from LiveKit - only show connecting if user is still authenticated
        if (mounted) {
          final isAuthenticated = supabase.Supabase.instance.client.auth.currentUser != null;
          setState(() {
            _isConnecting = isAuthenticated; // Only show connecting if logged in
          });
        }
      }
    });
    
    // Listen to user transcription (voice input) - show in input box
    _liveKitService.onUserTranscription.listen((transcription) {
      if (mounted && _isRecording) {
        // Show user's speech in the input box as they speak
        setState(() {
          _textController.text = transcription;
          // Move cursor to end
          _textController.selection = TextSelection.fromPosition(
            TextPosition(offset: transcription.length),
          );
        });
      }
    });
    
    // Listen to LiveKit errors
    _liveKitService.onError.listen((error) {
      if (mounted) {
        ToastUtils.showError(context, error);
      }
    });
    
    // Listen to errors from LiveKit service
    _liveKitService.onError.listen((error) {
      if (mounted) {
        print('❌ LiveKit Error: $error');
        // Show a snackbar or toast with the error
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(error),
            backgroundColor: Colors.red.shade700,
            duration: const Duration(seconds: 3),
          ),
        );
        // Reset generating state on error
        setState(() {
          _isGenerating = false;
          _isConnecting = false;
        });
      }
    });
    
    // Initialize screen recording service
    _screenRecordingService.setRepaintBoundaryKey(_repaintBoundaryKey);
    
    // Initialize animation controller for smooth transitions
    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 300),
    );
    
    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _animationController, curve: Curves.easeInOut),
    );

    // Add scroll listener for chat overlay
    _scrollController.addListener(_handleScroll);
  }

  void _startChipAutoHideTimer() {
    // Cancel any existing timer
    _chipAutoHideTimer?.cancel();
    
    // Start a new timer
    _chipAutoHideTimer = Timer(const Duration(seconds: 5), () {
      if (mounted) {
        setState(() {
          _showChip = false;
        });
      }
    });
  }

  void _handleScroll() {
    if (!_scrollController.hasClients || _isInInitialGracePeriod) return;
    
    final currentOffset = _scrollController.offset;
    const showThreshold = 150.0; // Show chip when scrolled 150px from bottom
    const hideThreshold = 20.0;  // Hide chip when within 20px of bottom
    
    // At bottom - hide chip
    if (currentOffset <= hideThreshold) {
      if (_showChip) {
        setState(() {
          _showChip = false;
        });
      }
    }
    // Scrolled significantly up - show chip
    else if (currentOffset > showThreshold) {
      if (!_showChip) {
        setState(() {
          _showChip = true;
        });
        _startChipAutoHideTimer();
      }
    }
  }

  void _startInitialGracePeriod() {
    setState(() {
      _isInInitialGracePeriod = true;
    });
    
    Future.delayed(const Duration(seconds: 3), () {
      if (mounted) {
        setState(() {
          _isInInitialGracePeriod = false;
        });
      }
    });
  }
  
  Future<void> _loadLastThread() async {
    try {
      print('📥 Loading last thread...');
      
      // Try to get cached thread ID first (instant load)
      final cachedThreadId = await cacheService.getLastThreadId();
      print('💾 Cached thread ID: $cachedThreadId');
      
      // Query Supabase for the actual last thread
      final user = supabase.Supabase.instance.client.auth.currentUser;
      if (user == null) {
        print('❌ No user logged in');
        return;
      }
      
      print('👤 User ID: ${user.id}');
      const avatarId = '12a65bd0-d264-479d-a5a4-ce0bdabdbcf9'; // Krishna's avatar ID
      
      final response = await supabase.Supabase.instance.client
          .from('threads')
          .select('id')
          .eq('user_id', user.id)
          .eq('avatar_id', avatarId)
          .order('created_at', ascending: false)
          .limit(1)
          .maybeSingle();
      
      print('🗄️ Supabase response: $response');
      final threadId = response?['id'] as String? ?? cachedThreadId;
      
      if (threadId != null && mounted) {
        print('✅ Found thread ID: $threadId');
        setState(() {
          _threadId = threadId;
        });
        
        // This will:
        // 1. Start watching the thread (loads cache instantly)
        // 2. Fetch from backend (updates cache when done)
        // 3. Stream auto-updates UI
        // Connect to LiveKit
        final user = supabase.Supabase.instance.client.auth.currentUser;
        final authToken = supabase.Supabase.instance.client.auth.currentSession?.accessToken;
        if (user != null && authToken != null) {
          // Set connecting state BEFORE starting connection
          setState(() {
            _isConnecting = true;
          });
          _liveKitService.connect(threadId, user.id, authToken: authToken);
        }

        print('📤 Dispatching ChatHistoryRequested for thread: $threadId');
        context.read<ChatBloc>().add(ChatHistoryRequested(threadId));
      } else {
        print('❌ No thread ID found (Supabase: ${response?['id']}, Cache: $cachedThreadId)');
      }
    } catch (e) {
      print('⚠️ Error loading last thread: $e');
    }
  }

  void _toggleLoginModal() {
    if (_showLoginModal) {
      // Close: animate out first, then hide
      _animationController.reverse().then((_) {
        setState(() {
          _showLoginModal = false;
        });
      });
    } else {
      // Open: show first, then animate in
      setState(() {
        _showLoginModal = true;
      });
      _animationController.forward();
    }
  }

  Future<void> _handleGoogleSignIn() async {
    // Trigger sign-in via BLoC
    context.read<AuthBloc>().add(const AuthGoogleSignInRequested());
  }

  Future<void> _showExitConfirmationDialog() async {
    final shouldExit = await showDialog<bool>(
      context: context,
      barrierDismissible: true,
      builder: (BuildContext dialogContext) {
        return GestureDetector(
          onTap: () => Navigator.of(dialogContext).pop(false),
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
            child: Container(
              color: Colors.black.withOpacity(0.1),
              child: Center(
                child: GestureDetector(
                  onTap: () {}, // Prevent closing when tapping the modal content
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 32),
                    child: Container(
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(28),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.15),
                            blurRadius: 40,
                            spreadRadius: 0,
                            offset: const Offset(0, 20),
                          ),
                          BoxShadow(
                            color: Colors.black.withOpacity(0.1),
                            blurRadius: 20,
                            spreadRadius: 0,
                            offset: const Offset(0, 10),
                          ),
                        ],
                      ),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(28),
                        child: BackdropFilter(
                          filter: ImageFilter.blur(sigmaX: 25, sigmaY: 25),
                          child: Material(
                            color: Colors.transparent,
                            child: Container(
                              padding: const EdgeInsets.fromLTRB(32, 40, 32, 32),
                              decoration: BoxDecoration(
                                color: Colors.white.withOpacity(0.12),
                                borderRadius: BorderRadius.circular(28),
                                border: Border.all(
                                  color: Colors.white.withOpacity(0.18),
                                  width: 0.5,
                                ),
                                gradient: LinearGradient(
                                  begin: Alignment.topLeft,
                                  end: Alignment.bottomRight,
                                  colors: [
                                    Colors.white.withOpacity(0.15),
                                    Colors.white.withOpacity(0.08),
                                  ],
                                ),
                              ),
                              child: Column(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  // Icon
                                  Icon(
                                    Icons.logout,
                                    color: Colors.white.withOpacity(0.9),
                                    size: 48,
                                  ),
                                  const SizedBox(height: 20),
                                  // Title
                                  const Text(
                                    'Exit App?',
                                    style: TextStyle(
                                      color: Colors.white,
                                      fontSize: 22,
                                      fontWeight: FontWeight.w500,
                                      letterSpacing: 0.2,
                                    ),
                                  ),
                                  const SizedBox(height: 12),
                                  // Message
                                  Text(
                                    'Are you sure you want to leave?',
                                    textAlign: TextAlign.center,
                                    style: TextStyle(
                                      color: Colors.white.withOpacity(0.8),
                                      fontSize: 16,
                                      height: 1.5,
                                    ),
                                  ),
                                  const SizedBox(height: 28),
                                  // Buttons
                                  Row(
                                    children: [
                                      Expanded(
                                        child: GestureDetector(
                                          onTap: () => Navigator.of(dialogContext).pop(false),
                                          child: Container(
                                            padding: const EdgeInsets.symmetric(vertical: 14),
                                            decoration: BoxDecoration(
                                              color: Colors.white.withOpacity(0.15),
                                              borderRadius: BorderRadius.circular(14),
                                              border: Border.all(
                                                color: Colors.white.withOpacity(0.3),
                                                width: 0.5,
                                              ),
                                            ),
                                            child: const Text(
                                              'Cancel',
                                              textAlign: TextAlign.center,
                                              style: TextStyle(
                                                color: Colors.white,
                                                fontSize: 16,
                                                fontWeight: FontWeight.w500,
                                              ),
                                            ),
                                          ),
                                        ),
                                      ),
                                      const SizedBox(width: 12),
                                      Expanded(
                                        child: GestureDetector(
                                          onTap: () => Navigator.of(dialogContext).pop(true),
                                          child: Container(
                                            padding: const EdgeInsets.symmetric(vertical: 14),
                                            decoration: BoxDecoration(
                                              color: Colors.red.withOpacity(0.85),
                                              borderRadius: BorderRadius.circular(14),
                                              boxShadow: [
                                                BoxShadow(
                                                  color: Colors.red.withOpacity(0.3),
                                                  blurRadius: 12,
                                                  spreadRadius: 0,
                                                  offset: const Offset(0, 4),
                                                ),
                                              ],
                                            ),
                                            child: const Text(
                                              'Exit',
                                              textAlign: TextAlign.center,
                                              style: TextStyle(
                                                color: Colors.white,
                                                fontSize: 16,
                                                fontWeight: FontWeight.w600,
                                              ),
                                            ),
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );

    // If user confirmed exit, close the app
    if (shouldExit == true) {
      SystemNavigator.pop();
    }
  }

  @override
  Widget build(BuildContext context) {
    final keyboardHeight = MediaQuery.of(context).viewInsets.bottom;
    
    return MultiBlocListener(
      listeners: [
        BlocListener<AuthBloc, AuthState>(
          listener: (context, state) {
            if (state is AuthAuthenticated) {
              // Close modal on successful auth
              if (_showLoginModal) {
                _toggleLoginModal();
              }
              // Load user data
              context.read<CreditsBloc>().add(const CreditsRequested());
              
              // Load last conversation
              _loadLastThread();
            } else if (state is AuthUnauthenticated) {
              // User signed out - disconnect LiveKit and clear all chat data
              _liveKitService.disconnect();
              context.read<ChatBloc>().add(const ChatMessagesCleared());
              
              // Reset local state
              setState(() {
                _threadId = null;
                _showFollowUps = false;
                _previousFollowUps = [];
                _isGenerating = false;
                _isConnecting = false; // Not connecting when logged out
                _showUserMessageBubble = false;
                _isAudioPlaying = false;
                _currentlyPlayingMessageId = null;
              });
              
              // Close menu drawer if open
              if (_showMenuDrawer) {
                _animationController.reverse().then((_) {
                  if (mounted) {
                    setState(() {
                      _showMenuDrawer = false;
                    });
                  }
                });
              }
              
              // Close chat sidebar if open
              if (_showChatSidebar) {
                setState(() {
                  _showChatSidebar = false;
                });
              }
            } else if (state is AuthError) {
              // Show error message
              ToastUtils.showError(context, 'Failed to sign in: ${state.message}');
            }
          },
        ),
        BlocListener<ChatBloc, ChatState>(
          listener: (context, state) async {
            if (state is ChatLoaded) {
              // Update thread ID
              if (state.threadId != null) {
                _threadId = state.threadId;
              }
              
              // Restore input field if there's a pending message (after error)
              if (state.pendingMessage != null && state.pendingMessage!.isNotEmpty) {
                _textController.text = state.pendingMessage!;
                print('📝 Restored failed message to input field: ${state.pendingMessage}');
              }
              
              // Sync generating state from bloc (important after errors)
              // Only update if bloc says not generating and we're not playing audio
              if (!state.isGenerating && !_isAudioPlaying) {
                if (mounted && (_isGenerating || _showUserMessageBubble)) {
                  setState(() {
                    _isGenerating = false;
                    _showUserMessageBubble = false; // Hide user message bubble on error recovery
                  });
                  print('✅ Synced state from ChatLoaded: _isGenerating=false, _showUserMessageBubble=false');
                  
                  // IMPORTANT: Don't auto-focus text field! User should manually tap to type.
                  // Prevents keyboard from opening prematurely while Krishna is still speaking.
                }
              }
              
              // Don't reset generating flag during audio playback
              // (It will be reset after audio playback completes)
              
              // Find any unplayed AI messages and play them
              for (final message in state.messages) {
                if (message.type == 'ai' && !message.isPlayed) {
                  // Skip if we're already playing this message
                  if (_currentlyPlayingMessageId == message.id) {
                    print('⏭️ Skipping - already playing message ${message.id}');
                    break;
                  }
                  
                  print('✅ Krishna responded: ${message.content.substring(0, min(50, message.content.length))}...');
                  
                  // Check conversation mode to decide whether to play audio
                  if (_conversationMode == ConversationMode.chatChat) {
                    // CHAT_CHAT mode: Text only, no audio playback
                    print('💬 CHAT_CHAT mode: Skipping audio playback, showing text only');
                    
                    // Mark message as played immediately (no audio wait)
                    context.read<ChatBloc>().add(ChatMessagePlayedStatusUpdated(
                      messageId: message.id,
                      threadId: state.threadId!,
                      isPlayed: true,
                    ));
                    
                    // Don't set _isAudioPlaying, just reset generating state
                    if (mounted) {
                      setState(() {
                        _isGenerating = false;
                        _showUserMessageBubble = false;
                        _showFollowUps = true; // Show follow-ups immediately in text mode
                      });
                    }
                    
                    // Refresh credits
                    context.read<CreditsBloc>().add(const CreditsRefreshed());
                    break;
                  }
                  
                  // CHAT_AUDIO or AUDIO_AUDIO mode: Play audio
                  print('🎵 Playing TTS for message ID: ${message.id}');
                  
                  // Mark this message as currently playing
                  _currentlyPlayingMessageId = message.id;
                  
                  // LiveKit handles audio playback automatically.
                  // We just mark the message as played so we don't process it again.
                  context.read<ChatBloc>().add(ChatMessagePlayedStatusUpdated(
                    messageId: message.id,
                    threadId: state.threadId!,
                    isPlayed: true,
                  ));
                  
                  // Clear the currently playing message ID
                  _currentlyPlayingMessageId = null;
                  
                  // Simulate audio duration for UI updates (e.g., follow-ups)
                  // In a real scenario, you'd get this from LiveKit or the TTS service.
                  // For now, we'll use a placeholder duration.
                  const double audioDuration = 3.0; // Placeholder for 3 seconds
                  
                  // Stop showing subtitles after the actual audio duration
                  Future.delayed(Duration(milliseconds: (audioDuration * 1000).toInt()), () async {
                      if (mounted) {
                        setState(() {
                          _isAudioPlaying = false;
 // Clear alignment data too
                          _isGenerating = false; // Reset generating state after audio finishes
                        });
                        print('🔇 Subtitles hidden after ${audioDuration.toStringAsFixed(2)}s');
                        print('✅ Reset _isGenerating = false (audio finished)');
                        
                        sendToUnity("Flutter", "OnAudioChunk", "END");
                        print('🏁 END signal sent to Unity (audio playback complete)');
                        
                        // Fade out user message bubble
                        if (_showUserMessageBubble) {
                          setState(() {
                            _showUserMessageBubble = false;
                          });
                          
                          // Wait for fade-out, then fade in follow-ups
                          await Future.delayed(const Duration(milliseconds: 400));
                          
                          // Trigger follow-up animations
                          if (state.followUpQuestions.isNotEmpty) {
                            _previousFollowUps = state.followUpQuestions;
                            _showFollowUps = false;
                            // Small delay before fade-in
                            Future.delayed(const Duration(milliseconds: 50), () {
                              if (mounted) {
                                setState(() {
                                  _showFollowUps = true;
                                });
                              }
                            });
                          }
                        }
                      }
                    });
                  
                  // Refresh credits after message sent
                  context.read<CreditsBloc>().add(const CreditsRefreshed());
                  
                  // Only play one message at a time
                  break;
                }
              }
            } else if (state is ChatError) {
              // Send END signal to Unity to clean up state
              sendToUnity("Flutter", "OnAudioChunk", "END");
              print('🏁 END signal sent to Unity (ChatError cleanup)');
              
              // Handle error and reset generating flag
              if (mounted) {
                setState(() {
                  _isGenerating = false;
                  _isAudioPlaying = false;
                  _showUserMessageBubble = false;
                });
              }
              ToastUtils.showError(context, state.message);
              print('❌ Error state received, reset _isGenerating = false');
            }
          },
        ),
      ],
      child: PopScope(
        canPop: false,
        onPopInvokedWithResult: (bool didPop, dynamic result) async {
          if (didPop) return;
          
          final keyboardHeight = MediaQuery.of(context).viewInsets.bottom;
          final hasFocus = _textFocusNode.hasFocus;
          
          // Priority 1: Close keyboard if actually visible
          if (keyboardHeight > 0) {
            FocusScope.of(context).unfocus();
            _textFocusNode.unfocus();
            await SystemChannels.textInput.invokeMethod('TextInput.hide');
            return;
          }
          
          // Also unfocus if field has focus but keyboard is already hidden
          if (hasFocus) {
            FocusScope.of(context).unfocus();
            _textFocusNode.unfocus();
            // Don't return - continue to next action
          }
          
          // Priority 2: Close login modal if open
          if (_showLoginModal) {
            _toggleLoginModal();
            return;
          }
          
          // Priority 3: Close chat sidebar if open
          if (_showChatSidebar) {
            setState(() {
              _showChatSidebar = false;
            });
            return;
          }
          
          // Priority 4: Show exit confirmation dialog
          _showExitConfirmationDialog();
        },
        child: Scaffold(
          backgroundColor: Colors.black,
          resizeToAvoidBottomInset: false,
        body: GestureDetector(
          onTap: () {
            // Dismiss keyboard on tap outside (works for iOS and Android)
            if (_textFocusNode.hasFocus) {
              FocusScope.of(context).unfocus();
              _textFocusNode.unfocus();
              SystemChannels.textInput.invokeMethod('TextInput.hide');
            }
          },
          behavior: HitTestBehavior.translucent,
          child: Stack(
          children: [
            // RepaintBoundary for widget recording
            Positioned.fill(
              child: RepaintBoundary(
                key: _repaintBoundaryKey,
                child: Stack(
                  children: [
                    // Unity avatar - full screen background
                    const Positioned.fill(
                      child: EmbedUnity(),
                    ),
                    
                    // User message - shows at top right after sending
                    if (_showUserMessageBubble && _lastUserMessage != null)
                      Positioned(
                        top: 100,
                        right: 20,
                        left: 20,
                        child: AnimatedOpacity(
                          opacity: _showUserMessageBubble ? 1.0 : 0.0,
                          duration: const Duration(milliseconds: 300),
                          child: Padding(
                            padding: const EdgeInsets.only(top: 20, right: 80),
                            child: Text(
                              _lastUserMessage!,
                              textAlign: TextAlign.left,
                              style: TextStyle(
                                color: Colors.white.withOpacity(0.9),
                                fontSize: 16,
                                height: 1.5,
                                fontWeight: FontWeight.w400,
                              ),
                            ),
                          ),
                        ),
                      ),
                    
                  ],
                ),
              ),
            ),
            
            // Top bar with menu and login
            Positioned(
              top: 0,
              left: 0,
              right: 0,
              child: SafeArea(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
                  child: Column(
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                      // Menu button (opens chat) - only when authenticated and not recording
                      BlocBuilder<AuthBloc, AuthState>(
                        builder: (context, state) {
                          if (state is AuthAuthenticated && !_isScreenRecording) {
                            return GestureDetector(
                              onTap: () {
                                // Toggle chat sidebar
                                if (_showChatSidebar) {
                                  // Cancel timer when closing overlay
                                  _chipAutoHideTimer?.cancel();
                                  _animationController.reverse().then((_) {
                                    if (mounted) {
                                      setState(() {
                                        _showChatSidebar = false;
                                      });
                                    }
                                  });
                                } else {
                                  setState(() {
                                    _showChatSidebar = true;
                                    _showChip = false; // Start hidden
                                    _conversationMode = ConversationMode.chatChat; // Past chats: Text input → Text output (no audio)
                                  });
                                  _animationController.forward();
                                  // Show chip after overlay starts animating
                                  Future.delayed(const Duration(milliseconds: 100), () {
                                    if (mounted && _showChatSidebar) {
                                      setState(() {
                                        _showChip = true;
                                      });
                                      _startInitialGracePeriod(); // 3s grace period before scroll behavior
                                      _startChipAutoHideTimer(); // Start fresh 5s timer
                                    }
                                  });
                                }
                              },
                              child: Container(
                                width: 44,
                                height: 44,
                                decoration: BoxDecoration(
                                  borderRadius: BorderRadius.circular(12),
                                  border: Border.all(
                                    color: Colors.white.withOpacity(0.3),
                                    width: 1.5,
                                  ),
                                  boxShadow: [
                                    BoxShadow(
                                      color: Colors.black.withOpacity(0.2),
                                      blurRadius: 8,
                                      offset: const Offset(0, 2),
                                    ),
                                  ],
                                ),
                                child: const Center(
                                  child: Icon(
                                    Icons.view_sidebar_outlined,
                                    color: Colors.white,
                                    size: 20,
                                  ),
                                ),
                              ),
                            );
                          }
                          return const SizedBox.shrink();
                        },
                      ),
                      // Right side - Profile or Login (hide during recording)
                      BlocBuilder<AuthBloc, AuthState>(
                        builder: (context, state) {
                          if (state is AuthAuthenticated && !_isScreenRecording) {
                            return ProfileAvatarWidget(
                              onTap: () {
                                setState(() {
                                  _showMenuDrawer = true;
                                });
                                _animationController.forward();
                              },
                            );
                          }
                          if (_isScreenRecording) {
                            return const SizedBox.shrink();
                          }
                          return GlassButton(
                            onTap: _toggleLoginModal,
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: const [
                                Icon(Icons.meeting_room,
                                    color: Colors.white, size: 20),
                                SizedBox(width: 8),
                                Text(
                                  'Login',
                                  style: TextStyle(
                                    color: Colors.white,
                                    fontSize: 16,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                              ],
                            ),
                          );
                        },
                      ),
                    ],
                  ),
                  // Recording button - appears below profile avatar when authenticated
                  // Hidden when recording is active (tap the "Recording" indicator to stop)
                  BlocBuilder<AuthBloc, AuthState>(
                    builder: (context, state) {
                      if (state is AuthAuthenticated && !_isScreenRecording) {
                        return Padding(
                          padding: const EdgeInsets.only(top: 12),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.end,
                            children: [
                              GestureDetector(
                                onTap: _toggleScreenRecording,
                                child: Container(
                                  width: 44,
                                  height: 44,
                                  decoration: BoxDecoration(
                                    gradient: LinearGradient(
                                      colors: [
                                        Colors.white.withOpacity(0.2),
                                        Colors.white.withOpacity(0.1),
                                      ],
                                    ),
                                    borderRadius: BorderRadius.circular(12),
                                    border: Border.all(
                                      color: Colors.white.withOpacity(0.3),
                                      width: 1.5,
                                    ),
                                    boxShadow: [
                                      BoxShadow(
                                        color: Colors.black.withOpacity(0.2),
                                        blurRadius: 8,
                                        offset: const Offset(0, 2),
                                      ),
                                    ],
                                  ),
                                  child: Center(
                                    child: Icon(
                                      Icons.fiber_manual_record,
                                      color: Colors.red,
                                      size: 24,
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        );
                      }
                      return const SizedBox.shrink();
                    },
                  ),
                ],
              ),
                ),
              ),
            ),
            
            // Chat Sidebar
            if (_showChatSidebar)
              FadeTransition(
                opacity: _fadeAnimation,
                child: ChatSidebar(
                  scrollController: _scrollController,
                  onClose: () {
                    _chipAutoHideTimer?.cancel(); // Cancel timer when closing
                    _animationController.reverse().then((_) {
                      setState(() {
                        _showChatSidebar = false;
                        _conversationMode = ConversationMode.chatAudio; // Back to default: Text input → Audio output
                      });
                    });
                  },
                  onFollowUpTap: (question) {
                    _textController.text = question;
                    _sendMessage(question, context);
                  },
                ),
              ),
            
            // Bottom input area (always visible, below overlays)
            Positioned(
                left: 0,
                right: 0,
                bottom: keyboardHeight,
                child: SafeArea(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      // Follow-up questions chips (horizontal scroll)
                      BlocBuilder<ChatBloc, ChatState>(
                        builder: (context, state) {
                          if (state is ChatLoaded && 
                              state.followUpQuestions.isNotEmpty && 
                              !_showChatSidebar) {
                            // Detect new follow-ups
                            if (_previousFollowUps != state.followUpQuestions) {
                              _previousFollowUps = state.followUpQuestions;
                              // Only show immediately if we're not currently processing a message
                              // (i.e., no user message bubble showing and not generating)
                              if (!_showUserMessageBubble && !state.isGenerating && !_isAudioPlaying) {
                                _showFollowUps = false;
                                Future.delayed(const Duration(milliseconds: 50), () {
                                  if (mounted && !_showUserMessageBubble && !_isAudioPlaying) {
                                    setState(() {
                                      _showFollowUps = true;
                                    });
                                  }
                                });
                              }
                            }
                            return AnimatedOpacity(
                              opacity: _showFollowUps ? 1.0 : 0.0,
                              duration: const Duration(milliseconds: 400),
                              child: Padding(
                                padding: const EdgeInsets.only(bottom: 10),
                                child: SizedBox(
                                  height: 36,
                                  child: ListView.builder(
                                scrollDirection: Axis.horizontal,
                                padding: const EdgeInsets.symmetric(horizontal: 10),
                                itemCount: state.followUpQuestions.length,
                                itemBuilder: (context, index) {
                                  final question = state.followUpQuestions[index];
                                  return Padding(
                                    padding: const EdgeInsets.only(right: 8),
                                    child: GestureDetector(
                                      onTap: () async {
                                        // Fade out chips first
                                        setState(() {
                                          _showFollowUps = false;
                                        });
                                        // Wait for fade-out animation
                                        await Future.delayed(const Duration(milliseconds: 300));
                                        _textController.text = question;
                                        _sendMessage(question, context);
                                      },
                                      child: Container(
                                        padding: const EdgeInsets.symmetric(
                                          horizontal: 14,
                                          vertical: 8,
                                        ),
                                        decoration: BoxDecoration(
                                          gradient: LinearGradient(
                                            colors: [
                                              Colors.white.withOpacity(0.2),
                                              Colors.white.withOpacity(0.1),
                                            ],
                                          ),
                                          borderRadius: BorderRadius.circular(18),
                                          border: Border.all(
                                            color: Colors.white.withOpacity(0.3),
                                            width: 1,
                                          ),
                                        ),
                                        child: Text(
                                          question,
                                          style: TextStyle(
                                            color: Colors.white.withOpacity(0.9),
                                            fontSize: 13,
                                            fontWeight: FontWeight.w500,
                                          ),
                                        ),
                                      ),
                                    ),
                                  );
                                },
                              ),
                            ),
                            ),
                            );
                          } else {
                            // Reset animation state when follow-ups are gone
                            if (_previousFollowUps.isNotEmpty) {
                              _previousFollowUps = [];
                              _showFollowUps = false;
                            }
                          }
                          return const SizedBox.shrink();
                        },
                      ),
                    BottomInputBar(
                      textController: _textController,
                      focusNode: _textFocusNode,
                      isConnecting: _isConnecting,
                      isGenerating: _isGenerating,
                      isRecording: _isRecording,
                      isAudioPlaying: _isAudioPlaying,
                      onSubmit: (value) => _sendMessage(value, context),
                      onMicTap: _toggleListening,
                    ),
                  ],
                ),
              ),
            ),
            
            // Menu Drawer (Profile settings) - renders on top of input bar
            if (_showMenuDrawer)
              FadeTransition(
                opacity: _fadeAnimation,
                child: MenuDrawer(
                  onClose: () {
                    _animationController.reverse().then((_) {
                      setState(() {
                        _showMenuDrawer = false;
                      });
                    });
                  },
                ),
              ),
            
            // Login Modal Overlay - renders on top of input bar
            if (_showLoginModal)
              FadeTransition(
                opacity: _fadeAnimation,
                child: BlocBuilder<AuthBloc, AuthState>(
                  builder: (context, state) {
                    return LoginModal(
                      onClose: _toggleLoginModal,
                      onGoogleSignIn: _handleGoogleSignIn,
                      isSigningIn: state is AuthLoading,
                    );
                  },
                ),
              ),
          ],
        ),
        ), // Close GestureDetector
      ),
        ), // Close Scaffold and PopScope
    );
  }


  Future<void> _startListening() async {
    // Request microphone permission
    final status = await Permission.microphone.request();
    if (!status.isGranted) {
      if (mounted) {
        ToastUtils.showError(context, 'Microphone permission required');
      }
      return;
    }

    try {
      // Enable microphone for AUDIO_AUDIO mode (speak → Krishna speaks)
      await _liveKitService.setMicrophoneEnabled(true);
      print('🎙️ Microphone enabled - switching to AUDIO_AUDIO mode');
      
      if (mounted) {
        setState(() {
          _isRecording = true;
          _conversationMode = ConversationMode.audioAudio; // Voice input → Voice output
        });
      }
    } catch (e) {
      print('❌ Error enabling microphone: $e');
      if (mounted) {
        ToastUtils.showError(context, 'Failed to enable microphone');
      }
    }
  }

  Future<void> _stopListening() async {
    try {
      // Disable microphone and switch back to CHAT_AUDIO mode (type → Krishna speaks)
      await _liveKitService.setMicrophoneEnabled(false);
      print('💬 Microphone disabled - switching back to CHAT_AUDIO mode');
      
      if (mounted) {
        setState(() {
          _isRecording = false;
          _conversationMode = ConversationMode.chatAudio; // Text input → Audio output
        });
      }
    } catch (e) {
      print('❌ Error disabling microphone: $e');
    }
  }

  Future<void> _toggleListening() async {
    // Check if user is authenticated
    final isAuthenticated = await _backendApi.isAuthenticated();
    if (!isAuthenticated) {
      if (mounted) {
        _toggleLoginModal();
      }
      return;
    }
    
    if (_isRecording) {
      _stopListening();
    } else {
      _startListening();
    }
  }

  Future<void> _sendMessage(String text, BuildContext context) async {
    if (text.trim().isEmpty) return;

    // Check if user is authenticated
    final isAuthenticated = await _backendApi.isAuthenticated();
    if (!isAuthenticated) {
      if (mounted) {
        // Dismiss keyboard before showing login modal
        FocusScope.of(context).unfocus();
        _textFocusNode.unfocus();
        SystemChannels.textInput.invokeMethod('TextInput.hide');
        
        // Show info and login modal
        ToastUtils.showInfo(context, 'Please sign in to chat with Krishna');
        _toggleLoginModal();
      }
      return;
    }

    setState(() {
      _isGenerating = true;
      _lastUserMessage = text;
      _showUserMessageBubble = true;
      _showFollowUps = false; // Hide follow-ups when sending message
    });
    
    // Start timeout for stuck pondering state
    _generatingTimeout?.cancel();
    _generatingTimeout = Timer(_generatingTimeoutDuration, () {
      if (mounted && _isGenerating) {
        print('⏰ Pondering timeout! Resetting state');
        setState(() {
          _isGenerating = false;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('Response timeout - please try again'),
            backgroundColor: Colors.orange.shade700,
            duration: const Duration(seconds: 3),
          ),
        );
      }
    });
    
    // IMPORTANT: Unfocus text field after sending message to prevent keyboard from reopening
    // The keyboard will only open when user explicitly taps the input field
    if (_textFocusNode.hasFocus) {
      _textFocusNode.unfocus();
      FocusScope.of(context).unfocus();
      print('⌨️ Unfocused text field after sending message (prevents keyboard reopening)');
    }

    // Clear input field immediately
    _textController.clear();

    print('📨 Sending message via ChatBloc: $text');
    
    // Send message via ChatBloc - the BlocListener will handle the response
    context.read<ChatBloc>().add(ChatMessageSent(
      message: text,
      threadId: _threadId,
    ));
  }

  void _showRecordingIndicator() {
    _recordingIndicatorOverlay = OverlayEntry(
      builder: (context) => RecordingIndicator(
        startTime: _recordingStartTime ?? DateTime.now(),
        maxDurationSeconds: _maxRecordingDurationMinutes * 60,
        onTap: () {
          // Tapping the recording indicator stops the recording
          _toggleScreenRecording();
        },
      ),
    );
    Overlay.of(context).insert(_recordingIndicatorOverlay!);
  }

  void _removeRecordingIndicator() {
    _recordingIndicatorOverlay?.remove();
    _recordingIndicatorOverlay = null;
  }

  Future<void> _toggleScreenRecording() async {
    if (_isScreenRecording) {
      // Show processing dialog
      if (!mounted) return;
      
      String processingMessage = 'Processing frames...';
      
      // Show modal dialog
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (BuildContext dialogContext) {
          return StatefulBuilder(
            builder: (context, setDialogState) {
              // Update dialog state when processing message changes
              _screenRecordingService.setProcessingCallback((message) {
                processingMessage = message;
                setDialogState(() {});
              });
              
              return WillPopScope(
                onWillPop: () async => false,
                child: AlertDialog(
                  backgroundColor: Colors.black.withOpacity(0.9),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(20),
                    side: BorderSide(color: Colors.white.withOpacity(0.2)),
                  ),
                  content: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const CircularProgressIndicator(
                        color: Colors.white,
                      ),
                      const SizedBox(height: 20),
                      Text(
                        processingMessage,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 16,
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ],
                  ),
                ),
              );
            },
          );
        },
      );
      
      // Stop recording
      String? path = await _screenRecordingService.stopRecording();
      
      // Close processing dialog
      if (mounted) {
        Navigator.of(context).pop();
      }
      
      // Cancel auto-stop timer
      _recordingAutoStopTimer?.cancel();
      _recordingAutoStopTimer = null;
      
      setState(() {
        _isScreenRecording = false;
        _recordingStartTime = null;
      });
      
      _removeRecordingIndicator();

      if (path != null && mounted) {
        // Show preview overlay
        await Future.delayed(const Duration(milliseconds: 300));
        if (mounted) {
          RecordingPreviewOverlay.show(context, path);
        }
      } else {
        if (mounted) {
          ToastUtils.showError(context, 'Failed to save recording');
        }
      }
    } else {
      // Start recording with microphone audio
      bool started = await _screenRecordingService.startRecording();
      
      if (started) {
        setState(() {
          _isScreenRecording = true;
          _recordingStartTime = DateTime.now();
        });
        
        // Start auto-stop timer (max recording duration)
        _recordingAutoStopTimer = Timer(
          Duration(minutes: _maxRecordingDurationMinutes),
          () async {
            if (_isScreenRecording && mounted) {
              debugPrint('⏱️ Auto-stopping recording after $_maxRecordingDurationMinutes minutes');
              await _toggleScreenRecording();
              if (mounted) {
                ToastUtils.showInfo(
                  context,
                  'Recording stopped (max duration reached)',
                );
              }
            }
          },
        );
        
        // Show recording indicator
        await Future.delayed(const Duration(milliseconds: 100));
        if (mounted) {
          _showRecordingIndicator();
        }
      } else {
        if (mounted) {
          ToastUtils.showError(
            context,
            'Failed to start recording. Please check permissions.',
          );
        }
      }
    }
  }

  @override
  void dispose() {
    _textController.dispose();
    _textFocusNode.dispose();
    _scrollController.dispose();
    _animationController.dispose();
    _chipAutoHideTimer?.cancel();
    _recordingAutoStopTimer?.cancel(); // Cancel recording auto-stop timer
    _generatingTimeout?.cancel(); // Cancel pondering timeout
    _removeRecordingIndicator();
    super.dispose();
  }
}

class Route2 extends StatelessWidget {

  const Route2({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
        appBar: AppBar(
          title: const Text('Route 2'),
        ),
        body: SafeArea(
          child: Builder(
              builder: (context) =>
                  Column(
                    children: [
                      const Padding(
                        padding: EdgeInsets.all(16),
                        child: Text(
                          "Unity can only be shown in 1 widget at a time. Therefore if a second route "
                              "with a FlutterEmbed is pushed onto the stack, Unity is 'detached' from "
                              "the first route, and attached to the second. When the second route is "
                              "popped from the stack, Unity is reattached to the first route.",
                        ),
                      ),
                      const Expanded(
                        child: EmbedUnity(),
                      ),
                      Padding(
                        padding: const EdgeInsets.all(8.0),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            const BackButton(),
                            ElevatedButton(
                              onPressed: () {
                                showDialog(context: context, builder: (_) => const Route3());
                              },
                              child: const Text("Open route 3", textAlign: TextAlign.center),
                            ),
                          ],
                        ),
                      )
                    ],
                  )
          ),
        )
    );
  }
}


class Route3 extends StatelessWidget {

  const Route3({super.key});

  @override
  Widget build(BuildContext context) {
    return const AlertDialog(
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            "Route 3",
            textAlign: TextAlign.center,
          ),
          SizedBox(
            height: 100,
            width: 80,
            child: EmbedUnity(),
          ),
        ],
      ),
    );
  }
}