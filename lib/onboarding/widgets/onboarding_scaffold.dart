import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../theme/onboarding_theme.dart';
import 'onboarding_progress.dart';

/// Base scaffold for onboarding screens
class OnboardingScaffold extends StatelessWidget {
  final double? progress; // 0.0 to 1.0, null to hide progress bar
  final bool showBackButton;
  final VoidCallback? onBack;
  final Widget child;
  
  const OnboardingScaffold({
    super.key,
    this.progress,
    this.showBackButton = false,
    this.onBack,
    required this.child,
  });
  
  @override
  Widget build(BuildContext context) {
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.light,
      child: Scaffold(
        body: Container(
          decoration: const BoxDecoration(
            gradient: OnboardingTheme.backgroundGradient,
          ),
          child: SafeArea(
            child: Column(
              children: [
                // Header with back button and progress bar
                if (progress != null || showBackButton)
                  Container(
                    height: 56,
                    padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
                    child: Row(
                      children: [
                        // Back button
                        if (showBackButton)
                          GestureDetector(
                            onTap: onBack ?? () => Navigator.of(context).pop(),
                            child: const SizedBox(
                              width: 24,
                              height: 24,
                              child: Icon(
                                Icons.arrow_back,
                                color: OnboardingTheme.textPrimary,
                                size: 24,
                              ),
                            ),
                          ),
                        const Spacer(),
                        // Progress bar
                        if (progress != null)
                          OnboardingProgress(progress: progress!),
                        const Spacer(),
                        // Empty space to center progress bar
                        if (showBackButton)
                          const SizedBox(width: 24, height: 24),
                      ],
                    ),
                  ),
                // Content
                Expanded(
                  child: child,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

