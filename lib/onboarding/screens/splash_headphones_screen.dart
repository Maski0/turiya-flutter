import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import '../theme/onboarding_theme.dart';
import '../widgets/onboarding_scaffold.dart';

/// Screen 1: Headphones recommended
class SplashHeadphonesScreen extends StatelessWidget {
  const SplashHeadphonesScreen({super.key});
  
  @override
  Widget build(BuildContext context) {
    return OnboardingScaffold(
      child: SizedBox.expand(
        child: Stack(
          children: [
          // Cloud decoration - top (with blur)
          Positioned(
            left: -37,
            top: 162,
            width: 343,
            height: 102,
            child: Opacity(
              opacity: 0.3,
              child: SvgPicture.asset(
                'assets/images/onboarding/cloud_top.svg',
                fit: BoxFit.contain,
              ),
            ),
          ),
          // Cloud decoration - bottom (with blur)
          Positioned(
            left: 165,
            bottom: 112,
            width: 343,
            height: 102,
            child: Opacity(
              opacity: 0.3,
              child: SvgPicture.asset(
                'assets/images/onboarding/cloud_bottom.svg',
                fit: BoxFit.contain,
              ),
            ),
          ),
            // Content
            Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Headphones icon
                  SizedBox(
                    width: 40,
                    height: 40,
                    child: SvgPicture.asset(
                      'assets/images/onboarding/headphones_icon.svg',
                      fit: BoxFit.contain,
                    ),
                  ),
                  const SizedBox(height: 8),
                  // Text
                  Text(
                    'Headphones recommended',
                    style: OnboardingTheme.bodyLarge.copyWith(
                      fontSize: 16,
                      color: OnboardingTheme.textPrimary.withOpacity(0.8),
                    ),
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

