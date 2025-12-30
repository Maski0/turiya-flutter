import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import '../theme/onboarding_theme.dart';
import '../widgets/onboarding_scaffold.dart';
import '../models/onboarding_data.dart';
import '../../widgets/icons/send_icon.dart';

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
    // Listen to focus changes to update border color
    _focusNode.addListener(() {
      setState(() {});
    });
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
                      style:
                          OnboardingTheme.headingLarge.copyWith(fontSize: 32),
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
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(16),
                        child: BackdropFilter(
                          filter: ImageFilter.blur(sigmaX: 8, sigmaY: 8),
                          child: Container(
                            decoration: BoxDecoration(
                              color: const Color(0x40000000), // 25% Black
                              border: Border.all(
                                color: _focusNode.hasFocus
                                    ? Colors.white // White when focused
                                    : OnboardingTheme.textPrimary.withOpacity(
                                        0.15), // Subtle when not focused
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
                                    style: OnboardingTheme.bodyLarge
                                        .copyWith(fontSize: 16),
                                    decoration: InputDecoration(
                                      border: InputBorder.none,
                                      hintText: 'Enter your name',
                                      hintStyle:
                                          OnboardingTheme.bodyLarge.copyWith(
                                        fontSize: 16,
                                        color: OnboardingTheme.textPrimary
                                            .withOpacity(0.4),
                                      ),
                                      contentPadding:
                                          const EdgeInsets.symmetric(
                                              horizontal: 20),
                                    ),
                                    textInputAction: TextInputAction.done,
                                    onSubmitted: (_) => _handleSubmit(),
                                    onChanged: (_) => setState(() {}),
                                    onTap: () => setState(
                                        () {}), // Trigger rebuild on focus
                                  ),
                                ),
                                // Send button
                                GestureDetector(
                                  onTap: _controller.text.trim().isEmpty
                                      ? null
                                      : _handleSubmit,
                                  child: Container(
                                    padding: const EdgeInsets.all(4),
                                    margin: const EdgeInsets.only(right: 12),
                                    child: SendIcon(
                                      isActive:
                                          _controller.text.trim().isNotEmpty,
                                      size: 28,
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
