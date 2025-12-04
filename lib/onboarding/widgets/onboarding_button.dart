import 'package:flutter/material.dart';
import '../theme/onboarding_theme.dart';

/// Primary button for onboarding screens
class OnboardingButton extends StatelessWidget {
  final String text;
  final VoidCallback? onPressed;
  final bool isOutlined;
  
  const OnboardingButton({
    super.key,
    required this.text,
    this.onPressed,
    this.isOutlined = false,
  });
  
  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: GestureDetector(
        onTap: onPressed,
        child: Container(
          width: double.infinity,
          height: OnboardingTheme.buttonHeight,
          decoration: BoxDecoration(
            color: isOutlined 
                ? Colors.transparent 
                : (onPressed == null 
                    ? Colors.white.withOpacity(0.3) 
                    : Colors.white),
            border: isOutlined 
                ? Border.all(color: OnboardingTheme.textPrimary.withOpacity(0.2), width: 1)
                : null,
            borderRadius: BorderRadius.circular(OnboardingTheme.borderRadiusL),
          ),
          child: Center(
            child: Text(
              text,
              style: OnboardingTheme.buttonText.copyWith(
                color: isOutlined
                    ? (onPressed == null 
                        ? OnboardingTheme.textPrimary.withOpacity(0.5)
                        : OnboardingTheme.textPrimary)
                    : (onPressed == null
                        ? Colors.black.withOpacity(0.3)
                        : Colors.black),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

