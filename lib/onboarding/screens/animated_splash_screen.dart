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
  
  @override
  void initState() {
    super.initState();
    
    // Clouds drift very slowly - 60 seconds for one cycle (breathing pace)
    _cloudController = AnimationController(
      duration: const Duration(seconds: 60),
      vsync: this,
    )..repeat(reverse: true);
    
    // Subtle drift - top cloud moves left, bottom cloud moves right
    _cloud1X = Tween<double>(begin: 0, end: -30).animate(
      CurvedAnimation(parent: _cloudController, curve: Curves.easeInOut),
    );
    _cloud2X = Tween<double>(begin: 0, end: 30).animate(
      CurvedAnimation(parent: _cloudController, curve: Curves.easeInOut),
    );
    
    // Main sequence - 28 seconds total, slow and meditative (professional timing)
    _sequenceController = AnimationController(
      duration: const Duration(seconds: 28),
      vsync: this,
    );
    
    // === PHASE 1: Headphones (0-4s) - 14 weight ===
    _headphonesOpacity = TweenSequence<double>([
      TweenSequenceItem(tween: Tween(begin: 0.0, end: 1.0), weight: 5),   // 0-1.4s fade in
      TweenSequenceItem(tween: Tween(begin: 1.0, end: 1.0), weight: 5),   // 1.4-2.8s hold
      TweenSequenceItem(tween: Tween(begin: 1.0, end: 0.0), weight: 4),   // 2.8-4s fade out
      TweenSequenceItem(tween: Tween(begin: 0.0, end: 0.0), weight: 86),  // rest hidden
    ]).animate(CurvedAnimation(parent: _sequenceController, curve: Curves.easeInOut));
    
    // === PHASE 2: Intro text (4-12s) - 29 weight ===
    _introTextOpacity = TweenSequence<double>([
      TweenSequenceItem(tween: Tween(begin: 0.0, end: 0.0), weight: 14),  // 0-4s hidden
      TweenSequenceItem(tween: Tween(begin: 0.0, end: 1.0), weight: 7),   // 4-6s fade in
      TweenSequenceItem(tween: Tween(begin: 1.0, end: 1.0), weight: 14),  // 6-10s hold
      TweenSequenceItem(tween: Tween(begin: 1.0, end: 0.0), weight: 8),   // 10-12s fade out
      TweenSequenceItem(tween: Tween(begin: 0.0, end: 0.0), weight: 57),  // rest hidden
    ]).animate(CurvedAnimation(parent: _sequenceController, curve: Curves.easeInOut));
    
    // === PHASE 3: Logo - Professional animation (12-23s) ===
    // Opacity and scale bloom TOGETHER (12-18s) - like a flower opening
    _logoOpacity = TweenSequence<double>([
      TweenSequenceItem(tween: Tween(begin: 0.0, end: 0.0), weight: 43),  // 0-12s hidden
      TweenSequenceItem(tween: Tween(begin: 0.0, end: 1.0), weight: 21),  // 12-18s gentle fade (6s bloom)
      TweenSequenceItem(tween: Tween(begin: 1.0, end: 1.0), weight: 36),  // rest visible
    ]).animate(CurvedAnimation(parent: _sequenceController, curve: Curves.easeInOutCubic));
    
    // Scale blooms with opacity, stays at full size
    _logoScale = TweenSequence<double>([
      TweenSequenceItem(tween: Tween(begin: 0.85, end: 0.85), weight: 43), // 0-12s at 0.85
      TweenSequenceItem(tween: Tween(begin: 0.85, end: 1.0), weight: 21),  // 12-18s bloom to 1.0 (6s)
      TweenSequenceItem(tween: Tween(begin: 1.0, end: 1.0), weight: 36),   // rest at full size (no shrink)
    ]).animate(CurvedAnimation(parent: _sequenceController, curve: Curves.easeInOutCubic));
    
    // Position: hold at center during bloom, then gentle rise (20-23s)
    _logoPositionY = TweenSequence<double>([
      TweenSequenceItem(tween: Tween(begin: 0.5, end: 0.5), weight: 71),   // 0-20s centered (through bloom+hold)
      TweenSequenceItem(tween: Tween(begin: 0.5, end: 0.32), weight: 11),  // 20-23s move up (3s)
      TweenSequenceItem(tween: Tween(begin: 0.32, end: 0.32), weight: 18), // rest at top
    ]).animate(CurvedAnimation(parent: _sequenceController, curve: Curves.easeOutCubic));
    
    // === PHASE 4: Chat + Enter (22.5-26s) ===
    // Chat appears as logo settles into place
    _chatOpacity = TweenSequence<double>([
      TweenSequenceItem(tween: Tween(begin: 0.0, end: 0.0), weight: 80),   // 0-22.5s hidden
      TweenSequenceItem(tween: Tween(begin: 0.0, end: 1.0), weight: 7),    // 22.5-24.5s fade in
      TweenSequenceItem(tween: Tween(begin: 1.0, end: 1.0), weight: 13),   // rest visible
    ]).animate(CurvedAnimation(parent: _sequenceController, curve: Curves.easeOut));
    
    // Enter button - final element, calm entrance
    _enterOpacity = TweenSequence<double>([
      TweenSequenceItem(tween: Tween(begin: 0.0, end: 0.0), weight: 86),   // 0-24s hidden
      TweenSequenceItem(tween: Tween(begin: 0.0, end: 1.0), weight: 7),    // 24-26s fade in
      TweenSequenceItem(tween: Tween(begin: 1.0, end: 1.0), weight: 7),    // rest visible
    ]).animate(CurvedAnimation(parent: _sequenceController, curve: Curves.easeOut));
    
    _sequenceController.forward();
  }
  
  @override
  void dispose() {
    _cloudController.dispose();
    _sequenceController.dispose();
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
            animation: Listenable.merge([_cloudController, _sequenceController]),
            builder: (context, child) {
              return Stack(
                children: [
                  // ===== CLOUD TOP-LEFT (stays in place, drifts gently) =====
                  Positioned(
                    left: -60 + _cloud1X.value,
                    top: 20,
                    width: 340,
                    height: 200,
                    child: Image.asset(
                      'assets/images/onboarding/cloud_top.png',
                      fit: BoxFit.contain,
                    ),
                  ),
                  
                  // ===== CLOUD BOTTOM-RIGHT (stays in place, drifts gently) =====
                  Positioned(
                    right: -60 + _cloud2X.value,
                    bottom: 40,
                    width: 340,
                    height: 200,
                    child: Image.asset(
                      'assets/images/onboarding/cloud_bottom.png',
                      fit: BoxFit.contain,
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
                          onTap: widget.onComplete,
                          child: Container(
                            height: 64,
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(16),
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
              );
            },
          ),
        ),
      ),
    );
  }
}
