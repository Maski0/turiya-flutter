import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../theme/onboarding_theme.dart';
import '../models/onboarding_data.dart';
import '../../blocs/auth/auth_bloc.dart';
import '../../blocs/auth/auth_event.dart';
import '../../blocs/auth/auth_state.dart';
import '../../utils/toast_utils.dart';

/// Screen 21: "Save your progress, make Krishna remember you"
class AuthScreen extends StatefulWidget {
  final OnboardingData data;
  final VoidCallback onNext;
  final VoidCallback onSkip;

  const AuthScreen({
    super.key,
    required this.data,
    required this.onNext,
    required this.onSkip,
  });

  @override
  State<AuthScreen> createState() => _AuthScreenState();
}

class _AuthScreenState extends State<AuthScreen> {
  bool _isSigningIn = false;

  @override
  void initState() {
    super.initState();
    // Check if already authenticated (e.g., returning from OAuth deeplink)
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _checkIfAlreadyAuthenticated();
    });
  }

  void _checkIfAlreadyAuthenticated() {
    final state = context.read<AuthBloc>().state;
    if (state is AuthAuthenticated) {
      print('✅ Already authenticated, proceeding to next screen');
      widget.data.hasCompletedAuth = true;
      widget.onNext();
    } else if (state is AuthLoading) {
      // OAuth in progress, show loading state
      setState(() {
        _isSigningIn = true;
      });
    }
  }

  void _handleGoogleSignIn() {
    if (_isSigningIn) return;

    setState(() {
      _isSigningIn = true;
    });

    // Trigger Google Sign-In via AuthBloc
    context.read<AuthBloc>().add(const AuthGoogleSignInRequested());
  }

  @override
  Widget build(BuildContext context) {
    // Return content only - wrapper handles scaffold
    return BlocListener<AuthBloc, AuthState>(
      listener: (context, state) {
        if (state is AuthLoading) {
          // Show loading state
          setState(() {
            _isSigningIn = true;
          });
        } else if (state is AuthAuthenticated) {
          // Sign-in successful
          setState(() {
            _isSigningIn = false;
          });
          widget.data.hasCompletedAuth = true;
          widget.onNext();
        } else if (state is AuthError) {
          // Sign-in failed
          setState(() {
            _isSigningIn = false;
          });

          // Show error message using app's toast utility
          ToastUtils.showError(context, state.message);
        } else if (state is AuthUnauthenticated) {
          // Reset loading state
          setState(() {
            _isSigningIn = false;
          });
        }
      },
      child: Column(
        children: [
          // Header
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
            child: Text(
              'Save your progress, make Krishna remember you',
              style: OnboardingTheme.headingMedium,
              textAlign: TextAlign.center,
            ),
          ),
          const Spacer(),
          // Logo
          SizedBox(
            width: 98.5,
            height: 156.3,
            child: SvgPicture.asset(
              'assets/images/onboarding/logo.svg',
              fit: BoxFit.contain,
            ),
          ),
          const Spacer(),
          // Sign in options
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Column(
              children: [
                // Google Sign In - White background
                GestureDetector(
                  onTap: _isSigningIn ? null : _handleGoogleSignIn,
                  child: Container(
                    height: 64,
                    decoration: BoxDecoration(
                      color: _isSigningIn
                          ? Colors.white.withOpacity(0.7)
                          : Colors.white,
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        if (_isSigningIn)
                          SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              valueColor: AlwaysStoppedAnimation<Color>(
                                Colors.grey.shade600,
                              ),
                            ),
                          )
                        else
                          // Google "G" logo
                          Container(
                            width: 18,
                            height: 18,
                            child: Image.network(
                              'https://www.google.com/favicon.ico',
                              width: 18,
                              height: 18,
                              errorBuilder: (context, error, stackTrace) {
                                return const Text('G',
                                    style: TextStyle(
                                        color: Colors.black,
                                        fontWeight: FontWeight.bold));
                              },
                            ),
                          ),
                        const SizedBox(width: 8),
                        Text(
                          _isSigningIn
                              ? 'Signing in...'
                              : 'Sign in with Google',
                          style: OnboardingTheme.buttonText.copyWith(
                            fontSize: 16,
                            color: Colors.black,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 24),
                // Skip option - Only "Skip for later" is underlined
                GestureDetector(
                  onTap: _isSigningIn ? null : widget.onSkip,
                  child: RichText(
                    textAlign: TextAlign.center,
                    text: TextSpan(
                      style: OnboardingTheme.bodyMedium.copyWith(
                        fontSize: 14,
                        color: OnboardingTheme.textPrimary
                            .withOpacity(_isSigningIn ? 0.3 : 0.6),
                      ),
                      children: const [
                        TextSpan(text: 'Don\'t want to do this now? '),
                        TextSpan(
                          text: 'Skip for later',
                          style:
                              TextStyle(decoration: TextDecoration.underline),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 40),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
