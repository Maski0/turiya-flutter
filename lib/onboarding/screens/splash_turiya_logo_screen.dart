import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import '../theme/onboarding_theme.dart';
import '../widgets/onboarding_scaffold.dart';

/// Screen 3 & 4: Turiya logo reveal with animated "Chat with Krishna" and Enter button
class SplashTuriyaLogoScreen extends StatefulWidget {
  const SplashTuriyaLogoScreen({super.key});
  
  @override
  State<SplashTuriyaLogoScreen> createState() => _SplashTuriyaLogoScreenState();
}

class _SplashTuriyaLogoScreenState extends State<SplashTuriyaLogoScreen>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _chatOpacity;
  late Animation<double> _enterOpacity;
  
  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(milliseconds: 2000),
      vsync: this,
    );
    
    // Chat text fades in from 500ms to 1000ms
    _chatOpacity = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _controller,
        curve: const Interval(0.25, 0.5, curve: Curves.easeInOut),
      ),
    );
    
    // Enter button fades in from 1000ms to 1500ms
    _enterOpacity = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _controller,
        curve: const Interval(0.5, 0.75, curve: Curves.easeInOut),
      ),
    );
    
    _controller.forward();
  }
  
  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }
  
  @override
  Widget build(BuildContext context) {
    return OnboardingScaffold(
      child: SizedBox.expand(
        child: Stack(
          children: [
            // Cloud decoration - top (with blur)
            Positioned(
              left: -49,
              top: 32,
              width: 343,
              height: 207,
              child: Opacity(
                opacity: 0.3,
                child: SvgPicture.asset(
                  'assets/images/onboarding/cloud_top.svg',
                  fit: BoxFit.contain,
                ),
              ),
            ),
            // Cloud decoration - bottom (with blur)
            Positioned(
              left: 99,
              bottom: 93,
              width: 343,
              height: 207,
              child: Opacity(
                opacity: 0.3,
                child: SvgPicture.asset(
                  'assets/images/onboarding/cloud_bottom.svg',
                  fit: BoxFit.contain,
                ),
              ),
            ),
            // Content
            Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                mainAxisSize: MainAxisSize.min,
                children: [
                  // TURIYA text logo (always visible)
                  SizedBox(
                    width: 294,
                    height: 142,
                    child: SvgPicture.asset(
                      'assets/images/onboarding/turiya_text_logo.svg',
                      fit: BoxFit.contain,
                    ),
                  ),
                  const SizedBox(height: 40),
                  // "Chat with Krśna" text (fades in)
                  FadeTransition(
                    opacity: _chatOpacity,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                      decoration: BoxDecoration(
                        border: Border.all(
                          color: OnboardingTheme.textPrimary.withOpacity(0.2),
                          width: 1,
                        ),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Text(
                        'Chat with Krśna',
                        style: OnboardingTheme.bodyLarge.copyWith(fontSize: 16),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            // "Enter" prompt at bottom (fades in last)
            Positioned(
              bottom: 100,
              left: 0,
              right: 0,
              child: FadeTransition(
                opacity: _enterOpacity,
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      'Enter',
                      style: OnboardingTheme.bodyLarge.copyWith(
                        fontSize: 20,
                        color: OnboardingTheme.textPrimary.withOpacity(0.6),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Icon(
                      Icons.arrow_forward,
                      color: OnboardingTheme.textPrimary.withOpacity(0.6),
                      size: 16,
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

