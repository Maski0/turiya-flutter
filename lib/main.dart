import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math';
import 'dart:ui';
import 'onboarding/onboarding_gate.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:flutter_embed_unity/flutter_embed_unity.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:supabase_flutter/supabase_flutter.dart' as supabase;
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:isar/isar.dart';
import 'package:path_provider/path_provider.dart';
import 'elevenlabs_service.dart';
import 'audio_streamer.dart';
import 'services/backend_api_service.dart';
import 'services/cache_service.dart';
import 'models/cached_message.dart';
import 'models/alignment_data.dart';
import 'widgets/login_modal.dart';
import 'widgets/chat_sidebar.dart';
import 'widgets/profile_menu.dart';
import 'widgets/recording_indicator.dart';
import 'widgets/recording_preview_overlay.dart';
import 'widgets/icons/hamburger_icon.dart';
import 'widgets/icons/right_arrow_icon.dart';
import 'widgets/bottom_input_bar.dart';
import 'widgets/main_menu.dart';
import 'widgets/profile_avatar_widget.dart';
import 'services/screen_recording_service.dart';
import 'blocs/auth/auth_bloc_export.dart';
import 'blocs/chat/chat_bloc_export.dart';
import 'blocs/credits/credits_bloc.dart';
import 'blocs/memory/memory_bloc.dart';
import 'services/background_audio_service.dart';
import 'services/livekit_service.dart';
import 'package:livekit_client/livekit_client.dart' show Hardware;
import 'package:speech_to_text/speech_to_text.dart' as stt;
import 'package:permission_handler/permission_handler.dart';
import 'utils/toast_utils.dart';
import 'theme/app_theme.dart';

// Method channel for native audio control
const _audioChannel = MethodChannel('com.turiya/audio');

// TODO: REMOVE FOR PRODUCTION - Fix server SSL certificate chain instead
class _DevHttpOverrides extends HttpOverrides {
  @override
  HttpClient createHttpClient(SecurityContext? context) {
    return super.createHttpClient(context)
      ..badCertificateCallback = (cert, host, port) => true;
  }
}

// Global cache service
late final CacheService cacheService;

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // TODO: REMOVE FOR PRODUCTION - Fix server SSL cert chain instead
  HttpOverrides.global = _DevHttpOverrides();

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
        home: const _AppInitializer(
          child: OnboardingGate(
            child: _MainScreen(),
          ),
        ),
      ),
    );
  }
}

/// Initializes app-wide services like background audio
class _AppInitializer extends StatefulWidget {
  final Widget child;

  const _AppInitializer({required this.child});

  @override
  State<_AppInitializer> createState() => _AppInitializerState();
}

class _AppInitializerState extends State<_AppInitializer> {
  @override
  void initState() {
    super.initState();
    // Initialize background audio immediately when app starts
    _initBackgroundAudio();
  }

  Future<void> _initBackgroundAudio() async {
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      await BackgroundAudioService().initialize();
    });
  }

  @override
  Widget build(BuildContext context) {
    return widget.child;
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

  // LiveKit for real-time voice (default for voice mode)
  final LiveKitService _liveKitService = LiveKitService();
  bool _isLiveKitConnected = false;
  bool _isLiveKitConnecting = false;
  bool _isLiveKitDisconnecting = false;
  bool _agentConnected = false;

  bool _isGenerating = false;
  bool _showLoginModal = false;
  bool _showChatSidebar = false;
  bool _showMenuDrawer = false;
  bool _showMainMenu = false;
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
  String? _lastUserMessage; // Track last sent message
  bool _showUserMessageBubble = false; // Control user message bubble visibility

  // Subtitle state
  AlignmentData? _currentAlignment;
  bool _isAudioPlaying = false;

  // Track currently playing message to prevent duplicates
  String? _currentlyPlayingMessageId;

  // Language selection
  String _selectedLanguage = 'telugu'; // 'telugu' or 'english'

  // Hide everything mode (for recording)
  bool _hideEverything = false;

  // Pending recording - waiting for Krishna to speak
  bool _pendingScreenRecording = false;
  String _recordingStatusMessage = ''; // For showing status in top bar
  String? _savedRecordingPath; // Path to saved recording
  bool _showRecordingPopup = false; // For slide animation control
  double?
      _expectedRecordingDurationSeconds; // Expected duration from audio response

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

    // Initialize app-specific services (audio is now initialized in _AppInitializer)
    _initServices();
  }

  /// Initialize main screen services after first frame renders
  Future<void> _initServices() async {
    // Wait for first frame to ensure app is ready
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      // Apply time of day after Unity loads (with delay)
      _applyTimeOfDayFromClock();
      // Setup LiveKit callbacks
      _setupLiveKitCallbacks();
      // Sync onboarding data to backend if user is authenticated
      _syncOnboardingDataIfNeeded();
      // Load credits if already authenticated (e.g., coming from onboarding)
      _loadCreditsIfAuthenticated();
    });
  }

  /// Load credits if user is already authenticated (handles post-onboarding case)
  void _loadCreditsIfAuthenticated() {
    final authState = context.read<AuthBloc>().state;
    if (authState is AuthAuthenticated) {
      // User is already authenticated, load credits
      context.read<CreditsBloc>().add(const CreditsRequested());
      // Also load last conversation
      _loadLastThread();
    }
  }

  /// Check local storage for onboarding data and sync to backend if authenticated
  Future<void> _syncOnboardingDataIfNeeded() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final onboardingDataJson = prefs.getString('onboarding_data');

      // If onboarding data exists in local storage and user is authenticated, push to backend
      if (onboardingDataJson != null && _backendApi.isAuthenticated()) {
        print('📤 Pushing onboarding data to backend...');

        try {
          final onboardingData = jsonDecode(onboardingDataJson);
          await _backendApi.saveOnboardingData(onboardingData: onboardingData);

          // Delete from local storage after successful sync
          await prefs.remove('onboarding_data');
          print(
              '✅ Onboarding data pushed to backend and removed from local storage');
        } catch (e) {
          print('❌ Failed to push onboarding data: $e');
          // Keep in local storage, will retry next time
        }
      }
    } catch (e) {
      print('Error syncing onboarding data: $e');
    }
  }

  /// Setup LiveKit service callbacks
  void _setupLiveKitCallbacks() {
    // IMPORTANT: Ensure LiveKit is disconnected on init (clean state after hot restart)
    _liveKitService.disconnect();
    _isLiveKitConnected = false;
    _isLiveKitConnecting = false;
    _agentConnected = false;

    _liveKitService.onConnectionStateChanged = (state) {
      if (mounted) {
        final newConnected = state == 'connected';
        final newConnecting = state == 'connecting' || state == 'reconnecting';
        // Only update if state actually changed to avoid unnecessary rebuilds
        if (_isLiveKitConnected != newConnected ||
            _isLiveKitConnecting != newConnecting) {
          setState(() {
            _isLiveKitConnected = newConnected;
            _isLiveKitConnecting = newConnecting;
          });
        }
        print('🎤 LiveKit connection state: $state');
      }
    };

    _liveKitService.onAgentConnected = () {
      if (mounted && !_agentConnected) {
        setState(() {
          _agentConnected = true;
        });
        print('🤖 LiveKit: Agent connected');
        // Update Unity avatar state
        _updateUnityAvatarState();
      }
    };

    _liveKitService.onAgentDisconnected = () {
      if (mounted && _agentConnected) {
        setState(() {
          _agentConnected = false;
        });
        print('🤖 LiveKit: Agent disconnected');
      }
    };

    _liveKitService.onAgentSpeakingChanged = (isSpeaking) {
      if (mounted && _isAudioPlaying != isSpeaking) {
        setState(() {
          _isAudioPlaying = isSpeaking;
        });
        _updateUnityAvatarState();
        print(
            '🔊 LiveKit: Agent ${isSpeaking ? "started" : "stopped"} speaking');
      }
    };

    _liveKitService.onError = (error) {
      print('❌ LiveKit error: $error');
      if (mounted) {
        // Only show error if not already disconnected
        if (_isLiveKitConnected || _isLiveKitConnecting) {
          _liveKitService.disconnect();

          setState(() {
            _isLiveKitConnected = false;
            _isLiveKitConnecting = false;
            _isLiveKitDisconnecting = false;
            _isGenerating = false;
            _agentConnected = false;
          });
          ToastUtils.showError(context, 'Voice connection lost');
        }
      }
    };

    // Handle agent state changes (for avatar animation)
    _liveKitService.onAgentStateChanged = (state) {
      print('🤖 LiveKit: Agent state → $state');
      if (mounted) {
        setState(() {
          // Map LiveKit agent state to our state variables
          switch (state) {
            case AgentState.thinking:
              _isGenerating = true;
              _isAudioPlaying = false;
              break;
            case AgentState.speaking:
              _isGenerating = false;
              _isAudioPlaying = true;
              break;
            case AgentState.listening:
            case AgentState.disconnected:
            case AgentState.connecting:
              _isGenerating = false;
              _isAudioPlaying = false;
              break;
          }
        });
        _updateUnityAvatarState();
      }
    };
  }

  /// Automatically set Unity scene ambience based on current time
  void _applyTimeOfDayFromClock() {
    // Delay to ensure Unity is fully loaded
    Future.delayed(const Duration(seconds: 2), () {
      final hour = DateTime.now().hour;

      String timeOfDay;
      if (hour >= 5 && hour < 17) {
        // 5 AM - 5 PM = Morning/Day
        timeOfDay = 'morning';
        sendToUnity("TimeOfDay", "SetMorning", "");
      } else if (hour >= 17 && hour < 20) {
        // 5 PM - 8 PM = Evening
        timeOfDay = 'evening';
        sendToUnity("TimeOfDay", "SetEvening", "");
      } else {
        // 8 PM - 5 AM = Night
        timeOfDay = 'night';
        sendToUnity("TimeOfDay", "SetNight", "");
      }

      print('🌅 Auto time of day: $timeOfDay (hour: $hour)');
    });
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
      // Check if Unity is loaded before sending messages
      sendToUnity("Flutter", "AvatarState", state);
      print('🎭 Unity avatar state changed to: $state');
    } catch (e) {
      // Unity not loaded yet, ignore silently
      // This is normal during app startup
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
      // Dismiss keyboard before showing modal
      FocusManager.instance.primaryFocus?.unfocus();
      _textFocusNode.unfocus();
      SystemChannels.textInput.invokeMethod('TextInput.hide');

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

              // Find the LAST unplayed AI message (most recent)
              ChatMessage? unplayedMessage;
              for (final message in state.messages.reversed) {
                if (message.type == 'ai' && !message.isPlayed) {
                  unplayedMessage = message;
                  break; // Take the first one found (which is the last in original list)
                }
              }

              if (unplayedMessage != null) {
                final message = unplayedMessage;

                // Skip if we're already playing this message
                if (_currentlyPlayingMessageId == message.id) {
                  print('⏭️ Skipping - already playing message ${message.id}');
                } else {
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
                      });
                      print(
                          '🔊 Set _isAudioPlaying = true at $streamingStartTime');
                      print(
                          '🎵 Set _isGenerating = false (will show "Narrating..." in status)');

                      // Update Unity avatar to speaking state
                      _updateUnityAvatarState();

                      // Start pending recording BEFORE audio plays (await it!)
                      if (_pendingScreenRecording) {
                        await _startPendingRecording();
                      }
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

                    // Store expected recording duration (audio + 3s buffer at end for iOS recording)
                    _expectedRecordingDurationSeconds = audioDuration + 3.0;
                    debugPrint(
                        '🎬 Set expected recording duration: $_expectedRecordingDurationSeconds seconds');

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

                      try {
                        sendToUnity("Flutter", "OnAudioChunk", "END");
                        print(
                            '🏁 END signal sent to Unity (audio playback complete)');
                      } catch (e) {
                        // Unity not available, ignore
                      }

                      // Auto-stop recording when Krishna finishes speaking
                      if (_isScreenRecording) {
                        debugPrint('🎬 Audio complete - stopping recording');
                        await _stopRecordingAndShowUI();
                      }

                      // Fade out user message bubble
                      if (_showUserMessageBubble) {
                        setState(() {
                          _showUserMessageBubble = false;
                        });

                        // Wait for fade-out
                        await Future.delayed(const Duration(milliseconds: 400));
                      }
                    }
                  } catch (e) {
                    print('❌ TTS Error: $e');
                    // Clear the currently playing message ID on error
                    _currentlyPlayingMessageId = null;

                    // Send END signal to Unity to clean up state
                    try {
                      sendToUnity("Flutter", "OnAudioChunk", "END");
                      print('🏁 END signal sent to Unity (error cleanup)');
                    } catch (e) {
                      // Unity not available, ignore
                    }

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
                    }
                  }

                  // Refresh credits after message sent
                  context.read<CreditsBloc>().add(const CreditsRefreshed());
                }
              } // End if (unplayedMessage != null)
            } else if (state is ChatError) {
              // Send END signal to Unity to clean up state
              try {
                sendToUnity("Flutter", "OnAudioChunk", "END");
                print('🏁 END signal sent to Unity (ChatError cleanup)');
              } catch (e) {
                // Unity not available, ignore
              }

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

          // Priority 2: Close main menu if open
          if (_showMainMenu) {
            setState(() {
              _showMainMenu = false;
            });
            return;
          }

          // Priority 3: Close login modal if open
          if (_showLoginModal) {
            _toggleLoginModal();
            return;
          }

          // Priority 4: Close chat sidebar if open
          if (_showChatSidebar) {
            setState(() {
              _showChatSidebar = false;
            });
            return;
          }

          // Priority 5: Show exit confirmation dialog
          _showExitConfirmationDialog();
        },
        child: Scaffold(
          backgroundColor: Colors.black,
          resizeToAvoidBottomInset: false,
          body: GestureDetector(
            onTap: _hideEverything
                ? () => setState(() => _hideEverything = false)
                : null,
            onVerticalDragStart: _hideEverything
                ? null
                : (_) {
                    // Dismiss keyboard on vertical drag (swipe)
                    FocusScope.of(context).unfocus();
                  },
            child: Stack(
              children: [
                // Layer 1: Unity (always visible)
                Positioned.fill(
                  child: RepaintBoundary(
                    key: _repaintBoundaryKey,
                    child: const EmbedUnity(),
                  ),
                ),

                // Layer 2: UI elements with animated fade
                // Wrap in AnimatedOpacity for smooth fade transition
                AnimatedOpacity(
                  opacity: _hideEverything ? 0.0 : 1.0,
                  duration: const Duration(milliseconds: 400),
                  curve: Curves.easeInOut,
                  child: IgnorePointer(
                    ignoring: _hideEverything,
                    child: Stack(
                      children: [
                        // Chat Sidebar
                        if (_showChatSidebar)
                          Positioned.fill(
                            child: FadeTransition(
                              opacity: _fadeAnimation,
                              child: BackdropFilter(
                                filter:
                                    ImageFilter.blur(sigmaX: 50, sigmaY: 50),
                                child: ChatSidebar(
                                  scrollController: _scrollController,
                                  onClose: () {
                                    _chipAutoHideTimer?.cancel();
                                    _animationController.reverse().then((_) {
                                      setState(() => _showChatSidebar = false);
                                    });
                                  },
                                  onFollowUpTap: (question) {
                                    _textController.text = question;
                                    _sendMessage(question, context);
                                  },
                                  onLoginTap: _toggleLoginModal,
                                  messageController: _textController,
                                  onSendMessage: () {
                                    final text = _textController.text.trim();
                                    if (text.isNotEmpty) {
                                      _sendMessage(text, context);
                                    }
                                  },
                                  isRecording: _isRecording,
                                  isAudioPlaying: _isAudioPlaying,
                                  onMicTap: _toggleListening,
                                  onStopAudio: _stopAudio,
                                  // Adjust bottom padding for keyboard
                                  bottomPadding: keyboardHeight + 90,
                                ),
                              ),
                            ),
                          ),

                        // Top bar with menu and login
                        // Hide when menu drawer is open
                        if (!_showMenuDrawer)
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
                                      mainAxisAlignment:
                                          MainAxisAlignment.spaceBetween,
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        // Top left button - Hamburger menu OR Close button when chat is open
                                        // Hide during screen recording
                                        if (!_isScreenRecording)
                                          GestureDetector(
                                            onTap: () {
                                              if (_showChatSidebar) {
                                                // Close chat sidebar
                                                _chipAutoHideTimer?.cancel();
                                                _animationController
                                                    .reverse()
                                                    .then((_) {
                                                  setState(() {
                                                    _showChatSidebar = false;
                                                  });
                                                });
                                              } else {
                                                // Toggle main menu
                                                setState(() {
                                                  _showMainMenu =
                                                      !_showMainMenu;
                                                });
                                              }
                                            },
                                            child: ClipRRect(
                                              borderRadius:
                                                  BorderRadius.circular(16),
                                              child: BackdropFilter(
                                                filter: ImageFilter.blur(
                                                    sigmaX: 12, sigmaY: 12),
                                                child: Container(
                                                  width: 48,
                                                  height: 48,
                                                  decoration: BoxDecoration(
                                                    color:
                                                        const Color(0x1AFFFFFF),
                                                    borderRadius:
                                                        BorderRadius.circular(
                                                            16),
                                                    border: Border.all(
                                                      color: const Color(
                                                          0x33FFFFFF),
                                                      width: 1,
                                                    ),
                                                  ),
                                                  child: Center(
                                                    // Show close icon when chat is open, hamburger otherwise
                                                    child: _showChatSidebar
                                                        ? const Icon(
                                                            Icons.close,
                                                            color: Colors.white,
                                                            size: 24,
                                                          )
                                                        : const HamburgerIcon(
                                                            size: 24),
                                                  ),
                                                ),
                                              ),
                                            ),
                                          )
                                        else
                                          const SizedBox(
                                              width:
                                                  48), // Placeholder to maintain spacing

                                        // Spacer to push profile to the right
                                        const Spacer(),

                                        // Right side - Profile on top, Record button below (right-aligned column)
                                        BlocBuilder<AuthBloc, AuthState>(
                                          builder: (context, state) {
                                            if (state is AuthAuthenticated &&
                                                !_isScreenRecording) {
                                              return Column(
                                                mainAxisSize: MainAxisSize.min,
                                                crossAxisAlignment:
                                                    CrossAxisAlignment.end,
                                                children: [
                                                  _buildCreditsAndProfile(
                                                      context),
                                                  const SizedBox(height: 12),
                                                  _buildRecordButton(),
                                                ],
                                              );
                                            }
                                            if (_isScreenRecording) {
                                              return const SizedBox.shrink();
                                            }
                                            // Web: auth-glass-btn styling
                                            // padding: 10px 12px, borderRadius: 16px,
                                            // background: rgba(255, 255, 255, 0.01),
                                            // border: 1px solid rgba(255, 255, 255, 0.08), blur: 16px
                                            return GestureDetector(
                                              onTap: _toggleLoginModal,
                                              child: ClipRRect(
                                                borderRadius:
                                                    BorderRadius.circular(16),
                                                child: BackdropFilter(
                                                  filter: ImageFilter.blur(
                                                      sigmaX: 16, sigmaY: 16),
                                                  child: Container(
                                                    padding:
                                                        const EdgeInsets.only(
                                                      left: 18,
                                                      right: 16,
                                                      top: 12,
                                                      bottom: 12,
                                                    ),
                                                    decoration: BoxDecoration(
                                                      // Web: rgba(255, 255, 255, 0.01)
                                                      color: const Color(
                                                          0x03FFFFFF),
                                                      borderRadius:
                                                          BorderRadius.circular(
                                                              16),
                                                      border: Border.all(
                                                        // Web: rgba(255, 255, 255, 0.08)
                                                        color: const Color(
                                                            0x14FFFFFF),
                                                        width: 1,
                                                      ),
                                                    ),
                                                    child: Row(
                                                      mainAxisSize:
                                                          MainAxisSize.min,
                                                      children: [
                                                        // Web: RightArrow icon with mr-1 (14x21)
                                                        const RightArrowIcon(
                                                          size: 14,
                                                          color: Colors.white,
                                                        ),
                                                        // Spacing between icon and text
                                                        const SizedBox(
                                                            width: 8),
                                                        // Web: font-medium text-xl (20px) but using 18px for mobile
                                                        // Use theme: titleLarge (18px)
                                                        Text(
                                                          'Login',
                                                          style:
                                                              Theme.of(context)
                                                                  .textTheme
                                                                  .titleLarge!
                                                                  .copyWith(
                                                                    color: Colors
                                                                        .white,
                                                                    fontWeight:
                                                                        FontWeight
                                                                            .w500,
                                                                  ),
                                                        ),
                                                      ],
                                                    ),
                                                  ),
                                                ),
                                              ),
                                            );
                                          },
                                        ),
                                      ],
                                    ),
                                    // Recording button - appears below profile avatar when authenticated
                                    // Hidden when recording is active or when chat sidebar is open
                                    // Fades in with profile avatar
                                    if (!_showChatSidebar)
                                      BlocBuilder<AuthBloc, AuthState>(
                                        builder: (context, authState) {
                                          if (authState is AuthAuthenticated &&
                                              !_isScreenRecording) {
                                            // Wait for credits to load before showing (matches profile fade)
                                            return BlocBuilder<CreditsBloc,
                                                CreditsState>(
                                              builder: (context, creditsState) {
                                                if (creditsState
                                                    is! CreditsLoaded) {
                                                  return const SizedBox
                                                      .shrink();
                                                }
                                                return TweenAnimationBuilder<
                                                    double>(
                                                  tween: Tween(
                                                      begin: 0.0, end: 1.0),
                                                  duration: const Duration(
                                                      milliseconds: 400),
                                                  curve: Curves.easeIn,
                                                  builder: (context, opacity,
                                                      child) {
                                                    return Opacity(
                                                      opacity: opacity,
                                                      child: child,
                                                    );
                                                  },
                                                  child:
                                                      const SizedBox.shrink(),
                                                );
                                              },
                                            );
                                          }
                                          return const SizedBox.shrink();
                                        },
                                      ),
                                    // "Hide everything" button - only shown when env var is set
                                    if (dotenv.env['SHOW_HIDE_OPTION'] ==
                                        'true')
                                      Padding(
                                        padding: const EdgeInsets.only(top: 12),
                                        child: Row(
                                          mainAxisAlignment:
                                              MainAxisAlignment.end,
                                          children: [
                                            GestureDetector(
                                              onTap: () => setState(
                                                  () => _hideEverything = true),
                                              child: Container(
                                                padding:
                                                    const EdgeInsets.symmetric(
                                                  horizontal: 16,
                                                  vertical: 10,
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
                                                      BorderRadius.circular(13),
                                                  border: Border.all(
                                                    color: Colors.white
                                                        .withOpacity(0.32),
                                                    width: 1.2,
                                                  ),
                                                ),
                                                child: Row(
                                                  mainAxisSize:
                                                      MainAxisSize.min,
                                                  children: [
                                                    Icon(
                                                      Icons.visibility_off,
                                                      color: Colors.white
                                                          .withOpacity(0.9),
                                                      size: 18,
                                                    ),
                                                    const SizedBox(width: 8),
                                                    Text(
                                                      'Hide UI',
                                                      style: TextStyle(
                                                        color: Colors.white
                                                            .withOpacity(0.9),
                                                        fontSize: 13,
                                                        fontWeight:
                                                            FontWeight.w500,
                                                      ),
                                                    ),
                                                  ],
                                                ),
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                  ],
                                ),
                              ),
                            ),
                          ),

                        // Bottom center - Disclaimer (hide when generating/playing/chat/menu open)
                        // Hide when chat sidebar or menu drawer is open

                        Positioned(
                          left: 0,
                          right: 0,
                          bottom: 0,
                          child: SafeArea(
                            bottom: true,
                            child: Padding(
                              padding: const EdgeInsets.only(bottom: 4),
                              child: Builder(
                                builder: (context) {
                                  // Show disclaimer when not generating/playing
                                  final baseStyle = Theme.of(context)
                                      .textTheme
                                      .bodySmall!
                                      .copyWith(
                                        color: const Color(0x80FFFFFF),
                                        height: 1.25,
                                      );
                                  return RichText(
                                    textAlign: TextAlign.center,
                                    text: TextSpan(
                                      style: baseStyle,
                                      children: [
                                        const TextSpan(
                                          text: 'Turiya',
                                          style: TextStyle(
                                              fontStyle: FontStyle.italic),
                                        ),
                                        const TextSpan(
                                            text: ' can make mistakes. '),
                                        TextSpan(
                                          text: 'Check disclaimer.',
                                          style: const TextStyle(
                                            decoration:
                                                TextDecoration.underline,
                                            decorationColor: Color(0x80FFFFFF),
                                          ),
                                          recognizer: TapGestureRecognizer()
                                            ..onTap = () async {
                                              final url = Uri.parse(
                                                'https://walnut-tin-527.notion.site/Disclaimer-2508bdb5861080ffbf5ec151d011e10d?source=copy_link',
                                              );
                                              if (await canLaunchUrl(url)) {
                                                await launchUrl(url,
                                                    mode: LaunchMode
                                                        .externalApplication);
                                              }
                                            },
                                        ),
                                      ],
                                    ),
                                  );
                                },
                              ),
                            ),
                          ),
                        ),

                        // Main Menu (About, FAQs, Blog, Contact)
                        MainMenu(
                          isOpen: _showMainMenu,
                          onClose: () {
                            setState(() {
                              _showMainMenu = false;
                            });
                          },
                        ),

                        // Bottom Input Bar with Liquid Glass
                        Positioned(
                          left: 16,
                          right: 16,
                          bottom: keyboardHeight,
                          child: SafeArea(
                            bottom: true,
                            child: Padding(
                              // Consistent bottom margin to avoid UI shift during connection
                              padding: const EdgeInsets.only(bottom: 28),
                              child: BottomInputBar(
                                textController: _textController,
                                focusNode: _textFocusNode,
                                isGenerating: _isGenerating,
                                isRecording: _isRecording,
                                isAudioPlaying: _isAudioPlaying,
                                onSubmit: (text) => _sendMessage(text, context),
                                onMicTap: _toggleListening,
                                onStopAudio: _stopAudio,
                                enabled: !_showLoginModal,
                                // LiveKit voice mode
                                isLiveKitConnected: _isLiveKitConnected,
                                isLiveKitConnecting: _isLiveKitConnecting ||
                                    _isLiveKitDisconnecting,
                                onVoiceCallTap: _connectToLiveKit,
                                onDisconnectLiveKit: _disconnectFromLiveKit,
                                onSettingsTap: () {
                                  setState(() {
                                    _showMenuDrawer = true;
                                  });
                                  _animationController.forward();
                                },
                                isMicMuted:
                                    !_liveKitService.isMicrophoneEnabled,
                                onMicToggle: () async {
                                  await _liveKitService.toggleMicrophone();
                                  setState(() {});
                                },
                                // Chat button & pondering chip
                                showChatButton: !_showChatSidebar,
                                hidePonderingChip: _showChatSidebar,
                                onChatButtonTap: () {
                                  setState(() {
                                    _showChatSidebar = true;
                                    _showChip = false;
                                  });
                                  _animationController.forward();
                                  Future.delayed(
                                      const Duration(milliseconds: 100), () {
                                    if (mounted && _showChatSidebar) {
                                      setState(() => _showChip = true);
                                      _startChipAutoHideTimer();
                                    }
                                  });
                                },
                              ),
                            ),
                          ),
                        ),

                        // Profile Menu - renders on top of everything
                        if (_showMenuDrawer)
                          FadeTransition(
                            opacity: _fadeAnimation,
                            child: ProfileMenu(
                              onClose: () {
                                _animationController.reverse().then((_) {
                                  setState(() {
                                    _showMenuDrawer = false;
                                  });
                                });
                              },
                            ),
                          ),

                        // Login Modal Overlay - renders on top of everything
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
                      ], // Close inner Stack children (UI elements)
                    ), // Close inner Stack
                  ), // Close IgnorePointer
                ), // Close AnimatedOpacity

                // Saved recording popup (shows after recording stops) - slides down from top
                if (_savedRecordingPath != null)
                  Positioned(
                    top: MediaQuery.of(context).padding.top + 16,
                    left: 0,
                    right: 0,
                    child: AnimatedSlide(
                      offset: _showRecordingPopup
                          ? Offset.zero
                          : const Offset(0, -2),
                      duration: const Duration(milliseconds: 400),
                      curve: Curves.easeOutCubic,
                      child: _buildSavedRecordingPopup(),
                    ),
                  ),
              ], // Close outer Stack children
            ), // Close outer Stack
          ), // Close GestureDetector (Scaffold body)
        ), // Close Scaffold
      ), // Close PopScope
    );
  }

  Future<void> _startListening() async {
    // Request microphone permission
    var status = await Permission.microphone.status;

    // If not granted, request permission first (shows native iOS popup)
    if (!status.isGranted) {
      status = await Permission.microphone.request();
    }

    // If still not granted, show settings dialog only if permanently denied
    if (!status.isGranted) {
      if (status.isPermanentlyDenied) {
        if (mounted) {
          final shouldOpenSettings = await showDialog<bool>(
            context: context,
            builder: (context) => AlertDialog(
              backgroundColor: const Color(0xFF1A1A1A),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
                side: BorderSide(color: Colors.white.withOpacity(0.1)),
              ),
              title: const Text('Microphone Permission',
                  style: TextStyle(
                      color: Colors.white,
                      fontSize: 18,
                      fontWeight: FontWeight.bold)),
              content: const Text(
                'Microphone access is needed for voice input.\n\n'
                'Please enable it in Settings > Turiya > Microphone.',
                style: TextStyle(color: Colors.white70, fontSize: 14),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context, false),
                  child:
                      Text('Cancel', style: TextStyle(color: Colors.grey[400])),
                ),
                TextButton(
                  onPressed: () => Navigator.pop(context, true),
                  child: const Text('Open Settings',
                      style: TextStyle(color: Color(0xFF22C55E))),
                ),
              ],
            ),
          );
          if (shouldOpenSettings == true) {
            await openAppSettings();
          }
        }
      } else {
        if (mounted) {
          ToastUtils.showError(context, 'Microphone permission required');
        }
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

    // Toggle STT (speech-to-text) - converts voice to text input
    if (_isRecording) {
      await _stopListening();
    } else {
      await _startListening();
    }
  }

  /// Toggle LiveKit voice mode (connect/disconnect and mic)
  Future<void> _toggleLiveKitVoice() async {
    if (_isLiveKitConnecting) {
      print('⏳ LiveKit: Already connecting, please wait...');
      return;
    }

    if (_isLiveKitConnected) {
      // Voice mode already active - mic button shouldn't be visible
      // This function should only be called when not connected
      print('⚠️ LiveKit: Already connected, use close button to disconnect');
      return;
    } else {
      // Connect to LiveKit
      await _connectToLiveKit();
    }
  }

  /// Connect to LiveKit room
  Future<void> _connectToLiveKit() async {
    setState(() {
      _isLiveKitConnecting = true;
    });

    try {
      // Get connection details from backend
      final connectionDetails = await _backendApi.getLiveKitConnectionDetails(
        threadId: _threadId,
        agentName: 'krsna-agent',
      );

      final serverUrl = connectionDetails['serverUrl'] as String;
      final token = connectionDetails['participantToken'] as String;
      final roomName = connectionDetails['roomName'] as String;

      print('🎤 LiveKit: Connecting to room $roomName');

      // Connect to room with thread/user context
      final connected = await _liveKitService.connect(
        serverUrl: serverUrl,
        token: token,
        roomName: roomName,
        threadId: _threadId,
        userId: _backendApi.getUserId(),
      );

      if (connected) {
        // Enable microphone after connection
        await _liveKitService.setMicrophoneEnabled(true);
        print('🎤 LiveKit: Microphone enabled, ready to listen');
        if (mounted) {
          setState(() {
            _isLiveKitConnected = true;
            _isLiveKitConnecting = false;
          });
        }
      } else {
        if (mounted) {
          setState(() {
            _isLiveKitConnecting = false;
          });
          ToastUtils.showError(context, 'Failed to connect voice');
        }
      }
    } catch (e) {
      print('❌ LiveKit connection error: $e');
      if (mounted) {
        setState(() {
          _isLiveKitConnecting = false;
        });
        ToastUtils.showError(context, 'Voice connection failed');
      }
    }
  }

  /// Disconnect from LiveKit room or cancel connection attempt
  Future<void> _disconnectFromLiveKit() async {
    // If connecting, cancel the connection attempt
    if (_isLiveKitConnecting) {
      print('🚫 Cancelling LiveKit connection...');
      if (mounted) {
        setState(() {
          _isLiveKitConnecting = false;
          _isLiveKitDisconnecting = false;
        });
      }
      await _liveKitService.disconnect();
      return;
    }

    // If already connected, disconnect
    if (!_isLiveKitConnected) return;

    if (mounted) {
      setState(() {
        _isLiveKitDisconnecting = true;
      });
    }

    print('🔌 Disconnecting from LiveKit...');
    await _liveKitService.disconnect();

    if (mounted) {
      setState(() {
        _isRecording = false;
        _isLiveKitConnected = false;
        _isLiveKitDisconnecting = false;
        _agentConnected = false;
      });
      print('✅ LiveKit disconnected');
    }
  }

  /// Toggle between local STT mode and LiveKit mode

  void _stopAudio() {
    _audioStreamer.cancel();

    // Stop audio playback immediately
    // Send START first (clears buffer and stops playback) then END
    try {
      sendToUnity("Flutter", "OnAudioChunk", "START"); // Stops current playback
      sendToUnity("Flutter", "OnAudioChunk", "END"); // Signal stream end
      print('⏸️ User stopped audio playback');
    } catch (e) {
      print('⚠️ Error sending stop signal to Unity: $e');
    }

    // Clear currently playing message to allow re-play if needed
    _currentlyPlayingMessageId = null;

    if (mounted) {
      setState(() {
        _isAudioPlaying = false;
        _currentAlignment = null;
        _isGenerating = false;
      });
      _updateUnityAvatarState();
    }
  }

  Future<void> _sendMessage(String text, BuildContext context) async {
    if (text.trim().isEmpty) return;

    // Check if user is authenticated
    final isAuthenticated = await _backendApi.isAuthenticated();
    if (!isAuthenticated) {
      if (mounted) {
        // Show info and login modal (keyboard dismissed in _toggleLoginModal)
        ToastUtils.showInfo(context, 'Please sign in to chat with Sai Baba');
        _toggleLoginModal();
      }
      return;
    }

    setState(() {
      _isGenerating = true;
      _lastUserMessage = text;
      _showUserMessageBubble = true;
    });

    // Update Unity avatar to thinking state
    _updateUnityAvatarState();

    // Clear input field immediately
    _textController.clear();

    // Always send text via HTTP (chat-chat mode)
    // Voice-to-voice uses LiveKit, but text input always uses HTTP
    print('📨 Sending text message via HTTP: $text');

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

  Widget _buildCreditsAndProfile(BuildContext context) {
    final backgroundAudio = BackgroundAudioService();

    // Just use ProfileAvatarWidget which already shows credits badge
    return ProfileAvatarWidget(
      onSettingsTap: () {
        setState(() {
          _showMenuDrawer = true;
        });
        _animationController.forward();
      },
      onMusicToggle: () async {
        await backgroundAudio.toggle();
        setState(() {});
      },
      isMusicMuted: !backgroundAudio.isPlaying,
      onRecordTap: _toggleScreenRecording,
      onLanguageTap: _showLanguageSelectionDialog,
      currentLanguage: _selectedLanguage == 'telugu' ? 'Telugu' : 'English',
      isPendingRecording: _pendingScreenRecording,
      isRecording: _isScreenRecording,
    );
  }

  /// Builds the separate record button (like web mobile view)
  Widget _buildRecordButton() {
    return GestureDetector(
      onTap: _toggleScreenRecording,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(16),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
          child: Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              color: const Color(0x1AFFFFFF),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: const Color(0x14FFFFFF),
                width: 1,
              ),
            ),
            child: Center(
              // Record icon: red filled circle with outer ring, blinks when recording
              child: _isScreenRecording || _pendingScreenRecording
                  ? _BlinkingRecordIcon()
                  : Container(
                      width: 24,
                      height: 24,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: Colors.red,
                          width: 2,
                        ),
                      ),
                      child: Center(
                        child: Container(
                          width: 12,
                          height: 12,
                          decoration: const BoxDecoration(
                            color: Colors.red,
                            shape: BoxShape.circle,
                          ),
                        ),
                      ),
                    ),
            ),
          ),
        ),
      ),
    );
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
    // If pending, cancel it
    if (_pendingScreenRecording) {
      setState(() {
        _pendingScreenRecording = false;
        _recordingStatusMessage = '';
      });
      if (mounted) {
        ToastUtils.showInfo(context, 'Recording cancelled');
      }
      return;
    }

    if (_isScreenRecording) {
      // Stop recording and show UI
      await _stopRecordingAndShowUI();
      return;
    }

    // Show confirmation popup - permissions are requested inside when Record is clicked
    final shouldRecord = await _showRecordingConfirmationPopup();
    if (shouldRecord != true) return;

    // Set pending state - will start recording when Krishna speaks
    setState(() {
      _pendingScreenRecording = true;
      _recordingStatusMessage = 'Awaiting response';
    });
  }

  /// Shows the recording confirmation popup with permission checklist
  Future<bool?> _showRecordingConfirmationPopup() async {
    return showDialog<bool>(
      context: context,
      barrierDismissible: true,
      barrierColor: Colors.transparent,
      useSafeArea: false,
      builder: (BuildContext dialogContext) {
        return _RecordingPermissionDialog(
          onRecord: () => Navigator.of(dialogContext).pop(true),
          onClose: () => Navigator.of(dialogContext).pop(false),
        );
      },
    );
  }

  /// Start recording when Krishna starts speaking (called from BlocListener)
  Future<void> _startPendingRecording() async {
    if (!_pendingScreenRecording) return;

    debugPrint('🎬 _startPendingRecording called - starting UI fade');

    // Dismiss keyboard first
    FocusManager.instance.primaryFocus?.unfocus();

    setState(() {
      _pendingScreenRecording = false;
      _hideEverything = true; // Hide UI - triggers AnimatedOpacity
      _recordingStatusMessage = 'Recording...';
    });

    // Wait for UI to fade out (AnimatedOpacity takes 400ms)
    debugPrint('🎬 Waiting 500ms for UI fade animation...');
    await Future.delayed(const Duration(milliseconds: 500));

    // Start actual recording
    debugPrint('🎬 Calling startRecording() at ${DateTime.now()}');
    bool started = await _screenRecordingService.startRecording();
    debugPrint('🎬 startRecording() returned $started at ${DateTime.now()}');

    if (started) {
      setState(() {
        _isScreenRecording = true;
        _recordingStartTime = DateTime.now();
      });

      // Aggressively force speaker output after recording starts
      // ReplayKit changes audio session, so we need to override it multiple times
      if (Platform.isIOS) {
        // Force speaker immediately
        try {
          await _audioChannel.invokeMethod('forceSpeaker');
          debugPrint('🔊 Forced speaker (1st attempt)');
        } catch (e) {
          debugPrint('⚠️ Error forcing speaker: $e');
        }

        // Force again after a short delay
        await Future.delayed(const Duration(milliseconds: 200));
        try {
          await _audioChannel.invokeMethod('forceSpeaker');
          debugPrint('🔊 Forced speaker (2nd attempt)');
        } catch (e) {
          debugPrint('⚠️ Error forcing speaker: $e');
        }

        // And again before audio starts
        await Future.delayed(const Duration(milliseconds: 300));
        try {
          await _audioChannel.invokeMethod('forceSpeaker');
          debugPrint('🔊 Forced speaker (3rd attempt)');
        } catch (e) {
          debugPrint('⚠️ Error forcing speaker: $e');
        }
      }

      // Start auto-stop timer (max recording duration)
      _recordingAutoStopTimer = Timer(
        Duration(minutes: _maxRecordingDurationMinutes),
        () async {
          if (_isScreenRecording && mounted) {
            debugPrint(
                '⏱️ Auto-stopping recording after $_maxRecordingDurationMinutes minutes');
            await _stopRecordingAndShowUI();
          }
        },
      );
    } else {
      // Failed to start - show UI again
      setState(() {
        _hideEverything = false;
        _recordingStatusMessage = '';
      });
      if (mounted) {
        ToastUtils.showError(context, 'Failed to start recording');
      }
    }
  }

  /// Stop recording and show UI again
  Future<void> _stopRecordingAndShowUI() async {
    if (!_isScreenRecording) return;

    debugPrint('🛑 Starting stop recording sequence...');

    // Cancel auto-stop timer
    _recordingAutoStopTimer?.cancel();
    _recordingAutoStopTimer = null;
    _expectedRecordingDurationSeconds = null;

    // Step 1: Wait 4 extra seconds to capture more of the video + layout
    debugPrint('⏳ Waiting 4 extra seconds before stopping...');
    await Future.delayed(const Duration(seconds: 4));

    // Step 2: Show UI first (fade in starts) - this gets recorded too
    debugPrint('🎬 Showing UI (fade in)...');
    setState(() {
      _hideEverything = false;
      _recordingStatusMessage = 'Saving...';
    });

    // Step 3: Wait for UI fade in animation (400ms) + small buffer
    await Future.delayed(const Duration(milliseconds: 600));

    // Step 4: Now stop recording
    debugPrint('🛑 Stopping recording now...');
    String? path = await _screenRecordingService.stopRecording();
    debugPrint('🛑 Recording saved: $path');

    setState(() {
      _isScreenRecording = false;
      _recordingStartTime = null;
      _recordingStatusMessage = '';
    });

    // Step 5: Show popup with slide animation after a delay
    if (path != null && mounted) {
      // Wait a moment before showing popup
      await Future.delayed(const Duration(milliseconds: 300));

      // Show popup notification with slide animation
      setState(() {
        _savedRecordingPath = path;
        _showRecordingPopup = true;
      });

      // Auto-hide popup after 10 seconds
      Future.delayed(const Duration(seconds: 10), () {
        if (mounted && _savedRecordingPath == path) {
          setState(() {
            _showRecordingPopup = false;
          });
          // Clear path after animation
          Future.delayed(const Duration(milliseconds: 300), () {
            if (mounted && _savedRecordingPath == path) {
              setState(() {
                _savedRecordingPath = null;
              });
            }
          });
        }
      });
    } else if (mounted) {
      ToastUtils.showError(context, 'Failed to save recording');
    }
  }

  /// Hide recording popup with animation
  void _hideRecordingPopup() {
    setState(() {
      _showRecordingPopup = false;
    });
    // Clear path after animation completes
    Future.delayed(const Duration(milliseconds: 300), () {
      if (mounted) {
        setState(() {
          _savedRecordingPath = null;
        });
      }
    });
  }

  /// Build saved recording popup with glass blur effect
  Widget _buildSavedRecordingPopup() {
    if (_savedRecordingPath == null) return const SizedBox.shrink();

    return GestureDetector(
      onTap: () {
        final path = _savedRecordingPath;
        if (path != null) {
          RecordingPreviewOverlay.show(context, path);
          _hideRecordingPopup();
        }
      },
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 20),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(16),
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
              decoration: BoxDecoration(
                color: const Color(0x14FFFFFF),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: const Color(0x14FFFFFF),
                  width: 1,
                ),
              ),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: Colors.green.withOpacity(0.15),
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: Colors.green.withOpacity(0.3),
                        width: 1,
                      ),
                    ),
                    child: const Icon(Icons.check, color: Colors.green, size: 18),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          'Recording Saved',
                          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                                color: Colors.white,
                                fontWeight: FontWeight.w600,
                              ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          'Tap to view',
                          style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                color: Colors.white.withOpacity(0.6),
                              ),
                        ),
                      ],
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Text(
                      'View',
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            color: Colors.black,
                            fontWeight: FontWeight.w600,
                          ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  GestureDetector(
                    onTap: _hideRecordingPopup,
                    child: Container(
                      padding: const EdgeInsets.all(4),
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.1),
                        shape: BoxShape.circle,
                      ),
                      child: Icon(Icons.close,
                          color: Colors.white.withOpacity(0.6), size: 18),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  /// Build recording status widget for top center
  Widget _buildRecordingStatus() {
    if (_recordingStatusMessage.isEmpty &&
        !_pendingScreenRecording &&
        !_isScreenRecording) {
      return const SizedBox.shrink();
    }

    Color dotColor = Colors.red; // Always red for pending and recording
    if (!_pendingScreenRecording && !_isScreenRecording) {
      dotColor = Colors.green; // Green only for saved
    }

    // Blinking dot for pending state
    final bool shouldBlink = _pendingScreenRecording;

    return GestureDetector(
      onTap: () {
        if (_savedRecordingPath != null) {
          RecordingPreviewOverlay.show(context, _savedRecordingPath!);
          setState(() {
            _recordingStatusMessage = '';
            _savedRecordingPath = null;
          });
        } else if (_isScreenRecording || _pendingScreenRecording) {
          // Cancel recording
          if (_isScreenRecording) {
            _stopRecordingAndShowUI();
          } else {
            setState(() {
              _pendingScreenRecording = false;
              _recordingStatusMessage = '';
            });
            ToastUtils.showInfo(context, 'Recording cancelled');
          }
        }
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: Colors.black.withOpacity(0.7),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: Colors.white.withOpacity(0.2)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Blinking red dot for pending, solid for others
            shouldBlink
                ? _BlinkingDot(color: dotColor)
                : Container(
                    width: 10,
                    height: 10,
                    decoration: BoxDecoration(
                      color: dotColor,
                      shape: BoxShape.circle,
                    ),
                  ),
            const SizedBox(width: 8),
            Text(
              _recordingStatusMessage,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 12,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    );
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
    _liveKitService.dispose(); // Clean up LiveKit
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

/// Blinking record icon for active/pending recording
class _BlinkingRecordIcon extends StatefulWidget {
  @override
  State<_BlinkingRecordIcon> createState() => _BlinkingRecordIconState();
}

class _BlinkingRecordIconState extends State<_BlinkingRecordIcon>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _animation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(milliseconds: 800),
      vsync: this,
    )..repeat(reverse: true);

    _animation = Tween<double>(begin: 0.4, end: 1.0).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _animation,
      builder: (context, child) {
        return Opacity(
          opacity: _animation.value,
          child: Container(
            width: 24,
            height: 24,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: Border.all(
                color: Colors.red,
                width: 2,
              ),
            ),
            child: Center(
              child: Container(
                width: 12,
                height: 12,
                decoration: const BoxDecoration(
                  color: Colors.red,
                  shape: BoxShape.circle,
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}

/// Blinking dot widget for pending recording state
class _BlinkingDot extends StatefulWidget {
  final Color color;

  const _BlinkingDot({required this.color});

  @override
  State<_BlinkingDot> createState() => _BlinkingDotState();
}

class _BlinkingDotState extends State<_BlinkingDot>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _animation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(milliseconds: 800),
      vsync: this,
    )..repeat(reverse: true);

    _animation = Tween<double>(begin: 0.3, end: 1.0).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _animation,
      builder: (context, child) {
        return Opacity(
          opacity: _animation.value,
          child: Container(
            width: 10,
            height: 10,
            decoration: BoxDecoration(
              color: widget.color,
              shape: BoxShape.circle,
            ),
          ),
        );
      },
    );
  }
}

/// Recording permission dialog with checklist
class _RecordingPermissionDialog extends StatefulWidget {
  final VoidCallback onRecord;
  final VoidCallback onClose;

  const _RecordingPermissionDialog({
    required this.onRecord,
    required this.onClose,
  });

  @override
  State<_RecordingPermissionDialog> createState() =>
      _RecordingPermissionDialogState();
}

class _RecordingPermissionDialogState
    extends State<_RecordingPermissionDialog> {
  bool _micGranted = false;
  bool _photosGranted = false;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _checkPermissions();
  }

  Future<void> _checkPermissions() async {
    final micStatus = await Permission.microphone.status;
    // Use photosAddOnly for saving recordings (iOS)
    final photosStatus = await Permission.photosAddOnly.status;

    debugPrint('🎤 Mic status: $micStatus');
    debugPrint('📷 Photos status: $photosStatus');

    if (mounted) {
      setState(() {
        _micGranted = micStatus.isGranted;
        // Accept both granted and limited as "granted" for photos
        _photosGranted = photosStatus.isGranted || photosStatus.isLimited;
        _isLoading = false;
      });
    }
  }

  Future<void> _requestPermission(Permission permission) async {
    debugPrint('📝 Requesting permission: $permission');
    final status = await permission.request();
    debugPrint('📝 Permission result: $status');
    await _checkPermissions();

    // If permanently denied, offer to open settings
    if (status.isPermanentlyDenied && mounted) {
      final shouldOpen = await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          backgroundColor: const Color(0xFF1A1A1A),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
            side: BorderSide(color: Colors.white.withOpacity(0.1)),
          ),
          title: const Text('Permission Required',
              style: TextStyle(
                  color: Colors.white,
                  fontSize: 18,
                  fontWeight: FontWeight.bold)),
          content: const Text(
            'This permission was denied. Please enable it in Settings.',
            style: TextStyle(color: Colors.white70, fontSize: 14),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: Text('Cancel', style: TextStyle(color: Colors.grey[400])),
            ),
            TextButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('Open Settings',
                  style: TextStyle(color: Color(0xFF22C55E))),
            ),
          ],
        ),
      );
      if (shouldOpen == true) {
        await openAppSettings();
        // Re-check after returning from settings
        await _checkPermissions();
      }
    }
  }

  bool get _allPermissionsGranted => _micGranted && _photosGranted;

  Widget _buildPermissionItem({
    required String title,
    required String description,
    required bool isGranted,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: isGranted ? null : onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 12),
        decoration: BoxDecoration(
          color: isGranted ? const Color(0x1022C55E) : const Color(0x10FFFFFF),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color:
                isGranted ? const Color(0x3022C55E) : const Color(0x20FFFFFF),
            width: 1,
          ),
        ),
        child: Row(
          children: [
            // Checkbox
            Container(
              width: 24,
              height: 24,
              decoration: BoxDecoration(
                color: isGranted ? const Color(0xFF22C55E) : Colors.transparent,
                borderRadius: BorderRadius.circular(6),
                border: Border.all(
                  color: isGranted
                      ? const Color(0xFF22C55E)
                      : Colors.white.withOpacity(0.3),
                  width: 2,
                ),
              ),
              child: isGranted
                  ? const Icon(Icons.check, color: Colors.white, size: 16)
                  : null,
            ),
            const SizedBox(width: 12),
            // Text
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: Theme.of(context).textTheme.bodyLarge!.copyWith(
                          color: Colors.white,
                          fontWeight: FontWeight.w500,
                        ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    description,
                    style: Theme.of(context).textTheme.bodySmall!.copyWith(
                          color: Colors.white.withOpacity(0.6),
                        ),
                  ),
                ],
              ),
            ),
            // Tap indicator if not granted
            if (!isGranted)
              Icon(
                Icons.touch_app,
                color: Colors.white.withOpacity(0.4),
                size: 20,
              ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: widget.onClose,
      child: Stack(
        children: [
          // Blurred background
          Positioned.fill(
            child: BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 18, sigmaY: 18),
              child: Container(color: const Color(0x03FFFFFF)),
            ),
          ),
          Center(
            child: GestureDetector(
              onTap: () {}, // Prevent closing
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(16),
                  child: BackdropFilter(
                    filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
                    child: Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: const Color(0x14FFFFFF),
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(
                          color: const Color(0x14FFFFFF),
                          width: 1,
                        ),
                      ),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // Header
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Expanded(
                                child: Text(
                                  'Record next conversation?',
                                  style: Theme.of(context)
                                      .textTheme
                                      .titleLarge!
                                      .copyWith(
                                        color: Colors.white,
                                        fontWeight: FontWeight.w500,
                                      ),
                                ),
                              ),
                              GestureDetector(
                                onTap: widget.onClose,
                                child: Container(
                                  width: 28,
                                  height: 28,
                                  decoration: BoxDecoration(
                                    color: const Color(0x14FFFFFF),
                                    shape: BoxShape.circle,
                                  ),
                                  child: const Icon(Icons.close,
                                      color: Colors.white, size: 16),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 12),
                          Text(
                            'Your conversation will be recorded. Please allow the following permissions:',
                            style: Theme.of(context)
                                .textTheme
                                .bodyMedium!
                                .copyWith(color: Colors.white.withOpacity(0.8)),
                          ),
                          const SizedBox(height: 16),
                          // Permission checklist
                          if (_isLoading)
                            const Center(
                              child: Padding(
                                padding: EdgeInsets.all(20),
                                child: CircularProgressIndicator(
                                  color: Colors.white,
                                  strokeWidth: 2,
                                ),
                              ),
                            )
                          else ...[
                            _buildPermissionItem(
                              title: 'Microphone',
                              description: 'To record audio from conversation',
                              isGranted: _micGranted,
                              onTap: () =>
                                  _requestPermission(Permission.microphone),
                            ),
                            const SizedBox(height: 10),
                            _buildPermissionItem(
                              title: 'Photo Library',
                              description: 'To save recording to your device',
                              isGranted: _photosGranted,
                              onTap: () =>
                                  _requestPermission(Permission.photosAddOnly),
                            ),
                          ],
                          const SizedBox(height: 20),
                          // Record button
                          Container(
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              color: const Color(0x0DFFFFFF),
                              borderRadius: BorderRadius.circular(16),
                              border: Border.all(
                                color: const Color(0x14FFFFFF),
                                width: 1,
                              ),
                            ),
                            child: ClipRRect(
                              borderRadius: BorderRadius.circular(12),
                              child: Material(
                                color: Colors.transparent,
                                child: InkWell(
                                  onTap: _allPermissionsGranted
                                      ? widget.onRecord
                                      : null,
                                  borderRadius: BorderRadius.circular(12),
                                  child: Container(
                                    width: double.infinity,
                                    padding: const EdgeInsets.symmetric(
                                        vertical: 14),
                                    decoration: BoxDecoration(
                                      color: _allPermissionsGranted
                                          ? Colors.white
                                          : Colors.white.withOpacity(0.3),
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                    child: Center(
                                      child: Text(
                                        'Record',
                                        style: Theme.of(context)
                                            .textTheme
                                            .titleLarge!
                                            .copyWith(
                                              color: _allPermissionsGranted
                                                  ? Colors.black
                                                  : Colors.black
                                                      .withOpacity(0.4),
                                              fontWeight: FontWeight.w500,
                                            ),
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
