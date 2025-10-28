import 'dart:ui';
import 'package:flutter/material.dart';
import 'animated_dots.dart';

class BottomInputBar extends StatelessWidget {
  final TextEditingController textController;
  final FocusNode? focusNode;
  final bool isGenerating;
  final bool isRecording;
  final Function(String) onSubmit;
  final VoidCallback onMicTap;
  final VoidCallback? onMicLongPress;

  const BottomInputBar({
    super.key,
    required this.textController,
    this.focusNode,
    required this.isGenerating,
    this.isRecording = false,
    required this.onSubmit,
    required this.onMicTap,
    this.onMicLongPress,
  });

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      painter: _BottomBarGradientBorderPainter(),
      child: ClipRRect(
        borderRadius: const BorderRadius.only(
          topLeft: Radius.circular(24),
          topRight: Radius.circular(24),
        ),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 15, sigmaY: 15),
          child: Container(
            padding: const EdgeInsets.fromLTRB(24, 18, 16, 18),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.12),
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(24),
                topRight: Radius.circular(24),
              ),
            ),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: textController,
                    focusNode: focusNode,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 16,
                      fontWeight: FontWeight.w400,
                    ),
                    decoration: const InputDecoration(
                      hintText: 'Ask what your heart seeks',
                      hintStyle: TextStyle(
                        color: Colors.white54,
                        fontSize: 16,
                        fontWeight: FontWeight.w300,
                      ),
                      border: InputBorder.none,
                      contentPadding: EdgeInsets.zero,
                      isDense: true,
                    ),
                    onSubmitted: onSubmit,
                  ),
                ),
                const SizedBox(width: 16),
                // Mic button (with recording indicator)
                GestureDetector(
                  onTap: onMicTap,
                  onLongPress: onMicLongPress,
                  child: Stack(
                    alignment: Alignment.center,
                    children: [
                      // Pulsing circle when recording
                      if (isRecording)
                        Container(
                          width: 32,
                          height: 32,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: Colors.red.withOpacity(0.3),
                          ),
                        ),
                      // Mic icon
                      Padding(
                        padding: const EdgeInsets.all(4),
                        child: Icon(
                          isRecording ? Icons.mic : Icons.mic_none,
                          color: isRecording 
                              ? Colors.red 
                              : Colors.white.withOpacity(0.8),
                          size: 24,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 12),
                // Send button (arrow) - disabled when recording
                GestureDetector(
                  onTap: (isGenerating || isRecording) 
                      ? null 
                      : () => onSubmit(textController.text),
                  child: Padding(
                    padding: const EdgeInsets.all(4),
                    child: isGenerating
                        ? AnimatedDots(
                            color: Colors.white.withOpacity(0.8),
                            size: 4.0,
                          )
                        : Icon(
                            Icons.arrow_forward,
                            color: (isRecording)
                                ? Colors.white.withOpacity(0.3)
                                : Colors.white.withOpacity(0.8),
                            size: 24,
                          ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// Custom painter for bottom bar gradient border (top-rounded)
class _BottomBarGradientBorderPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final rect = Rect.fromLTWH(0, 0, size.width, size.height);
    final rrect = RRect.fromRectAndCorners(
      rect,
      topLeft: const Radius.circular(24),
      topRight: const Radius.circular(24),
    );
    
    final gradient = LinearGradient(
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
      colors: [
        Colors.white.withOpacity(0.2),
        Colors.white.withOpacity(0.7),
        Colors.white.withOpacity(0.7),
        Colors.white.withOpacity(0.2),
      ],
      stops: const [0.0, 0.3, 0.7, 1.0],
    );
    
    final paint = Paint()
      ..shader = gradient.createShader(rect)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 0.5;
    
    // Add subtle glow
    final glowPaint = Paint()
      ..color = Colors.white.withOpacity(0.04)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 4
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 4);
    
    canvas.drawRRect(rrect, glowPaint);
    canvas.drawRRect(rrect, paint);
  }
  
  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

