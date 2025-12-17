import 'package:flutter/material.dart';

/// Animated star border - glow sweeps back and forth
class AnimatedStarBorder extends StatefulWidget {
  final Widget child;
  final Color color;
  final Duration speed;
  final double borderRadius;

  const AnimatedStarBorder({
    super.key,
    required this.child,
    this.color = const Color(0xFFFFFFFF),
    this.speed = const Duration(seconds: 8),
    this.borderRadius = 12,
  });

  @override
  State<AnimatedStarBorder> createState() => _AnimatedStarBorderState();
}

class _AnimatedStarBorderState extends State<AnimatedStarBorder>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: widget.speed,
      vsync: this,
    );

    // Start animation and add listener for pause between cycles
    _controller.addStatusListener(_onAnimationStatus);
    _controller.forward();
  }

  void _onAnimationStatus(AnimationStatus status) {
    if (status == AnimationStatus.completed) {
      // Pause for 3 seconds before restarting
      Future.delayed(const Duration(seconds: 3), () {
        if (mounted) {
          _controller.reset();
          _controller.forward();
        }
      });
    }
  }

  @override
  void dispose() {
    _controller.removeStatusListener(_onAnimationStatus);
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(widget.borderRadius),
      child: Stack(
        children: [
          // Child content
          widget.child,

          // Animated glow overlay
          Positioned.fill(
            child: IgnorePointer(
              child: AnimatedBuilder(
                animation: _controller,
                builder: (context, _) {
                  return CustomPaint(
                    painter: _StarGlowPainter(
                      progress: _controller.value,
                      color: widget.color,
                    ),
                  );
                },
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _StarGlowPainter extends CustomPainter {
  final double progress;
  final Color color;

  _StarGlowPainter({required this.progress, required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final glowRadius = 60.0;
    final opacity = 0.7 * (1 - progress * 0.3); // Subtle fade

    // Extended range so glow enters and exits beyond the edges
    final totalWidth = size.width + glowRadius * 2;

    // Bottom glow - moves right to left
    // Starts from right (outside) and exits left (outside)
    final bottomX = (size.width + glowRadius) - (totalWidth * progress);
    final bottomCenter = Offset(bottomX, size.height + 35); // 35px below bottom

    final bottomPaint = Paint()
      ..shader = RadialGradient(
        colors: [
          color.withOpacity(opacity),
          color.withOpacity(opacity * 0.4),
          color.withOpacity(0),
        ],
        stops: const [0.0, 0.4, 1.0],
      ).createShader(Rect.fromCircle(center: bottomCenter, radius: glowRadius));

    canvas.drawCircle(bottomCenter, glowRadius, bottomPaint);

    // Top glow - moves left to right
    // Starts from left (outside) and exits right (outside)
    final topX = -glowRadius + (totalWidth * progress);
    final topCenter = Offset(topX, -40); // 40px above top

    final topPaint = Paint()
      ..shader = RadialGradient(
        colors: [
          color.withOpacity(opacity),
          color.withOpacity(opacity * 0.4),
          color.withOpacity(0),
        ],
        stops: const [0.0, 0.4, 1.0],
      ).createShader(Rect.fromCircle(center: topCenter, radius: glowRadius));

    canvas.drawCircle(topCenter, glowRadius, topPaint);
  }

  @override
  bool shouldRepaint(_StarGlowPainter oldDelegate) {
    return oldDelegate.progress != progress;
  }
}
