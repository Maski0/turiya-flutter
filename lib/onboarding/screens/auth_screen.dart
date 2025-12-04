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
    // Return content only - wrapper handles scaffold
    return Column(
      children: [
        // Header
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
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
                // Google Sign In - White background
                GestureDetector(
                  onTap: _handleGoogleSignIn,
                  child: Container(
                    height: 64,
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        // Google "G" logo (using text for now, proper icon should be asset)
                        Container(
                          width: 18,
                          height: 18,
                          child: Image.network(
                            'https://www.google.com/favicon.ico',
                            width: 18,
                            height: 18,
                            errorBuilder: (context, error, stackTrace) {
                              return const Text('G', style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold));
                            },
                          ),
                        ),
                        const SizedBox(width: 8),
                        Text(
                          'Sign in with Google',
                          style: OnboardingTheme.buttonText.copyWith(
                            fontSize: 16,
                            color: Colors.black,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                // Apple Sign In - Black background, white icon/text
                GestureDetector(
                  onTap: _handleAppleSignIn,
                  child: Container(
                    height: 64,
                    decoration: BoxDecoration(
                      color: Colors.black,
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        // Apple icon
                        const Icon(
                          Icons.apple,
                          color: Colors.white,
                          size: 20,
                        ),
                        const SizedBox(width: 8),
                        Text(
                          'Sign in with Apple',
                          style: OnboardingTheme.buttonText.copyWith(
                            fontSize: 16,
                            color: Colors.white,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 24),
                // Skip option - Only "Skip for later" is underlined
                GestureDetector(
                  onTap: onSkip,
                  child: RichText(
                    textAlign: TextAlign.center,
                    text: TextSpan(
                      style: OnboardingTheme.bodyMedium.copyWith(
                        fontSize: 14,
                        color: OnboardingTheme.textPrimary.withOpacity(0.6),
                      ),
                      children: const [
                        TextSpan(text: 'Don\'t want to do this now? '),
                        TextSpan(
                          text: 'Skip for later',
                          style: TextStyle(decoration: TextDecoration.underline),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 40),
              ],
            ),
          ),
        ],
    );
  }
}

