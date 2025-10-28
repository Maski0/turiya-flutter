import 'dart:async';
import 'dart:math';
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
import 'widgets/subtitle_widget.dart';
import 'widgets/profile_avatar_widget.dart';
import 'blocs/auth/auth_bloc_export.dart';
import 'blocs/chat/chat_bloc_export.dart';
import 'blocs/credits/credits_bloc.dart';
import 'blocs/memory/memory_bloc.dart';
import 'package:speech_to_text/speech_to_text.dart' as stt;
import 'package:permission_handler/permission_handler.dart';

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
        theme: ThemeData(
          fontFamily: 'Alegreya',
          brightness: Brightness.dark,
        ),
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

class _MainScreenState extends State<_MainScreen> with SingleTickerProviderStateMixin {
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
  Timer? _chipAutoHideTimer; // Timer for auto-hiding the chip
  late AnimationController _animationController;
  late Animation<double> _fadeAnimation;
  String? _threadId; // Conversation thread ID
  List<String> _previousFollowUps = []; // Track previous follow-ups for animation
  bool _showFollowUps = false; // Control fade-in animation
  String? _lastUserMessage; // Track last sent message
  bool _showUserMessageBubble = false; // Control user message bubble visibility
  
  // Subtitle state
  AlignmentData? _currentAlignment;
  bool _isAudioPlaying = false;
  
  // Track currently playing message to prevent duplicates
  String? _currentlyPlayingMessageId;

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
            } else if (state is AuthError) {
              // Show error message
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text('Failed to sign in: ${state.message}'),
                  backgroundColor: Colors.red,
                  duration: const Duration(seconds: 3),
                  behavior: SnackBarBehavior.floating,
                  margin: const EdgeInsets.only(top: 80, left: 20, right: 20),
                ),
              );
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
              
              // Don't reset generating flag here - keep it until audio finishes
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
                  print('🎵 Playing TTS for message ID: ${message.id}');
                  
                  // Mark this message as currently playing
                  _currentlyPlayingMessageId = message.id;
                  
                  // Generate TTS with subtitles
                  try {
                    print('🎤 Generating TTS with timestamps...');
                    print('📝 Text for TTS: "${message.content}"');
                    print('📝 Text length: ${message.content.length} chars');
                    
                    // Clear previous alignment (but don't set isAudioPlaying yet to avoid blink)
                    if (mounted) {
                      setState(() {
                        _currentAlignment = null;
                        _isAudioPlaying = false;
                      });
                    }
                    
                    // Content is already parsed in ChatMessage.fromJson, use directly
                    await _audioStreamer.streamToUnity(
                      message.content,
                      onAlignmentUpdate: (alignment) {
                        // Update alignment data as chunks arrive (but don't start audio playback yet)
                        if (mounted) {
                          setState(() {
                            _currentAlignment = alignment;
                          });
                        }
                      },
                    );
                    print('✅ Audio sent to Unity with ${_currentAlignment?.characters.length ?? 0} characters');
                    print('🎵 All audio chunks sent - Unity should be playing NOW');
                    
                    // NOW start audio playback - Unity has received all chunks and END signal
                    if (mounted) {
                      setState(() {
                        _isAudioPlaying = true;
                        _showFollowUps = false; // Hide follow-ups when audio starts
                      });
                      print('🔊 Set _isAudioPlaying = true at ${DateTime.now()}');
                    }
                    
                    // Calculate actual audio duration from alignment data
                    double audioDuration = 3.0; // Default fallback
                    if (_currentAlignment != null && 
                        _currentAlignment!.characterEndTimesSeconds.isNotEmpty) {
                      // Get the end time of the last character
                      audioDuration = _currentAlignment!.characterEndTimesSeconds.last;
                      // Add a small buffer (0.5s) to ensure audio finishes
                      audioDuration += 0.5;
                      print('📊 Audio duration: ${audioDuration.toStringAsFixed(2)}s');
                    } else {
                      print('⚠️ No alignment data, using default ${audioDuration}s duration');
                    }
                    
                    // Mark message as played
                    if (_threadId != null) {
                      context.read<ChatBloc>().add(ChatMessagePlayedStatusUpdated(
                        messageId: message.id,
                        threadId: _threadId!,
                        isPlayed: true,
                      ));
                      print('✅ Marked message ${message.id} as played');
                    }
                    
                    // Clear the currently playing message ID
                    _currentlyPlayingMessageId = null;
                    
                    // Stop showing subtitles after the actual audio duration
                    Future.delayed(Duration(milliseconds: (audioDuration * 1000).toInt()), () async {
                      if (mounted) {
                        setState(() {
                          _isAudioPlaying = false;
                          _currentAlignment = null; // Clear alignment data too
                          _isGenerating = false; // Reset generating state after audio finishes
                        });
                        print('🔇 Subtitles hidden after ${audioDuration.toStringAsFixed(2)}s');
                        print('✅ Reset _isGenerating = false (audio finished)');
                        
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
                  } catch (e) {
                    print('❌ TTS Error: $e');
                    // Clear the currently playing message ID on error
                    _currentlyPlayingMessageId = null;
                    
                    // Hide subtitles immediately on error
                    if (mounted) {
                      setState(() {
                        _isAudioPlaying = false;
                        _currentAlignment = null;
                        _showUserMessageBubble = false; // Hide user message on error
                        _isGenerating = false; // Reset generating state on error
                      });
                      
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
              // Handle error and reset generating flag
              if (_isGenerating) {
                _isGenerating = false;
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text(state.message),
                    backgroundColor: Colors.red,
                    behavior: SnackBarBehavior.floating,
                    margin: const EdgeInsets.only(top: 80, left: 20, right: 20),
                  ),
                );
              }
            }
          },
        ),
      ],
      child: Scaffold(
        backgroundColor: Colors.black,
        resizeToAvoidBottomInset: false,
        body: Stack(
          children: [
            // Unity avatar - full screen background
            const Positioned.fill(
              child: EmbedUnity(),
            ),
            
            // Top bar with menu and login
            Positioned(
              top: 0,
              left: 0,
              right: 0,
              child: SafeArea(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      // Menu button (opens chat) - only when authenticated
                      BlocBuilder<AuthBloc, AuthState>(
                        builder: (context, state) {
                          if (state is AuthAuthenticated) {
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
                                    Icons.menu,
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
                      // Right side - Profile or Login
                      BlocBuilder<AuthBloc, AuthState>(
                        builder: (context, state) {
                          if (state is AuthAuthenticated) {
                            return ProfileAvatarWidget(
                              onTap: () {
                                setState(() {
                                  _showMenuDrawer = true;
                                });
                                _animationController.forward();
                              },
                            );
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
                ),
              ),
            ),
            
            // Login Modal Overlay
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
                      // "Talk to Krishna" chip - only visible when chat is open
                      if (_showChip && _showChatSidebar)
                        AnimatedSlide(
                        offset: Offset.zero,
                        duration: const Duration(milliseconds: 450),
                        curve: Curves.easeOutBack,
                        child: AnimatedOpacity(
                          opacity: 1.0,
                          duration: const Duration(milliseconds: 300),
                          child: Padding(
                            padding: const EdgeInsets.only(bottom: 8),
                          child: Center(
                            child: GestureDetector(
                              onTap: () {
                                // Close chip and chat overlay immediately
                                _chipAutoHideTimer?.cancel(); // Cancel timer
                                setState(() {
                                  _showChip = false;
                                });
                                _animationController.reverse().then((_) {
                                  if (mounted) {
                                    setState(() {
                                      _showChatSidebar = false;
                                    });
                                  }
                                });
                              },
                              child: Container(
                                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                                decoration: BoxDecoration(
                                  gradient: LinearGradient(
                                    colors: [
                                      Colors.white.withOpacity(0.2),
                                      Colors.white.withOpacity(0.1),
                                    ],
                                  ),
                                  borderRadius: BorderRadius.circular(20),
                                  border: Border.all(
                                    color: Colors.white.withOpacity(0.3),
                                    width: 1,
                                  ),
                                ),
                                    child: Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        // Chevron back icon
                                        Icon(
                                          Icons.keyboard_arrow_down,
                                          color: Colors.white.withOpacity(0.8),
                                          size: 20,
                                        ),
                                        const SizedBox(width: 6),
                                        Text(
                                          'Talk to Kṛṣṇa',
                                          style: TextStyle(
                                            color: Colors.white.withOpacity(0.9),
                                            fontSize: 13,
                                            fontWeight: FontWeight.w500,
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
                    BottomInputBar(
                      textController: _textController,
                      focusNode: _textFocusNode,
                      isGenerating: _isGenerating,
                      isRecording: _isRecording,
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
                    padding: const EdgeInsets.only(top: 20),
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
            
            // Real-time subtitles - shows during audio playback
            if (_isAudioPlaying && _currentAlignment != null)
              SubtitleWidget(
                alignment: _currentAlignment,
                isPlaying: _isAudioPlaying,
              ),
          ],
        ),
      ),
    );
  }


  Future<void> _startListening() async {
    // Request microphone permission
    final status = await Permission.microphone.request();
    if (!status.isGranted) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Microphone permission required'),
            backgroundColor: Colors.red,
            behavior: SnackBarBehavior.floating,
            margin: EdgeInsets.only(top: 80, left: 20, right: 20),
          ),
        );
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
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Speech recognition not available'),
            backgroundColor: Colors.red,
            behavior: SnackBarBehavior.floating,
            margin: EdgeInsets.only(top: 80, left: 20, right: 20),
          ),
        );
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
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Please sign in to chat with Krishna'),
            backgroundColor: Colors.orange,
            behavior: SnackBarBehavior.floating,
            margin: EdgeInsets.only(top: 80, left: 20, right: 20),
          ),
        );
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

    // Clear input field immediately
    _textController.clear();

    print('📨 Sending message via ChatBloc: $text');
    
    // Send message via ChatBloc - the BlocListener will handle the response
    context.read<ChatBloc>().add(ChatMessageSent(
      message: text,
      threadId: _threadId,
    ));
  }

  @override
  void dispose() {
    _textController.dispose();
    _textFocusNode.dispose();
    _scrollController.dispose();
    _animationController.dispose();
    _chipAutoHideTimer?.cancel(); // Cancel timer on dispose
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