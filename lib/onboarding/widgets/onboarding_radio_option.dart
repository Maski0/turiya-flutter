import 'package:flutter/material.dart';
import '../theme/onboarding_theme.dart';

/// Custom radio button option for onboarding
class OnboardingRadioOption extends StatelessWidget {
  final String label;
  final bool isSelected;
  final VoidCallback onTap;
  final bool showCheckmark; // Multi-select mode
  
  const OnboardingRadioOption({
    super.key,
    required this.label,
    required this.isSelected,
    required this.onTap,
    this.showCheckmark = true, // Default to multi-select style
  });
  
  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        height: 64,
        margin: const EdgeInsets.only(bottom: 12),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          curve: Curves.easeInOut,
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 20),
          decoration: BoxDecoration(
            color: isSelected
                ? const Color(0x80000000) // 50% Black for selected
                : const Color(0x40000000), // 25% Black for unselected (rgba(0,0,0,0.25))
            border: Border.all(
              color: isSelected
                  ? Colors.white // Solid white border for selected
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
          children: [
            // Radio button / Checkbox
            AnimatedContainer(
              duration: const Duration(milliseconds: 150),
              curve: Curves.easeOut,
              width: OnboardingTheme.radioButtonSize,
              height: OnboardingTheme.radioButtonSize,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(
                  color: isSelected
                      ? OnboardingTheme.textPrimary
                      : OnboardingTheme.textPrimary.withOpacity(0.4),
                  width: 1.5,
                ),
                color: isSelected && showCheckmark
                    ? OnboardingTheme.textPrimary
                    : Colors.transparent,
              ),
              child: AnimatedSwitcher(
                duration: const Duration(milliseconds: 100),
                child: isSelected
                    ? (showCheckmark
                        ? const Icon(
                            Icons.check,
                            color: OnboardingTheme.backgroundDark,
                            size: 12,
                            key: ValueKey('check'),
                          )
                        : Center(
                            child: Container(
                              key: const ValueKey('inner'),
                              width: OnboardingTheme.radioButtonInnerSize,
                              height: OnboardingTheme.radioButtonInnerSize,
                              decoration: const BoxDecoration(
                                shape: BoxShape.circle,
                                color: OnboardingTheme.radioSelected,
                              ),
                            ),
                          ))
                    : const SizedBox.shrink(key: ValueKey('empty')),
              ),
            ),
            const SizedBox(width: 16),
            // Label
            Expanded(
              child: Text(
                label,
                style: OnboardingTheme.bodyLarge.copyWith(
                  fontSize: 16,
                  height: 1.2,
                ),
              ),
            ),
          ],
        ),
        ),
      ),
    );
  }
}

