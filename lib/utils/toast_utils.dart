import 'dart:async';
import 'package:flutter/material.dart';

/// Toast utility with fade in/out animations
class ToastUtils {
  static OverlayEntry? _currentToast;
  static Timer? _dismissTimer;

  /// Show a success toast message
  static void showSuccess(BuildContext context, String message) {
    _showToast(
      context: context,
      message: message,
      iconColor: Colors.green,
      icon: Icons.check_circle_outline,
    );
  }

  /// Show an error toast message
  static void showError(BuildContext context, String message) {
    _showToast(
      context: context,
      message: message,
      iconColor: Colors.red,
      icon: Icons.error_outline,
    );
  }

  /// Show a warning toast message
  static void showWarning(BuildContext context, String message) {
    _showToast(
      context: context,
      message: message,
      iconColor: Colors.orange,
      icon: Icons.warning_amber_outlined,
    );
  }

  /// Show an info toast message
  static void showInfo(BuildContext context, String message) {
    _showToast(
      context: context,
      message: message,
      iconColor: Colors.blue,
      icon: Icons.info_outline,
    );
  }

  static void _showToast({
    required BuildContext context,
    required String message,
    required Color iconColor,
    required IconData icon,
  }) {
    // Dismiss any existing toast
    _dismissCurrentToast();

    final overlay = Overlay.of(context);
    final animationController = AnimationController(
      vsync: Navigator.of(context),
      duration: const Duration(milliseconds: 300),
    );

    final fadeAnimation = CurvedAnimation(
      parent: animationController,
      curve: Curves.easeOut,
      reverseCurve: Curves.easeIn,
    );

    late OverlayEntry overlayEntry;
    overlayEntry = OverlayEntry(
      builder: (context) => _ToastWidget(
        message: message,
        icon: icon,
        iconColor: iconColor,
        animation: fadeAnimation,
      ),
    );

    _currentToast = overlayEntry;
    overlay.insert(overlayEntry);

    // Fade in
    animationController.forward();

    // Auto dismiss after 3 seconds
    _dismissTimer = Timer(const Duration(seconds: 3), () {
      // Fade out
      animationController.reverse().then((_) {
        if (_currentToast == overlayEntry) {
          overlayEntry.remove();
          animationController.dispose();
          _currentToast = null;
        }
      });
    });
  }

  static void _dismissCurrentToast() {
    _dismissTimer?.cancel();
    _currentToast?.remove();
    _currentToast = null;
  }
}

class _ToastWidget extends StatelessWidget {
  final String message;
  final IconData icon;
  final Color iconColor;
  final Animation<double> animation;

  const _ToastWidget({
    required this.message,
    required this.icon,
    required this.iconColor,
    required this.animation,
  });

  @override
  Widget build(BuildContext context) {
    final topPadding = MediaQuery.of(context).padding.top;

    return Positioned(
      top: topPadding + 12,
      left: 20,
      right: 20,
      child: FadeTransition(
        opacity: animation,
        child: Material(
          color: Colors.transparent,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.12),
                  offset: const Offset(0, 4),
                  blurRadius: 16,
                  spreadRadius: 0,
                ),
              ],
            ),
            child: Row(
              children: [
                Icon(
                  icon,
                  color: iconColor,
                  size: 24,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    message,
                    style: const TextStyle(
                      color: Colors.black87,
                      fontSize: 15,
                      fontWeight: FontWeight.w500,
                      height: 1.3,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
