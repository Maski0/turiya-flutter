import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import '../theme/app_theme.dart';
import 'package:flutter_liquid_glass_plus/flutter_liquid_glass.dart';
import 'star_border.dart';

const _blackGlassSettings = LiquidGlassSettings(
  thickness: 15,
  blur: 16,
  refractiveIndex: 1.7,
  chromaticAberration: 0.002,
  lightIntensity: 0.08,
  glassColor: Color.fromARGB(55, 0, 0, 0),
  saturation: 0.7,
);

class HomeBottomSection extends StatefulWidget {
  final TextEditingController textController;
  final FocusNode? focusNode;
  final bool isGenerating;
  final bool isRecording;
  final bool isAudioPlaying;
  final Function(String) onSubmit;
  final VoidCallback onMicTap;
  final VoidCallback? onMicLongPress;
  final VoidCallback? onRecordingSubmit;
  final VoidCallback? onStopAudio;
  final bool enabled;
  final bool isLiveKitConnected;
  final bool isLiveKitConnecting;
  final VoidCallback? onVoiceCallTap;
  final VoidCallback? onDisconnectLiveKit;
  final VoidCallback? onSettingsTap;
  final bool isMicMuted;
  final VoidCallback? onMicToggle;
  final VoidCallback? onCameraTap;
  final Function(String) onSuggestionTap;
  final bool showSuggestions;
  final bool hidePonderingChip;

  const HomeBottomSection({
    super.key,
    required this.textController,
    this.focusNode,
    required this.isGenerating,
    this.isRecording = false,
    this.isAudioPlaying = false,
    required this.onSubmit,
    required this.onMicTap,
    this.onMicLongPress,
    this.onRecordingSubmit,
    this.onStopAudio,
    this.enabled = true,
    this.isLiveKitConnected = false,
    this.isLiveKitConnecting = false,
    this.onVoiceCallTap,
    this.onDisconnectLiveKit,
    this.onSettingsTap,
    this.isMicMuted = false,
    this.onMicToggle,
    this.onCameraTap,
    required this.onSuggestionTap,
    this.showSuggestions = true,
    this.hidePonderingChip = false,
  });

  @override
  State<HomeBottomSection> createState() => _HomeBottomSectionState();
}

class _HomeBottomSectionState extends State<HomeBottomSection> {
  static const _suggestions = [
    ['A short reflection', 'to start with clarity'],
    ['Guide me to focus', 'on what truly matters'],
    ['A brief thought', 'to quiet my mind'],
    ['Help me understand', 'my inner wisdom'],
    ['Show me the path', 'to inner peace'],
    ['What does my soul', 'truly seek today'],
    ['Guide my heart', 'to deeper understanding'],
  ];

  @override
  void initState() {
    super.initState();
    widget.textController.addListener(_onTextChanged);
  }

  @override
  void dispose() {
    widget.textController.removeListener(_onTextChanged);
    super.dispose();
  }

  void _onTextChanged() {
    final hadFocus = widget.focusNode?.hasFocus ?? false;
    setState(() {});
    if (hadFocus) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        widget.focusNode?.requestFocus();
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final isPondering = widget.isGenerating && !widget.isAudioPlaying;
    return SafeArea(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Old behavior parity: pondering chip above input (hidden when sidebar open).
          if (isPondering && !widget.hidePonderingChip)
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(16),
                child: LGContainer(
                  useOwnLayer: true,
                  quality: LGQuality.premium,
                  shape: const LiquidRoundedSuperellipse(borderRadius: 16),
                  settings: _blackGlassSettings,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: 8,
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        'Pondering',
                        style: AppTheme.bodyS(context).copyWith(
                          color: Colors.white.withOpacity(0.9),
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      const SizedBox(width: 6),
                      const _LoadingBeads(),
                    ],
                  ),
                ),
              ),
            ),

          // Suggestion chips - hide when typing, pondering, or on chat screen
          if (widget.showSuggestions &&
              !widget.isLiveKitConnected &&
              widget.textController.text.isEmpty &&
              !widget.isGenerating &&
              !widget.isAudioPlaying)
            Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                physics: const BouncingScrollPhysics(),
                child: IntrinsicHeight(
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const SizedBox(width: 8),
                      for (int i = 0; i < _suggestions.length; i++) ...[
                        if (i > 0) const SizedBox(width: 8),
                        _buildSuggestionChip(
                          _suggestions[i][0],
                          _suggestions[i][1],
                        ),
                      ],
                      const SizedBox(width: 8),
                    ],
                  ),
                ),
              ),
            ),

          // Input bar - key ensures Flutter preserves this element when suggestions disappear
          Padding(
            key: const ValueKey('input_bar'),
            padding: const EdgeInsets.symmetric(horizontal: 8),
            child: (widget.isLiveKitConnected || widget.isLiveKitConnecting)
                ? _buildVoiceModeUI()
                : _buildInputRow(),
          ),

          const SizedBox(height: 28),
        ],
      ),
    );
  }

  Widget _buildVoiceModeUI() {
    Widget buildButton({
      required Widget child,
      VoidCallback? onTap,
      String? tooltip,
    }) {
      final button = GestureDetector(
        onTap: onTap,
        child: LGContainer(
          useOwnLayer: true,
          quality: LGQuality.premium,
          shape: const LiquidRoundedSuperellipse(borderRadius: 12),
          settings: _blackGlassSettings,
          width: 48,
          height: 48,
          child: Center(child: child),
        ),
      );
      return tooltip == null ? button : Tooltip(message: tooltip, child: button);
    }

    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        buildButton(
          tooltip: widget.isMicMuted ? 'Unmute Mic' : 'Mute Mic',
          onTap: widget.onMicToggle,
          child: Icon(
            widget.isMicMuted ? Icons.mic_off : Icons.mic,
            color: Colors.white,
            size: 20,
          ),
        ),
        const SizedBox(width: 16),
        buildButton(
          tooltip: widget.isLiveKitConnecting ? 'Connecting...' : 'Disconnect',
          onTap: widget.onDisconnectLiveKit,
          child: widget.isLiveKitConnecting
              ? const SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                  ),
                )
              : const Icon(Icons.close, color: Colors.white, size: 20),
        ),
        const SizedBox(width: 16),
        buildButton(
          tooltip: 'Settings',
          onTap: widget.onSettingsTap,
          child: const Icon(Icons.settings_outlined,
              color: Colors.white, size: 20),
        ),
      ],
    );
  }

  Widget _buildSuggestionChip(String title, String subtitle) {
    return GestureDetector(
      onTap: () {
        final fullText = '$title $subtitle';
        widget.textController.text = fullText;
        widget.onSuggestionTap(fullText);
      },
      child: LGContainer(
        useOwnLayer: true,
        quality: LGQuality.premium,
        shape: const LiquidRoundedSuperellipse(borderRadius: 16),
        settings: _blackGlassSettings,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              title,
              style: AppTheme.bodyM(context).copyWith(
                color: Colors.white,
                fontWeight: FontWeight.w500,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              subtitle,
              style: AppTheme.bodyM(context).copyWith(
                color: Colors.white.withOpacity(0.5),
                fontWeight: FontWeight.w400,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildInputRow() {
    final bool disabled = widget.isGenerating || widget.isAudioPlaying;
    final bool hasText = widget.textController.text.isNotEmpty;
    final bool isPondering = widget.isGenerating && !widget.isAudioPlaying;

    return Row(
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        // Chat button (left) - hide when typing or pondering
        if (!widget.isLiveKitConnected && !hasText && !isPondering)
          Padding(
            padding: const EdgeInsets.only(right: 8),
            child: GestureDetector(
              onTap: widget.onCameraTap,
              child: LGContainer(
                useOwnLayer: true,
                quality: LGQuality.premium,
                shape: const LiquidRoundedSuperellipse(borderRadius: 24),
                settings: _blackGlassSettings,
                width: 56,
                height: 56,
                child: Center(
                  child: SvgPicture.asset(
                    'assets/icons/chat_bubble.svg',
                    width: 24,
                    height: 24,
                  ),
                ),
              ),
            ),
          ),

        // Main input field
        Expanded(
          key: const ValueKey('main_input'),
          child: ConstrainedBox(
            constraints: const BoxConstraints(minHeight: 56),
            child: LGContainer(
              useOwnLayer: true,
              quality: LGQuality.premium,
              shape: const LiquidRoundedSuperellipse(borderRadius: 24),
              settings: _blackGlassSettings,
              child: isPondering
                  ? _buildPonderingContent()
                  : widget.isAudioPlaying
                      ? _buildSpeakingContent()
                      : Row(
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: [
                            Expanded(
                              child: Padding(
                                padding: const EdgeInsets.only(left: 16),
                                child: TextField(
                                  controller: widget.textController,
                                  focusNode: widget.focusNode,
                                  enabled: widget.enabled,
                                  readOnly: disabled,
                                  maxLines: 5,
                                  minLines: 1,
                                  style: AppTheme.bodyM(context).copyWith(
                                    color: Colors.white,
                                  ),
                                  decoration: InputDecoration(
                                    hintText: 'Ask what your heart seeks',
                                    hintStyle: AppTheme.bodyM(context).copyWith(
                                      color: Colors.white.withOpacity(0.5),
                                    ),
                                    border: InputBorder.none,
                                    contentPadding: const EdgeInsets.symmetric(
                                        vertical: 16),
                                    isDense: true,
                                  ),
                                  onSubmitted: widget.onSubmit,
                                ),
                              ),
                            ),
                            Padding(
                              padding: const EdgeInsets.all(12),
                          child: widget.isRecording
                              ? _buildRecordingSubmitButton()
                              : hasText
                                  ? _buildSendButton()
                                  : _buildIdleButtons(disabled),
                            ),
                          ],
                        ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildRecordingSubmitButton() {
    return GestureDetector(
      onTap: widget.onRecordingSubmit ??
          () {
            final text = widget.textController.text.trim();
            if (text.isNotEmpty) widget.onSubmit(text);
          },
      child: Container(
        width: 32,
        height: 32,
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.15),
          borderRadius: BorderRadius.circular(12),
          boxShadow: [
            BoxShadow(
              color: const Color(0x14111111),
              offset: const Offset(0, 4),
              blurRadius: 16,
            ),
          ],
        ),
        child: Center(
          child: SvgPicture.asset(
            'assets/icons/check.svg',
            width: 18,
            height: 18,
            colorFilter: const ColorFilter.mode(Colors.white, BlendMode.srcIn),
          ),
        ),
      ),
    );
  }

  Widget _buildSpeakingContent() {
    return Row(
      children: [
        Expanded(
          child: Padding(
            padding: const EdgeInsets.only(left: 16),
            child: Row(
              children: [
                const _SpeakingBeads(),
                const SizedBox(width: 8),
                Text(
                  'Speaking',
                  style: AppTheme.bodyM(context).copyWith(
                    color: Colors.white,
                  ),
                ),
              ],
            ),
          ),
        ),
        Padding(
          padding: const EdgeInsets.all(12),
          child: _buildStopButton(),
        ),
      ],
    );
  }

  Widget _buildPonderingContent() {
    return Row(
      children: [
        Expanded(
          child: Padding(
            padding: const EdgeInsets.only(left: 16),
            child: Row(
              children: [
                const _LoadingBeads(),
                const SizedBox(width: 8),
                Text(
                  'Pondering',
                  style: AppTheme.bodyM(context).copyWith(
                    color: Colors.white,
                  ),
                ),
              ],
            ),
          ),
        ),
        Padding(
          padding: const EdgeInsets.all(12),
          child: _buildStopButton(),
        ),
      ],
    );
  }

  Widget _buildStopButton() {
    return GestureDetector(
      onTap: widget.onStopAudio,
      child: Container(
        width: 32,
        height: 32,
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.15),
          borderRadius: BorderRadius.circular(12),
          boxShadow: [
            BoxShadow(
              color: const Color(0x14111111),
              offset: const Offset(0, 4),
              blurRadius: 16,
            ),
          ],
        ),
        child: Center(
          child: Container(
            width: 12,
            height: 12,
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(3),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildSendButton() {
    return GestureDetector(
      onTap: () {
        final text = widget.textController.text.trim();
        if (text.isNotEmpty) widget.onSubmit(text);
      },
      child: Container(
        width: 32,
        height: 32,
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.15),
          borderRadius: BorderRadius.circular(12),
          boxShadow: [
            BoxShadow(
              color: const Color(0x14111111),
              offset: const Offset(0, 4),
              blurRadius: 16,
            ),
          ],
        ),
        child: Center(
          child: SvgPicture.asset(
            'assets/icons/send_arrow.svg',
            width: 14,
            height: 16,
          ),
        ),
      ),
    );
  }

  Widget _buildIdleButtons(bool disabled) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        GestureDetector(
          onTap: disabled ? null : widget.onMicTap,
          onLongPress: disabled ? null : widget.onMicLongPress,
          child: Opacity(
            opacity: disabled ? 0.3 : 1.0,
            child: widget.isRecording
                ? const Icon(Icons.stop, color: Colors.white, size: 24)
                : SvgPicture.asset(
                    'assets/icons/mic_outline.svg',
                    width: 24,
                    height: 24,
                  ),
          ),
        ),
        const SizedBox(width: 8),
        if (!widget.isLiveKitConnected)
          GestureDetector(
            onTap: widget.onVoiceCallTap,
            child: AnimatedStarBorder(
              color: const Color(0x99FFFFFF),
              speed: const Duration(seconds: 8),
              borderRadius: 12,
              child: Container(
                width: 32,
                height: 32,
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.15),
                  borderRadius: BorderRadius.circular(12),
                  boxShadow: [
                    BoxShadow(
                      color: const Color(0x14111111),
                      offset: const Offset(0, 4),
                      blurRadius: 16,
                    ),
                  ],
                ),
                child: Center(
                  child: SvgPicture.asset(
                    'assets/icons/waveform.svg',
                    width: 16,
                    height: 14,
                  ),
                ),
              ),
            ),
          ),
      ],
    );
  }
}

class _LoadingBeads extends StatefulWidget {
  const _LoadingBeads();

  @override
  State<_LoadingBeads> createState() => _LoadingBeadsState();
}

class _LoadingBeadsState extends State<_LoadingBeads>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  int _activeDot = 0;

  static const _dotColors = [
    Color(0xFFFF0000),
    Color(0xFFFFA569),
    Color(0xFFA7A6FB),
    Color(0xFF046E80),
  ];

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(milliseconds: 600),
      vsync: this,
    )..addStatusListener((status) {
        if (status == AnimationStatus.completed) {
          setState(() => _activeDot = (_activeDot + 1) % 4);
          _controller.forward(from: 0);
        }
      });
    _controller.forward();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, _) {
        return SizedBox(
          width: 32,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: List.generate(4, (i) {
              final isActive = i == _activeDot;
              final size = isActive ? 6.0 : 4.0;
              return AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                width: size,
                height: size,
                decoration: BoxDecoration(
                  color: _dotColors[i],
                  shape: BoxShape.circle,
                ),
              );
            }),
          ),
        );
      },
    );
  }
}

class _SpeakingBeads extends StatefulWidget {
  const _SpeakingBeads();

  @override
  State<_SpeakingBeads> createState() => _SpeakingBeadsState();
}

class _SpeakingBeadsState extends State<_SpeakingBeads>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;

  static const _barColors = [
    Color(0xFFFF0000),
    Color(0xFFFFA569),
    Color(0xFFA7A6FB),
    Color(0xFF046E80),
  ];

  static const _baseHeights = [8.0, 16.0, 8.0, 4.0];
  static const _barWidth = 4.0;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(milliseconds: 800),
      vsync: this,
    )..repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, _) {
        return SizedBox(
          width: 32,
          height: 22,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            crossAxisAlignment: CrossAxisAlignment.center,
            children: List.generate(4, (i) {
              final phase = (_controller.value + i * 0.25) % 1.0;
              final scale =
                  0.5 + 0.5 * (0.5 + 0.5 * (1.0 - (2.0 * (phase - 0.5)).abs()));
              final h = _baseHeights[i] * scale;
              return Container(
                width: _barWidth,
                height: h,
                decoration: BoxDecoration(
                  color: _barColors[i],
                  borderRadius: BorderRadius.circular(2),
                ),
              );
            }),
          ),
        );
      },
    );
  }
}
