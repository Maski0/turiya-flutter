import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import '../theme/onboarding_theme.dart';
import '../widgets/onboarding_scaffold.dart';

/// Screen 13: Logo screen with "Every path begins with a first step"
class SplashLogoScreen extends StatelessWidget {
  const SplashLogoScreen({super.key});
  
  @override
  Widget build(BuildContext context) {
    return OnboardingScaffold(
      progress: 0.4,
      showBackButton: true,
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          // Turiya Morpankh logo
          SizedBox(
            width: 98.5,
            height: 156.3,
            child: SvgPicture.asset(
              'assets/images/onboarding/logo.svg',
              fit: BoxFit.contain,
            ),
          ),
          const SizedBox(height: 24),
          // Text
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Text(
              'Every path begins\nwith a first step',
              style: OnboardingTheme.displayXL,
              textAlign: TextAlign.center,
            ),
          ),
        ],
      ),
    );
  }
}

