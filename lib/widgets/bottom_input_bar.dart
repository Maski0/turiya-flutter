import 'dart:ui';
import 'package:flutter/material.dart';
import 'icons/mic_icon.dart';
import 'icons/send_icon.dart';
import 'icons/check_icon.dart';
import 'icons/textchat_icon.dart';
import 'star_border.dart';

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
  final bool enabled;
  final bool isLiveKitConnected;
  final bool isLiveKitConnecting;
  final VoidCallback? onDisconnectLiveKit;

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
    this.enabled = true,
    this.isLiveKitConnected = false,
    this.isLiveKitConnecting = false,
    this.onDisconnectLiveKit,
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
          // Pondering chip - shown above input when generating (not playing)
          if (widget.isGenerating && !widget.isAudioPlaying)
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(16),
                child: BackdropFilter(
                  filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 14,
                      vertical: 8,
                    ),
                    decoration: BoxDecoration(
                      color: const Color(0x30000000),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(
                        color: const Color(0x20FFFFFF),
                        width: 1,
                      ),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          'Pondering',
                          style: TextStyle(
                            fontFamily: 'Alegreya',
                            fontSize: 14,
                            fontWeight: FontWeight.w500,
                            color: Colors.white.withOpacity(0.9),
                          ),
                        ),
                        const SizedBox(width: 6),
                        // Colored bouncing dots
                        const _PonderingDot(color: Color(0xFFFF0000), delay: 0),
                        const SizedBox(width: 3),
                        const _PonderingDot(
                            color: Color(0xFFFFA569), delay: 150),
                        const SizedBox(width: 3),
                        const _PonderingDot(
                            color: Color(0xFFA7A6FB), delay: 300),
                        const SizedBox(width: 3),
                        const _PonderingDot(
                            color: Color(0xFF046E80), delay: 450),
                      ],
                    ),
                  ),
                ),
              ),
            ),
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
                  // Animated star border with frosted glass effect
                  child: AnimatedStarBorder(
                    color: const Color(0x99FFFFFF),
                    speed: const Duration(seconds: 8),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(12),
                      child: BackdropFilter(
                        filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
                        child: Container(
                          height: 56,
                          decoration: BoxDecoration(
                            color:
                                const Color(0x28FFFFFF), // ~16% opacity white
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                              color: const Color(0x40FFFFFF),
                              width: 0.5,
                            ),
                          ),
                          child: Padding(
                            // Web: p-4 but we need less vertical to fit in 56px
                            padding: const EdgeInsets.only(
                              left: 18,
                              top: 6,
                              right: 8,
                              bottom: 6,
                            ),
                            child: Row(
                              crossAxisAlignment: CrossAxisAlignment.center,
                              children: [
                                // Textarea/Input field
                                Expanded(
                                  child: TextField(
                                    controller: widget.textController,
                                    focusNode: widget.focusNode,
                                    enabled: widget.enabled,
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
                                      hintText: widget.isLiveKitConnecting &&
                                              widget.isLiveKitConnected
                                          ? 'Disconnecting...'
                                          : widget.isLiveKitConnecting
                                              ? 'Connecting...'
                                              : widget.isGenerating
                                                  ? 'Pondering...'
                                                  : widget.isLiveKitConnected
                                                      ? 'Speak what your heart seeks'
                                                      : 'Ask what your heart seeks',
                                      // Use theme: titleLarge (18px)
                                      hintStyle: Theme.of(context)
                                          .textTheme
                                          .titleLarge!
                                          .copyWith(
                                            color:
                                                Colors.white.withOpacity(0.5),
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

                                // Mic button - hidden when LiveKit is connected or connecting
                                if (!widget.isLiveKitConnected &&
                                    !widget.isLiveKitConnecting)
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
                                          borderRadius:
                                              BorderRadius.circular(20),
                                        ),
                                        child: const MicIcon(size: 28),
                                      ),
                                    ),
                                  ),

                                // Right button - dynamic based on state
                                if (widget.isLiveKitConnected ||
                                    widget.isLiveKitConnecting)
                                  // LiveKit connected or connecting: show close button to disconnect/cancel
                                  GestureDetector(
                                    onTap: widget.onDisconnectLiveKit,
                                    child: Container(
                                      margin: const EdgeInsets.only(left: 12),
                                      padding: const EdgeInsets.all(8),
                                      decoration: BoxDecoration(
                                        color: Colors.transparent,
                                        borderRadius: BorderRadius.circular(20),
                                      ),
                                      child: const Icon(
                                        Icons.close,
                                        color: Colors.white,
                                        size: 24,
                                      ),
                                    ),
                                  )
                                else if (widget.isRecording)
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
                                  // Streaming: show stop button in circle
                                  GestureDetector(
                                    onTap: widget.onStopAudio,
                                    child: Container(
                                      width: 38,
                                      height: 38,
                                      margin: const EdgeInsets.only(left: 4),
                                      decoration: BoxDecoration(
                                        color: Colors.white.withOpacity(0.15),
                                        shape: BoxShape.circle,
                                        border: Border.all(
                                          color: Colors.white.withOpacity(0.2),
                                          width: 1,
                                        ),
                                      ),
                                      child: const Center(
                                        child: Icon(
                                          Icons.stop_rounded,
                                          color: Colors.white,
                                          size: 32,
                                        ),
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
                                          borderRadius:
                                              BorderRadius.circular(20),
                                        ),
                                        child: SendIcon(
                                          isActive: widget.textController.text
                                                  .trim()
                                                  .isNotEmpty &&
                                              !widget.isGenerating,
                                          size: 28,
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
              ),

              // Chat button - show when: text empty OR pondering OR streaming
              if (widget.showChatButton &&
                  (widget.textController.text.trim().isEmpty ||
                      widget.isGenerating ||
                      widget.isAudioPlaying))
                Padding(
                  padding: const EdgeInsets.only(left: 8, right: 8),
                  // Frosted glass effect with BackdropFilter
                  child: GestureDetector(
                    onTap: widget.onChatButtonTap,
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(12),
                      child: BackdropFilter(
                        filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
                        child: Container(
                          height: 56,
                          width: 56,
                          decoration: BoxDecoration(
                            color:
                                const Color(0x28FFFFFF), // ~16% opacity white
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                              color: const Color(0x40FFFFFF),
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

/// Animated bouncing dot for pondering state
class _PonderingDot extends StatefulWidget {
  final Color color;
  final int delay;

  const _PonderingDot({required this.color, required this.delay});

  @override
  State<_PonderingDot> createState() => _PonderingDotState();
}

class _PonderingDotState extends State<_PonderingDot>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _animation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(milliseconds: 500),
      vsync: this,
    );

    // Subtle bouncy effect - reduced vertical movement
    _animation = Tween<double>(
      begin: 0,
      end: -3,
    ).animate(CurvedAnimation(
      parent: _controller,
      curve: const Cubic(0.68, -0.55, 0.27, 1.55),
    ));

    Future.delayed(Duration(milliseconds: widget.delay), () {
      if (mounted) {
        _controller.repeat(reverse: true);
      }
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _animation,
      builder: (context, child) {
        return Transform.translate(
          offset: Offset(0, _animation.value),
          child: Container(
            width: 4,
            height: 4,
            decoration: BoxDecoration(
              color: widget.color,
              shape: BoxShape.circle,
            ),
          ),
        );
      },
    );
  }
}
