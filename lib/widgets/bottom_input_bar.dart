import 'dart:ui';
import 'package:flutter/material.dart';
import 'icons/mic_icon.dart';
import 'icons/send_icon.dart';
import 'icons/check_icon.dart';
import 'icons/textchat_icon.dart';

class BottomInputBar extends StatefulWidget {
  final TextEditingController textController;
  final FocusNode? focusNode;
  final bool isGenerating;
  final bool isRecording;
  final bool isAudioPlaying;
  final Function(String) onSubmit;
  final VoidCallback onMicTap;
  final VoidCallback? onMicLongPress;
  final VoidCallback? onStopAudio;
  final bool showChatButton;
  final VoidCallback? onChatButtonTap;

  const BottomInputBar({
    super.key,
    required this.textController,
    this.focusNode,
    required this.isGenerating,
    this.isRecording = false,
    this.isAudioPlaying = false,
    required this.onSubmit,
    required this.onMicTap,
    this.onMicLongPress,
    this.onStopAudio,
    this.showChatButton = false,
    this.onChatButtonTap,
  });

  @override
  State<BottomInputBar> createState() => _BottomInputBarState();
}

class _BottomInputBarState extends State<BottomInputBar> {
  @override
  void initState() {
    super.initState();
    // Listen to text changes to hide/show chat button
    widget.textController.addListener(_onTextChanged);
  }

  @override
  void dispose() {
    widget.textController.removeListener(_onTextChanged);
    super.dispose();
  }

  void _onTextChanged() {
    // Trigger rebuild when text changes
    setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      bottom: true,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Row containing input bar and optional chat button
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              // Input container - Web: containerBase = 56px
              Expanded(
                child: Padding(
                  // Symmetric margin when chat button hidden, left only when shown
                  padding: EdgeInsets.only(
                    left: 8,
                    right: widget.showChatButton ? 0 : 8,
                  ),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(12),
                    child: BackdropFilter(
                      // High blur for liquid glass refraction effect
                      filter: ImageFilter.blur(sigmaX: 24, sigmaY: 24),
                      child: Container(
                        height: 56, // Web: containerBase = 56px
                        decoration: BoxDecoration(
                          // Glass effect - no background, just border
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: const Color(0x33FFFFFF),
                            width: 0.5,
                          ),
                        ),
                        child: Padding(
                          // Web: p-4 but we need less vertical to fit in 56px
                          padding: const EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 8,
                          ),
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.center,
                            children: [
                              // Textarea/Input field
                              Expanded(
                                child: TextField(
                                  controller: widget.textController,
                                  focusNode: widget.focusNode,
                                  readOnly: widget.isGenerating ||
                                      widget.isAudioPlaying,
                                  maxLines: null,
                                  // Use theme: titleLarge (18px)
                                  style: Theme.of(context)
                                      .textTheme
                                      .titleLarge!
                                      .copyWith(
                                        color: Colors.white,
                                        fontWeight: FontWeight.w500,
                                        height: 1.25,
                                      ),
                                  decoration: InputDecoration(
                                    hintText: widget.isGenerating
                                        ? 'Pondering...'
                                        : 'Ask what your heart seeks',
                                    // Use theme: titleLarge (18px)
                                    hintStyle: Theme.of(context)
                                        .textTheme
                                        .titleLarge!
                                        .copyWith(
                                          color: Colors.white.withOpacity(0.5),
                                          fontWeight: FontWeight.w500,
                                          height: 1.25,
                                        ),
                                    border: InputBorder.none,
                                    contentPadding: EdgeInsets.zero,
                                    isDense: true,
                                  ),
                                  onSubmitted: widget.onSubmit,
                                ),
                              ),

                              // Mic button - disabled during generating/streaming
                              GestureDetector(
                                onTap: (widget.isGenerating ||
                                        widget.isAudioPlaying)
                                    ? null
                                    : widget.onMicTap,
                                onLongPress: (widget.isGenerating ||
                                        widget.isAudioPlaying)
                                    ? null
                                    : widget.onMicLongPress,
                                child: Opacity(
                                  opacity: (widget.isGenerating ||
                                          widget.isAudioPlaying)
                                      ? 0.3
                                      : 1.0,
                                  child: Container(
                                    padding: const EdgeInsets.all(4),
                                    decoration: BoxDecoration(
                                      color: Colors.transparent,
                                      borderRadius: BorderRadius.circular(20),
                                    ),
                                    child: const MicIcon(size: 24),
                                  ),
                                ),
                              ),

                              // Right button - dynamic based on state
                              if (widget.isRecording)
                                // Recording: show check to submit
                                GestureDetector(
                                  onTap: () => widget
                                      .onSubmit(widget.textController.text),
                                  child: Container(
                                    margin: const EdgeInsets.only(left: 12),
                                    padding: const EdgeInsets.all(4),
                                    decoration: BoxDecoration(
                                      color: Colors.transparent,
                                      borderRadius: BorderRadius.circular(20),
                                    ),
                                    child: const CheckIcon(size: 24),
                                  ),
                                )
                              else if (widget.isAudioPlaying &&
                                  widget.onStopAudio != null)
                                // Streaming: show stop button
                                GestureDetector(
                                  onTap: widget.onStopAudio,
                                  child: Container(
                                    margin: const EdgeInsets.only(left: 4),
                                    padding: const EdgeInsets.all(4),
                                    decoration: BoxDecoration(
                                      color: Colors.transparent,
                                      borderRadius: BorderRadius.circular(20),
                                    ),
                                    child: const Icon(
                                      Icons.stop_rounded,
                                      color: Colors.white,
                                      size: 24,
                                    ),
                                  ),
                                )
                              else
                                // Normal/Pondering: show send button (disabled when pondering)
                                Opacity(
                                  opacity: widget.isGenerating ? 0.3 : 1.0,
                                  child: GestureDetector(
                                    onTap: (widget.isGenerating ||
                                            widget.textController.text
                                                .trim()
                                                .isEmpty)
                                        ? null
                                        : () => widget.onSubmit(
                                            widget.textController.text),
                                    child: Container(
                                      margin: const EdgeInsets.only(left: 4),
                                      padding: const EdgeInsets.all(4),
                                      decoration: BoxDecoration(
                                        color: Colors.transparent,
                                        borderRadius: BorderRadius.circular(20),
                                      ),
                                      child: SendIcon(
                                        isActive: widget.textController.text
                                                .trim()
                                                .isNotEmpty &&
                                            !widget.isGenerating,
                                        size: 24,
                                      ),
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
              ),

              // Chat button - show when: text empty OR pondering OR streaming
              if (widget.showChatButton &&
                  (widget.textController.text.trim().isEmpty ||
                      widget.isGenerating ||
                      widget.isAudioPlaying))
                Padding(
                  padding: const EdgeInsets.only(left: 8, right: 8),
                  child: GestureDetector(
                    onTap: widget.onChatButtonTap,
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(12),
                      child: BackdropFilter(
                        filter: ImageFilter.blur(sigmaX: 16, sigmaY: 16),
                        child: Container(
                          height: 56,
                          width: 56,
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                              color: const Color(0x33FFFFFF),
                              width: 0.5,
                            ),
                          ),
                          child: const Center(
                            child: TextChatIcon(size: 20),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }
}
