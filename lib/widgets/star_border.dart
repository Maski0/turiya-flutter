import 'package:flutter/material.dart';

/// Animated star border effect that creates a glowing border animation
/// Wraps any child widget with two animated glowing lines that move around the border
class AnimatedStarBorder extends StatefulWidget {
  final Widget child;
  final Color color;
  final Duration speed;

  const AnimatedStarBorder({
    super.key,
    required this.child,
    this.color = const Color(0x99FFFFFF), // rgba(255, 255, 255, 0.6)
    this.speed = const Duration(seconds: 8),
  });

  @override
  State<AnimatedStarBorder> createState() => _AnimatedStarBorderState();
}

class _AnimatedStarBorderState extends State<AnimatedStarBorder>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _animation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: widget.speed,
      vsync: this,
    )..repeat(reverse: true);

    _animation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _controller, curve: Curves.linear),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final width = constraints.maxWidth;
        final glowWidth = width * 3; // 300% width like web

        return ClipRRect(
          borderRadius: BorderRadius.circular(12), // rounded-xl
          child: Stack(
            clipBehavior: Clip.none,
            children: [
              // Child content
              widget.child,

              // Bottom star animation - moves from right to left
              AnimatedBuilder(
                animation: _animation,
                builder: (context, child) {
                  // Web: starts at right: -250%, ends at right: -100% (moves left)
                  // 0% -> right: -glowWidth * 2.5, 100% -> right: -glowWidth
                  final rightOffset =
                      -glowWidth * 2.5 + (_animation.value * glowWidth * 1.5);
                  return Positioned(
                    bottom: 0,
                    right: rightOffset,
                    child: IgnorePointer(
                      child: Opacity(
                        // Web: opacity-20 (0.2) fading to 0
                        opacity: 0.7 * (1.0 - _animation.value),
                        child: Container(
                          width: glowWidth,
                          height: 16, // h-4 = 16px
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(9999),
                            gradient: RadialGradient(
                              center: Alignment.center,
                              radius: 0.5,
                              colors: [
                                widget.color,
                                widget.color.withOpacity(0.3),
                                Colors.transparent,
                              ],
                              stops: const [0.0, 0.05, 0.1],
                            ),
                          ),
                        ),
                      ),
                    ),
                  );
                },
              ),

              // Top star animation - moves from left to right
              AnimatedBuilder(
                animation: _animation,
                builder: (context, child) {
                  // Web: starts at left: -250%, ends at left: -100% (moves right)
                  // 0% -> left: -glowWidth * 2.5, 100% -> left: -glowWidth
                  final leftOffset =
                      -glowWidth * 2.5 + (_animation.value * glowWidth * 1.5);
                  return Positioned(
                    top: 0,
                    left: leftOffset,
                    child: IgnorePointer(
                      child: Opacity(
                        // Web: opacity-20 (0.2) fading to 0
                        opacity: 0.7 * (1.0 - _animation.value),
                        child: Container(
                          width: glowWidth,
                          height: 16, // h-4 = 16px
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(9999),
                            gradient: RadialGradient(
                              center: Alignment.center,
                              radius: 0.5,
                              colors: [
                                widget.color,
                                widget.color.withOpacity(0.3),
                                Colors.transparent,
                              ],
                              stops: const [0.0, 0.05, 0.1],
                            ),
                          ),
                        ),
                      ),
                    ),
                  );
                },
              ),
            ],
          ),
        );
      },
    );
  }
}
