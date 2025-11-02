import 'dart:math';
import 'package:flutter/material.dart';

class AnimatedDots extends StatefulWidget {
  final double size;
  final List<Color>? colors;
  final bool isNarrating; // If true, show ripple circles instead of bouncing dots

  const AnimatedDots({
    super.key,
    this.size = 4.0,
    this.colors,
    this.isNarrating = false,
  });

  @override
  State<AnimatedDots> createState() => _AnimatedDotsState();
}

class _AnimatedDotsState extends State<AnimatedDots>
    with TickerProviderStateMixin {
  late AnimationController _controller;
  late AnimationController _transitionController;
  late Animation<double> _transitionAnimation;
  
  // Default 4 colors: red, orange, purple, blue
  static const List<Color> _defaultColors = [
    Color(0xFFFF0000), // Red
    Color(0xFFFFA569), // Orange
    Color(0xFFA7A6FB), // Lavender/Purple
    Color(0xFF046E80), // Teal/Blue
  ];

  @override
  void initState() {
    super.initState();
    // Longer duration for breathing effect (narrating), shorter for bouncing (pondering)
    final duration = widget.isNarrating 
        ? const Duration(milliseconds: 8000) // Very slow breathing (8s - like deep meditation)
        : const Duration(milliseconds: 1600); // Smooth bouncing
    
    _controller = AnimationController(
      vsync: this,
      duration: duration,
    )..repeat();
    
    // Transition animation controller for morphing between dots and bars
    _transitionController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200), // Slower, smoother transition
    );
    
    _transitionAnimation = CurvedAnimation(
      parent: _transitionController,
      curve: Curves.easeInOut,
    );
    
    // Start at the correct state
    if (widget.isNarrating) {
      _transitionController.value = 1.0;
    }
  }
  
  @override
  void didUpdateWidget(AnimatedDots oldWidget) {
    super.didUpdateWidget(oldWidget);
    // Update duration if isNarrating changes
    if (oldWidget.isNarrating != widget.isNarrating) {
      final duration = widget.isNarrating 
          ? const Duration(milliseconds: 8000) // Very slow breathing (8s)
          : const Duration(milliseconds: 1600); // Smooth bouncing
      
      _controller.duration = duration;
      
      // Animate the transition
      // Allow current animation cycle to complete before transitioning back
      if (widget.isNarrating) {
        _transitionController.forward();
      } else {
        // Delay reverse to let the current breathing cycle complete
        Future.delayed(Duration(milliseconds: (8000 * (1 - _controller.value)).toInt()), () {
          if (mounted && !widget.isNarrating) {
            _transitionController.reverse();
          }
        });
      }
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    _transitionController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final colors = widget.colors ?? _defaultColors;
    
    // Unified animation that morphs between dots and circles
    return AnimatedBuilder(
      animation: Listenable.merge([_controller, _transitionAnimation]),
      builder: (context, child) {
        final transition = _transitionAnimation.value; // 0 = dots, 1 = circles
        
         return SizedBox(
           width: 28,
           height: 28,
           child: Stack(
             alignment: Alignment.center,
             children: List.generate(4, (index) {
              final colorIndex = index; // Keep consistent color for each dot position
              
              // Animation delay/phase for wave effect
              final staggerDelay = index * 0.09375; // Stagger for both animations
              
              var value = (_controller.value - staggerDelay) % 1.0;
              if (value < 0) {
                value = value + 1.0;
              }
              
              // Calculate animations
              final bounce = _smoothBounce(value);
              
              // Horizontal position stays constant
              final dotSpacing = widget.size * 1.8;
              final dotOffset = (index - 1.5) * dotSpacing;
              
              // Stop bouncing when transition starts (freeze dots)
              final offsetY = transition > 0 ? 0.0 : -4.0 * bounce;
              
              // Breathing animation: smooth sine wave (like inhale/exhale)
              // Goes from 0 → 1 → 0 smoothly
              final breathingWave = (1 - cos(value * 2 * pi)) / 2; // 0 to 1 and back
              
              // Size interpolation: dots → bars
              final minSize = widget.size; // Dot size (4px)
              final maxSize = 18.0; // Maximum bar height
              final midSize = (minSize + maxSize) / 2; // Average size
              
              // Gradually morph from dot to bar during transition
              // transition 0→1: dot stays dot, then starts growing
              final baseHeight = minSize + (transition * (midSize - minSize));
              
              // After transition, use breathing wave to animate
              final breathingAmplitude = (maxSize - midSize) * transition; // Grows as transition progresses
              final targetHeight = baseHeight + (breathingWave * breathingAmplitude);
              
              // Interpolate corner radius: circle (50%) → rounded bar (50% of width)
              final cornerRadius = widget.size / 2; // Always fully rounded
              
              return Align(
                alignment: Alignment.center,
                child: Transform.translate(
                  offset: Offset(dotOffset, offsetY),
                  child: Container(
                    width: widget.size,
                    height: targetHeight,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(cornerRadius),
                      color: colors[colorIndex],
                    ),
                  ),
                ),
              );
             }),
           ),
         );
      },
    );
  }
  
  // Smooth bounce using sine wave - creates a gentle, calming motion
  double _smoothBounce(double t) {
    // Each dot bounces up and down once per cycle
    // Using sine wave for perfectly smooth motion
    // Goes from 0 -> 1 -> 0 in a smooth curve
    return (1 - cos(t * 2 * pi)) / 2;
  }
}

