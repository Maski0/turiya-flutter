import 'package:flutter/material.dart';

/// Design tokens extracted from Figma design
class OnboardingTheme {
  // Colors
  static const Color backgroundDark = Color(0xFF00263B); // Dark teal bottom
  static const Color backgroundLight = Color(0xFF004459); // Light teal top
  static const Color textPrimary = Color(0xFFFFFFFF); // White
  static const Color textSecondary = Color(0xFFFFFFFF); // White with opacity
  static const Color accentOrange = Color(0xFFFF6B35); // Orange accent
  static const Color progressBar = Color(0x1AFFFFFF); // Progress bar background (10% white)
  static const Color progressBarFill = Color(0xFFFFFFFF); // Progress bar fill
  static const Color radioSelected = Color(0xFFFFFFFF); // Selected radio button
  static const Color radioUnselected = Color(0x33FFFFFF); // Unselected radio (20% white)
  
  // Gradients
  static const LinearGradient backgroundGradient = LinearGradient(
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
    colors: [backgroundLight, backgroundDark],
  );
  
  // Typography
  static const TextStyle displayXL = TextStyle(
    fontFamily: 'Alegreya',
    fontSize: 40,
    fontWeight: FontWeight.w400,
    height: 1.2,
    letterSpacing: -0.4,
    color: textPrimary,
  );
  
  static const TextStyle headingLarge = TextStyle(
    fontFamily: 'Alegreya',
    fontSize: 32,
    fontWeight: FontWeight.w400,
    height: 1.2,
    letterSpacing: -0.2,
    color: textPrimary,
  );
  
  static const TextStyle headingMedium = TextStyle(
    fontFamily: 'Alegreya',
    fontSize: 28,
    fontWeight: FontWeight.w400,
    height: 1.3,
    color: textPrimary,
  );
  
  static const TextStyle bodyLarge = TextStyle(
    fontFamily: 'Alegreya',
    fontSize: 20,
    fontWeight: FontWeight.w400,
    height: 1.4,
    color: textPrimary,
  );
  
  static const TextStyle bodyMedium = TextStyle(
    fontFamily: 'Alegreya',
    fontSize: 16,
    fontWeight: FontWeight.w400,
    height: 1.4,
    color: textPrimary,
  );
  
  static const TextStyle buttonText = TextStyle(
    fontFamily: 'Alegreya',
    fontSize: 20,
    fontWeight: FontWeight.w500,
    height: 1.5,
    color: textPrimary,
  );
  
  // Spacing
  static const double spacingXS = 8.0;
  static const double spacingS = 16.0;
  static const double spacingM = 24.0;
  static const double spacingL = 32.0;
  static const double spacingXL = 40.0;
  static const double spacingXXL = 64.0;
  
  // Border Radius
  static const double borderRadiusS = 8.0;
  static const double borderRadiusM = 12.0;
  static const double borderRadiusL = 16.0;
  static const double borderRadiusXL = 32.0;
  static const double borderRadiusFull = 999.0;
  
  // Dimensions
  static const double progressBarHeight = 4.0;
  static const double progressBarWidth = 136.0;
  static const double buttonHeight = 64.0;
  static const double radioButtonSize = 16.0;
  static const double radioButtonInnerSize = 8.0;
}

