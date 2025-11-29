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
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 20),
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.03),
          border: Border.all(
            color: isSelected
                ? OnboardingTheme.textPrimary.withOpacity(0.6)
                : OnboardingTheme.textPrimary.withOpacity(0.15),
            width: isSelected ? 1.5 : 1,
          ),
          borderRadius: BorderRadius.circular(16),
        ),
        child: Row(
          children: [
            // Radio button / Checkbox
            Container(
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
              child: isSelected
                  ? (showCheckmark
                      ? const Icon(
                          Icons.check,
                          color: OnboardingTheme.backgroundDark,
                          size: 12,
                        )
                      : Center(
                          child: Container(
                            width: OnboardingTheme.radioButtonInnerSize,
                            height: OnboardingTheme.radioButtonInnerSize,
                            decoration: const BoxDecoration(
                              shape: BoxShape.circle,
                              color: OnboardingTheme.radioSelected,
                            ),
                          ),
                        ))
                  : null,
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
    );
  }
}

