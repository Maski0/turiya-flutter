import 'dart:ui';
import 'package:flutter/material.dart';
import 'icons/mic_icon.dart';
import 'icons/send_icon.dart';
import 'icons/check_icon.dart';
import 'icons/voice_mode_icon.dart';
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
  final bool enabled;
  // LiveKit voice mode
  final bool isLiveKitConnected;
  final bool isLiveKitConnecting;
  final VoidCallback? onVoiceCallTap;
  final VoidCallback? onDisconnectLiveKit;
  final VoidCallback? onSettingsTap;
  final bool isMicMuted;
  final VoidCallback? onMicToggle;
  // Chat button
  final bool showChatButton;
  final VoidCallback? onChatButtonTap;
  // Hide pondering chip (when chat sidebar is open)
  final bool hidePonderingChip;

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
    this.enabled = true,
    this.isLiveKitConnected = false,
    this.isLiveKitConnecting = false,
    this.onVoiceCallTap,
    this.onDisconnectLiveKit,
    this.onSettingsTap,
    this.isMicMuted = false,
    this.onMicToggle,
    this.showChatButton = false,
    this.onChatButtonTap,
    this.hidePonderingChip = false,
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
          // Hidden when chat sidebar is open (it has its own indicator)
          if (widget.isGenerating &&
              !widget.isAudioPlaying &&
              !widget.hidePonderingChip)
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

          // Voice Mode UI - 3 buttons when LiveKit connected
          if (widget.isLiveKitConnected || widget.isLiveKitConnecting)
            _buildVoiceModeUI()
          else
            _buildChatInputUI(),
        ],
      ),
    );
  }

  /// Voice Mode UI - 3 centered buttons (Mic Toggle, Cancel, Settings)
  Widget _buildVoiceModeUI() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          // Mic Toggle button
          Tooltip(
            message: widget.isMicMuted ? 'Unmute Mic' : 'Mute Mic',
            child: GestureDetector(
              onTap: widget.onMicToggle,
              child: ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: BackdropFilter(
                  filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
                  child: Container(
                    height: 48,
                    width: 48,
                    decoration: BoxDecoration(
                      color: widget.isMicMuted
                          ? const Color(0x40FFFFFF)
                          : const Color(0x28FFFFFF),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: const Color(0x40FFFFFF),
                        width: 0.5,
                      ),
                    ),
                    child: Center(
                      child: Icon(
                        widget.isMicMuted ? Icons.mic_off : Icons.mic,
                        color: Colors.white,
                        size: 20,
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(width: 16),

          // Cancel/Disconnect button
          Tooltip(
            message:
                widget.isLiveKitConnecting ? 'Connecting...' : 'Disconnect',
            child: GestureDetector(
              onTap: widget.onDisconnectLiveKit,
              child: ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: BackdropFilter(
                  filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
                  child: Container(
                    height: 48,
                    width: 48,
                    decoration: BoxDecoration(
                      color: const Color(0x28FFFFFF),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: const Color(0x40FFFFFF),
                        width: 0.5,
                      ),
                    ),
                    child: Center(
                      child: widget.isLiveKitConnecting
                          ? const SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                valueColor:
                                    AlwaysStoppedAnimation<Color>(Colors.white),
                              ),
                            )
                          : const Icon(
                              Icons.close,
                              color: Colors.white,
                              size: 20,
                            ),
                    ),
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(width: 16),

          // Settings button
          Tooltip(
            message: 'Settings',
            child: GestureDetector(
              onTap: widget.onSettingsTap,
              child: ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: BackdropFilter(
                  filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
                  child: Container(
                    height: 48,
                    width: 48,
                    decoration: BoxDecoration(
                      color: const Color(0x28FFFFFF),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: const Color(0x40FFFFFF),
                        width: 0.5,
                      ),
                    ),
                    child: const Center(
                      child: Icon(
                        Icons.settings_outlined,
                        color: Colors.white,
                        size: 20,
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// Chat Input UI - text input with mic + send, and Voice Call button
  Widget _buildChatInputUI() {
    // Determine which buttons to show
    final bool showChatIcon = widget.showChatButton &&
        (widget.textController.text.trim().isEmpty ||
            widget.isGenerating ||
            widget.isAudioPlaying);

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 4),
      child: Row(
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
          // Input container - expands to fill available space
        Expanded(
            child: ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: BackdropFilter(
                filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
                child: Container(
                  height: 48,
                  decoration: BoxDecoration(
                    color: const Color(0x28FFFFFF),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: const Color(0x40FFFFFF),
                      width: 0.5,
                    ),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.only(
                      left: 14,
                      top: 4,
                      right: 6,
                      bottom: 4,
                    ),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        // Text input field
                        Expanded(
                          child: TextField(
                            controller: widget.textController,
                            focusNode: widget.focusNode,
                            enabled: widget.enabled,
                            readOnly:
                                widget.isGenerating || widget.isAudioPlaying,
                            maxLines: null,
                            style: const TextStyle(
                              fontFamily: 'Alegreya',
                              fontSize: 15,
                              fontWeight: FontWeight.w500,
                              color: Colors.white,
                              height: 1.25,
                            ),
                            decoration: InputDecoration(
                              hintText: widget.isGenerating
                                  ? 'Pondering...'
                                  : 'Ask what your heart seeks',
                              hintMaxLines: 1,
                              hintStyle: TextStyle(
                                fontFamily: 'Alegreya',
                                fontSize: 15,
                                fontWeight: FontWeight.w500,
                                color: Colors.white.withOpacity(0.5),
                                height: 1.25,
                                overflow: TextOverflow.ellipsis,
                              ),
                              border: InputBorder.none,
                              contentPadding: EdgeInsets.zero,
                              isDense: true,
                            ),
                            onSubmitted: widget.onSubmit,
                          ),
                        ),

                        // Mic button - for STT (speech to text)
                        GestureDetector(
                          onTap: (widget.isGenerating || widget.isAudioPlaying)
                              ? null
                              : widget.onMicTap,
                          onLongPress:
                              (widget.isGenerating || widget.isAudioPlaying)
                                  ? null
                                  : widget.onMicLongPress,
                          child: Opacity(
                            opacity:
                                (widget.isGenerating || widget.isAudioPlaying)
                                    ? 0.3
                                    : 1.0,
                            child: Container(
                              padding: const EdgeInsets.all(4),
                              decoration: BoxDecoration(
                                color: widget.isRecording
                                    ? Colors.white.withOpacity(0.1)
                                    : Colors.transparent,
                                borderRadius: BorderRadius.circular(16),
                              ),
                              child: widget.isRecording
                                  ? const Icon(Icons.close,
                                      color: Colors.white, size: 20)
                                  : const MicIcon(size: 22),
                            ),
                          ),
                        ),

                        // Right button - dynamic based on state
                        if (widget.isRecording)
                          // Recording: show check to submit
                          GestureDetector(
                            onTap: () =>
                                widget.onSubmit(widget.textController.text),
                            child: Container(
                              margin: const EdgeInsets.only(left: 4),
                              padding: const EdgeInsets.all(4),
                              decoration: BoxDecoration(
                                color: Colors.transparent,
                                borderRadius: BorderRadius.circular(16),
                              ),
                              child: const CheckIcon(size: 20),
                            ),
                          )
                        else if (widget.isAudioPlaying &&
                            widget.onStopAudio != null)
                          // Playing audio: show stop button
                          GestureDetector(
                            onTap: widget.onStopAudio,
                            child: Container(
                              width: 32,
                              height: 32,
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
                                  size: 24,
                                ),
                              ),
                            ),
                          )
                        else
                          // Normal: show send button
                          Opacity(
                            opacity: widget.isGenerating ? 0.3 : 1.0,
                            child: GestureDetector(
                              onTap: (widget.isGenerating ||
                                      widget.textController.text.trim().isEmpty)
                                  ? null
                                  : () => widget
                                      .onSubmit(widget.textController.text),
                              child: Container(
                                margin: const EdgeInsets.only(left: 4),
                                padding: const EdgeInsets.all(4),
                                decoration: BoxDecoration(
                                  color: Colors.transparent,
                                  borderRadius: BorderRadius.circular(16),
                                ),
                                child: SendIcon(
                                  isActive: widget.textController.text
                                          .trim()
                                          .isNotEmpty &&
                                      !widget.isGenerating,
                                  size: 22,
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

          // Voice Call button - shows in different positions based on context
          // When showChatButton=true AND chat icon showing: Voice is first, Chat is second
          // When showChatButton=false OR chat icon hidden: Voice takes the rightmost slot
          if (widget.showChatButton && showChatIcon) ...[
            // Main screen with chat icon: Voice button first
            Padding(
              padding: const EdgeInsets.only(left: 10),
              child: _buildVoiceCallButton(),
            ),
            // Chat button second (rightmost)
            Padding(
              padding: const EdgeInsets.only(left: 10),
              child: GestureDetector(
                onTap: widget.onChatButtonTap,
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(12),
                  child: BackdropFilter(
                    filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
                    child: Container(
                      height: 48,
                      width: 48,
                      decoration: BoxDecoration(
                        color: const Color(0x28FFFFFF),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: const Color(0x40FFFFFF),
                          width: 0.5,
                        ),
                      ),
                      child: const Center(
                        child: TextChatIcon(size: 18),
                  ),
                ),
              ),
            ),
          ),
        ),
          ] else ...[
            // Chat sidebar OR main screen without chat icon: Voice takes rightmost position
        Padding(
          padding: const EdgeInsets.only(left: 10),
              child: _buildVoiceCallButton(),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildVoiceCallButton() {
    return AnimatedStarBorder(
            color: const Color(0x99FFFFFF),
            speed: const Duration(seconds: 8),
            child: Tooltip(
              message: 'Voice Call',
              child: GestureDetector(
                onTap: widget.onVoiceCallTap,
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(12),
                  child: BackdropFilter(
                    filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
                    child: Container(
                      height: 48,
                      width: 48,
                      decoration: BoxDecoration(
                        color: const Color(0x28FFFFFF),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: const Color(0x40FFFFFF),
                          width: 0.5,
                        ),
                      ),
                      child: const Center(
                        child: VoiceModeIcon(size: 20),
                      ),
                    ),
                  ),
                ),
              ),
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
