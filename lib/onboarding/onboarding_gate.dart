import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'onboarding_flow.dart';

/// Widget that shows onboarding on first launch, then the main app
class OnboardingGate extends StatefulWidget {
  final Widget child;
  
  const OnboardingGate({
    super.key,
    required this.child,
  });
  
  @override
  State<OnboardingGate> createState() => _OnboardingGateState();
}

class _OnboardingGateState extends State<OnboardingGate> {
  bool _isLoading = true;
  bool _hasCompletedOnboarding = false;
  
  @override
  void initState() {
    super.initState();
    _checkOnboardingStatus();
  }
  
  Future<void> _checkOnboardingStatus() async {
    final prefs = await SharedPreferences.getInstance();
    final completed = prefs.getBool('onboarding_completed') ?? false;
    
    if (mounted) {
        setState(() {
        // _hasCompletedOnboarding = completed;
        _hasCompletedOnboarding = true;
        _isLoading = false;
      });
    }
  }
  
  Future<void> _completeOnboarding() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('onboarding_completed', true);
    
    if (mounted) {
      setState(() {
        _hasCompletedOnboarding = true;
      });
    }
  }
  
  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Scaffold(
        body: Center(
          child: CircularProgressIndicator(),
        ),
      );
    }
    
    if (!_hasCompletedOnboarding) {
      return OnboardingFlow(
        onComplete: _completeOnboarding,
      );
    }
    
    return widget.child;
  }
}

