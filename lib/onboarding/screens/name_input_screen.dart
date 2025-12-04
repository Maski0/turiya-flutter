import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:liquid_glass_renderer/liquid_glass_renderer.dart';
import '../theme/onboarding_theme.dart';
import '../widgets/onboarding_scaffold.dart';
import '../models/onboarding_data.dart';

/// Screen 5: Name input
class NameInputScreen extends StatefulWidget {
  final OnboardingData data;
  final VoidCallback onNext;
  
  const NameInputScreen({
    super.key,
    required this.data,
    required this.onNext,
  });
  
  @override
  State<NameInputScreen> createState() => _NameInputScreenState();
}

class _NameInputScreenState extends State<NameInputScreen> {
  final TextEditingController _controller = TextEditingController();
  final FocusNode _focusNode = FocusNode();
  
  @override
  void initState() {
    super.initState();
    if (widget.data.userName != null) {
      _controller.text = widget.data.userName!;
    }
  }
  
  @override
  void dispose() {
    _controller.dispose();
    _focusNode.dispose();
    super.dispose();
  }
  
  void _handleSubmit() {
    if (_controller.text.trim().isNotEmpty) {
      widget.data.userName = _controller.text.trim();
      widget.onNext();
    }
  }
  
  @override
  Widget build(BuildContext context) {
    // Return content only - wrapper handles scaffold
    return LayoutBuilder(
      builder: (context, constraints) {
        return SingleChildScrollView(
          child: ConstrainedBox(
            constraints: BoxConstraints(minHeight: constraints.maxHeight),
            child: IntrinsicHeight(
              child: Column(
                children: [
                  const SizedBox(height: 40),
                  // Question
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 32),
                    child: Text(
                      'What shall I call you?',
                      style: OnboardingTheme.headingLarge.copyWith(fontSize: 32),
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
                  // Input field (glass effect)
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: Container(
                      height: 64,
                      child: FakeGlass(
                        shape: LiquidRoundedSuperellipse(borderRadius: 16),
                        settings: const LiquidGlassSettings(
                          blur: 8,
                          glassColor: Color(0x40000000), // 25% Black
                        ),
                        child: Container(
                          decoration: BoxDecoration(
                            border: Border.all(
                              color: Colors.white, // Solid white border
                              width: 1,
                            ),
                            borderRadius: BorderRadius.circular(16),
                          ),
                          child: Row(
                        children: [
                          Expanded(
                            child: TextField(
                              controller: _controller,
                              focusNode: _focusNode,
                              style: OnboardingTheme.bodyLarge.copyWith(fontSize: 16),
                              decoration: InputDecoration(
                                border: InputBorder.none,
                                hintText: 'Enter your name',
                                hintStyle: OnboardingTheme.bodyLarge.copyWith(
                                  fontSize: 16,
                                  color: OnboardingTheme.textPrimary.withOpacity(0.4),
                                ),
                                contentPadding: const EdgeInsets.symmetric(horizontal: 20),
                              ),
                              textInputAction: TextInputAction.done,
                              onSubmitted: (_) => _handleSubmit(),
                              onChanged: (_) => setState(() {}),
                            ),
                          ),
                          // Send button
                          GestureDetector(
                            onTap: _controller.text.trim().isEmpty ? null : _handleSubmit,
                            child: Container(
                              width: 40,
                              height: 40,
                              margin: const EdgeInsets.only(right: 12),
                              child: Icon(
                                Icons.send,
                                color: _controller.text.trim().isEmpty
                                    ? OnboardingTheme.textPrimary.withOpacity(0.3)
                                    : OnboardingTheme.textPrimary.withOpacity(0.8),
                                size: 20,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
                  const SizedBox(height: 40),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}

