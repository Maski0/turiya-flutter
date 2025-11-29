import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import '../theme/onboarding_theme.dart';
import '../widgets/onboarding_scaffold.dart';

/// Screen 2: "There is a state beyond waking, dreaming and sleeping... Ancient rishis called it"
class SplashIntroScreen extends StatelessWidget {
  const SplashIntroScreen({super.key});
  
  @override
  Widget build(BuildContext context) {
    return OnboardingScaffold(
      child: Stack(
        children: [
          // Cloud decoration - top (with blur)
          Positioned(
            left: -82,
            top: 69,
            width: 343,
            height: 207,
            child: Opacity(
              opacity: 0.3,
              child: SvgPicture.asset(
                'assets/images/onboarding/cloud_bottom.svg',
                fit: BoxFit.contain,
              ),
            ),
          ),
          // Cloud decoration - bottom (with blur)
          Positioned(
            left: 306,
            bottom: 134,
            width: 343,
            height: 89,
            child: Opacity(
              opacity: 0.3,
              child: SvgPicture.asset(
                'assets/images/onboarding/cloud_top.svg',
                fit: BoxFit.contain,
              ),
            ),
          ),
          // Content
          Center(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    'There is a state beyond waking, dreaming and sleeping',
                    style: OnboardingTheme.headingMedium.copyWith(fontSize: 24),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 32),
                  // Decorative line
                  Container(
                    width: 246,
                    height: 6,
                    decoration: BoxDecoration(
                      color: OnboardingTheme.textPrimary.withOpacity(0.2),
                      borderRadius: BorderRadius.circular(3),
                    ),
                  ),
                  const SizedBox(height: 32),
                  Text(
                    'Ancient rishis called it',
                    style: OnboardingTheme.bodyLarge,
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

