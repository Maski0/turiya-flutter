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
    const double buttonHeightWithPadding = 80; // 64 + 8 + 8
    
    return Stack(
      children: [
        // Scrollable content with bottom padding
        ListView.builder(
          padding: EdgeInsets.only(
            left: 16,
            right: 16,
            top: 0,
            bottom: buttonHeightWithPadding + 16, // Extra space for last item visibility
          ),
          itemCount: options.length + 1, // +1 for header
          itemBuilder: (context, index) {
            if (index == 0) {
              // Header
              return Padding(
                padding: const EdgeInsets.only(left: 8, right: 8, top: 16, bottom: 16),
                child: Text(
                  'Every journey begins with a question, what brings you here?',
                  style: OnboardingTheme.headingMedium,
                  textAlign: TextAlign.start,
                ),
              );
            }
            
            final optionIndex = index - 1;
            final option = options[optionIndex];
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
        
        // Fixed button at bottom
        Positioned(
          bottom: 0,
          left: 0,
          right: 0,
          child: OnboardingButton(
            text: 'Continue',
            onPressed: selected.isNotEmpty ? _handleSubmit : null,
          ),
        ),
      ],
    );
  }
}

