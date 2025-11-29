import 'package:flutter/material.dart';
import '../theme/onboarding_theme.dart';
import '../widgets/onboarding_scaffold.dart';
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
    return OnboardingScaffold(
      progress: 0.5, // 4/8
      showBackButton: true,
      child: Column(
        children: [
          // Header
          Padding(
            padding: const EdgeInsets.all(16),
            child: Text(
              'What feels like your biggest struggle right now?',
              style: OnboardingTheme.headingMedium,
              textAlign: TextAlign.start,
            ),
          ),
          const SizedBox(height: 40),
          // Options
          Expanded(
            child: ListView(
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
                const SizedBox(height: 12),
                // "Something else?" text input
                GestureDetector(
                  onTap: () {
                    _customFocusNode.requestFocus();
                  },
                  child: Container(
                    height: 64,
                    margin: const EdgeInsets.only(bottom: 12),
                    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 20),
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.03),
                      border: Border.all(
                        color: _customFocusNode.hasFocus
                            ? OnboardingTheme.textPrimary.withOpacity(0.6)
                            : OnboardingTheme.textPrimary.withOpacity(0.15),
                        width: 1,
                      ),
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: TextField(
                      controller: _customController,
                      focusNode: _customFocusNode,
                      style: OnboardingTheme.bodyLarge.copyWith(fontSize: 16),
                      decoration: InputDecoration(
                        border: InputBorder.none,
                        hintText: 'Something else?',
                        hintStyle: OnboardingTheme.bodyLarge.copyWith(
                          fontSize: 16,
                          color: OnboardingTheme.textPrimary.withOpacity(0.5),
                        ),
                        contentPadding: EdgeInsets.zero,
                        isDense: true,
                      ),
                      textInputAction: TextInputAction.done,
                      onChanged: (_) => setState(() {}),
                    ),
                  ),
                ),
                const SizedBox(height: 24),
              ],
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
    );
  }
}

