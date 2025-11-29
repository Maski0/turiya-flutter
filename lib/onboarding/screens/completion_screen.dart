import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import '../theme/onboarding_theme.dart';
import '../widgets/onboarding_scaffold.dart';
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

class _CompletionScreenState extends State<CompletionScreen> {
  bool isLoading = true;
  
  @override
  void initState() {
    super.initState();
    // Simulate plan creation
    Future.delayed(const Duration(seconds: 3), () {
      if (mounted) {
        setState(() {
          isLoading = false;
        });
      }
    });
  }
  
  @override
  Widget build(BuildContext context) {
    if (isLoading) {
      // Loading state (Screen 22-23)
      return OnboardingScaffold(
        progress: 1.0,
        child: Column(
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
            // Loading bar
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 40),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(2),
                child: const LinearProgressIndicator(
                  backgroundColor: OnboardingTheme.progressBar,
                  valueColor: AlwaysStoppedAnimation<Color>(
                    OnboardingTheme.progressBarFill,
                  ),
                ),
              ),
            ),
          ],
        ),
      );
    }

    // Plan ready state (Screen 24)
    return OnboardingScaffold(
      progress: 1.0,
      child: Column(
        children: [
          const SizedBox(height: 24),
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
            padding: const EdgeInsets.symmetric(horizontal: 32),
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
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.03),
                  border: Border.all(
                    color: OnboardingTheme.textPrimary.withOpacity(0.15),
                    width: 1,
                  ),
                  borderRadius: BorderRadius.circular(16),
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
            ),
          ),
          // Button
          OnboardingButton(
            text: 'Talk to Krishna',
            onPressed: widget.onComplete,
          ),
        ],
      ),
    );
  }

  Widget _buildPracticeItem({
    required IconData icon,
    required String title,
    required String duration,
    bool showCheckbox = false,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 18),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.02),
        border: Border.all(
          color: OnboardingTheme.textPrimary.withOpacity(0.1),
          width: 1,
        ),
        borderRadius: BorderRadius.circular(12),
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
                const SizedBox(height: 4),
                Text(
                  duration,
                  style: OnboardingTheme.bodyMedium.copyWith(
                    fontSize: 12,
                    color: OnboardingTheme.textPrimary.withOpacity(0.6),
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

