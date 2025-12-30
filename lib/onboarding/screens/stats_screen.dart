import 'package:flutter/material.dart';
import 'dart:math' as math;
import '../theme/onboarding_theme.dart';
import '../widgets/onboarding_scaffold.dart';
import '../widgets/onboarding_button.dart';

/// Screen 411: Stats screen showing "Your Inner Stillness" graph
class StatsScreen extends StatelessWidget {
  final VoidCallback onNext;
  
  const StatsScreen({
    super.key,
    required this.onNext,
  });
  
  @override
  Widget build(BuildContext context) {
    // Return content only - wrapper handles scaffold
    return Column(
        children: [
          const SizedBox(height: 40),
          // Title
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 32),
            child: Text(
              'Your Inner Stillness',
              style: OnboardingTheme.displayXL.copyWith(fontSize: 36),
              textAlign: TextAlign.center,
            ),
          ),
          const Spacer(),
          // Graph
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            child: SizedBox(
              height: 260,
              child: CustomPaint(
                painter: StillnessGraphPainter(),
                size: const Size(double.infinity, 260),
              ),
            ),
          ),
          const SizedBox(height: 60),
          // Stats text
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 40),
            child: RichText(
              textAlign: TextAlign.center,
              text: TextSpan(
                style: OnboardingTheme.bodyMedium.copyWith(
                  fontSize: 14,
                  height: 1.4,
                ),
                children: [
                  const TextSpan(text: 'Regular seekers find '),
                  TextSpan(
                    text: '4×',
                    style: OnboardingTheme.bodyMedium.copyWith(
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const TextSpan(text: ' more peace within weeks of consistent reflection.'),
                ],
              ),
            ),
          ),
          const Spacer(),
          // Continue button
          OnboardingButton(
            text: 'Continue',
            onPressed: onNext,
          ),
        ],
    );
  }
}

/// Custom painter for the stillness growth graph
class StillnessGraphPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2;

    // Draw grid lines (horizontal dotted lines)
    final gridPaint = Paint()
      ..color = OnboardingTheme.textPrimary.withOpacity(0.15)
      ..strokeWidth = 1
      ..style = PaintingStyle.stroke;

    for (int i = 0; i <= 4; i++) {
      final y = size.height * 0.15 + (i * (size.height * 0.7 / 4));
      _drawDashedLine(
        canvas,
        Offset(0, y),
        Offset(size.width, y),
        gridPaint,
      );
    }

    // Draw "with Turiya" curve (white, exponential growth)
    final turiyaPath = Path();
    turiyaPath.moveTo(0, size.height * 0.85);
    
    for (double x = 0; x <= size.width; x += 1) {
      final progress = x / size.width;
      // Exponential growth curve
      final y = size.height * 0.85 - (size.height * 0.7 * math.pow(progress, 1.5));
      if (x == 0) {
        turiyaPath.moveTo(x, y);
      } else {
        turiyaPath.lineTo(x, y);
      }
    }
    
    paint.color = OnboardingTheme.textPrimary;
    paint.strokeWidth = 2.5;
    canvas.drawPath(turiyaPath, paint);

    // Draw start dot for Turiya line
    canvas.drawCircle(
      Offset(0, size.height * 0.85),
      6,
      Paint()
        ..color = OnboardingTheme.textPrimary
        ..style = PaintingStyle.fill,
    );

    // Draw end dot for Turiya line
    canvas.drawCircle(
      Offset(size.width, size.height * 0.15),
      6,
      Paint()
        ..color = OnboardingTheme.textPrimary
        ..style = PaintingStyle.fill,
    );

    // Draw "with Turiya" label
    final turiyaTextPainter = TextPainter(
      text: TextSpan(
        children: [
          TextSpan(
            text: 'with ',
            style: TextStyle(
              color: OnboardingTheme.textPrimary.withOpacity(0.8),
              fontSize: 12,
              fontFamily: 'Alegreya',
            ),
          ),
          TextSpan(
            text: 'Turīya',
            style: TextStyle(
              color: OnboardingTheme.textPrimary.withOpacity(0.8),
              fontSize: 12,
              fontFamily: 'Alegreya',
              fontStyle: FontStyle.italic,
            ),
          ),
        ],
      ),
      textDirection: TextDirection.ltr,
    );
    turiyaTextPainter.layout();
    turiyaTextPainter.paint(
      canvas,
      Offset(size.width - turiyaTextPainter.width - 20, size.height * 0.2),
    );

    // Draw "no practice" curve (red, slight decline)
    final noPracticePath = Path();
    for (double x = 0; x <= size.width; x += 1) {
      final progress = x / size.width;
      // Slight decline with plateau
      final y = size.height * 0.7 + (size.height * 0.1 * math.pow(progress, 1.2));
      if (x == 0) {
        noPracticePath.moveTo(x, y);
      } else {
        noPracticePath.lineTo(x, y);
      }
    }
    
    paint.color = const Color(0xFFE74C3C); // Red color
    paint.strokeWidth = 2.5;
    canvas.drawPath(noPracticePath, paint);

    // Draw "no practice" label
    final noPracticeTextPainter = TextPainter(
      text: TextSpan(
        text: 'no practice',
        style: TextStyle(
          color: const Color(0xFFE74C3C).withOpacity(0.9),
          fontSize: 12,
          fontFamily: 'Alegreya',
        ),
      ),
      textDirection: TextDirection.ltr,
    );
    noPracticeTextPainter.layout();
    noPracticeTextPainter.paint(
      canvas,
      Offset(size.width - noPracticeTextPainter.width - 20, size.height * 0.72),
    );

    // Draw x-axis labels
    final month1TextPainter = TextPainter(
      text: TextSpan(
        text: 'Month 1',
        style: TextStyle(
          color: OnboardingTheme.textPrimary.withOpacity(0.6),
          fontSize: 12,
          fontFamily: 'Alegreya',
        ),
      ),
      textDirection: TextDirection.ltr,
    );
    month1TextPainter.layout();
    month1TextPainter.paint(canvas, Offset(0, size.height * 0.92));

    final month3TextPainter = TextPainter(
      text: TextSpan(
        text: 'Month 3',
        style: TextStyle(
          color: OnboardingTheme.textPrimary.withOpacity(0.6),
          fontSize: 12,
          fontFamily: 'Alegreya',
        ),
      ),
      textDirection: TextDirection.ltr,
    );
    month3TextPainter.layout();
    month3TextPainter.paint(
      canvas,
      Offset(size.width - month3TextPainter.width, size.height * 0.92),
    );
  }

  void _drawDashedLine(Canvas canvas, Offset start, Offset end, Paint paint) {
    const dashWidth = 5.0;
    const dashSpace = 5.0;
    double distance = (end - start).distance;
    double totalDash = dashWidth + dashSpace;
    int dashCount = (distance / totalDash).floor();
    
    for (int i = 0; i < dashCount; i++) {
      double startX = start.dx + (totalDash * i);
      double startY = start.dy + ((end.dy - start.dy) / distance) * (totalDash * i);
      double endX = startX + dashWidth;
      double endY = startY + ((end.dy - start.dy) / distance) * dashWidth;
      
      canvas.drawLine(
        Offset(startX, startY),
        Offset(endX, endY),
        paint,
      );
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

