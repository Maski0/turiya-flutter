import 'package:flutter/material.dart';

class AnimatedDots extends StatefulWidget {
  final Color color;
  final double size;

  const AnimatedDots({
    super.key,
    this.color = Colors.white,
    this.size = 4.0,
  });

  @override
  State<AnimatedDots> createState() => _AnimatedDotsState();
}

class _AnimatedDotsState extends State<AnimatedDots>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
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
      builder: (context, child) {
        return Row(
          mainAxisSize: MainAxisSize.min,
          children: List.generate(3, (index) {
            final delay = index * 0.2;
            final value = (_controller.value - delay) % 1.0;
            final opacity = (value < 0.5 ? value * 2 : (1 - value) * 2).clamp(0.2, 1.0);
            
            return Padding(
              padding: EdgeInsets.symmetric(horizontal: widget.size / 2),
              child: Container(
                width: widget.size,
                height: widget.size,
                decoration: BoxDecoration(
                  color: widget.color.withOpacity(opacity),
                  shape: BoxShape.circle,
                ),
              ),
            );
          }),
        );
      },
    );
  }
}

