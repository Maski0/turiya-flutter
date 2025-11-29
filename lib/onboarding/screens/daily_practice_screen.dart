import 'package:flutter/material.dart';
import '../theme/onboarding_theme.dart';
import '../widgets/onboarding_scaffold.dart';
import '../widgets/onboarding_button.dart';
import '../models/onboarding_data.dart';

/// Screen 20: "How would you like to shape your daily practice?"
class DailyPracticeScreen extends StatefulWidget {
  final OnboardingData data;
  final VoidCallback onNext;
  
  const DailyPracticeScreen({
    super.key,
    required this.data,
    required this.onNext,
  });
  
  @override
  State<DailyPracticeScreen> createState() => _DailyPracticeScreenState();
}

class _DailyPracticeScreenState extends State<DailyPracticeScreen> {
  final List<Map<String, String>> options = [
    {
      'title': 'Conversations with Krishna',
      'subtitle': 'Talk with Krishna about your thoughts, doubts, or everyday life. A space for reflection, comfort, and insight.',
      'icon': 'chat',
    },
    {
      'title': 'Gita Reflections',
      'subtitle': 'Deepen your understanding through daily readings and guided reflections from the Bhagavad Gita.',
      'icon': 'book',
    },
    {
      'title': 'Breathwork',
      'subtitle': 'Find calm and balance through short guided breathing sessions that center your awareness.',
      'icon': 'air',
    },
    {
      'title': 'Saadhna',
      'subtitle': 'Build a consistent spiritual discipline — combining meditation, mantra, and devotion.',
      'icon': 'yoga',
    },
  ];
  
  Set<String> selected = {};
  
  @override
  void initState() {
    super.initState();
    selected = Set.from(widget.data.dailyPractices);
  }
  
  void _handleSubmit() {
    if (selected.isNotEmpty) {
      widget.data.dailyPractices = selected.toList();
      widget.onNext();
    }
  }
  
  IconData _getIcon(String iconName) {
    switch (iconName) {
      case 'chat':
        return Icons.chat_bubble_outline;
      case 'book':
        return Icons.book_outlined;
      case 'air':
        return Icons.air;
      case 'yoga':
        return Icons.self_improvement;
      default:
        return Icons.circle;
    }
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
              'How would you like to shape your daily practice?',
              style: OnboardingTheme.headingMedium,
              textAlign: TextAlign.start,
            ),
          ),
          const SizedBox(height: 40),
          // Options
          Expanded(
            child: ListView.builder(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              itemCount: options.length,
              itemBuilder: (context, index) {
                final option = options[index];
                final title = option['title']!;
                final subtitle = option['subtitle']!;
                final icon = _getIcon(option['icon']!);
                final isSelected = selected.contains(title);
                
                return GestureDetector(
                  onTap: () {
                    setState(() {
                      if (isSelected) {
                        selected.remove(title);
                      } else {
                        selected.add(title);
                      }
                    });
                  },
                  child: Container(
                    margin: const EdgeInsets.only(bottom: 16),
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.03),
                      border: Border.all(
                        color: isSelected 
                            ? OnboardingTheme.textPrimary.withOpacity(0.4)
                            : OnboardingTheme.textPrimary.withOpacity(0.15),
                        width: 1,
                      ),
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Icon
                        Icon(
                          icon,
                          color: OnboardingTheme.textPrimary,
                          size: 28,
                        ),
                        const SizedBox(width: 16),
                        // Text
                        Expanded(
                          child: Padding(
                            padding: const EdgeInsets.only(top: 4),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  title,
                                  style: OnboardingTheme.bodyMedium.copyWith(
                                    fontSize: 16,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                                const SizedBox(height: 8),
                                Text(
                                  subtitle,
                                  style: OnboardingTheme.bodyMedium.copyWith(
                                    fontSize: 12,
                                    color: OnboardingTheme.textPrimary.withOpacity(0.65),
                                    height: 1.4,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        // Checkmark on right
                        if (isSelected)
                          Container(
                            width: 20,
                            height: 20,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: OnboardingTheme.textPrimary,
                            ),
                            child: const Icon(
                              Icons.check,
                              color: OnboardingTheme.backgroundDark,
                              size: 14,
                            ),
                          )
                        else
                          const SizedBox(width: 20, height: 20),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),
          // Continue button
          OnboardingButton(
            text: 'Continue',
            onPressed: selected.isNotEmpty ? _handleSubmit : null,
          ),
        ],
      ),
    );
  }
}

