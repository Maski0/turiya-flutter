import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import '../theme/onboarding_theme.dart';
import '../widgets/onboarding_scaffold.dart';
import '../widgets/onboarding_button.dart';
import '../models/onboarding_data.dart';

/// Screen 19: "Would you like to receive daily blessings from Krśna?"
class DailyBlessingsScreen extends StatelessWidget {
  final OnboardingData data;
  final VoidCallback onNext;
  
  const DailyBlessingsScreen({
    super.key,
    required this.data,
    required this.onNext,
  });
  
  void _handleResponse(bool response) {
    data.wantsDailyBlessings = response;
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
            'Would you like to receive daily blessings from Krśna?',
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
        // Buttons
        Column(
          children: [
            OnboardingButton(
              text: 'Yes',
              onPressed: () => _handleResponse(true),
            ),
            const SizedBox(height: 0), // No gap between buttons
            OnboardingButton(
              text: 'Not now',
              onPressed: () => _handleResponse(false),
              isOutlined: true,
            ),
          ],
        ),
      ],
    );
  }
}

