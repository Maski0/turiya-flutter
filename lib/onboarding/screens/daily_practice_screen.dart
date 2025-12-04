import 'package:flutter/material.dart';
import 'package:liquid_glass_renderer/liquid_glass_renderer.dart';
import '../theme/onboarding_theme.dart';
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
                padding: const EdgeInsets.only(left: 8, right: 8, top: 16, bottom: 40),
                child: Text(
                  'How would you like to shape your daily practice?',
                  style: OnboardingTheme.headingMedium,
                  textAlign: TextAlign.start,
                ),
              );
            }
            
            final optionIndex = index - 1;
            final option = options[optionIndex];
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
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  curve: Curves.easeInOut,
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: isSelected
                        ? const Color(0x80000000) // 50% Black for selected
                        : const Color(0x40000000), // 25% Black for unselected (rgba(0,0,0,0.25))
                    border: Border.all(
                      color: isSelected 
                          ? Colors.white // Solid white for selected
                          : OnboardingTheme.textPrimary.withOpacity(0.15),
                      width: 1,
                    ),
                    borderRadius: BorderRadius.circular(16),
                    boxShadow: [
                      BoxShadow(
                        color: const Color(0x14111111), // rgba(17,17,17,0.08)
                        offset: const Offset(0, 4),
                        blurRadius: 16,
                        spreadRadius: 0,
                      ),
                    ],
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
                ),
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

