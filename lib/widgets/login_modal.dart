import 'dart:ui';
import 'package:flutter/material.dart';

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
      child: Stack(
        children: [
          // Blurred background overlay - Web: bg-[rgba(255,255,255,0.01)] backdrop-blur-[18px]
          Positioned.fill(
            child: BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 18, sigmaY: 18),
              child: Container(
                // Web: rgba(255, 255, 255, 0.01) - very subtle white, NOT black
                color: const Color(0x03FFFFFF),
              ),
            ),
          ),
          Center(
            child: GestureDetector(
              onTap: () {}, // Prevent closing when tapping modal content
              child: ClipRRect(
                borderRadius: BorderRadius.circular(16),
                child: BackdropFilter(
                  filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
                  child: Container(
                    // Web: w-[calc(100%-32px)] max-w-lg (355px max)
                    constraints: const BoxConstraints(maxWidth: 355),
                    margin: const EdgeInsets.symmetric(horizontal: 16),
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: const Color(0x14FFFFFF),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(
                        color: const Color(0x14FFFFFF),
                        width: 1,
                      ),
                      boxShadow: const [
                        BoxShadow(
                          color: Color(0x14111111),
                          blurRadius: 16,
                          offset: Offset(0, 4),
                        ),
                      ],
                    ),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        // Logo - Web: w-32 (reduced to 100px to be smaller)
                        SizedBox(
                          width: 100,
                          child: Image.asset(
                            'assets/images/logo.png',
                            fit: BoxFit.contain,
                            errorBuilder: (context, error, stackTrace) {
                              return const Text(
                                'Turiya',
                                style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 36,
                                  fontWeight: FontWeight.w400,
                                  fontStyle: FontStyle.italic,
                                  fontFamily: 'Alegreya',
                                ),
                                textAlign: TextAlign.center,
                              );
                            },
                          ),
                        ),
                        const SizedBox(height: 16),
                        // Subtitle - Web: text-2xl font-medium font-alegreya
                        // Use theme: displaySmall (24px)
                        Text(
                          'Please login to continue',
                          style: Theme.of(context)
                              .textTheme
                              .displaySmall!
                              .copyWith(
                                color: Colors.white,
                                fontWeight: FontWeight.w500,
                                height: 1.0,
                              ),
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(height: 16),
                        // Button container with glass effect
                        Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            // Web: background: rgba(255, 255, 255, 0.05)
                            color: const Color(0x0DFFFFFF),
                            borderRadius: BorderRadius.circular(16),
                            // Web: border: 1px solid rgba(255, 255, 255, 0.08)
                            border: Border.all(
                              color: const Color(0x14FFFFFF),
                              width: 1,
                            ),
                            // Web: boxShadow: 0 4px 30px rgba(17, 17, 17, 0.08)
                            boxShadow: const [
                              BoxShadow(
                                color: Color(0x14111111),
                                blurRadius: 30,
                                offset: Offset(0, 4),
                              ),
                            ],
                          ),
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(12),
                            child: BackdropFilter(
                              // Web: backdropFilter: blur(16px)
                              filter: ImageFilter.blur(sigmaX: 16, sigmaY: 16),
                              child: Material(
                                color: Colors.transparent,
                                child: InkWell(
                                  onTap: isSigningIn ? null : onGoogleSignIn,
                                  borderRadius: BorderRadius.circular(12),
                                  child: Container(
                                    // Web: rounded-xl px-6 py-3
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 24,
                                      vertical: 12,
                                    ),
                                    decoration: BoxDecoration(
                                      // Web: bg-white
                                      color: isSigningIn
                                          ? Colors.white.withOpacity(0.7)
                                          : Colors.white,
                                      borderRadius: BorderRadius.circular(12),
                                      border: Border.all(
                                        color: const Color(0x33CCCCCC),
                                        width: 1,
                                      ),
                                    ),
                                    child: Row(
                                      mainAxisAlignment:
                                          MainAxisAlignment.center,
                                      children: [
                                        if (isSigningIn)
                                          // Web: w-5 h-5 spinner
                                          SizedBox(
                                            width: 20,
                                            height: 20,
                                            child: CircularProgressIndicator(
                                              strokeWidth: 2,
                                              valueColor:
                                                  AlwaysStoppedAnimation<Color>(
                                                Colors.grey.shade600,
                                              ),
                                            ),
                                          )
                                        else
                                          // Google Icon - Web: w-5 h-5
                                          SizedBox(
                                            width: 20,
                                            height: 20,
                                            child: Image.network(
                                              'https://www.google.com/favicon.ico',
                                              errorBuilder:
                                                  (context, error, stackTrace) {
                                                return Container(
                                                  decoration:
                                                      const BoxDecoration(
                                                    color: Colors.blue,
                                                    shape: BoxShape.circle,
                                                  ),
                                                  child: const Center(
                                                    child: Text(
                                                      'G',
                                                      style: TextStyle(
                                                        color: Colors.white,
                                                        fontSize: 12,
                                                        fontWeight:
                                                            FontWeight.bold,
                                                      ),
                                                    ),
                                                  ),
                                                );
                                              },
                                            ),
                                          ),
                                        const SizedBox(width: 12),
                                        // Web: text-black font-alegreya font-medium leading-7 text-lg
                                        // Use theme: titleLarge (18px)
                                        Text(
                                          isSigningIn
                                              ? 'Signing in...'
                                              : 'Sign in with Google',
                                          style: Theme.of(context)
                                              .textTheme
                                              .titleLarge!
                                              .copyWith(
                                                color: Colors.black,
                                                fontWeight: FontWeight.w500,
                                                height: 1.75,
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
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
