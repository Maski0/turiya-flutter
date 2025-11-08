import 'dart:async';
import 'package:flutter/material.dart';

/// A blinking glowing red dot that appears at the top center of the screen during recording
/// Shows elapsed recording time
class RecordingIndicator extends StatefulWidget {
  final DateTime startTime;
  final int? maxDurationSeconds; // Optional max duration warning
  
  const RecordingIndicator({
    Key? key,
    required this.startTime,
    this.maxDurationSeconds,
  }) : super(key: key);

  @override
  State<RecordingIndicator> createState() => _RecordingIndicatorState();
}

class _RecordingIndicatorState extends State<RecordingIndicator>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _animation;
  late Timer _timer;
  Duration _elapsed = Duration.zero;

  @override
  void initState() {
    super.initState();
    
    // Blinking animation
    _controller = AnimationController(
      duration: const Duration(milliseconds: 1000),
      vsync: this,
    )..repeat(reverse: true);

    _animation = Tween<double>(begin: 0.3, end: 1.0).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeInOut),
    );

    // Timer to update elapsed time every second
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (mounted) {
        setState(() {
          _elapsed = DateTime.now().difference(widget.startTime);
        });
      }
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    _timer.cancel();
    super.dispose();
  }

  String _formatDuration(Duration duration) {
    String twoDigits(int n) => n.toString().padLeft(2, '0');
    final minutes = twoDigits(duration.inMinutes);
    final seconds = twoDigits(duration.inSeconds.remainder(60));
    return '$minutes:$seconds';
  }

  bool _isNearingMax() {
    if (widget.maxDurationSeconds == null) return false;
    return _elapsed.inSeconds >= widget.maxDurationSeconds! - 30; // 30 seconds warning
  }

  @override
  Widget build(BuildContext context) {
    final isWarning = _isNearingMax();
    
    return Positioned(
      top: MediaQuery.of(context).padding.top + 10,
      left: 0,
      right: 0,
      child: Center(
        child: AnimatedBuilder(
          animation: _animation,
          builder: (context, child) {
            return Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: Colors.black.withOpacity(0.7),
                borderRadius: BorderRadius.circular(20),
                border: isWarning
                    ? Border.all(
                        color: Colors.orange.withOpacity(0.6),
                        width: 1.5,
                      )
                    : null,
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Glowing dot with shadow
                  Container(
                    width: 10,
                    height: 10,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: isWarning ? Colors.orange : Colors.red,
                      boxShadow: [
                        BoxShadow(
                          color: (isWarning ? Colors.orange : Colors.red)
                              .withOpacity(_animation.value),
                          blurRadius: 8 * _animation.value,
                          spreadRadius: 2 * _animation.value,
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  // Recording text
                  Text(
                    'Recording',
                    style: TextStyle(
                      color: Colors.white.withOpacity(0.9),
                      fontSize: 13,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  const SizedBox(width: 8),
                  // Timer
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 2,
                    ),
                    decoration: BoxDecoration(
                      color: (isWarning ? Colors.orange : Colors.red)
                          .withOpacity(0.2),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child:                       Text(
                        _formatDuration(_elapsed),
                        style: TextStyle(
                          color: Colors.white.withOpacity(0.95),
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          fontFeatures: const [
                            FontFeature.tabularFigures(),
                          ],
                        ),
                      ),
                  ),
                ],
              ),
            );
          },
        ),
      ),
    );
  }
}
