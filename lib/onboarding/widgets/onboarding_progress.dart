import 'package:flutter/material.dart';
import '../theme/onboarding_theme.dart';

/// Progress bar shown at top of onboarding screens
class OnboardingProgress extends StatelessWidget {
  final double progress; // 0.0 to 1.0
  
  const OnboardingProgress({
    super.key,
    required this.progress,
  });
  
  @override
  Widget build(BuildContext context) {
    return Container(
      width: OnboardingTheme.progressBarWidth,
      height: OnboardingTheme.progressBarHeight,
      decoration: BoxDecoration(
        color: OnboardingTheme.progressBar,
        borderRadius: BorderRadius.circular(OnboardingTheme.borderRadiusFull),
      ),
      child: FractionallySizedBox(
        alignment: Alignment.centerLeft,
        widthFactor: progress.clamp(0.0, 1.0),
        child: Container(
          decoration: BoxDecoration(
            color: OnboardingTheme.progressBarFill,
            borderRadius: BorderRadius.circular(OnboardingTheme.borderRadiusFull),
          ),
        ),
      ),
    );
  }
}

