import 'package:flutter/material.dart';

/// Centralized app theme configuration matching Figma design system
/// Type Scale: Display, Heading, Body, Caption with Regular and Emphasised variants
class AppTheme {
  AppTheme._();

  static const String fontFamily = 'Alegreya';

  /// Color palette
  static const Color primaryWhite = Colors.white;
  static Color secondaryWhite = Colors.white.withOpacity(0.78);
  static Color tertiaryWhite = Colors.white.withOpacity(0.6);
  static Color subtleWhite = Colors.white.withOpacity(0.4);

  /// Figma Design System - Type Scale
  /// Maps Flutter's TextTheme to Figma's naming convention:
  /// - displayLarge = Display/XL (40px, w400, h1.2, ls-1)
  /// - displayMedium = Display/L (32px, w400, h1.2, ls-1)
  /// - displaySmall = DisplayE/L (32px, w500, h1.2, ls-1)
  /// - headlineLarge = Heading/L (24px, w400, h1.25)
  /// - headlineMedium = Heading/M (20px, w400, h1.25)
  /// - headlineSmall = Heading/S (18px, w400, h1.25)
  /// - titleLarge = HeadingE/M (20px, w500, h1.25)
  /// - titleMedium = BodyE/L (18px, w500, h1.4)
  /// - titleSmall = BodyE/M (16px, w500, h1.4)
  /// - bodyLarge = Body/L (18px, w400, h1.4)
  /// - bodyMedium = Body/M (16px, w400, h1.4)
  /// - bodySmall = Body/S (14px, w400, h1.4)
  /// - labelLarge = Caption/S (12px, w400, h1.25)
  static const TextTheme textTheme = TextTheme(
    // Display styles
    displayLarge: TextStyle(
      fontFamily: fontFamily,
      fontSize: 40,
      fontWeight: FontWeight.w400,
      height: 1.2,
      letterSpacing: -1,
      color: primaryWhite,
    ),
    displayMedium: TextStyle(
      fontFamily: fontFamily,
      fontSize: 32,
      fontWeight: FontWeight.w400,
      height: 1.2,
      letterSpacing: -1,
      color: primaryWhite,
    ),
    displaySmall: TextStyle(
      fontFamily: fontFamily,
      fontSize: 32,
      fontWeight: FontWeight.w500,
      height: 1.2,
      letterSpacing: -0.32,
      color: primaryWhite,
    ),

    // Heading styles
    headlineLarge: TextStyle(
      fontFamily: fontFamily,
      fontSize: 24,
      fontWeight: FontWeight.w400,
      height: 1.25,
      color: primaryWhite,
    ),
    headlineMedium: TextStyle(
      fontFamily: fontFamily,
      fontSize: 20,
      fontWeight: FontWeight.w400,
      height: 1.25,
      color: primaryWhite,
    ),
    headlineSmall: TextStyle(
      fontFamily: fontFamily,
      fontSize: 18,
      fontWeight: FontWeight.w400,
      height: 1.25,
      color: primaryWhite,
    ),

    // Title styles (Emphasised variants)
    titleLarge: TextStyle(
      fontFamily: fontFamily,
      fontSize: 20,
      fontWeight: FontWeight.w500,
      height: 1.25,
      color: primaryWhite,
    ),
    titleMedium: TextStyle(
      fontFamily: fontFamily,
      fontSize: 18,
      fontWeight: FontWeight.w500,
      height: 1.4,
      color: primaryWhite,
    ),
    titleSmall: TextStyle(
      fontFamily: fontFamily,
      fontSize: 16,
      fontWeight: FontWeight.w500,
      height: 1.4,
      color: primaryWhite,
    ),

    // Body styles
    bodyLarge: TextStyle(
      fontFamily: fontFamily,
      fontSize: 18,
      fontWeight: FontWeight.w400,
      height: 1.4,
      color: primaryWhite,
    ),
    bodyMedium: TextStyle(
      fontFamily: fontFamily,
      fontSize: 16,
      fontWeight: FontWeight.w400,
      height: 1.4,
      color: primaryWhite,
    ),
    bodySmall: TextStyle(
      fontFamily: fontFamily,
      fontSize: 14,
      fontWeight: FontWeight.w400,
      height: 1.4,
      color: primaryWhite,
    ),

    // Label/Caption styles
    labelLarge: TextStyle(
      fontFamily: fontFamily,
      fontSize: 12,
      fontWeight: FontWeight.w400,
      height: 1.25,
      color: primaryWhite,
    ),
    labelMedium: TextStyle(
      fontFamily: fontFamily,
      fontSize: 12,
      fontWeight: FontWeight.w700,
      height: 1.25,
      color: primaryWhite,
    ),
    labelSmall: TextStyle(
      fontFamily: fontFamily,
      fontSize: 11,
      fontWeight: FontWeight.w500,
      height: 1.25,
      color: primaryWhite,
    ),
  );

  static ThemeData get darkTheme {
    return ThemeData(
      fontFamily: fontFamily,
      brightness: Brightness.dark,
      textTheme: textTheme,
      primaryColor: primaryWhite,
      scaffoldBackgroundColor: Colors.black,
      appBarTheme: const AppBarTheme(
        backgroundColor: Colors.transparent,
        elevation: 0,
        centerTitle: true,
        titleTextStyle: TextStyle(
          fontFamily: fontFamily,
          fontSize: 18,
          fontWeight: FontWeight.w400,
          height: 1.25,
          color: primaryWhite,
        ),
      ),
      iconTheme: const IconThemeData(
        color: primaryWhite,
        size: 24,
      ),
      dividerTheme: DividerThemeData(
        color: primaryWhite.withOpacity(0.1),
        thickness: 1,
      ),
    );
  }

  /// Convenience getters for Figma design system naming
  static TextStyle displayXL(BuildContext context) =>
      Theme.of(context).textTheme.displayLarge!;
  static TextStyle displayL(BuildContext context) =>
      Theme.of(context).textTheme.displayMedium!;
  static TextStyle displayEL(BuildContext context) =>
      Theme.of(context).textTheme.displaySmall!;
  static TextStyle headingL(BuildContext context) =>
      Theme.of(context).textTheme.headlineLarge!;
  static TextStyle headingM(BuildContext context) =>
      Theme.of(context).textTheme.headlineMedium!;
  static TextStyle headingS(BuildContext context) =>
      Theme.of(context).textTheme.headlineSmall!;
  static TextStyle headingEM(BuildContext context) =>
      Theme.of(context).textTheme.titleLarge!;
  static TextStyle bodyEL(BuildContext context) =>
      Theme.of(context).textTheme.titleMedium!;
  static TextStyle bodyEM(BuildContext context) =>
      Theme.of(context).textTheme.titleSmall!;
  static TextStyle bodyL(BuildContext context) =>
      Theme.of(context).textTheme.bodyLarge!;
  static TextStyle bodyM(BuildContext context) =>
      Theme.of(context).textTheme.bodyMedium!;
  static TextStyle bodyS(BuildContext context) =>
      Theme.of(context).textTheme.bodySmall!;
  static TextStyle captionS(BuildContext context) =>
      Theme.of(context).textTheme.labelLarge!;
  static TextStyle captionSBold(BuildContext context) =>
      Theme.of(context).textTheme.labelMedium!;
}
