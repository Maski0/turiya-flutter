import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_embed_unity/flutter_embed_unity.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:supabase_flutter/supabase_flutter.dart' as supabase;
import 'package:flutter_bloc/flutter_bloc.dart';
import 'elevenlabs_service.dart';
import 'audio_streamer.dart';
import 'auth_service.dart';
import 'services/backend_api_service.dart';
import 'widgets/glass_button.dart';
import 'widgets/bottom_input_bar.dart';
import 'widgets/login_modal.dart';
import 'blocs/auth/auth_bloc_export.dart';

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
  
  runApp(const ExampleApp());
}

class ExampleApp extends StatelessWidget {
  const ExampleApp({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (context) => AuthBloc(),
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
  final BackendApiService _backendApi = BackendApiService();
  late AudioStreamer _audioStreamer;
  bool _isGenerating = false;
  bool _showLoginModal = false;
  late AnimationController _animationController;
  late Animation<double> _fadeAnimation;
  String? _threadId; // Conversation thread ID

  @override
  void initState() {
    super.initState();
    
    // Initialize ElevenLabs service with your API key and voice ID from environment
    final elevenLabsService = ElevenLabsService(
      apiKey: dotenv.env['ELEVENLABS_API_KEY'] ?? '',
      voiceId: dotenv.env['ELEVENLABS_VOICE_ID'] ?? '',
    );
    _audioStreamer = AudioStreamer(elevenLabsService);
    
    // Initialize animation controller for smooth transitions
    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 300),
    );
    
    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _animationController, curve: Curves.easeInOut),
    );
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
    
    return BlocListener<AuthBloc, AuthState>(
      listener: (context, state) {
        if (state is AuthAuthenticated) {
          // Close modal on successful auth
          if (_showLoginModal) {
            _toggleLoginModal();
          }
          // Show success message
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Welcome, ${state.user.email ?? "User"}!'),
              backgroundColor: Colors.green,
              duration: const Duration(seconds: 2),
            ),
          );
        } else if (state is AuthError) {
          // Show error message
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Failed to sign in: ${state.message}'),
              backgroundColor: Colors.red,
              duration: const Duration(seconds: 3),
            ),
          );
        }
      },
      child: Scaffold(
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
                      // Menu button
                      GlassButton(
                        onTap: () {
                          // TODO: Open menu
                        },
                        child: const Icon(Icons.menu, color: Colors.white, size: 24),
                      ),
                      // Login button
                      GlassButton(
                        onTap: _toggleLoginModal,
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.meeting_room, color: Colors.white, size: 20),
                            const SizedBox(width: 8),
                            const Text(
                              'Login',
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 16,
                                fontWeight: FontWeight.w500,
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
            
            // Bottom input area
            Positioned(
              left: 0,
              right: 0,
              bottom: keyboardHeight,
              child: BottomInputBar(
                textController: _textController,
                isGenerating: _isGenerating,
                onSubmit: (value) => _generateAudio(value, context),
                onMicTap: () {
                  // TODO: Voice input
                },
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
          ],
        ),
      ),
    );
  }


  Future<void> _generateAudio(String text, BuildContext context) async {
    if (text.trim().isEmpty) return;

    // Check if user is authenticated
    final isAuthenticated = await _backendApi.isAuthenticated();
    if (!isAuthenticated) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Please sign in to chat with Krishna'),
            backgroundColor: Colors.orange,
          ),
        );
        _toggleLoginModal();
      }
      return;
    }

    setState(() {
      _isGenerating = true;
    });

    try {
      print('📨 Sending message to Krishna: $text');
      
      // 1. Call backend AI agent
      final response = await _backendApi.invokeAgent(
        message: text,
        threadId: _threadId,
        model: 'claude-3-5-sonnet-latest',
        agentId: 'krsna-agent',
      );
      
      // Store thread ID for conversation continuity
      if (_threadId == null && response['thread_id'] != null) {
        _threadId = response['thread_id'];
        print('🧵 Thread ID: $_threadId');
      }
      
      // Parse Krishna's response
      final aiMessage = response['content'];
      final aiData = jsonDecode(aiMessage);
      final krishnaResponse = aiData['response'];
      final followUps = aiData['follow_ups'] as List?;
      
      print('✅ Krishna responded: ${krishnaResponse.substring(0, 50)}...');
      if (followUps != null) {
        print('💡 Follow-ups: ${followUps.length}');
      }
      
      // Clear input field
      _textController.clear();
      
      // 2. Generate TTS from Krishna's response
      print('🎤 Generating TTS...');
      await _audioStreamer.streamToUnity(krishnaResponse);
      
      // 3. Show follow-up questions (optional - can be implemented later)
      // TODO: Display followUps in UI for quick selection
      
      print('✅ Audio sent to Unity');
      
    } on Exception catch (e) {
      print('❌ Error: $e');
      
      String errorMessage = 'Error: $e';
      
      // Handle specific errors
      if (e.toString().contains('Authentication expired')) {
        errorMessage = 'Session expired. Please sign in again.';
        _toggleLoginModal();
      } else if (e.toString().contains('Insufficient credits')) {
        errorMessage = 'Insufficient credits. Please upgrade your plan.';
      }
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(errorMessage),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 4),
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isGenerating = false;
        });
      }
    }
  }

  @override
  void dispose() {
    _textController.dispose();
    _animationController.dispose();
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