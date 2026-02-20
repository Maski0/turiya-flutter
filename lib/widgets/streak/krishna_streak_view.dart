import 'package:flutter/material.dart';
import 'dart:ui' as ui;

import 'package:flutter_liquid_glass_plus/flutter_liquid_glass.dart';
import 'package:rive/rive.dart' hide Animation, PaintingStyle;

/// Figma node: 127:2534 (Krishna streak)
class KrishnaStreakView extends StatefulWidget {
  /// Week data for Mon..Sun.
  /// - true: completed (solid)
  /// - false: missed (dashed)
  /// - null: future/unavailable (dim outline)
  final List<bool?> week;
  final VoidCallback? onContinue;
  final VoidCallback? onBackdropTap;

  const KrishnaStreakView({
    super.key,
    required this.week,
    this.onContinue,
    this.onBackdropTap,
  });

  @override
  State<KrishnaStreakView> createState() => _KrishnaStreakViewState();
}

class _KrishnaStreakViewState extends State<KrishnaStreakView>
    with TickerProviderStateMixin {
  late final AnimationController _glowController;
  late final AnimationController _enterController;
  late final Animation<double> _fillAnimation;
  late final Animation<double> _countAnimation;

  @override
  void initState() {
    super.initState();
    _glowController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1100),
    )..repeat(reverse: true);

    _enterController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 650),
    );
    _fillAnimation = CurvedAnimation(
      parent: _enterController,
      curve: Curves.easeOutCubic,
    );
    _countAnimation = CurvedAnimation(
      parent: _enterController,
      curve: Curves.easeOutCubic,
    );
    // Start as outline-only, then fill after a short pause.
    _enterController.value = 0.0;
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      await Future<void>.delayed(const Duration(seconds: 1));
      if (!mounted) return;
      if (_shouldAnimateTodayFill) _enterController.forward();
    });
  }

  @override
  void dispose() {
    _glowController.dispose();
    _enterController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final mq = MediaQuery.of(context);
    final scale = mq.size.height / 852.0;
    final week = _normalizedWeek(widget.week);
    final int todayIndex =
        _clampInt(DateTime.now().weekday - 1, min: 0, max: 6);
    final bool todayIsComplete = week[todayIndex] == true;
    final int preCount = _currentStreakCount(
      week: week,
      todayIndex: todayIndex,
      includeToday: false,
    );
    final int finalCount = _currentStreakCount(
      week: week,
      todayIndex: todayIndex,
      includeToday: todayIsComplete,
    );

    final dotWidgets = <Widget>[];
    for (var i = 0; i < 7; i++) {
      final state = _dayState(index: i, todayIndex: todayIndex, week: week);
      final isDim = state == _DayCircleState.future;

      dotWidgets.add(
        Opacity(
          opacity: isDim ? 0.5 : 1.0,
          child: _DayCircleColumn(
            dayLabel: _dayLabel(i),
            state: state,
            todayIsComplete: todayIsComplete,
            glow: _glowController,
            enter: _fillAnimation,
            scale: scale,
          ),
        ),
      );

      if (i != 6) dotWidgets.add(SizedBox(width: 16 * scale));
    }

    return Stack(
      children: [
        Positioned.fill(
          child: GestureDetector(
            onTap: widget.onBackdropTap,
            behavior: HitTestBehavior.opaque,
            child: BackdropFilter(
              filter: ui.ImageFilter.blur(sigmaX: 32, sigmaY: 32),
              child: Container(color: const Color.fromRGBO(0, 0, 0, 0.20)),
            ),
          ),
        ),
        Align(
          alignment: Alignment.center,
          child: Transform.translate(
            offset: Offset(0, -48 * scale),
            child: SizedBox(
              width: double.infinity,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Column(
                    children: [
                      SizedBox(
                        width: 160 * scale,
                        height: 160 * scale,
                        child: RiveWidgetBuilder(
                          fileLoader: FileLoader.fromAsset(
                            'assets/images/pricing/feather.riv',
                            riveFactory: Factory.flutter,
                          ),
                          builder: (context, state) {
                            if (state is RiveLoaded) {
                              return RiveWidget(
                                controller: state.controller,
                                fit: Fit.contain,
                              );
                            }
                            return const SizedBox.shrink();
                          },
                        ),
                      ),
                      SizedBox(height: 16 * scale),
                      Text(
                        'You showed up today',
                        textAlign: TextAlign.center,
                        style: Theme.of(context)
                            .textTheme
                            .displaySmall
                            ?.copyWith(
                              fontSize: 32 * scale,
                              height: 1.2,
                              letterSpacing: -0.32,
                              fontWeight: FontWeight.w500,
                            ),
                      ),
                    ],
                  ),
                  SizedBox(height: 48 * scale),
                  Column(
                    children: [
                      SizedBox(
                        width: double.infinity,
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: dotWidgets,
                        ),
                      ),
                      SizedBox(height: 24 * scale),
                      _StreakPill(
                        preCount: preCount,
                        finalCount: finalCount,
                        animate: todayIsComplete,
                        progress: _countAnimation,
                        scale: scale,
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
        Positioned(
          left: 16 * scale,
          right: 16 * scale,
          bottom: 45 * scale,
          child: GestureDetector(
            onTap: widget.onContinue,
            behavior: HitTestBehavior.opaque,
            child: DecoratedBox(
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16 * scale),
              ),
              child: Padding(
                padding: EdgeInsets.all(16 * scale),
                child: Center(
                  child: Text(
                    'Continue',
                    style: Theme.of(context).textTheme.titleSmall?.copyWith(
                          color: const Color(0xFF111111),
                          fontSize: 16 * scale,
                          height: 1.4,
                          fontWeight: FontWeight.w500,
                        ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }

  _DayCircleState _dayState({
    required int index,
    required int todayIndex,
    required List<bool?> week,
  }) {
    if (index == todayIndex) return _DayCircleState.today;
    final v = week[index];
    if (v == null) return _DayCircleState.future;
    return v ? _DayCircleState.completed : _DayCircleState.missed;
  }

  String _dayLabel(int i) {
    switch (i) {
      case 0:
        return 'M';
      case 1:
        return 'T';
      case 2:
        return 'W';
      case 3:
        return 'Th';
      case 4:
        return 'F';
      case 5:
        return 'St';
      default:
        return 'Su';
    }
  }
}

int _clampInt(int value, {required int min, required int max}) {
  if (value < min) return min;
  if (value > max) return max;
  return value;
}

enum _DayCircleState { missed, completed, today, future }

class _DayCircleColumn extends StatelessWidget {
  final String dayLabel;
  final _DayCircleState state;
  final bool todayIsComplete;
  final Animation<double> glow;
  final Animation<double> enter;
  final double scale;

  const _DayCircleColumn({
    required this.dayLabel,
    required this.state,
    required this.todayIsComplete,
    required this.glow,
    required this.enter,
    required this.scale,
  });

  @override
  Widget build(BuildContext context) {
    final labelStyle = Theme.of(context).textTheme.bodyMedium?.copyWith(
          fontSize: 16 * scale,
          height: 1.4,
          color: Colors.white,
          fontWeight: FontWeight.w400,
        );

    return SizedBox(
      width: 32 * scale,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          SizedBox(
            width: 32 * scale,
            height: 32 * scale,
            child: _DayCircle(
              state: state,
              todayIsComplete: todayIsComplete,
              glow: glow,
              enter: enter,
              scale: scale,
            ),
          ),
          SizedBox(height: 8 * scale),
          Text(dayLabel, textAlign: TextAlign.center, style: labelStyle),
        ],
      ),
    );
  }
}

class _DayCircle extends StatelessWidget {
  final _DayCircleState state;
  final bool todayIsComplete;
  final Animation<double> glow;
  final Animation<double> enter;
  final double scale;

  const _DayCircle({
    required this.state,
    required this.todayIsComplete,
    required this.glow,
    required this.enter,
    required this.scale,
  });

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: Listenable.merge([glow, enter]),
      builder: (context, _) {
        final t = glow.value;
        final glowOpacity = 0.22 + (0.38 * t);
        final glowBlur = (14 + (18 * t)) * scale;
        final glowSpread = (1.0 + (2.2 * t)) * scale;
        final haloOpacity = 0.10 + (0.14 * t);
        final haloBlur = (34 + (28 * t)) * scale;

        switch (state) {
          case _DayCircleState.completed:
            return DecoratedBox(
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: Colors.white,
                boxShadow: [
                  BoxShadow(
                    color: Colors.white.withOpacity(0.22 + (0.18 * t)),
                    blurRadius: (10 + (10 * t)) * scale,
                    spreadRadius: (0.4 + (0.8 * t)) * scale,
                  ),
                  BoxShadow(
                    color: Colors.white.withOpacity(0.08 + (0.08 * t)),
                    blurRadius: (26 + (18 * t)) * scale,
                    spreadRadius: (0.8 + (0.8 * t)) * scale,
                  ),
                ],
              ),
            );
          case _DayCircleState.today:
            final fillT = todayIsComplete ? enter.value : 0.0;
            return Transform.scale(
              scale: 1.0 + (0.09 * t),
              child: DecoratedBox(
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: Colors.white.withOpacity(fillT),
                  border: Border.all(color: Colors.white, width: 3 * scale),
                  boxShadow: [
                    BoxShadow(
                      color:
                          Colors.white.withOpacity(glowOpacity * (0.2 + 0.8 * fillT)),
                      blurRadius: glowBlur,
                      spreadRadius: glowSpread,
                    ),
                    BoxShadow(
                      color:
                          Colors.white.withOpacity(haloOpacity * (0.2 + 0.8 * fillT)),
                      blurRadius: haloBlur,
                      spreadRadius: (3.0 + (2.0 * t)) * scale,
                    ),
                  ],
                ),
              ),
            );
          case _DayCircleState.future:
            return DecoratedBox(
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(
                  color: Colors.white.withOpacity(0.6),
                  width: 2 * scale,
                ),
              ),
            );
          case _DayCircleState.missed:
            return CustomPaint(
              painter: _DashedCirclePainter(
                color: Colors.white.withOpacity(0.75),
                strokeWidth: 2 * scale,
              ),
            );
        }
      },
    );
  }
}

class _DashedCirclePainter extends CustomPainter {
  final Color color;
  final double strokeWidth;

  const _DashedCirclePainter({
    required this.color,
    required this.strokeWidth,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth
      ..color = color
      ..strokeCap = StrokeCap.round;

    final rect = Offset.zero & size;
    final center = rect.center;
    final radius = (size.shortestSide - strokeWidth) / 2;

    const dashCount = 10;
    const gapRadians = 0.22;
    final dashRadians =
        ((2 * 3.141592653589793) / dashCount) - gapRadians;

    double start = -3.141592653589793 / 2;
    for (var i = 0; i < dashCount; i++) {
      canvas.drawArc(
        Rect.fromCircle(center: center, radius: radius),
        start,
        dashRadians,
        false,
        paint,
      );
      start += dashRadians + gapRadians;
    }
  }

  @override
  bool shouldRepaint(covariant _DashedCirclePainter oldDelegate) {
    return oldDelegate.color != color || oldDelegate.strokeWidth != strokeWidth;
  }
}

class _StreakPill extends StatelessWidget {
  final int preCount;
  final int finalCount;
  final bool animate;
  final Animation<double> progress;
  final double scale;

  const _StreakPill({
    required this.preCount,
    required this.finalCount,
    required this.animate,
    required this.progress,
    required this.scale,
  });

  @override
  Widget build(BuildContext context) {
    final labelStyle = Theme.of(context).textTheme.titleSmall?.copyWith(
          fontSize: 18 * scale,
          height: 1.4,
          fontWeight: FontWeight.w500,
          fontFeatures: const [ui.FontFeature.tabularFigures()],
        );

    return ClipRRect(
      borderRadius: BorderRadius.circular(64 * scale),
      child: LGContainer(
        useOwnLayer: true,
        quality: LGQuality.premium,
        shape: LiquidRoundedSuperellipse(borderRadius: 64 * scale),
        settings: const LiquidGlassSettings(
          thickness: 22,
          blur: 10,
          refractiveIndex: 1.12,
          chromaticAberration: 0.004,
          lightIntensity: 0.25,
          glassColor: Color.fromRGBO(255, 255, 255, 0.20),
          saturation: 1.15,
        ),
        padding: EdgeInsets.symmetric(
          horizontal: 16 * scale,
          vertical: 8 * scale,
        ),
        child: AnimatedBuilder(
          animation: progress,
          builder: (context, _) {
            final t = animate ? progress.value : 1.0;
            final count = (preCount + ((finalCount - preCount) * t)).round();

            return Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Image.asset(
                  'assets/icons/streak_fire.png',
                  width: 20 * scale,
                  height: 20 * scale,
                  fit: BoxFit.contain,
                  errorBuilder: (_, __, ___) => Icon(
                    Icons.local_fire_department_rounded,
                    size: 20 * scale,
                    color: const Color(0xFFFFA569),
                  ),
                ),
                SizedBox(width: 8 * scale),
                AnimatedSwitcher(
                  duration: const Duration(milliseconds: 220),
                  reverseDuration: const Duration(milliseconds: 160),
                  transitionBuilder: (child, animation) => FadeTransition(
                    opacity: animation,
                    child: child,
                  ),
                  layoutBuilder: (currentChild, previousChildren) {
                    return Stack(
                      alignment: Alignment.center,
                      children: <Widget>[
                        ...previousChildren,
                        if (currentChild != null) currentChild,
                      ],
                    );
                  },
                  child: SizedBox(
                    key: ValueKey<int>(count),
                    width: 18 * scale, // fixed width so layout never shifts
                    child: Text(
                      '$count',
                      textAlign: TextAlign.center,
                      style: labelStyle,
                    ),
                  ),
                ),
                Text('-Day Streak!', style: labelStyle),
              ],
            );
          },
        ),
      ),
    );
  }
}

extension on _KrishnaStreakViewState {
  bool get _shouldAnimateTodayFill {
    final week = _normalizedWeek(widget.week);
    final int todayIndex =
        _clampInt(DateTime.now().weekday - 1, min: 0, max: 6);
    return week[todayIndex] == true;
  }
}

List<bool?> _normalizedWeek(List<bool?> input) {
  if (input.length == 7) return input;
  final out = List<bool?>.filled(7, null);
  for (var i = 0; i < 7 && i < input.length; i++) {
    out[i] = input[i];
  }
  return out;
}

int _currentStreakCount({
  required List<bool?> week,
  required int todayIndex,
  required bool includeToday,
}) {
  var end = includeToday ? todayIndex : (todayIndex - 1);
  if (end < 0) return 0;

  var count = 0;
  for (var i = end; i >= 0; i--) {
    if (week[i] == true) {
      count++;
    } else {
      break;
    }
  }
  return count;
}

