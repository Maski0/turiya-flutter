import 'package:flutter/material.dart';
import '../theme/onboarding_theme.dart';
import '../widgets/onboarding_scaffold.dart';
import '../widgets/onboarding_radio_option.dart';
import '../widgets/onboarding_button.dart';
import '../models/onboarding_data.dart';

/// Screen 9: "What brings you here?"
class MotivationScreen extends StatefulWidget {
  final OnboardingData data;
  final VoidCallback onNext;
  
  const MotivationScreen({
    super.key,
    required this.data,
    required this.onNext,
  });
  
  @override
  State<MotivationScreen> createState() => _MotivationScreenState();
}

class _MotivationScreenState extends State<MotivationScreen> {
  final List<String> options = [
    'I want clarity and guidance',
    'I wish to reconnect with myself',
    'I\'m curious about Krishna and the Gita',
    'I\'m seeking strength or healing',
    'I want to make spirituality part of my routine',
    'I don\'t know, I\'m just exploring',
  ];
  
  Set<String> selected = {};
  
  @override
  void initState() {
    super.initState();
    selected = Set.from(widget.data.motivations);
  }
  
  void _handleSubmit() {
    if (selected.isNotEmpty) {
      widget.data.motivations = selected.toList();
      widget.onNext();
    }
  }
  
  @override
  Widget build(BuildContext context) {
    return OnboardingScaffold(
      progress: 0.25, // 2/8
      showBackButton: true,
      child: Column(
        children: [
          // Header
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 40),
            child: Text(
              'Every journey begins with a question, what brings you here?',
              style: OnboardingTheme.headingMedium,
              textAlign: TextAlign.start,
            ),
          ),
          // Options
          Expanded(
            child: ListView.builder(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              itemCount: options.length,
              itemBuilder: (context, index) {
                final option = options[index];
                final isSelected = selected.contains(option);
                return OnboardingRadioOption(
                  label: option,
                  isSelected: isSelected,
                  onTap: () {
                    setState(() {
                      if (isSelected) {
                        selected.remove(option);
                      } else {
                        selected.add(option);
                      }
                    });
                  },
                );
              },
            ),
          ),
          // Continue button
          Padding(
            padding: const EdgeInsets.only(bottom: 0),
            child: OnboardingButton(
              text: 'Continue',
              onPressed: selected.isNotEmpty ? _handleSubmit : null,
            ),
          ),
        ],
      ),
    );
  }
}

