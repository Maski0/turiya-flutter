import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import '../theme/onboarding_theme.dart';
import '../widgets/onboarding_scaffold.dart';
import '../models/onboarding_data.dart';

/// Interlude screen with custom text
class InterludeScreen extends StatelessWidget {
  final String text;
  final double progress;
  final OnboardingData? data; // Optional, for personalized messages
  
  const InterludeScreen({
    super.key,
    required this.text,
    required this.progress,
    this.data,
  });
  
  @override
  Widget build(BuildContext context) {
    // Replace {userName} placeholder with actual name
    String displayText = text;
    if (data?.userName != null) {
      displayText = text.replaceAll('{userName}', data!.userName!);
    }
    
    // Return content only - wrapper handles scaffold
    return Column(
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
          // Text
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 32),
            child: Text(
              displayText,
              style: OnboardingTheme.displayXL.copyWith(fontSize: 32),
              textAlign: TextAlign.center,
            ),
          ),
        ],
    );
  }
}

