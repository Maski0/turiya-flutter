import 'dart:ui';
import 'package:flutter/material.dart';
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
  bool _showCustomInput = false;

  @override
  void initState() {
    super.initState();
    selected = Set.from(widget.data.struggles);
    if (widget.data.customStruggle != null) {
      _customController.text = widget.data.customStruggle!;
    }
    // Listen to focus changes to hide custom input when focus is lost
    _customFocusNode.addListener(() {
      if (!_customFocusNode.hasFocus && mounted) {
        setState(() {
          _showCustomInput = false;
        });
      }
    });
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
    final bool isInputMode = _customFocusNode.hasFocus || _showCustomInput;

    // Return content only - wrapper handles scaffold
    return WillPopScope(
      onWillPop: () async {
        // If custom input is showing, close it instead of going back
        if (isInputMode) {
          _customFocusNode.unfocus();
          setState(() {
            _showCustomInput = false;
          });
          return false; // Don't pop
        }
        return true; // Allow normal back navigation
      },
      child: GestureDetector(
        onVerticalDragDown: (_) {
          // Dismiss keyboard on swipe down
          if (isInputMode) {
            FocusScope.of(context).unfocus();
          }
        },
        behavior: HitTestBehavior.translucent,
        child: Stack(
          children: [
            // Main content - always visible
            Column(
              children: [
                // Header - not blurred
                Padding(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
                  child: Text(
                    'What feels like your biggest struggle right now?',
                    style: OnboardingTheme.headingMedium,
                    textAlign: TextAlign.center,
                  ),
                ),
                const SizedBox(height: 40),
                // Options list - can be blurred
                Expanded(
                  child: Stack(
                    children: [
                      // Options list
                      ListView(
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
                          const SizedBox(
                              height: 200), // Space for bottom elements
                        ],
                      ),
                      // Blur overlay on options only when input mode is active - gradual appearance
                      Positioned.fill(
                        child: IgnorePointer(
                          ignoring: !isInputMode,
                          child: AnimatedOpacity(
                            opacity: isInputMode ? 1.0 : 0.0,
                            duration: const Duration(milliseconds: 500),
                            curve: Curves.easeInOut,
                            child: ClipRect(
                              child: BackdropFilter(
                                filter: ImageFilter.blur(sigmaX: 2, sigmaY: 2),
                                child: Container(
                                  decoration: BoxDecoration(
                                    gradient: LinearGradient(
                                      begin: Alignment.topCenter,
                                      end: Alignment.bottomCenter,
                                      colors: [
                                        Colors.transparent, // No tint at top
                                        Colors.white.withOpacity(
                                            0.05), // Very subtle white tint
                                        Colors.white.withOpacity(0.15),
                                        Colors.white.withOpacity(0.25),
                                      ],
                                      stops: const [0.0, 0.3, 0.7, 1.0],
                                    ),
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
              ],
            ),
            // White gradient overlay - fades in when input is active
            Positioned.fill(
              child: IgnorePointer(
                ignoring: !isInputMode,
                child: AnimatedOpacity(
                  opacity: isInputMode ? 1.0 : 0.0,
                  duration: const Duration(milliseconds: 400),
                  curve: Curves.easeInOut,
                  child: Container(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.bottomCenter,
                        end: Alignment.topCenter,
                        colors: [
                          Colors.white.withOpacity(0.65), // Reduced from 0.85
                          Colors.white.withOpacity(0.5), // Reduced from 0.7
                          Colors.white.withOpacity(0.35), // Reduced from 0.5
                          Colors.white.withOpacity(0.2), // Reduced from 0.3
                          Colors.white.withOpacity(0.08), // Reduced from 0.1
                          Colors.transparent,
                        ],
                        stops: const [0.0, 0.2, 0.4, 0.6, 0.85, 1.0],
                      ),
                    ),
                  ),
                ),
              ),
            ),
            // Bottom section with input bar and Continue button - moves up with keyboard
            Positioned(
              left: 0,
              right: 0,
              bottom: 0,
              child: SafeArea(
                top: false,
                child: Padding(
                  padding: const EdgeInsets.only(bottom: 16),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      // Single input bar - clickable when not focused, editable when focused
                      GestureDetector(
                        onTap: !isInputMode
                            ? () {
                                _scrollController.animateTo(
                                  0,
                                  duration: const Duration(milliseconds: 300),
                                  curve: Curves.easeInOut,
                                );
                                setState(() {
                                  _showCustomInput = true;
                                });
                                Future.delayed(
                                    const Duration(milliseconds: 100), () {
                                  _customFocusNode.requestFocus();
                                });
                              }
                            : null,
                        child: Container(
                          margin: const EdgeInsets.symmetric(
                              horizontal: 16, vertical: 12),
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(16),
                            child: BackdropFilter(
                              filter: ImageFilter.blur(sigmaX: 8, sigmaY: 8),
                              child: Container(
                                width: double.infinity, // Full width
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 20, vertical: 16),
                                decoration: BoxDecoration(
                                  color: isInputMode
                                      ? const Color(
                                          0x60000000) // Darker opacity when typing for readability
                                      : const Color(
                                          0x20000000), // Less when just showing placeholder
                                  border: Border.all(
                                    color: isInputMode
                                        ? Colors.white.withOpacity(
                                            0.6) // Thicker/brighter border when focused
                                        : Colors.white.withOpacity(
                                            0.3), // Subtle when not focused
                                    width: isInputMode
                                        ? 2
                                        : 1, // Thicker border when focused
                                  ),
                                  borderRadius: BorderRadius.circular(16),
                                ),
                                child: isInputMode
                                    ? TextField(
                                        controller: _customController,
                                        focusNode: _customFocusNode,
                                        autofocus: false,
                                        style:
                                            OnboardingTheme.bodyLarge.copyWith(
                                          fontSize: 16,
                                          color: OnboardingTheme.textPrimary
                                              .withOpacity(0.9),
                                        ),
                                        minLines: 1,
                                        maxLines: 3,
                                        keyboardType: TextInputType.multiline,
                                        textAlignVertical:
                                            TextAlignVertical.center,
                                        decoration: InputDecoration(
                                          border: InputBorder.none,
                                          hintText: 'Write your own...',
                                          hintStyle: OnboardingTheme.bodyLarge
                                              .copyWith(
                                            fontSize: 16,
                                            color: OnboardingTheme.textPrimary
                                                .withOpacity(0.4),
                                          ),
                                          contentPadding: EdgeInsets.zero,
                                          isDense: true,
                                        ),
                                        textInputAction: TextInputAction.done,
                                        onChanged: (_) => setState(() {}),
                                        onSubmitted: (_) {
                                          if (_customController.text
                                              .trim()
                                              .isNotEmpty) {
                                            widget.data.customStruggle =
                                                _customController.text.trim();
                                            widget.onNext();
                                          }
                                        },
                                      )
                                    : Text(
                                        'Something else?',
                                        style:
                                            OnboardingTheme.bodyLarge.copyWith(
                                          fontSize: 16,
                                          color: OnboardingTheme.textPrimary
                                              .withOpacity(0.4),
                                        ),
                                      ),
                              ),
                            ),
                          ),
                        ),
                      ),
                      // Continue button with drop shadow
                      Container(
                        decoration: BoxDecoration(
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withOpacity(0.15),
                              offset: const Offset(0, 4),
                              blurRadius: 12,
                              spreadRadius: 0,
                            ),
                          ],
                        ),
                        child: OnboardingButton(
                          text: 'Continue',
                          onPressed: (selected.isNotEmpty ||
                                  _customController.text.trim().isNotEmpty)
                              ? _handleSubmit
                              : null,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
