import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import '../theme/onboarding_theme.dart';
import '../widgets/onboarding_scaffold.dart';
import '../models/onboarding_data.dart';

/// Screen 21: "Save your progress, make Krishna remember you"
class AuthScreen extends StatelessWidget {
  final OnboardingData data;
  final VoidCallback onNext;
  final VoidCallback onSkip;
  
  const AuthScreen({
    super.key,
    required this.data,
    required this.onNext,
    required this.onSkip,
  });
  
  void _handleGoogleSignIn() {
    // TODO: Implement Google Sign In
    data.hasCompletedAuth = true;
    onNext();
  }
  
  void _handleAppleSignIn() {
    // TODO: Implement Apple Sign In
    data.hasCompletedAuth = true;
    onNext();
  }
  
  @override
  Widget build(BuildContext context) {
    return OnboardingScaffold(
      progress: 0.875,
      showBackButton: true,
      child: Column(
        children: [
          // Header
          Padding(
            padding: const EdgeInsets.all(16),
            child: Text(
              'Save your progress, make Krishna remember you',
              style: OnboardingTheme.headingMedium,
              textAlign: TextAlign.start,
            ),
          ),
          const Spacer(),
          // Logo
          SizedBox(
            width: 98.5,
            height: 156.3,
            child: SvgPicture.asset(
              'assets/images/onboarding/logo.svg',
              fit: BoxFit.contain,
            ),
          ),
          const Spacer(),
          // Sign in options
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Column(
              children: [
                // Google Sign In
                GestureDetector(
                  onTap: _handleGoogleSignIn,
                  child: Container(
                    height: 64,
                    decoration: BoxDecoration(
                      color: Colors.transparent,
                      border: Border.all(
                        color: OnboardingTheme.textPrimary.withOpacity(0.2),
                        width: 1,
                      ),
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        // Google icon placeholder
                        Container(
                          width: 18,
                          height: 18,
                          decoration: const BoxDecoration(
                            color: Colors.white,
                            shape: BoxShape.circle,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Text(
                          'Sign in with Google',
                          style: OnboardingTheme.buttonText.copyWith(fontSize: 16),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                // Apple Sign In
                GestureDetector(
                  onTap: _handleAppleSignIn,
                  child: Container(
                    height: 64,
                    decoration: BoxDecoration(
                      color: Colors.transparent,
                      border: Border.all(
                        color: OnboardingTheme.textPrimary.withOpacity(0.2),
                        width: 1,
                      ),
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        // Apple icon
                        const Icon(
                          Icons.apple,
                          color: OnboardingTheme.textPrimary,
                          size: 20,
                        ),
                        const SizedBox(width: 8),
                        Text(
                          'Sign in with Apple',
                          style: OnboardingTheme.buttonText.copyWith(fontSize: 16),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 24),
                // Skip option
                GestureDetector(
                  onTap: onSkip,
                  child: Text(
                    'Don\'t want to do this now? Skip for later',
                    style: OnboardingTheme.bodyMedium.copyWith(
                      fontSize: 14,
                      color: OnboardingTheme.textPrimary.withOpacity(0.6),
                      decoration: TextDecoration.underline,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ),
                const SizedBox(height: 40),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

