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
    return OnboardingScaffold(
      progress: 0.875, // 7/8
      showBackButton: true,
      child: Column(
        children: [
          // Header
          Padding(
            padding: const EdgeInsets.all(16),
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
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: OnboardingButton(
                  text: 'Yes',
                  onPressed: () => _handleResponse(true),
                  isOutlined: true,
                ),
              ),
              OnboardingButton(
                text: 'Not now',
                onPressed: () => _handleResponse(false),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

