import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import '../theme/onboarding_theme.dart';
import '../widgets/onboarding_button.dart';

/// Screen 22-24: Completion and plan ready
class CompletionScreen extends StatefulWidget {
  final VoidCallback onComplete;
  
  const CompletionScreen({
    super.key,
    required this.onComplete,
  });
  
  @override
  State<CompletionScreen> createState() => _CompletionScreenState();
}

class _CompletionScreenState extends State<CompletionScreen> with SingleTickerProviderStateMixin {
  bool isLoading = true;
  late AnimationController _progressController;
  late Animation<double> _progressAnimation;
  
  @override
  void initState() {
    super.initState();
    
    // Deterministic progress animation (0% to 100% over 3 seconds)
    _progressController = AnimationController(
      duration: const Duration(seconds: 3),
      vsync: this,
    );
    
    _progressAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _progressController, curve: Curves.easeInOut),
    );
    
    // Start animation
    _progressController.forward().then((_) {
      if (mounted) {
        setState(() {
          isLoading = false;
        });
      }
    });
  }
  
  @override
  void dispose() {
    _progressController.dispose();
    super.dispose();
  }
  
  @override
  Widget build(BuildContext context) {
    // Return content only - wrapper handles scaffold
    if (isLoading) {
      // Loading state (Screen 22-23)
      return Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // Logo
            SizedBox(
              width: 123,
              height: 156.3,
              child: SvgPicture.asset(
                'assets/images/onboarding/logo.svg',
                fit: BoxFit.contain,
              ),
            ),
            const SizedBox(height: 40),
            // Loading text
            Text(
              'Shaping a path just for you',
              style: OnboardingTheme.headingMedium.copyWith(fontSize: 24),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 12),
            Text(
              'Preparing your practice flow…',
              style: OnboardingTheme.bodyMedium.copyWith(
                fontSize: 16,
                color: OnboardingTheme.textPrimary.withOpacity(0.7),
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 40),
            // Deterministic loading bar
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 40),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(2),
                child: AnimatedBuilder(
                  animation: _progressAnimation,
                  builder: (context, child) {
                    return LinearProgressIndicator(
                      value: _progressAnimation.value, // Deterministic progress
                      backgroundColor: OnboardingTheme.progressBar,
                      valueColor: const AlwaysStoppedAnimation<Color>(
                        OnboardingTheme.progressBarFill,
                      ),
                    );
                  },
                ),
              ),
            ),
          ],
      );
    }

    // Plan ready state (Screen 24)
    const double buttonHeightWithPadding = 80; // 64 + 8 + 8
    
    return Stack(
      children: [
        // Scrollable content with bottom padding
        SingleChildScrollView(
          padding: EdgeInsets.only(
            left: 16,
            right: 16,
            top: 24,
            bottom: buttonHeightWithPadding + 16, // Extra space for visibility
          ),
          child: Column(
            children: [
              // Logo
              SizedBox(
                width: 123,
                height: 156.3,
                child: SvgPicture.asset(
                  'assets/images/onboarding/logo.svg',
                  fit: BoxFit.contain,
                ),
              ),
              const SizedBox(height: 24),
              // Header text
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Column(
                  children: [
                    Text(
                      'Your custom plan is ready',
                      style: OnboardingTheme.displayXL.copyWith(fontSize: 28),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 12),
                    Text(
                      'A sacred rhythm designed to bring peace to your mind and stillness to your heart.',
                      style: OnboardingTheme.bodyMedium.copyWith(
                        fontSize: 13,
                        color: OnboardingTheme.textPrimary.withOpacity(0.75),
                        height: 1.4,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 32),
              // Daily ritual section
              Container(
                padding: const EdgeInsets.only(left: 16, right: 16, top: 24, bottom: 16),
                decoration: BoxDecoration(
                  color: const Color(0x40000000), // 25% black to match Figma
                  borderRadius: BorderRadius.circular(24),
                  boxShadow: [
                    BoxShadow(
                      color: const Color(0x14111111), // rgba(17,17,17,0.08)
                      offset: const Offset(0, 4),
                      blurRadius: 16,
                      spreadRadius: 0,
                    ),
                  ],
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Header
                    Row(
                      children: [
                        const Icon(
                          Icons.wb_sunny_outlined,
                          color: OnboardingTheme.textPrimary,
                          size: 24,
                        ),
                        const SizedBox(width: 12),
                        Text(
                          'Daily ritual',
                          style: OnboardingTheme.headingMedium.copyWith(fontSize: 20),
                        ),
                        const Spacer(),
                        Text(
                          '1/3',
                          style: OnboardingTheme.bodyMedium.copyWith(
                            fontSize: 14,
                            color: OnboardingTheme.textPrimary.withOpacity(0.6),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 24),
                    // Practice items
                    _buildPracticeItem(
                      icon: Icons.chat_bubble_outline,
                      title: 'Reflect with Krishna',
                      duration: '20 mins',
                    ),
                    const SizedBox(height: 16),
                    _buildPracticeItem(
                      icon: Icons.self_improvement,
                      title: 'Sādhanā',
                      duration: '20 mins',
                    ),
                    const SizedBox(height: 16),
                    _buildPracticeItem(
                      icon: Icons.air,
                      title: 'Breathwork',
                      duration: 'Box breathing, 5 minutes',
                      showCheckbox: false,
                    ),
                    const SizedBox(height: 16),
                    _buildPracticeItem(
                      icon: Icons.directions_walk,
                      title: 'Outside Walk',
                      duration: '25 minutes',
                      showCheckbox: false,
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        
        // Fixed button at bottom
        Positioned(
          bottom: 0,
          left: 0,
          right: 0,
          child: OnboardingButton(
            text: 'Talk to Krishna',
            onPressed: widget.onComplete,
          ),
        ),
      ],
    );
  }

  Widget _buildPracticeItem({
    required IconData icon,
    required String title,
    required String duration,
    bool showCheckbox = false,
  }) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.transparent, // Transparent to match Figma
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: const Color(0x14111111), // rgba(17,17,17,0.08)
            offset: const Offset(0, 4),
            blurRadius: 16,
            spreadRadius: 0,
          ),
        ],
      ),
      child: Row(
        children: [
          // Icon
          Icon(
            icon,
            color: OnboardingTheme.textPrimary,
            size: 24,
          ),
          const SizedBox(width: 16),
          // Text
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: OnboardingTheme.bodyMedium.copyWith(
                    fontSize: 16,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(height: 8), // 8px gap to match Figma
                Text(
                  duration,
                  style: OnboardingTheme.bodyMedium.copyWith(
                    fontSize: 12,
                    color: OnboardingTheme.textPrimary.withOpacity(0.48), // 48% opacity to match Figma
                  ),
                ),
              ],
            ),
          ),
          // Optional checkbox placeholder
          if (showCheckbox)
            Container(
              width: 24,
              height: 24,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(
                  color: OnboardingTheme.textPrimary.withOpacity(0.3),
                  width: 1.5,
                ),
              ),
            ),
        ],
      ),
    );
  }
}

