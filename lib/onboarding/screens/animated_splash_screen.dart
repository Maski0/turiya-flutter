import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import '../theme/onboarding_theme.dart';

/// Unified animated splash screen - calming, meditative pace
class AnimatedSplashScreen extends StatefulWidget {
  final VoidCallback onComplete;
  
  const AnimatedSplashScreen({
    super.key,
    required this.onComplete,
  });
  
  @override
  State<AnimatedSplashScreen> createState() => _AnimatedSplashScreenState();
}

class _AnimatedSplashScreenState extends State<AnimatedSplashScreen>
    with TickerProviderStateMixin {
  
  late AnimationController _cloudController;
  late AnimationController _sequenceController;
  late AnimationController _exitController;
  
  // Cloud gentle continuous drift
  late Animation<double> _cloud1X;
  late Animation<double> _cloud2X;
  
  // Phase animations
  late Animation<double> _headphonesOpacity;
  late Animation<double> _introTextOpacity;
  late Animation<double> _logoOpacity;
  late Animation<double> _logoScale;
  late Animation<double> _logoPositionY;
  late Animation<double> _chatOpacity;
  late Animation<double> _enterOpacity;
  
  // Exit animations
  late Animation<double> _exitOpacity;
  late Animation<double> _exitCloud1X;
  late Animation<double> _exitCloud2X;
  bool _isExiting = false;
  
  @override
  void initState() {
    super.initState();
    
    // Clouds drift gently - 35 seconds for one cycle (calm breathing pace)
    _cloudController = AnimationController(
      duration: const Duration(seconds: 10),
      vsync: this,
    )..repeat(reverse: true);
    
    // Very subtle drift - top cloud moves left, bottom cloud moves right
    _cloud1X = Tween<double>(begin: 0, end: -20).animate(
      CurvedAnimation(parent: _cloudController, curve: Curves.easeInOutSine),
    );
    _cloud2X = Tween<double>(begin: 0, end: 20).animate(
      CurvedAnimation(parent: _cloudController, curve: Curves.easeInOutSine),
    );
    
    // Main sequence - 22 seconds total, smooth and meditative
    _sequenceController = AnimationController(
      duration: const Duration(seconds: 22),
      vsync: this,
    );
    
    // === PHASE 1: Headphones (0-3.7s) - 16 weight ===
    // Fade in and out with same duration
    _headphonesOpacity = TweenSequence<double>([
      TweenSequenceItem(tween: Tween(begin: 0.0, end: 1.0), weight: 3),   // 0-0.66s fade in
      TweenSequenceItem(tween: Tween(begin: 1.0, end: 1.0), weight: 10),  // 0.66-2.86s hold (2.2s visible)
      TweenSequenceItem(tween: Tween(begin: 1.0, end: 0.0), weight: 3),   // 2.86-3.52s fade out (same as fade in)
      TweenSequenceItem(tween: Tween(begin: 0.0, end: 0.0), weight: 84),  // rest hidden
    ]).animate(CurvedAnimation(parent: _sequenceController, curve: Curves.easeInOut));
    
    // === PHASE 2: Intro text (3.7-10.5s) - 28 weight ===
    // Starts shortly after headphones fade out (minimal gap)
    _introTextOpacity = TweenSequence<double>([
      TweenSequenceItem(tween: Tween(begin: 0.0, end: 0.0), weight: 16),  // 0-3.52s hidden (0.2s gap)
      TweenSequenceItem(tween: Tween(begin: 0.0, end: 1.0), weight: 5),   // 3.7-4.8s fade in
      TweenSequenceItem(tween: Tween(begin: 1.0, end: 1.0), weight: 16),  // 4.8-8.3s hold
      TweenSequenceItem(tween: Tween(begin: 1.0, end: 0.0), weight: 8),   // 8.3-10.1s fade out
      TweenSequenceItem(tween: Tween(begin: 0.0, end: 0.0), weight: 55),  // rest hidden
    ]).animate(CurvedAnimation(parent: _sequenceController, curve: Curves.easeInOut));
    
    // === PHASE 3: Logo - Professional animation (10.3-21s) ===
    // Opacity and scale bloom TOGETHER (10.3-16.3s) - like a flower opening
    _logoOpacity = TweenSequence<double>([
      TweenSequenceItem(tween: Tween(begin: 0.0, end: 0.0), weight: 43),  // 0-10.1s hidden
      TweenSequenceItem(tween: Tween(begin: 0.0, end: 1.0), weight: 25),  // 10.1-16.1s gentle fade (6s bloom)
      TweenSequenceItem(tween: Tween(begin: 1.0, end: 1.0), weight: 32),  // rest visible
    ]).animate(CurvedAnimation(parent: _sequenceController, curve: Curves.easeInOutCubic));
    
    // Scale blooms with opacity, stays at full size
    _logoScale = TweenSequence<double>([
      TweenSequenceItem(tween: Tween(begin: 0.85, end: 0.85), weight: 43), // 0-10.1s at 0.85
      TweenSequenceItem(tween: Tween(begin: 0.85, end: 1.0), weight: 25),  // 10.1-16.1s bloom to 1.0 (6s)
      TweenSequenceItem(tween: Tween(begin: 1.0, end: 1.0), weight: 32),   // rest at full size (no shrink)
    ]).animate(CurvedAnimation(parent: _sequenceController, curve: Curves.easeInOutCubic));
    
    // Position: stay at top throughout (no vertical movement, only scale)
    _logoPositionY = TweenSequence<double>([
      TweenSequenceItem(tween: Tween(begin: 0.32, end: 0.32), weight: 100),  // Always at top position
    ]).animate(CurvedAnimation(parent: _sequenceController, curve: Curves.linear));
    
    // === PHASE 4: Chat + Enter (19-21s) - STAGGERED fade in ===
    // Chat appears WHILE logo is moving up - overlapping animation
    _chatOpacity = TweenSequence<double>([
      TweenSequenceItem(tween: Tween(begin: 0.0, end: 0.0), weight: 79),   // 0-19s hidden
      TweenSequenceItem(tween: Tween(begin: 0.0, end: 1.0), weight: 6),    // 19-20.4s quick fade in
      TweenSequenceItem(tween: Tween(begin: 1.0, end: 1.0), weight: 15),   // rest visible
    ]).animate(CurvedAnimation(parent: _sequenceController, curve: Curves.easeOut));
    
    // Enter button - starts fading AFTER chat is 50% done (staggered effect)
    _enterOpacity = TweenSequence<double>([
      TweenSequenceItem(tween: Tween(begin: 0.0, end: 0.0), weight: 82),   // 0-19.7s hidden (chat 50% done)
      TweenSequenceItem(tween: Tween(begin: 0.0, end: 1.0), weight: 5),    // 19.7-20.9s fade in
      TweenSequenceItem(tween: Tween(begin: 1.0, end: 1.0), weight: 13),   // rest visible
    ]).animate(CurvedAnimation(parent: _sequenceController, curve: Curves.easeOut));
    
    _sequenceController.forward();
    
    // Exit animation controller - 800ms for smooth exit
    _exitController = AnimationController(
      duration: const Duration(milliseconds: 800),
      vsync: this,
    );
    
    // Exit fade out - everything fades to black
    _exitOpacity = Tween<double>(begin: 1.0, end: 0.0).animate(
      CurvedAnimation(parent: _exitController, curve: Curves.easeInOut),
    );
    
    // Exit clouds - move out of view faster
    _exitCloud1X = Tween<double>(begin: 0.0, end: -150.0).animate(
      CurvedAnimation(parent: _exitController, curve: Curves.easeInCubic),
    );
    _exitCloud2X = Tween<double>(begin: 0.0, end: 150.0).animate(
      CurvedAnimation(parent: _exitController, curve: Curves.easeInCubic),
    );
  }
  
  void _handleEnterTuriya() {
    if (_isExiting) return;
    
    setState(() {
      _isExiting = true;
    });
    
    _exitController.forward().then((_) {
      if (mounted) {
        widget.onComplete();
      }
    });
  }
  
  @override
  void dispose() {
    _cloudController.dispose();
    _sequenceController.dispose();
    _exitController.dispose();
    super.dispose();
  }
  
  @override
  Widget build(BuildContext context) {
    final screenHeight = MediaQuery.of(context).size.height;
    
    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: OnboardingTheme.backgroundGradient,
        ),
        child: SafeArea(
          child: AnimatedBuilder(
            animation: Listenable.merge([_cloudController, _sequenceController, _exitController]),
            builder: (context, child) {
              // Calculate final positions (drift + exit)
              final cloud1XOffset = _cloud1X.value + (_isExiting ? _exitCloud1X.value : 0.0);
              final cloud2XOffset = _cloud2X.value + (_isExiting ? _exitCloud2X.value : 0.0);
              final contentOpacity = _isExiting ? _exitOpacity.value : 1.0;
              
              return Opacity(
                opacity: contentOpacity,
                child: Stack(
                  children: [
                    // ===== CLOUD TOP-LEFT (drifts gently left, exits fast) =====
                    Positioned(
                      left: -60,
                      top: 20,
                      width: 340,
                      height: 200,
                      child: Transform.translate(
                        offset: Offset(cloud1XOffset, 0),
                        child: Image.asset(
                          'assets/images/onboarding/cloud_top.png',
                          fit: BoxFit.contain,
                        ),
                      ),
                    ),
                    
                    // ===== CLOUD BOTTOM-RIGHT (drifts gently right, exits fast) =====
                    Positioned(
                      right: -60,
                      bottom: 40,
                      width: 340,
                      height: 200,
                      child: Transform.translate(
                        offset: Offset(cloud2XOffset, 0),
                        child: Image.asset(
                          'assets/images/onboarding/cloud_bottom.png',
                          fit: BoxFit.contain,
                        ),
                      ),
                    ),
                  
                  // ===== PHASE 1: HEADPHONES =====
                  if (_headphonesOpacity.value > 0.01)
                    Opacity(
                      opacity: _headphonesOpacity.value,
                      child: Center(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            SizedBox(
                              width: 40,
                              height: 40,
                              child: SvgPicture.asset(
                                'assets/images/onboarding/headphones_icon.svg',
                                fit: BoxFit.contain,
                              ),
                            ),
                            const SizedBox(height: 12),
                            Text(
                              'Headphones recommended',
                              style: TextStyle(
                                fontFamily: 'Alegreya',
                                fontSize: 16,
                                color: Colors.white.withOpacity(0.8),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  
                  // ===== PHASE 2: INTRO TEXT + PROGRESS BAR =====
                  if (_introTextOpacity.value > 0.01)
                    Opacity(
                      opacity: _introTextOpacity.value,
                      child: Center(
                        child: Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 32),
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(
                                'There is a state beyond',
                                style: TextStyle(
                                  fontFamily: 'Alegreya',
                                  fontSize: 24,
                                  fontStyle: FontStyle.italic,
                                  color: Colors.white,
                                  height: 1.4,
                                ),
                                textAlign: TextAlign.center,
                              ),
                              Text(
                                'waking, dreaming and sleeping',
                                style: TextStyle(
                                  fontFamily: 'Alegreya',
                                  fontSize: 24,
                                  fontStyle: FontStyle.italic,
                                  color: Colors.white,
                                  height: 1.4,
                                ),
                                textAlign: TextAlign.center,
                              ),
                              const SizedBox(height: 40),
                              // Decorative line
                              SvgPicture.asset(
                                'assets/images/onboarding/vector_7_stroke.svg',
                                width: 240,
                                height: 8,
                                fit: BoxFit.contain,
                              ),
                              const SizedBox(height: 40),
                              Text(
                                'Ancient rishis called it',
                                style: TextStyle(
                                  fontFamily: 'Alegreya',
                                  fontSize: 24,
                                  fontStyle: FontStyle.italic,
                                  color: Colors.white,
                                ),
                                textAlign: TextAlign.center,
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  
                  // ===== PHASE 3 & 4: TURIYA LOGO =====
                  if (_logoOpacity.value > 0.01)
                    Positioned(
                      left: 0,
                      right: 0,
                      top: screenHeight * _logoPositionY.value - 70,
                      child: Opacity(
                        opacity: _logoOpacity.value,
                        child: Transform.scale(
                          scale: _logoScale.value,
                          child: Center(
                            child: SizedBox(
                              width: 300,
                              height: 140,
                              child: SvgPicture.asset(
                                'assets/images/onboarding/turiya_text_logo.svg',
                                fit: BoxFit.contain,
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                  
                  // ===== PHASE 4: CHAT WITH KRISHNA =====
                  if (_chatOpacity.value > 0.01)
                    Positioned(
                      left: 0,
                      right: 0,
                      top: screenHeight * 0.40,
                      child: Opacity(
                        opacity: _chatOpacity.value,
                        child: Center(
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                            decoration: BoxDecoration(
                              color: Colors.black.withOpacity(0.25),
                              borderRadius: BorderRadius.circular(16),
                            ),
                            child: Text(
                              'Chat with Krśna',
                              style: TextStyle(
                                fontFamily: 'Alegreya',
                                fontSize: 16,
                                color: Colors.white,
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                  
                  // ===== PHASE 4: ENTER BUTTON =====
                  if (_enterOpacity.value > 0.01)
                    Positioned(
                      left: 16,
                      right: 16,
                      bottom: 50,
                      child: Opacity(
                        opacity: _enterOpacity.value,
                        child: GestureDetector(
                          onTap: _handleEnterTuriya,
                          child: Container(
                            height: 64,
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(16),
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.black.withOpacity(0.12),
                                  offset: const Offset(0, 4),
                                  blurRadius: 16,
                                  spreadRadius: 0,
                                ),
                                BoxShadow(
                                  color: Colors.black.withOpacity(0.08),
                                  offset: const Offset(0, 2),
                                  blurRadius: 8,
                                  spreadRadius: 0,
                                ),
                              ],
                            ),
                            child: Center(
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Text(
                                    'Enter ',
                                    style: TextStyle(
                                      fontFamily: 'Alegreya',
                                      fontSize: 18,
                                      fontWeight: FontWeight.w500,
                                      color: Color(0xFF111111),
                                    ),
                                  ),
                                  Text(
                                    'Turīya',
                                    style: TextStyle(
                                      fontFamily: 'Alegreya',
                                      fontSize: 18,
                                      fontWeight: FontWeight.w500,
                                      fontStyle: FontStyle.italic,
                                      color: Color(0xFF111111),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              );
            },
          ),
        ),
      ),
    );
  }
}
