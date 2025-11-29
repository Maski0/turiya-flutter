import 'package:flutter/material.dart';
import '../theme/onboarding_theme.dart';
import '../widgets/onboarding_scaffold.dart';
import '../widgets/onboarding_radio_option.dart';
import '../widgets/onboarding_button.dart';
import '../models/onboarding_data.dart';

/// Screen 12: "How familiar are you with the teachings of vedanta?"
class VedantaFamiliarityScreen extends StatefulWidget {
  final OnboardingData data;
  final VoidCallback onNext;
  
  const VedantaFamiliarityScreen({
    super.key,
    required this.data,
    required this.onNext,
  });
  
  @override
  State<VedantaFamiliarityScreen> createState() => _VedantaFamiliarityScreenState();
}

class _VedantaFamiliarityScreenState extends State<VedantaFamiliarityScreen> {
  final List<String> options = [
    'I\'m new to this',
    'I\'ve read or heard about this',
    'I\'ve practiced before',
  ];
  
  String? selected;
  
  @override
  void initState() {
    super.initState();
    selected = widget.data.vedantaFamiliarity;
  }
  
  void _handleSubmit() {
    if (selected != null) {
      widget.data.vedantaFamiliarity = selected;
      widget.onNext();
    }
  }
  
  @override
  Widget build(BuildContext context) {
    return OnboardingScaffold(
      progress: 0.375, // 3/8
      showBackButton: true,
      child: Column(
        children: [
          // Header
          Padding(
            padding: const EdgeInsets.all(16),
            child: Text(
              'How familiar are you with the teachings of vedanta?',
              style: OnboardingTheme.headingMedium,
              textAlign: TextAlign.start,
            ),
          ),
          const SizedBox(height: 40),
          // Options
          ...options.map((option) => OnboardingRadioOption(
            label: option,
            isSelected: selected == option,
            showCheckmark: false, // Single-select, not multi-select
            onTap: () {
              setState(() {
                selected = option;
              });
            },
          )),
          const Spacer(),
          // Continue button
          OnboardingButton(
            text: 'Continue',
            onPressed: selected != null ? _handleSubmit : null,
          ),
        ],
      ),
    );
  }
}

