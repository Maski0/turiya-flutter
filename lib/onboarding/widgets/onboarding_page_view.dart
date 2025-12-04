import 'package:flutter/material.dart';
import '../theme/onboarding_theme.dart';

/// Unified onboarding page view with fixed header and smooth transitions
class OnboardingPageView extends StatefulWidget {
  final double progress;
  final bool showBackButton;
  final VoidCallback? onBack;
  final Widget child;
  final Key? childKey; // To detect when child changes
  
  const OnboardingPageView({
    super.key,
    required this.progress,
    required this.showBackButton,
    this.onBack,
    required this.child,
    this.childKey,
  });
  
  @override
  State<OnboardingPageView> createState() => OnboardingPageViewState();
}

class OnboardingPageViewState extends State<OnboardingPageView>
    with SingleTickerProviderStateMixin {
  late AnimationController _fadeController;
  late Animation<double> _fadeAnimation;
  
  Widget? _currentChild;
  Widget? _nextChild;
  bool _showBackButton = false;
  bool _isTransitioning = false;
  
  @override
  void initState() {
    super.initState();
    
    _fadeController = AnimationController(
      duration: const Duration(milliseconds: 350), // 350ms for each fade
      vsync: this,
    );
    
    _fadeAnimation = Tween<double>(begin: 1.0, end: 0.0).animate(
      CurvedAnimation(parent: _fadeController, curve: Curves.easeInOut),
    );
    
    _currentChild = widget.child;
    _showBackButton = widget.showBackButton;
  }
  
  @override
  void didUpdateWidget(OnboardingPageView oldWidget) {
    super.didUpdateWidget(oldWidget);
    
    // Detect if child changed (new screen)
    if (widget.childKey != oldWidget.childKey && !_isTransitioning) {
      _transitionToNewChild();
    }
  }
  
  void _transitionToNewChild() async {
    if (_isTransitioning) {
      print('🚫 Already transitioning');
      return;
    }
    
    print('🎬 Starting transition... opacity=${_fadeAnimation.value}');
    
    // Close keyboard first
    FocusScope.of(context).unfocus();
    
    setState(() {
      _isTransitioning = true;
      _nextChild = widget.child;
    });
    
    // Wait a bit for keyboard to close
    await Future.delayed(const Duration(milliseconds: 150));
    if (!mounted) return;
    
    // Step 1: Fade out current screen (350ms)
    print('📉 Fading out...');
    await _fadeController.forward();
    if (!mounted) return;
    print('✅ Faded out, opacity=${_fadeAnimation.value}');
    
    // Step 2: Switch to next child while screen is blank
    print('🔄 Switching child...');
    setState(() {
      _currentChild = _nextChild;
      _nextChild = null;
      _showBackButton = widget.showBackButton; // Update button visibility here
    });
    
    // Brief pause while blank
    await Future.delayed(const Duration(milliseconds: 50));
    if (!mounted) return;
    
    // Step 3: Fade in next screen (350ms)
    print('📈 Fading in...');
    await _fadeController.reverse();
    if (!mounted) return;
    print('✅ Faded in, opacity=${_fadeAnimation.value}');
    
    setState(() {
      _isTransitioning = false;
    });
    print('🎉 Transition complete!');
  }
  
  @override
  void dispose() {
    _fadeController.dispose();
    super.dispose();
  }
  
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.transparent,
      body: Container(
        decoration: const BoxDecoration(
          gradient: OnboardingTheme.backgroundGradient,
        ),
        child: SafeArea(
          child: Column(
            children: [
              // ===== FIXED HEADER: Back Button + Progress Bar =====
              SizedBox(
                height: 56,
                child: Stack(
                  children: [
                    // Back button - fades with content
                    if (_showBackButton)
                      Positioned(
                        left: 24,
                        top: 8,
                        child: FadeTransition(
                          opacity: _fadeAnimation,
                          child: IconButton(
                            icon: const Icon(
                              Icons.arrow_back,
                              color: Colors.white,
                              size: 24,
                            ),
                            onPressed: widget.onBack,
                          ),
                        ),
                      ),
                    
                    // Animated Progress Bar
                    Center(
                      child: Container(
                        width: 136,
                        height: 4,
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.2),
                          borderRadius: BorderRadius.circular(2),
                        ),
                        child: Align(
                          alignment: Alignment.centerLeft,
                          child: AnimatedContainer(
                            duration: const Duration(milliseconds: 600),
                            curve: Curves.easeInOutCubic,
                            width: 136 * widget.progress.clamp(0.0, 1.0),
                            height: 4,
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(2),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              
              // ===== CONTENT AREA: Sequential fade out → fade in =====
              Expanded(
                child: FadeTransition(
                  opacity: _fadeAnimation,
                  child: _currentChild ?? const SizedBox.shrink(),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

