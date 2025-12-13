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
import 'elevenlabs_service.dart';
import 'audio_streamer.dart';
import 'services/backend_api_service.dart';
import 'services/cache_service.dart';
import 'models/cached_message.dart';
import 'models/alignment_data.dart';
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
import 'package:speech_to_text/speech_to_text.dart' as stt;
import 'package:permission_handler/permission_handler.dart';
import 'utils/toast_utils.dart';
import 'theme/app_theme.dart';

// Global cache service
late final CacheService cacheService;

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

  runApp(const ExampleApp());
}

class ExampleApp extends StatelessWidget {
  const ExampleApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiBlocProvider(
      providers: [
        BlocProvider(create: (context) => AuthBloc()),
        BlocProvider(create: (context) => ChatBloc(cacheService: cacheService)),
        BlocProvider(create: (context) => CreditsBloc()),
        BlocProvider(create: (context) => MemoryBloc()),
      ],
      child: MaterialApp(
        debugShowCheckedModeBanner: false,
        theme: AppTheme.darkTheme,
        // Respect system text scaling for accessibility
        builder: (context, child) {
          return MediaQuery(
            // Limit text scale factor to prevent breaking UI
            data: MediaQuery.of(context).copyWith(
              textScaleFactor:
                  MediaQuery.of(context).textScaleFactor.clamp(0.8, 1.3),
            ),
            child: child!,
          );
        },
        home: const _MainScreen(),
      ),
    );
  }
}

class _MainScreen extends StatefulWidget {
  const _MainScreen();

  @override
  State<_MainScreen> createState() => _MainScreenState();
}

class _MainScreenState extends State<_MainScreen>
    with SingleTickerProviderStateMixin {
  final TextEditingController _textController = TextEditingController();
  final FocusNode _textFocusNode = FocusNode();
  final BackendApiService _backendApi = BackendApiService();
  final ScrollController _scrollController = ScrollController();
  late AudioStreamer _audioStreamer;
  late stt.SpeechToText _speechToText;
  bool _isGenerating = false;
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
  List<String> _previousFollowUps =
      []; // Track previous follow-ups for animation
  bool _showFollowUps = false; // Control fade-in animation
  String? _lastUserMessage; // Track last sent message
  bool _showUserMessageBubble = false; // Control user message bubble visibility

  // Subtitle state
  AlignmentData? _currentAlignment;
  bool _isAudioPlaying = false;

  // Track currently playing message to prevent duplicates
  String? _currentlyPlayingMessageId;

  // Language selection
  String _selectedLanguage = 'telugu'; // 'telugu' or 'english'

  @override
  void initState() {
    super.initState();

    // Initialize ElevenLabs service to call backend TTS proxy (keeps API key secure)
    final elevenLabsService = ElevenLabsService(
      backendUrl: BackendApiService.baseUrl,
      getAuthToken: () => _backendApi.getAccessToken(),
    );
    _audioStreamer = AudioStreamer(elevenLabsService);

    // Initialize speech to text
    _speechToText = stt.SpeechToText();

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

    // Set initial Unity avatar state to listening
    _updateUnityAvatarState();
  }

  /// Updates Unity avatar state based on current Flutter app state
  /// - "listening" = default/idle state
  /// - "thinking" = when _isGenerating is true (pondering response)
  /// - "speaking" = when _isAudioPlaying is true (narrating response)
  void _updateUnityAvatarState() {
    String state;

    if (_isAudioPlaying) {
      state = "speaking";
    } else if (_isGenerating) {
      state = "thinking";
    } else {
      state = "listening";
    }

    try {
      sendToUnity("Flutter", "AvatarState", state);
      print('🎭 Unity avatar state changed to: $state');
    } catch (e) {
      print('⚠️ Failed to update Unity avatar state: $e');
    }
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
    const hideThreshold = 20.0; // Hide chip when within 20px of bottom

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
      const avatarId =
          '12a65bd0-d264-479d-a5a4-ce0bdabdbcf9'; // Sai Baba's avatar ID

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
        print('📤 Dispatching ChatHistoryRequested for thread: $threadId');
        context.read<ChatBloc>().add(ChatHistoryRequested(threadId));
      } else {
        print(
            '❌ No thread ID found (Supabase: ${response?['id']}, Cache: $cachedThreadId)');
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
                  onTap:
                      () {}, // Prevent closing when tapping the modal content
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
                              padding:
                                  const EdgeInsets.fromLTRB(32, 40, 32, 32),
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
                                    color: Colors.white.withOpacity(0.92),
                                    size: 46,
                                  ),
                                  const SizedBox(height: 22),
                                  // Title
                                  Text(
                                    'Exit App?',
                                    style: Theme.of(context)
                                        .textTheme
                                        .headlineMedium
                                        ?.copyWith(
                                          color: Colors.white,
                                        ),
                                  ),
                                  const SizedBox(height: 14),
                                  // Message
                                  Text(
                                    'Are you sure you want to leave?',
                                    textAlign: TextAlign.center,
                                    style: Theme.of(context)
                                        .textTheme
                                        .bodyLarge
                                        ?.copyWith(
                                          color: Colors.white.withOpacity(0.78),
                                        ),
                                  ),
                                  const SizedBox(height: 30),
                                  // Buttons
                                  Row(
                                    children: [
                                      Expanded(
                                        child: GestureDetector(
                                          onTap: () =>
                                              Navigator.of(dialogContext)
                                                  .pop(false),
                                          child: Container(
                                            padding: const EdgeInsets.symmetric(
                                                vertical: 15),
                                            decoration: BoxDecoration(
                                              color: Colors.white
                                                  .withOpacity(0.14),
                                              borderRadius:
                                                  BorderRadius.circular(16),
                                              border: Border.all(
                                                color: Colors.white
                                                    .withOpacity(0.28),
                                                width: 0.6,
                                              ),
                                            ),
                                            child: Text(
                                              'Cancel',
                                              textAlign: TextAlign.center,
                                              style: AppTheme.title(context),
                                            ),
                                          ),
                                        ),
                                      ),
                                      const SizedBox(width: 12),
                                      Expanded(
                                        child: GestureDetector(
                                          onTap: () =>
                                              Navigator.of(dialogContext)
                                                  .pop(true),
                                          child: Container(
                                            padding: const EdgeInsets.symmetric(
                                                vertical: 15),
                                            decoration: BoxDecoration(
                                              color:
                                                  Colors.red.withOpacity(0.88),
                                              borderRadius:
                                                  BorderRadius.circular(16),
                                              boxShadow: [
                                                BoxShadow(
                                                  color: Colors.red
                                                      .withOpacity(0.32),
                                                  blurRadius: 14,
                                                  spreadRadius: 0,
                                                  offset: const Offset(0, 5),
                                                ),
                                              ],
                                            ),
                                            child: Text(
                                              'Exit',
                                              textAlign: TextAlign.center,
                                              style: AppTheme.title(context)
                                                  .copyWith(
                                                fontWeight: FontWeight.w700,
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
              // User signed out - clear all chat data
              context.read<ChatBloc>().add(const ChatMessagesCleared());

              // Reset local state
              setState(() {
                _threadId = null;
                _showFollowUps = false;
                _previousFollowUps = [];
                _isGenerating = false;
                _showUserMessageBubble = false;
                _currentAlignment = null;
                _isAudioPlaying = false;
                _currentlyPlayingMessageId = null;
              });

              // Update Unity avatar to listening state
              _updateUnityAvatarState();

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
              ToastUtils.showError(
                  context, 'Failed to sign in: ${state.message}');
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
              if (state.pendingMessage != null &&
                  state.pendingMessage!.isNotEmpty) {
                _textController.text = state.pendingMessage!;
                print(
                    '📝 Restored failed message to input field: ${state.pendingMessage}');
              }

              // Sync generating state from bloc (important after errors)
              // Only update if bloc says not generating and we're not playing audio
              if (!state.isGenerating && !_isAudioPlaying) {
                if (mounted && (_isGenerating || _showUserMessageBubble)) {
                  setState(() {
                    _isGenerating = false;
                    _showUserMessageBubble =
                        false; // Hide user message bubble on error recovery
                  });
                  print(
                      '✅ Synced state from ChatLoaded: _isGenerating=false, _showUserMessageBubble=false');

                  // Update Unity avatar to listening state
                  _updateUnityAvatarState();
                }
              }

              // Don't reset generating flag during audio playback
              // (It will be reset after audio playback completes)

              // Find any unplayed AI messages and play them
              for (final message in state.messages) {
                if (message.type == 'ai' && !message.isPlayed) {
                  // Skip if we're already playing this message
                  if (_currentlyPlayingMessageId == message.id) {
                    print(
                        '⏭️ Skipping - already playing message ${message.id}');
                    break;
                  }

                  print(
                      '✅ Sai Baba responded: ${message.content.substring(0, min(50, message.content.length))}...');
                  print('🎵 Playing TTS for message ID: ${message.id}');

                  // Mark this message as currently playing
                  _currentlyPlayingMessageId = message.id;

                  // Generate TTS with subtitles
                  try {
                    print('🎤 Generating TTS with timestamps...');
                    print('📝 Text for TTS: "${message.content}"');
                    print('📝 Text length: ${message.content.length} chars');

                    // Clear previous alignment and start audio playback immediately
                    // Set _isGenerating = false so status shows "Narrating..." (not "Pondering...")
                    // Track when streaming starts to calculate correct wait time
                    final streamingStartTime = DateTime.now();

                    if (mounted) {
                      setState(() {
                        _currentAlignment = null;
                        _isAudioPlaying =
                            true; // Start showing subtitles immediately
                        _isGenerating =
                            false; // IMPORTANT: Set to false so "Narrating..." shows (not "Pondering...")
                        _showFollowUps =
                            false; // Hide follow-ups when audio starts
                      });
                      print(
                          '🔊 Set _isAudioPlaying = true at $streamingStartTime');
                      print(
                          '🎵 Set _isGenerating = false (will show "Narrating..." in status)');

                      // Update Unity avatar to speaking state
                      _updateUnityAvatarState();
                    }

                    // Content is already parsed in ChatMessage.fromJson, use directly
                    final consolidatedAlignment =
                        await _audioStreamer.streamToUnity(
                      message.content,
                      language: _selectedLanguage, // Pass selected language
                      onAlignmentUpdate: (alignment) {
                        // Update alignment data as chunks arrive - subtitles will update in real-time
                        if (mounted) {
                          setState(() {
                            _currentAlignment = alignment;
                          });
                        }
                      },
                    );
                    print(
                        '✅ Audio sent to Unity with ${_currentAlignment?.characters.length ?? 0} characters');
                    print(
                        '🎵 All audio chunks sent - Unity is playing with synced subtitles');

                    // Use actual audio duration from PCM bytes (includes all audio, even without alignment)
                    double audioDuration =
                        consolidatedAlignment.actualAudioDurationSeconds;
                    // Add a small buffer (0.5s) to ensure audio finishes
                    audioDuration += 0.5;
                    print(
                        '📊 Audio duration: ${audioDuration.toStringAsFixed(2)}s');

                    if (_currentAlignment == null ||
                        _currentAlignment!.characterEndTimesSeconds.isEmpty) {
                      print(
                          '⚠️ No alignment data, but audio duration is ${audioDuration}s from PCM bytes');
                    }

                    // Mark message as played
                    if (_threadId != null) {
                      context
                          .read<ChatBloc>()
                          .add(ChatMessagePlayedStatusUpdated(
                            messageId: message.id,
                            threadId: _threadId!,
                            isPlayed: true,
                          ));
                      print('✅ Marked message ${message.id} as played');
                    }

                    // Clear the currently playing message ID
                    _currentlyPlayingMessageId = null;

                    // Calculate how much time has elapsed since streaming started
                    // Unity starts playing when first batches arrive (during streaming), not after
                    final elapsedTime =
                        DateTime.now().difference(streamingStartTime);
                    final elapsedSeconds = elapsedTime.inMilliseconds / 1000.0;
                    final remainingTime = audioDuration - elapsedSeconds;

                    print(
                        '⏱️ Time elapsed since streaming started: ${elapsedSeconds.toStringAsFixed(2)}s');
                    print(
                        '🎵 Total audio duration: ${audioDuration.toStringAsFixed(2)}s');
                    print(
                        '⏳ Remaining time to wait: ${remainingTime.toStringAsFixed(2)}s');

                    // Only wait if there's remaining time (audio might already be done!)
                    if (remainingTime > 0) {
                      await Future.delayed(Duration(
                          milliseconds: (remainingTime * 1000).toInt()));
                    } else {
                      print('✅ Audio already finished! No need to wait.');
                    }

                    if (mounted) {
                      setState(() {
                        _isAudioPlaying = false;
                        _currentAlignment = null; // Clear alignment data
                        // _isGenerating already set to false when audio started
                      });
                      print('🔇 Audio playback complete, state reset');

                      // Update Unity avatar to listening state
                      _updateUnityAvatarState();

                      sendToUnity("Flutter", "OnAudioChunk", "END");
                      print(
                          '🏁 END signal sent to Unity (audio playback complete)');

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
                  } catch (e) {
                    print('❌ TTS Error: $e');
                    // Clear the currently playing message ID on error
                    _currentlyPlayingMessageId = null;

                    // Send END signal to Unity to clean up state
                    sendToUnity("Flutter", "OnAudioChunk", "END");
                    print('🏁 END signal sent to Unity (error cleanup)');

                    // Hide subtitles immediately on error
                    if (mounted) {
                      setState(() {
                        _isAudioPlaying = false;
                        _currentAlignment = null;
                        _showUserMessageBubble =
                            false; // Hide user message on error
                        _isGenerating =
                            false; // Reset generating state on error
                      });

                      // Update Unity avatar to listening state
                      _updateUnityAvatarState();

                      // Show follow-ups after a delay
                      Future.delayed(const Duration(milliseconds: 400), () {
                        if (state.followUpQuestions.isNotEmpty && mounted) {
                          setState(() {
                            _showFollowUps = true;
                          });
                        }
                      });
                    }
                  }

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

                // Update Unity avatar to listening state
                _updateUnityAvatarState();
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
            onVerticalDragStart: (_) {
              // Dismiss keyboard on vertical drag (swipe)
              FocusScope.of(context).unfocus();
            },
            child: Stack(
              children: [
                // Liquid glass background layer
                Positioned.fill(
                  child: Container(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                        colors: [
                          const Color(0xFF0A1628), // Deep navy
                          const Color(0xFF0D2847), // Dark blue
                          const Color(0xFF1A3A5C), // Medium blue
                        ],
                      ),
                    ),
                  ),
                ),

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
                                padding:
                                    const EdgeInsets.only(top: 20, right: 80),
                                child: Text(
                                  _lastUserMessage!,
                                  textAlign: TextAlign.left,
                                  style: AppTheme.body(
                                    context,
                                    color: Colors.white.withOpacity(0.92),
                                    height: 1.5,
                                  ).copyWith(fontWeight: FontWeight.w500),
                                ),
                              ),
                            ),
                          ),

                        // Subtitles disabled
                        // if (_isAudioPlaying && _currentAlignment != null)
                        //   SubtitleWidget(
                        //     alignment: _currentAlignment,
                        //     isPlaying: _isAudioPlaying,
                        //   ),
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
                      padding: const EdgeInsets.symmetric(
                          horizontal: 20, vertical: 16),
                      child: Column(
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              // Menu button (opens chat) - only when authenticated and not recording
                              BlocBuilder<AuthBloc, AuthState>(
                                builder: (context, state) {
                                  if (state is AuthAuthenticated &&
                                      !_isScreenRecording) {
                                    return GestureDetector(
                                      onTap: () {
                                        // Toggle chat sidebar
                                        if (_showChatSidebar) {
                                          // Cancel timer when closing overlay
                                          _chipAutoHideTimer?.cancel();
                                          _animationController
                                              .reverse()
                                              .then((_) {
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
                                          });
                                          _animationController.forward();
                                          // Show chip after overlay starts animating
                                          Future.delayed(
                                              const Duration(milliseconds: 100),
                                              () {
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
                                          borderRadius:
                                              BorderRadius.circular(13),
                                          border: Border.all(
                                            color:
                                                Colors.white.withOpacity(0.32),
                                            width: 1.2,
                                          ),
                                          boxShadow: [
                                            BoxShadow(
                                              color: Colors.black
                                                  .withOpacity(0.18),
                                              blurRadius: 10,
                                              offset: const Offset(0, 3),
                                            ),
                                          ],
                                        ),
                                        child: Center(
                                          child: Icon(
                                            Icons.view_sidebar_outlined,
                                            color:
                                                Colors.white.withOpacity(0.95),
                                            size: 19,
                                          ),
                                        ),
                                      ),
                                    );
                                  }
                                  return const SizedBox.shrink();
                                },
                              ),
                              // Right side - Language dropdown, Profile or Login (hide during recording)
                              BlocBuilder<AuthBloc, AuthState>(
                                builder: (context, state) {
                                  if (state is AuthAuthenticated &&
                                      !_isScreenRecording) {
                                    return Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        // Language Selection Button
                                        GlassButton(
                                          onTap: () =>
                                              _showLanguageSelectionDialog(),
                                          child: Row(
                                            mainAxisSize: MainAxisSize.min,
                                            children: [
                                              Icon(
                                                Icons.language,
                                                color: Colors.white,
                                                size: 18,
                                              ),
                                              const SizedBox(width: 6),
                                              Text(
                                                _selectedLanguage == 'telugu'
                                                    ? 'Telugu'
                                                    : 'English',
                                                style: AppTheme.body(context)
                                                    .copyWith(
                                                  fontWeight: FontWeight.w500,
                                                  fontSize: 14,
                                                ),
                                              ),
                                            ],
                                          ),
                                        ),
                                        const SizedBox(width: 12),
                                        ProfileAvatarWidget(
                                          onTap: () {
                                            setState(() {
                                              _showMenuDrawer = true;
                                            });
                                            _animationController.forward();
                                          },
                                        ),
                                      ],
                                    );
                                  }
                                  if (_isScreenRecording) {
                                    return const SizedBox.shrink();
                                  }
                                  return GlassButton(
                                    onTap: _toggleLoginModal,
                                    child: Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        const Icon(Icons.meeting_room,
                                            color: Colors.white, size: 20),
                                        const SizedBox(width: 8),
                                        Text(
                                          'Login',
                                          style:
                                              AppTheme.title(context).copyWith(
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
                              if (state is AuthAuthenticated &&
                                  !_isScreenRecording) {
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
                                                Colors.white.withOpacity(0.18),
                                                Colors.white.withOpacity(0.10),
                                              ],
                                            ),
                                            borderRadius:
                                                BorderRadius.circular(13),
                                            border: Border.all(
                                              color: Colors.white
                                                  .withOpacity(0.32),
                                              width: 1.2,
                                            ),
                                            boxShadow: [
                                              BoxShadow(
                                                color: Colors.black
                                                    .withOpacity(0.18),
                                                blurRadius: 10,
                                                offset: const Offset(0, 3),
                                              ),
                                            ],
                                          ),
                                          child: Center(
                                            child: Icon(
                                              Icons.fiber_manual_record,
                                              color: Colors.red.shade400,
                                              size: 22,
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
                        _chipAutoHideTimer
                            ?.cancel(); // Cancel timer when closing
                        _animationController.reverse().then((_) {
                          setState(() {
                            _showChatSidebar = false;
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
                    bottom: true,
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
                              if (_previousFollowUps !=
                                  state.followUpQuestions) {
                                _previousFollowUps = state.followUpQuestions;
                                // Only show immediately if we're not currently processing a message
                                // (i.e., no user message bubble showing and not generating)
                                if (!_showUserMessageBubble &&
                                    !state.isGenerating &&
                                    !_isAudioPlaying) {
                                  _showFollowUps = false;
                                  Future.delayed(
                                      const Duration(milliseconds: 50), () {
                                    if (mounted &&
                                        !_showUserMessageBubble &&
                                        !_isAudioPlaying) {
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
                                  child: ConstrainedBox(
                                    constraints: const BoxConstraints(
                                      maxHeight:
                                          44, // Max height constraint instead of fixed
                                    ),
                                    child: ListView.builder(
                                      shrinkWrap: true,
                                      scrollDirection: Axis.horizontal,
                                      padding: const EdgeInsets.symmetric(
                                          horizontal: 10),
                                      itemCount: state.followUpQuestions.length,
                                      itemBuilder: (context, index) {
                                        final question =
                                            state.followUpQuestions[index];
                                        return Padding(
                                          padding:
                                              const EdgeInsets.only(right: 8),
                                          child: GestureDetector(
                                            onTap: () async {
                                              // Fade out chips first
                                              setState(() {
                                                _showFollowUps = false;
                                              });
                                              // Wait for fade-out animation
                                              await Future.delayed(
                                                  const Duration(
                                                      milliseconds: 300));
                                              _textController.text = question;
                                              _sendMessage(question, context);
                                            },
                                            child: Container(
                                              padding:
                                                  const EdgeInsets.symmetric(
                                                horizontal: 16,
                                                vertical: 8,
                                              ),
                                              decoration: BoxDecoration(
                                                gradient: LinearGradient(
                                                  colors: [
                                                    Colors.white
                                                        .withOpacity(0.18),
                                                    Colors.white
                                                        .withOpacity(0.10),
                                                  ],
                                                ),
                                                borderRadius:
                                                    BorderRadius.circular(20),
                                                border: Border.all(
                                                  color: Colors.white
                                                      .withOpacity(0.28),
                                                  width: 0.8,
                                                ),
                                              ),
                                              child: Center(
                                                child: Text(
                                                  question,
                                                  style: Theme.of(context)
                                                      .textTheme
                                                      .bodyMedium
                                                      ?.copyWith(
                                                        color: Colors.white
                                                            .withOpacity(0.92),
                                                        fontWeight:
                                                            FontWeight.w600,
                                                      ),
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
              ], // Close Stack children
            ), // Close Stack
          ), // Close GestureDetector (Scaffold body)
        ), // Close Scaffold
      ), // Close PopScope
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

    bool available = await _speechToText.initialize(
      onError: (error) {
        print('❌ STT Error: $error');
        if (mounted) {
          setState(() {
            _isRecording = false;
          });
        }
      },
      onStatus: (status) {
        print('🎤 STT Status: $status');
        if (status == 'done' || status == 'notListening') {
          if (mounted && _isRecording) {
            setState(() {
              _isRecording = false;
            });
          }
        }
      },
    );

    if (available) {
      setState(() {
        _isRecording = true;
        _textController.clear();
      });

      await _speechToText.listen(
        onResult: (result) {
          setState(() {
            _textController.text = result.recognizedWords;
          });
        },
        listenMode: stt.ListenMode.confirmation,
      );
    } else {
      if (mounted) {
        ToastUtils.showError(context, 'Speech recognition not available');
      }
    }
  }

  Future<void> _stopListening() async {
    await _speechToText.stop();
    setState(() {
      _isRecording = false;
    });

    // Auto-submit if we have text
    if (_textController.text.trim().isNotEmpty) {
      _sendMessage(_textController.text, context);
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
        ToastUtils.showInfo(context, 'Please sign in to chat with Sai Baba');
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

    // Update Unity avatar to thinking state
    _updateUnityAvatarState();

    // Clear input field immediately
    _textController.clear();

    print('📨 Sending message via ChatBloc: $text');

    // Send message via ChatBloc - the BlocListener will handle the response
    context.read<ChatBloc>().add(ChatMessageSent(
          message: text,
          threadId: _threadId,
          language: _selectedLanguage, // Pass selected language
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

  void _showLanguageSelectionDialog() {
    showDialog(
      context: context,
      barrierColor: Colors.black.withOpacity(0.7),
      builder: (BuildContext context) {
        return Dialog(
          backgroundColor: Colors.transparent,
          child: Container(
            constraints: const BoxConstraints(maxWidth: 280),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.05),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(
                color: Colors.white.withOpacity(0.2),
                width: 1.5,
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.3),
                  blurRadius: 20,
                  spreadRadius: 0,
                ),
              ],
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(20),
              child: BackdropFilter(
                filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // Header
                    Container(
                      padding: const EdgeInsets.all(20),
                      decoration: BoxDecoration(
                        border: Border(
                          bottom: BorderSide(
                            color: Colors.white.withOpacity(0.1),
                            width: 1,
                          ),
                        ),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            Icons.language,
                            color: Colors.white.withOpacity(0.9),
                            size: 20,
                          ),
                          const SizedBox(width: 8),
                          Text(
                            'Select Language',
                            style: AppTheme.body(context).copyWith(
                              fontSize: 16,
                              fontWeight: FontWeight.w600,
                              color: Colors.white.withOpacity(0.9),
                            ),
                          ),
                        ],
                      ),
                    ),

                    // Language Options
                    Padding(
                      padding: const EdgeInsets.symmetric(
                          vertical: 8, horizontal: 12),
                      child: Column(
                        children: [
                          _buildLanguageOption(
                            language: 'english',
                            displayName: 'English',
                          ),
                          _buildLanguageOption(
                            language: 'telugu',
                            displayName: 'Telugu',
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildLanguageOption({
    required String language,
    required String displayName,
  }) {
    final isSelected = _selectedLanguage == language;

    return GestureDetector(
      onTap: () {
        setState(() {
          _selectedLanguage = language;
        });
        print('🌐 Language changed to: $language');
        Navigator.of(context).pop();
      },
      child: Container(
        margin: const EdgeInsets.symmetric(vertical: 4),
        padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 16),
        decoration: BoxDecoration(
          color:
              isSelected ? Colors.white.withOpacity(0.15) : Colors.transparent,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color:
                isSelected ? Colors.white.withOpacity(0.3) : Colors.transparent,
            width: 1,
          ),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              displayName,
              style: AppTheme.body(context).copyWith(
                fontSize: 16,
                fontWeight: isSelected ? FontWeight.w600 : FontWeight.w400,
                color: Colors.white.withOpacity(isSelected ? 1.0 : 0.7),
              ),
            ),
            if (isSelected)
              Icon(
                Icons.check_circle,
                color: Colors.white.withOpacity(0.9),
                size: 20,
              ),
          ],
        ),
      ),
    );
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
                        style: AppTheme.body(context),
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
      // Start recording with internal audio only (no microphone needed!)
      _screenRecordingService.setAudioCaptureMode(internalOnly: true);
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
              debugPrint(
                  '⏱️ Auto-stopping recording after $_maxRecordingDurationMinutes minutes');
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
              builder: (context) => Column(
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
                                showDialog(
                                    context: context,
                                    builder: (_) => const Route3());
                              },
                              child: const Text("Open route 3",
                                  textAlign: TextAlign.center),
                            ),
                          ],
                        ),
                      )
                    ],
                  )),
        ));
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
