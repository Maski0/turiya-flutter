import 'dart:ui';
import 'package:flutter/material.dart';
import 'animated_dots.dart';
import '../theme/app_theme.dart';

class BottomInputBar extends StatefulWidget {
  final TextEditingController textController;
  final FocusNode? focusNode;
  final bool isGenerating;
  final bool isRecording;
  final bool isAudioPlaying;
  final Function(String) onSubmit;
  final VoidCallback onMicTap;
  final VoidCallback? onMicLongPress;

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
  });

  @override
  State<BottomInputBar> createState() => _BottomInputBarState();
}

class _BottomInputBarState extends State<BottomInputBar>
    with TickerProviderStateMixin {
  late AnimationController _glowController;
  late Animation<double> _glowAnimation;
  late AnimationController _textFadeController;
  late Animation<double> _textFadeAnimation;

  String _previousHintText = 'Ask what your heart seeks';

  @override
  void initState() {
    super.initState();
    _glowController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2000), // 2s pulse cycle
    )..repeat(reverse: true);

    _glowAnimation = Tween<double>(begin: 0.2, end: 0.8).animate(
      CurvedAnimation(parent: _glowController, curve: Curves.easeInOut),
    );

    // Text fade controller for smooth hint text transitions
    _textFadeController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 300),
      value: 1.0,
    );

    _textFadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _textFadeController, curve: Curves.easeInOut),
    );
  }

  @override
  void didUpdateWidget(BottomInputBar oldWidget) {
    super.didUpdateWidget(oldWidget);
    // Detect hint text changes and animate
    final oldHint = oldWidget.isGenerating
        ? 'Pondering...'
        : oldWidget.isAudioPlaying
            ? 'Narrating...'
            : 'Ask what your heart seeks';
    final newHint = widget.isGenerating
        ? 'Pondering...'
        : widget.isAudioPlaying
            ? 'Narrating...'
            : 'Ask what your heart seeks';

    if (oldHint != newHint) {
      // Fade out, change text, fade in
      _textFadeController.reverse().then((_) {
        if (mounted) {
          setState(() {
            _previousHintText = newHint;
          });
          _textFadeController.forward();
        }
      });
    }
  }

  @override
  void dispose() {
    _glowController.dispose();
    _textFadeController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final bool isActive = widget.isGenerating || widget.isAudioPlaying;

    return AnimatedBuilder(
      animation: _glowAnimation,
      builder: (context, child) {
        return CustomPaint(
          painter: _BottomBarGradientBorderPainter(
            glowIntensity: isActive ? _glowAnimation.value : 0.0,
          ),
          child: ClipRRect(
            borderRadius: const BorderRadius.only(
              topLeft: Radius.circular(26),
              topRight: Radius.circular(26),
            ),
            child: BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 15, sigmaY: 15),
              child: Container(
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.11),
                  borderRadius: const BorderRadius.only(
                    topLeft: Radius.circular(26),
                    topRight: Radius.circular(26),
                  ),
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Padding(
                      padding: const EdgeInsets.fromLTRB(24, 24, 18, 24),
                      child: Row(
                        children: [
                          Expanded(
                            child: AnimatedBuilder(
                              animation: _textFadeAnimation,
                              builder: (context, child) {
                                return TextField(
                                  controller: widget.textController,
                                  focusNode: widget.focusNode,
                                  readOnly: widget.isGenerating ||
                                      widget.isAudioPlaying,
                                  style: AppTheme.body(context, height: 1.4),
                                  decoration: InputDecoration(
                                    hintText: _previousHintText,
                                    hintStyle: Theme.of(context)
                                        .textTheme
                                        .bodyLarge
                                        ?.copyWith(
                                          color: Colors.white54.withOpacity(
                                              _textFadeAnimation.value * 0.50),
                                          fontWeight: FontWeight.w300,
                                          fontStyle: (widget.isGenerating ||
                                                  widget.isAudioPlaying)
                                              ? FontStyle.italic
                                              : FontStyle.normal,
                                          letterSpacing: 0.2,
                                        ),
                                    border: InputBorder.none,
                                    contentPadding: EdgeInsets.zero,
                                    isDense: true,
                                  ),
                                  onSubmitted: widget.onSubmit,
                                );
                              },
                            ),
                          ),
                          const SizedBox(width: 16),
                          // Mic button (with recording indicator) - hidden when generating or narrating
                          // Keep the space even when hidden to maintain consistent height
                          SizedBox(
                            width:
                                (!widget.isGenerating && !widget.isAudioPlaying)
                                    ? 32
                                    : 0,
                            height: 32,
                            child: (!widget.isGenerating &&
                                    !widget.isAudioPlaying)
                                ? GestureDetector(
                                    onTap: widget.onMicTap,
                                    onLongPress: widget.onMicLongPress,
                                    child: Stack(
                                      alignment: Alignment.center,
                                      children: [
                                        // Pulsing circle when recording
                                        if (widget.isRecording)
                                          Container(
                                            width: 32,
                                            height: 32,
                                            decoration: BoxDecoration(
                                              shape: BoxShape.circle,
                                              color:
                                                  Colors.red.withOpacity(0.3),
                                            ),
                                          ),
                                        // Mic icon
                                        Padding(
                                          padding: const EdgeInsets.all(4),
                                          child: Icon(
                                            widget.isRecording
                                                ? Icons.mic
                                                : Icons.mic_none,
                                            color: widget.isRecording
                                                ? Colors.red
                                                : Colors.white.withOpacity(0.8),
                                            size: 24,
                                          ),
                                        ),
                                      ],
                                    ),
                                  )
                                : null,
                          ),
                          SizedBox(
                              width: (!widget.isGenerating &&
                                      !widget.isAudioPlaying)
                                  ? 12
                                  : 0),
                          // Send button (arrow) - disabled when recording
                          GestureDetector(
                            onTap: (widget.isGenerating ||
                                    widget.isRecording ||
                                    widget.isAudioPlaying)
                                ? null
                                : () =>
                                    widget.onSubmit(widget.textController.text),
                            child: Padding(
                              padding: const EdgeInsets.all(4),
                              child: SizedBox(
                                width: 24,
                                height: 24,
                                child: (widget.isGenerating ||
                                        widget.isAudioPlaying)
                                    ? Center(
                                        child: AnimatedDots(
                                          size: 4.0,
                                          isNarrating: widget.isAudioPlaying,
                                        ),
                                      )
                                    : Icon(
                                        Icons.arrow_forward,
                                        color: (widget.isRecording)
                                            ? Colors.white.withOpacity(0.3)
                                            : Colors.white.withOpacity(0.8),
                                        size: 24,
                                      ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}

// Custom painter for bottom bar gradient border (top-rounded) with glow effect
class _BottomBarGradientBorderPainter extends CustomPainter {
  final double glowIntensity; // 0.0 to 1.0

  _BottomBarGradientBorderPainter({this.glowIntensity = 0.0});

  @override
  void paint(Canvas canvas, Size size) {
    final rect = Rect.fromLTWH(0, 0, size.width, size.height);
    final rrect = RRect.fromRectAndCorners(
      rect,
      topLeft: const Radius.circular(26),
      topRight: const Radius.circular(26),
    );

    final gradient = LinearGradient(
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
      colors: [
        Colors.white.withOpacity(0.18),
        Colors.white.withOpacity(0.65),
        Colors.white.withOpacity(0.65),
        Colors.white.withOpacity(0.18),
      ],
      stops: const [0.0, 0.32, 0.68, 1.0],
    );

    final paint = Paint()
      ..shader = gradient.createShader(rect)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 0.6;

    // Add subtle glow
    final baseGlowPaint = Paint()
      ..color = Colors.white.withOpacity(0.04)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 4
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 4);

    canvas.drawRRect(rrect, baseGlowPaint);
    canvas.drawRRect(rrect, paint);

    // Add pulsing glow effect when active (thinking/narrating)
    if (glowIntensity > 0) {
      // Full border glow
      final pulseGlowPaint = Paint()
        ..color = Colors.white.withOpacity(0.3 * glowIntensity)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 6 + (4 * glowIntensity) // Pulse from 6 to 10
        ..maskFilter = MaskFilter.blur(BlurStyle.normal,
            8 + (8 * glowIntensity)); // Pulse blur from 8 to 16

      canvas.drawRRect(rrect, pulseGlowPaint);

      // Concentrated white glow at the center top
      final centerGlowPaint = Paint()
        ..shader = RadialGradient(
          center: Alignment.topCenter,
          radius: 0.8,
          colors: [
            Colors.white
                .withOpacity(0.6 * glowIntensity), // Bright white center
            Colors.white.withOpacity(0.3 * glowIntensity),
            Colors.white.withOpacity(0.0),
          ],
          stops: const [0.0, 0.4, 1.0],
        ).createShader(Rect.fromLTWH(0, 0, size.width, 40))
        ..style = PaintingStyle.fill
        ..maskFilter =
            MaskFilter.blur(BlurStyle.normal, 12 + (12 * glowIntensity));

      // Draw the concentrated glow only at the top
      final glowPath = Path()
        ..moveTo(0, 24)
        ..lineTo(0, 0)
        ..lineTo(size.width, 0)
        ..lineTo(size.width, 24)
        ..quadraticBezierTo(size.width / 2, -10, 0, 24);

      canvas.drawPath(glowPath, centerGlowPaint);
    }
  }

  @override
  bool shouldRepaint(covariant _BottomBarGradientBorderPainter oldDelegate) {
    return oldDelegate.glowIntensity != glowIntensity;
  }
}
