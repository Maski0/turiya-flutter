import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import '../theme/onboarding_theme.dart';
import '../widgets/onboarding_scaffold.dart';

/// Screen 4: "Chat with Krśna" introduction
class SplashChatIntroScreen extends StatelessWidget {
  const SplashChatIntroScreen({super.key});
  
  @override
  Widget build(BuildContext context) {
    return OnboardingScaffold(
      child: Stack(
        children: [
          // Cloud decoration - top
          Positioned(
            left: -143,
            top: 27,
            width: 343,
            height: 207,
            child: SvgPicture.asset(
              'assets/images/onboarding/cloud_top.svg',
              fit: BoxFit.contain,
            ),
          ),
          // Cloud decoration - bottom
          Positioned(
            left: 220,
            bottom: 121,
            width: 343,
            height: 207,
            child: SvgPicture.asset(
              'assets/images/onboarding/cloud_bottom.svg',
              fit: BoxFit.contain,
            ),
          ),
          // Content
          Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                // Logo
                SizedBox(
                  width: 98.5,
                  height: 156.3,
                  child: SvgPicture.asset(
                    'assets/images/onboarding/logo.svg',
                    fit: BoxFit.contain,
                  ),
                ),
                const SizedBox(height: 40),
                // "Chat with Krśna" text
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                  decoration: BoxDecoration(
                    border: Border.all(
                      color: OnboardingTheme.textPrimary.withOpacity(0.2),
                      width: 1,
                    ),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    'Chat with Krśna',
                    style: OnboardingTheme.bodyLarge.copyWith(fontSize: 16),
                  ),
                ),
                const SizedBox(height: 40),
                // "Enter" prompt at bottom
                Padding(
                  padding: const EdgeInsets.only(bottom: 100),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        'Enter',
                        style: OnboardingTheme.bodyLarge.copyWith(
                          fontSize: 20,
                          color: OnboardingTheme.textPrimary.withOpacity(0.6),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Icon(
                        Icons.arrow_forward,
                        color: OnboardingTheme.textPrimary.withOpacity(0.6),
                        size: 16,
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

