import 'package:flutter/material.dart';

/// Centralized app theme configuration
/// Provides consistent typography, colors, and styling across the app
class AppTheme {
  // Private constructor to prevent instantiation
  AppTheme._();

  /// Base font family
  static const String fontFamily = 'Alegreya';

  /// Color palette
  static const Color primaryWhite = Colors.white;
  static Color secondaryWhite = Colors.white.withOpacity(0.78);
  static Color tertiaryWhite = Colors.white.withOpacity(0.6);
  static Color subtleWhite = Colors.white.withOpacity(0.4);

  /// Text Theme - Responsive typography
  /// Uses Flutter's standard text theme tokens
  static const TextTheme textTheme = TextTheme(
    // Display styles - Largest text (page titles, hero text)
    displayLarge: TextStyle(
      fontSize: 32,
      fontWeight: FontWeight.w700,
      letterSpacing: 0.5,
      color: primaryWhite,
    ),
    displayMedium: TextStyle(
      fontSize: 28,
      fontWeight: FontWeight.w700,
      letterSpacing: 0.4,
      color: primaryWhite,
    ),
    displaySmall: TextStyle(
      fontSize: 24,
      fontWeight: FontWeight.w700,
      letterSpacing: 0.3,
      color: primaryWhite,
    ),

    // Headline styles - Section headers
    headlineLarge: TextStyle(
      fontSize: 24,
      fontWeight: FontWeight.w700,
      letterSpacing: 0.3,
      color: primaryWhite,
    ),
    headlineMedium: TextStyle(
      fontSize: 22,
      fontWeight: FontWeight.w700,
      letterSpacing: 0.3,
      color: primaryWhite,
    ),
    headlineSmall: TextStyle(
      fontSize: 20,
      fontWeight: FontWeight.w600,
      letterSpacing: 0.2,
      color: primaryWhite,
    ),

    // Title styles - Card titles, dialog titles
    titleLarge: TextStyle(
      fontSize: 18,
      fontWeight: FontWeight.w600,
      letterSpacing: 0.2,
      color: primaryWhite,
    ),
    titleMedium: TextStyle(
      fontSize: 16,
      fontWeight: FontWeight.w600,
      letterSpacing: 0.15,
      color: primaryWhite,
    ),
    titleSmall: TextStyle(
      fontSize: 14,
      fontWeight: FontWeight.w600,
      letterSpacing: 0.1,
      color: primaryWhite,
    ),

    // Body styles - Main content text
    bodyLarge: TextStyle(
      fontSize: 16,
      fontWeight: FontWeight.w400,
      letterSpacing: 0.2,
      height: 1.5,
      color: primaryWhite,
    ),
    bodyMedium: TextStyle(
      fontSize: 14,
      fontWeight: FontWeight.w400,
      letterSpacing: 0.15,
      height: 1.5,
      color: primaryWhite,
    ),
    bodySmall: TextStyle(
      fontSize: 13,
      fontWeight: FontWeight.w400,
      letterSpacing: 0.1,
      height: 1.4,
      color: primaryWhite,
    ),

    // Label styles - Buttons, small UI elements
    labelLarge: TextStyle(
      fontSize: 14,
      fontWeight: FontWeight.w600,
      letterSpacing: 0.2,
      color: primaryWhite,
    ),
    labelMedium: TextStyle(
      fontSize: 12,
      fontWeight: FontWeight.w500,
      letterSpacing: 0.15,
      color: primaryWhite,
    ),
    labelSmall: TextStyle(
      fontSize: 11,
      fontWeight: FontWeight.w500,
      letterSpacing: 0.1,
      color: primaryWhite,
    ),
  );

  /// Main app theme
  static ThemeData get darkTheme {
    return ThemeData(
      fontFamily: fontFamily,
      brightness: Brightness.dark,
      textTheme: textTheme,

      // Default text color
      primaryColor: primaryWhite,

      // Scaffold background (if needed)
      scaffoldBackgroundColor: Colors.black,

      // App bar theme
      appBarTheme: const AppBarTheme(
        backgroundColor: Colors.transparent,
        elevation: 0,
        centerTitle: true,
        titleTextStyle: TextStyle(
          fontSize: 18,
          fontWeight: FontWeight.w600,
          letterSpacing: 0.2,
          color: primaryWhite,
        ),
      ),

      // Icon theme
      iconTheme: const IconThemeData(
        color: primaryWhite,
        size: 24,
      ),

      // Divider theme
      dividerTheme: DividerThemeData(
        color: primaryWhite.withOpacity(0.1),
        thickness: 1,
      ),
    );
  }

  /// Helper methods for common text styles with color overrides

  static TextStyle headline(BuildContext context, {Color? color}) {
    return Theme.of(context).textTheme.headlineMedium!.copyWith(
          color: color ?? primaryWhite,
        );
  }

  static TextStyle title(BuildContext context, {Color? color}) {
    return Theme.of(context).textTheme.titleMedium!.copyWith(
          color: color ?? primaryWhite,
        );
  }

  static TextStyle body(BuildContext context, {Color? color, double? height}) {
    return Theme.of(context).textTheme.bodyLarge!.copyWith(
          color: color ?? primaryWhite,
          height: height,
        );
  }

  static TextStyle bodySecondary(BuildContext context, {double? height}) {
    return Theme.of(context).textTheme.bodyLarge!.copyWith(
          color: secondaryWhite,
          height: height,
        );
  }

  static TextStyle label(BuildContext context, {Color? color}) {
    return Theme.of(context).textTheme.labelLarge!.copyWith(
          color: color ?? primaryWhite,
        );
  }

  static TextStyle caption(BuildContext context) {
    return Theme.of(context).textTheme.labelMedium!.copyWith(
          color: tertiaryWhite,
        );
  }
}
