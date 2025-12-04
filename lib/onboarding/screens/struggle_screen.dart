import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:liquid_glass_renderer/liquid_glass_renderer.dart';
import '../theme/onboarding_theme.dart';
import '../widgets/onboarding_radio_option.dart';
import '../widgets/onboarding_button.dart';
import '../models/onboarding_data.dart';

/// Screen 14-16: "What feels like your biggest struggle right now?"
class StruggleScreen extends StatefulWidget {
  final OnboardingData data;
  final VoidCallback onNext;
  
  const StruggleScreen({
    super.key,
    required this.data,
    required this.onNext,
  });
  
  @override
  State<StruggleScreen> createState() => _StruggleScreenState();
}

class _StruggleScreenState extends State<StruggleScreen> {
  final List<String> options = [
    'Restlessness of mind',
    'Lack of clarity or direction',
    'Emotional heaviness or pain',
    'Difficulty staying disciplined',
    'Overthinking or self-doubt',
  ];
  
  Set<String> selected = {};
  final TextEditingController _customController = TextEditingController();
  final FocusNode _customFocusNode = FocusNode();
  final ScrollController _scrollController = ScrollController();
  
  @override
  void initState() {
    super.initState();
    selected = Set.from(widget.data.struggles);
    if (widget.data.customStruggle != null) {
      _customController.text = widget.data.customStruggle!;
    }
  }
  
  @override
  void dispose() {
    _customController.dispose();
    _customFocusNode.dispose();
    _scrollController.dispose();
    super.dispose();
  }
  
  void _handleSubmit() {
    if (selected.isNotEmpty || _customController.text.trim().isNotEmpty) {
      widget.data.struggles = selected.toList();
      widget.data.customStruggle = _customController.text.trim().isNotEmpty 
          ? _customController.text.trim() 
          : null;
      widget.onNext();
    }
  }
  
  @override
  Widget build(BuildContext context) {
    // Return content only - wrapper handles scaffold
    return Stack(
      children: [
        // Main content with conditional blur
        AnimatedContainer(
          duration: const Duration(milliseconds: 300),
          child: _customFocusNode.hasFocus
              ? ImageFiltered(
                  imageFilter: ImageFilter.blur(sigmaX: 8, sigmaY: 8),
                  child: _buildMainContent(),
                )
              : _buildMainContent(),
        ),
        // Bottom section with "Something else?" and Continue button
        Positioned(
          left: 0,
          right: 0,
          bottom: 0,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // "Something else?" - always visible at bottom with glass effect
              if (!_customFocusNode.hasFocus)
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: GestureDetector(
                    onTap: () {
                      // Scroll to top when tapped
                      _scrollController.animateTo(
                        0,
                        duration: const Duration(milliseconds: 300),
                        curve: Curves.easeInOut,
                      );
                      // Request focus to open keyboard
                      Future.delayed(const Duration(milliseconds: 350), () {
                        _customFocusNode.requestFocus();
                      });
                    },
                    child: Container(
                      height: 64,
                      margin: const EdgeInsets.only(bottom: 12),
                      child: FakeGlass(
                        shape: LiquidRoundedSuperellipse(borderRadius: 16),
                        settings: const LiquidGlassSettings(
                          blur: 6,
                          glassColor: Color(0x06FFFFFF),
                        ),
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 20),
                          decoration: BoxDecoration(
                            border: Border.all(
                              color: OnboardingTheme.textPrimary.withOpacity(0.15),
                              width: 1,
                            ),
                            borderRadius: BorderRadius.circular(16),
                          ),
                          child: Align(
                            alignment: Alignment.centerLeft,
                            child: Text(
                              'Something else?',
                              style: OnboardingTheme.bodyLarge.copyWith(
                                fontSize: 16,
                                color: OnboardingTheme.textPrimary.withOpacity(0.4),
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              // Continue button
              OnboardingButton(
                text: 'Continue',
                onPressed: (selected.isNotEmpty || _customController.text.trim().isNotEmpty)
                    ? _handleSubmit
                    : null,
              ),
            ],
          ),
        ),
        // Elevated text input with gradient background (appears when focused)
        if (_customFocusNode.hasFocus)
          Positioned(
            left: 0,
            right: 0,
            bottom: 0,
            child: Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    OnboardingTheme.backgroundDark.withOpacity(0.0),
                    OnboardingTheme.backgroundDark.withOpacity(0.95),
                    OnboardingTheme.backgroundDark,
                  ],
                  stops: const [0.0, 0.3, 1.0],
                ),
              ),
              padding: const EdgeInsets.all(16),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Elevated text input with glass effect
                  FakeGlass(
                    shape: LiquidRoundedSuperellipse(borderRadius: 16),
                    settings: const LiquidGlassSettings(
                      blur: 12,
                      glassColor: Color(0x40000000), // 25% Black
                    ),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
                      decoration: BoxDecoration(
                        border: Border.all(
                          color: Colors.white, // Solid white border
                          width: 1,
                        ),
                        borderRadius: BorderRadius.circular(16),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.3),
                            offset: const Offset(0, 8),
                            blurRadius: 24,
                            spreadRadius: 0,
                          ),
                        ],
                      ),
                      child: TextField(
                      controller: _customController,
                      focusNode: _customFocusNode,
                      style: OnboardingTheme.bodyLarge.copyWith(
                        fontSize: 16,
                        color: OnboardingTheme.textPrimary.withOpacity(0.9),
                      ),
                      maxLines: 3,
                      decoration: InputDecoration(
                        border: InputBorder.none,
                        hintText: 'Write your own...',
                        hintStyle: OnboardingTheme.bodyLarge.copyWith(
                          fontSize: 16,
                          color: OnboardingTheme.textPrimary.withOpacity(0.4),
                        ),
                        contentPadding: EdgeInsets.zero,
                        isDense: true,
                      ),
                      textInputAction: TextInputAction.done,
                      onChanged: (_) => setState(() {}),
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  // Continue button
                  OnboardingButton(
                    text: 'Continue',
                    onPressed: (selected.isNotEmpty || _customController.text.trim().isNotEmpty)
                        ? _handleSubmit
                        : null,
                  ),
                ],
              ),
            ),
          ),
      ],
    );
  }

  Widget _buildMainContent() {
    return Column(
      children: [
        // Header
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
          child: Text(
            'What feels like your biggest struggle right now?',
            style: OnboardingTheme.headingMedium,
            textAlign: TextAlign.start,
          ),
        ),
        const SizedBox(height: 40),
        // Options list
        Expanded(
          child: ListView(
            controller: _scrollController,
            padding: const EdgeInsets.symmetric(horizontal: 16),
            children: [
              ...options.map((option) => OnboardingRadioOption(
                label: option,
                isSelected: selected.contains(option),
                onTap: () {
                  setState(() {
                    if (selected.contains(option)) {
                      selected.remove(option);
                    } else {
                      selected.add(option);
                    }
                  });
                },
              )),
              const SizedBox(height: 200), // Space for bottom elements
            ],
          ),
        ),
      ],
    );
  }
}

