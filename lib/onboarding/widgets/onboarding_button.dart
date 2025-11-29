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
    return GestureDetector(
      onTap: onPressed,
      child: Container(
        height: OnboardingTheme.buttonHeight,
        padding: const EdgeInsets.symmetric(horizontal: 24),
        decoration: BoxDecoration(
          color: isOutlined ? Colors.transparent : Colors.transparent,
          border: isOutlined 
              ? Border.all(color: OnboardingTheme.textPrimary.withOpacity(0.2), width: 1)
              : const Border(
                  top: BorderSide(color: Color(0x1AFFFFFF), width: 1),
                ),
          borderRadius: isOutlined ? BorderRadius.circular(OnboardingTheme.borderRadiusL) : null,
        ),
        child: Center(
          child: Text(
            text,
            style: OnboardingTheme.buttonText.copyWith(
              color: onPressed == null 
                  ? OnboardingTheme.textPrimary.withOpacity(0.5)
                  : OnboardingTheme.textPrimary,
            ),
          ),
        ),
      ),
    );
  }
}

