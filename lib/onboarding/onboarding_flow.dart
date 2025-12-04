import 'package:flutter/material.dart';
import 'models/onboarding_data.dart';
import 'widgets/onboarding_page_view.dart';
import 'screens/animated_splash_screen.dart';
import 'screens/name_input_screen.dart';
import 'screens/greeting_screen.dart';
import 'screens/motivation_screen.dart';
import 'screens/interlude_screen.dart';
import 'screens/vedanta_familiarity_screen.dart';
import 'screens/struggle_screen.dart';
import 'screens/stats_screen.dart';
import 'screens/daily_practice_screen.dart';
import 'screens/daily_blessings_screen.dart';
import 'screens/auth_screen.dart';
import 'screens/completion_screen.dart';

/// Main onboarding flow controller
class OnboardingFlow extends StatefulWidget {
  final VoidCallback onComplete;
  
  const OnboardingFlow({
    super.key,
    required this.onComplete,
  });
  
  @override
  State<OnboardingFlow> createState() => _OnboardingFlowState();
}

class _OnboardingFlowState extends State<OnboardingFlow> {
  int currentStep = 0;
  final OnboardingData data = OnboardingData();
  
  void _nextStep() {
    if (currentStep < 13) {
      setState(() {
        currentStep++;
      });
    }
  }
  
  void _previousStep() {
    if (currentStep > 0) {
      setState(() {
        currentStep--;
      });
    }
  }
  
  Widget _getCurrentScreen() {
    switch (currentStep) {
      case 0:
        // Unified animated splash: Headphones → Intro text → Logo → Chat with Krishna → Enter
        return AnimatedSplashScreen(
          onComplete: _nextStep,
        );
      
      case 1:
        // Name input (Screen 5)
        return NameInputScreen(data: data, onNext: _nextStep);
      
      case 2:
        // Greeting "Namaste {userName}" (Screen 7) - auto-advance after 2s
        Future.delayed(const Duration(seconds: 2), () {
          if (mounted && currentStep == 2) {
            _nextStep();
          }
        });
        return GreetingScreen(data: data);
      
      case 3:
        // "What brings you here?" (Screen 8-9)
        return MotivationScreen(data: data, onNext: _nextStep);
      
      case 4:
        // "Peace starts with awareness" interlude (Screen 10) - auto-advance
        Future.delayed(const Duration(seconds: 3), () {
          if (mounted && currentStep == 4) {
            _nextStep();
          }
        });
        return InterludeScreen(
          text: 'Peace starts with awareness',
          progress: 0.3,
        );
      
      case 5:
        // Vedanta familiarity (Screen 11-12)
        return VedantaFamiliarityScreen(data: data, onNext: _nextStep);
      
      case 6:
        // "Every path begins..." interlude (Screen 13) - auto-advance
        Future.delayed(const Duration(seconds: 3), () {
          if (mounted && currentStep == 6) {
            _nextStep();
          }
        });
        return InterludeScreen(
          text: 'Every path begins with a first step',
          progress: 0.4,
        );
      
      case 7:
        // Biggest struggle (Screen 14-16)
        return StruggleScreen(data: data, onNext: _nextStep);
      
      case 8:
        // "Your honesty is the beginning of peace, {userName}" interlude (Screen 17) - auto-advance
        Future.delayed(const Duration(seconds: 3), () {
          if (mounted && currentStep == 8) {
            _nextStep();
          }
        });
        return InterludeScreen(
          text: 'Your honesty is the beginning of peace, {userName}',
          progress: 0.6,
          data: data,
        );
      
      case 9:
        // Stats screen "Your Inner Stillness" (Frame 411)
        return StatsScreen(onNext: _nextStep);
      
      case 10:
        // Daily blessings (Screen 19)
        return DailyBlessingsScreen(data: data, onNext: _nextStep);
      
      case 11:
        // Daily practice selection (Screen 20)
        return DailyPracticeScreen(data: data, onNext: _nextStep);
      
      case 12:
        // Auth (Screen 21)
        return AuthScreen(
          data: data,
          onNext: () {
            setState(() {
              currentStep = 13;
            });
          },
          onSkip: () {
            setState(() {
              currentStep = 13;
            });
          },
        );
      
      case 13:
        // Completion (Screen 22-24)
        return CompletionScreen(onComplete: widget.onComplete);
      
      default:
        return AnimatedSplashScreen(onComplete: _nextStep);
    }
  }
  
  double _getProgress() {
    // Calculate progress based on current step
    // Total steps: 14 (0-13), but step 0 is splash screen
    if (currentStep == 0) return 0.0; // Splash
    return (currentStep / 13).clamp(0.0, 1.0);
  }
  
  bool _shouldShowBackButton() {
    // Don't show back button on splash, auto-advancing interlude screens, or completion
    return currentStep > 0 && currentStep != 2 && currentStep != 4 && currentStep != 6 && currentStep != 8 && currentStep != 13;
  }
  
  @override
  Widget build(BuildContext context) {
    // Special case: Splash screen doesn't use the page view wrapper
    if (currentStep == 0) {
      return _getCurrentScreen();
    }
    
    return WillPopScope(
      onWillPop: () async {
        if (currentStep > 0 && _shouldShowBackButton()) {
          _previousStep();
          return false;
        }
        return true;
      },
      child: OnboardingPageView(
        progress: _getProgress(),
        showBackButton: _shouldShowBackButton(),
        onBack: _previousStep,
        childKey: ValueKey(currentStep),
        child: _getCurrentScreen(),
      ),
    );
  }
}

