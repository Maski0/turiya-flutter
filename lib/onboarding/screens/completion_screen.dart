import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';
import '../theme/onboarding_theme.dart';
import '../widgets/onboarding_button.dart';
import '../models/onboarding_data.dart';
import '../../services/backend_api_service.dart';

/// Screen 22-24: Completion and plan ready
class CompletionScreen extends StatefulWidget {
  final VoidCallback onComplete;
  final OnboardingData? data;

  const CompletionScreen({
    super.key,
    required this.onComplete,
    this.data,
  });

  @override
  State<CompletionScreen> createState() => _CompletionScreenState();
}

class _CompletionScreenState extends State<CompletionScreen>
    with TickerProviderStateMixin {
  bool isLoading = true;
  bool _isExiting = false;
  late AnimationController _progressController;
  late Animation<double> _progressAnimation;
  late AnimationController _fadeController;
  late Animation<double> _fadeAnimation;

  // Plan data from API (array of cards)
  List<dynamic>? _planData;
  final BackendApiService _apiService = BackendApiService();

  @override
  void initState() {
    super.initState();

    // Deterministic progress animation (0% to 100% over 3 seconds)
    _progressController = AnimationController(
      duration: const Duration(seconds: 3),
      vsync: this,
    );

    _progressAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _progressController, curve: Curves.easeInOut),
    );

    // Fade out animation for exit
    _fadeController = AnimationController(
      duration: const Duration(milliseconds: 350),
      vsync: this,
    );

    _fadeAnimation = Tween<double>(begin: 1.0, end: 0.0).animate(
      CurvedAnimation(parent: _fadeController, curve: Curves.easeInOut),
    );

    // Start animation and save onboarding data
    _progressController.forward();
    _saveOnboardingData();
  }

  Future<void> _handleComplete() async {
    if (_isExiting) return;

    setState(() {
      _isExiting = true;
    });

    // Fade out
    await _fadeController.forward();

    // Then complete
    widget.onComplete();
  }

  Future<void> _saveOnboardingData() async {
    if (widget.data == null) {
      await Future.delayed(const Duration(seconds: 3));
      await _transitionToPlanReady();
      return;
    }

    try {
      // Prepare onboarding data
      final onboardingData = {
        'user_name': widget.data!.userName,
        'motivations': widget.data!.motivations,
        'vedanta_familiarity': widget.data!.vedantaFamiliarity,
        'struggles': widget.data!.struggles,
        'custom_struggle': widget.data!.customStruggle,
        'wants_daily_blessings': widget.data!.wantsDailyBlessings,
        'daily_practices': widget.data!.dailyPractices,
      };

      // Save to local storage (for later sync after login)
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('onboarding_data', jsonEncode(onboardingData));
      print('✅ Onboarding data saved to local storage');

      // Get custom plan from API (no auth required)
      try {
        final plan = await _apiService.getOnboardingPlan(
          onboardingData: onboardingData,
        );
        if (plan != null && mounted) {
          setState(() {
            _planData = plan;
          });
        }
        print('✅ Custom plan received from API');
      } catch (e) {
        print('⚠️ Plan API call failed: $e');
      }

      // Wait for progress animation to complete
      await Future.delayed(const Duration(seconds: 3));

      // Transition to plan ready with fade
      await _transitionToPlanReady();
    } catch (e) {
      print('❌ Error during onboarding completion: $e');
      await Future.delayed(const Duration(seconds: 3));
      await _transitionToPlanReady();
    }
  }

  Future<void> _transitionToPlanReady() async {
    if (!mounted) return;

    // Fade out loading screen
    await _fadeController.forward();
    if (!mounted) return;

    // Switch to plan ready state
    setState(() {
      isLoading = false;
    });

    // Fade in plan ready screen
    await _fadeController.reverse();
  }

  @override
  void dispose() {
    _progressController.dispose();
    _fadeController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // Return content only - wrapper handles scaffold
    if (isLoading) {
      // Loading state
      return FadeTransition(
        opacity: _fadeAnimation,
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // Logo
            SizedBox(
              width: 123,
              height: 156.3,
              child: SvgPicture.asset(
                'assets/images/onboarding/logo.svg',
                fit: BoxFit.contain,
              ),
            ),
            const SizedBox(height: 40),
            // Loading text
            Text(
              'Shaping a path just for you',
              style: OnboardingTheme.headingMedium,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 12),
            Text(
              'Preparing your practice flow…',
              style: OnboardingTheme.bodyMedium.copyWith(
                color: OnboardingTheme.textPrimary.withOpacity(0.7),
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 40),
            // Deterministic loading bar
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 40),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(2),
                child: AnimatedBuilder(
                  animation: _progressAnimation,
                  builder: (context, child) {
                    return LinearProgressIndicator(
                      value: _progressAnimation.value,
                      backgroundColor: OnboardingTheme.progressBar,
                      valueColor: const AlwaysStoppedAnimation<Color>(
                        OnboardingTheme.progressBarFill,
                      ),
                    );
                  },
                ),
              ),
            ),
          ],
        ),
      );
    }

    // Plan ready state
    const double buttonHeightWithPadding = 80; // 64 + 8 + 8

    return FadeTransition(
      opacity: _fadeAnimation,
      child: Stack(
        children: [
          // Scrollable content with bottom padding
          SingleChildScrollView(
            padding: EdgeInsets.only(
              left: 16,
              right: 16,
              top: 24,
              bottom:
                  buttonHeightWithPadding + 16, // Extra space for visibility
            ),
            child: Column(
              children: [
                // Logo
                SizedBox(
                  width: 123,
                  height: 156.3,
                  child: SvgPicture.asset(
                    'assets/images/onboarding/logo.svg',
                    fit: BoxFit.contain,
                  ),
                ),
                const SizedBox(height: 24),
                // Header text
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: Column(
                    children: [
                      Text(
                        'Your custom plan is ready',
                        style: OnboardingTheme.headingMedium,
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 12),
                      Text(
                        'A sacred rhythm designed to bring peace to your mind and stillness to your heart.',
                        style: OnboardingTheme.bodyMedium.copyWith(
                          color: OnboardingTheme.textPrimary.withOpacity(0.75),
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 32),
                // Plan cards from API or default
                ..._buildPlanCards(),
              ],
            ),
          ),

          // Fixed button at bottom
          Positioned(
            bottom: 0,
            left: 0,
            right: 0,
            child: OnboardingButton(
              text: 'Talk to Krishna',
              onPressed: _handleComplete,
            ),
          ),
        ],
      ),
    );
  }

  /// Build plan cards from API data
  List<Widget> _buildPlanCards() {
    if (_planData == null || _planData!.isEmpty) {
      return [];
    }

    final widgets = <Widget>[];
    for (var i = 0; i < _planData!.length; i++) {
      final card = _planData![i] as Map<String, dynamic>;
      widgets.add(_buildPlanCard(card));
      if (i < _planData!.length - 1) {
        widgets.add(const SizedBox(height: 16));
      }
    }
    return widgets;
  }

  /// Build a single plan card
  Widget _buildPlanCard(Map<String, dynamic> card) {
    final items = card['items'] as List<dynamic>? ?? [];

    return Container(
      padding: const EdgeInsets.only(left: 16, right: 16, top: 24, bottom: 16),
      decoration: BoxDecoration(
        color: const Color(0x40000000), // 25% black to match Figma
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: const Color(0x14111111), // rgba(17,17,17,0.08)
            offset: const Offset(0, 4),
            blurRadius: 16,
            spreadRadius: 0,
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
          Row(
            children: [
              SvgPicture.asset(
                'assets/icons/sun.svg',
                width: 24,
                height: 24,
                colorFilter: const ColorFilter.mode(
                  OnboardingTheme.textPrimary,
                  BlendMode.srcIn,
                ),
              ),
              const SizedBox(width: 12),
              Text(
                card['title'] as String? ?? 'Daily ritual',
                style: OnboardingTheme.bodyLarge.copyWith(
                  fontWeight: FontWeight.w500,
                ),
              ),
              const Spacer(),
              Text(
                card['subtitle'] as String? ?? '',
                style: OnboardingTheme.bodyMedium.copyWith(
                  color: OnboardingTheme.textPrimary.withOpacity(0.6),
                ),
              ),
            ],
          ),
          const SizedBox(height: 24),
          // Practice items
          ..._buildPracticeItems(items),
        ],
      ),
    );
  }

  /// Build practice items for a card
  List<Widget> _buildPracticeItems(List<dynamic> items) {
    final widgets = <Widget>[];
    for (var i = 0; i < items.length; i++) {
      final item = items[i] as Map<String, dynamic>;
      widgets.add(_buildPracticeItem(
        iconName: item['icon'] as String? ?? 'convo',
        title: item['title'] as String? ?? '',
        duration: item['duration'] as String? ?? '',
      ));
      if (i < items.length - 1) {
        widgets.add(const SizedBox(height: 16));
      }
    }
    return widgets;
  }

  Widget _buildPracticeItem({
    required String iconName,
    required String title,
    required String duration,
  }) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0x40000000), // 25% Black (rgba(0,0,0,0.25))
        border: Border.all(
          color: OnboardingTheme.textPrimary.withOpacity(0.15),
          width: 1,
        ),
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: const Color(0x14111111), // rgba(17,17,17,0.08)
            offset: const Offset(0, 4),
            blurRadius: 16,
            spreadRadius: 0,
          ),
        ],
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          // SVG Icon
          SvgPicture.asset(
            'assets/icons/$iconName.svg',
            width: 28,
            height: 28,
            colorFilter: const ColorFilter.mode(
              OnboardingTheme.textPrimary,
              BlendMode.srcIn,
            ),
          ),
          const SizedBox(width: 16),
          // Text
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: OnboardingTheme.bodyMedium.copyWith(
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  duration,
                  style: OnboardingTheme.bodyMedium.copyWith(
                    color: OnboardingTheme.textPrimary.withOpacity(0.65),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
