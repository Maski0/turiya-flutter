import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:another_flushbar/flushbar.dart';

/// Toast utility for showing beautiful blur-based notifications
class ToastUtils {
  /// Show a success toast message
  static void showSuccess(BuildContext context, String message) {
    _showToast(
      context: context,
      message: message,
      backgroundColor: Colors.green.withOpacity(0.15),
      iconColor: Colors.green,
      icon: Icons.check_circle_outline,
    );
  }

  /// Show an error toast message
  static void showError(BuildContext context, String message) {
    _showToast(
      context: context,
      message: message,
      backgroundColor: Colors.red.withOpacity(0.15),
      iconColor: Colors.red,
      icon: Icons.error_outline,
    );
  }

  /// Show a warning toast message
  static void showWarning(BuildContext context, String message) {
    _showToast(
      context: context,
      message: message,
      backgroundColor: Colors.orange.withOpacity(0.15),
      iconColor: Colors.orange,
      icon: Icons.warning_amber_outlined,
    );
  }

  /// Show an info toast message
  static void showInfo(BuildContext context, String message) {
    _showToast(
      context: context,
      message: message,
      backgroundColor: Colors.blue.withOpacity(0.15),
      iconColor: Colors.blue,
      icon: Icons.info_outline,
    );
  }

  /// Internal method to show toast with blur effect
  static void _showToast({
    required BuildContext context,
    required String message,
    required Color backgroundColor,
    required Color iconColor,
    required IconData icon,
  }) {
    Flushbar(
      message: message,
      icon: Icon(
        icon,
        color: iconColor,
        size: 24,
      ),
      duration: const Duration(seconds: 5), // Stay longer
      margin: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
      borderRadius: BorderRadius.circular(16),
      borderColor: Colors.white.withOpacity(0.15), // Subtle white border
      borderWidth: 0.5,
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
      flushbarPosition: FlushbarPosition.TOP,
      animationDuration: const Duration(milliseconds: 600), // Slower animation
      forwardAnimationCurve: Curves.easeInOut, // Ease in out
      reverseAnimationCurve: Curves.easeInOut, // Ease in out
      backgroundColor: Colors.transparent,
      messageText: Text(
        message,
        style: const TextStyle(
          color: Colors.white,
          fontSize: 15,
          fontWeight: FontWeight.w500,
          height: 1.3,
        ),
      ),
      // Custom blur background
      backgroundGradient: null,
      boxShadows: [
        BoxShadow(
          color: Colors.black.withOpacity(0.2),
          offset: const Offset(0, 4),
          blurRadius: 12,
          spreadRadius: 0,
        ),
      ],
      // Use BackdropFilter for blur effect
      barBlur: 10,
    ).show(context);
  }
}

