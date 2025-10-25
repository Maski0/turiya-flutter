import 'package:flutter/material.dart';

// Glass Button Widget
class GlassButton extends StatelessWidget {
  final VoidCallback onTap;
  final Widget child;

  const GlassButton({
    super.key,
    required this.onTap,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: CustomPaint(
        painter: _GradientBorderPainter(),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          child: child,
        ),
      ),
    );
  }
}

// Custom painter for gradient border
class _GradientBorderPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final rect = Rect.fromLTWH(0, 0, size.width, size.height);
    final rrect = RRect.fromRectAndRadius(rect, const Radius.circular(12));
    
    final gradient = LinearGradient(
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
      colors: [
        Colors.white.withOpacity(0.6),
        Colors.white.withOpacity(0.2),
        Colors.white.withOpacity(0.2),
        Colors.white.withOpacity(0.6),
      ],
      stops: const [0.0, 0.3, 0.7, 1.0],
    );
    
    final paint = Paint()
      ..shader = gradient.createShader(rect)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 0.8;
    
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

