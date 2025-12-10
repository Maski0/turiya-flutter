import 'dart:ui';
import 'package:flutter/material.dart';
import 'animated_dots.dart';
import 'package:liquid_glass_renderer/liquid_glass_renderer.dart';

class LoginModal extends StatelessWidget {
  final VoidCallback onClose;
  final Future<void> Function() onGoogleSignIn;
  final bool isSigningIn;

  const LoginModal({
    super.key,
    required this.onClose,
    required this.onGoogleSignIn,
    required this.isSigningIn,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onClose,
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
        child: Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [
                Colors.black.withOpacity(0.12),
                Colors.black.withOpacity(0.18),
              ],
            ),
          ),
          child: Center(
            child: GestureDetector(
              onTap: () {}, // Prevent closing when tapping the modal content
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 28),
                child: Container(
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(28),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.15),
                        blurRadius: 40,
                        spreadRadius: 0,
                        offset: const Offset(0, 20),
                      ),
                      BoxShadow(
                        color: Colors.black.withOpacity(0.1),
                        blurRadius: 20,
                        spreadRadius: 0,
                        offset: const Offset(0, 10),
                      ),
                    ],
                  ),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(28),
                    child: BackdropFilter(
                      filter: ImageFilter.blur(sigmaX: 28, sigmaY: 28),
                      child: Container(
                        padding: const EdgeInsets.fromLTRB(30, 40, 30, 34),
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.11),
                          borderRadius: BorderRadius.circular(28),
                          border: Border.all(
                            color: Colors.white.withOpacity(0.20),
                            width: 0.6,
                          ),
                          gradient: LinearGradient(
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                            colors: [
                              Colors.white.withOpacity(0.15),
                              Colors.white.withOpacity(0.08),
                            ],
                          ),
                        ),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            // Turiya Logo
                            Image.asset(
                              'assets/images/logo.png',
                              height: 40,
                              fit: BoxFit.contain,
                              errorBuilder: (context, error, stackTrace) {
                                // Fallback to text if logo not found
                                return const Text(
                                  'Turiya',
                                  style: TextStyle(
                                    color: Colors.white,
                                    fontSize: 48,
                                    fontWeight: FontWeight.w400,
                                    fontStyle: FontStyle.italic,
                                  ),
                                );
                              },
                            ),
                            const SizedBox(height: 20),
                            // Subtitle
                            Text(
                              'Please login to continue.',
                              style: TextStyle(
                                color: Colors.white.withOpacity(0.92),
                                fontSize: 16,
                                fontWeight: FontWeight.w400,
                                letterSpacing: 0.3,
                                height: 1.4,
                              ),
                            ),
                            const SizedBox(height: 30),
                            // Google Sign In Button
                            GestureDetector(
                              onTap: isSigningIn ? null : onGoogleSignIn,
                              child: Container(
                                width: double.infinity,
                                padding: const EdgeInsets.symmetric(
                                    vertical: 16, horizontal: 22),
                                decoration: BoxDecoration(
                                  color: isSigningIn
                                      ? Colors.white.withOpacity(0.75)
                                      : Colors.white,
                                  borderRadius: BorderRadius.circular(16),
                                  boxShadow: [
                                    BoxShadow(
                                      color: Colors.black.withOpacity(0.08),
                                      blurRadius: 20,
                                      spreadRadius: 0,
                                      offset: const Offset(0, 6),
                                    ),
                                    BoxShadow(
                                      color: Colors.black.withOpacity(0.04),
                                      blurRadius: 8,
                                      spreadRadius: 0,
                                      offset: const Offset(0, 2),
                                    ),
                                  ],
                                ),
                                child: Row(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    if (isSigningIn)
                                      const AnimatedDots(
                                        size: 5.0,
                                      )
                                    else
                                      // Google Icon (using a colored container as placeholder)
                                      Container(
                                        width: 24,
                                        height: 24,
                                        decoration: const BoxDecoration(
                                          shape: BoxShape.circle,
                                        ),
                                        child: Image.network(
                                          'https://www.google.com/favicon.ico',
                                          errorBuilder:
                                              (context, error, stackTrace) {
                                            return Container(
                                              decoration: BoxDecoration(
                                                color: Colors.blue,
                                                shape: BoxShape.circle,
                                              ),
                                              child: const Center(
                                                child: Text(
                                                  'G',
                                                  style: TextStyle(
                                                    color: Colors.white,
                                                    fontWeight: FontWeight.bold,
                                                    fontSize: 14,
                                                  ),
                                                ),
                                              ),
                                            );
                                          },
                                        ),
                                      ),
                                    const SizedBox(width: 14),
                                    Text(
                                      isSigningIn
                                          ? 'Signing in...'
                                          : 'Sign in with Google',
                                      style: const TextStyle(
                                        color: Colors.black87,
                                        fontSize: 16,
                                        fontWeight: FontWeight.w600,
                                        letterSpacing: 0.2,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
