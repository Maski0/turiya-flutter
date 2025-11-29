import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import '../theme/onboarding_theme.dart';
import '../widgets/onboarding_scaffold.dart';
import '../models/onboarding_data.dart';

/// Screen 7: Greeting screen "Namaste {userName}"
class GreetingScreen extends StatelessWidget {
  final OnboardingData data;
  
  const GreetingScreen({
    super.key,
    required this.data,
  });
  
  @override
  Widget build(BuildContext context) {
    return OnboardingScaffold(
      progress: 0.2,
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
          const SizedBox(height: 40),
          // Greeting text with user's name
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 32),
            child: Text(
              'Namaste ${data.userName ?? ""}',
              style: OnboardingTheme.displayXL.copyWith(fontSize: 36),
              textAlign: TextAlign.center,
            ),
          ),
        ],
      ),
    );
  }
}

