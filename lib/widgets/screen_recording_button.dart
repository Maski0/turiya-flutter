import 'package:flutter/material.dart';
import '../theme/app_theme.dart';
import '../services/screen_recording_service.dart';
import '../utils/toast_utils.dart';

/// A floating button widget for screen recording controls
class ScreenRecordingButton extends StatefulWidget {
  final VoidCallback? onRecordingStarted;
  final void Function(String path)? onRecordingStopped;

  const ScreenRecordingButton({
    Key? key,
    this.onRecordingStarted,
    this.onRecordingStopped,
  }) : super(key: key);

  @override
  State<ScreenRecordingButton> createState() => _ScreenRecordingButtonState();
}

class _ScreenRecordingButtonState extends State<ScreenRecordingButton>
    with SingleTickerProviderStateMixin {
  final ScreenRecordingService _recordingService = ScreenRecordingService();
  bool _isRecording = false;
  late AnimationController _pulseController;

  @override
  void initState() {
    super.initState();
    _isRecording = _recordingService.isRecording;

    // Pulse animation for recording indicator
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1000),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _pulseController.dispose();
    super.dispose();
  }

  Future<void> _toggleRecording() async {
    if (_isRecording) {
      // Show processing dialog
      if (!mounted) return;

      String processingMessage = 'Processing frames...';

      // Set up callback to update dialog
      _recordingService.setProcessingCallback((message) {
        processingMessage = message;
        if (mounted) {
          setState(() {}); // Trigger rebuild to update dialog
        }
      });

      // Show modal dialog
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (BuildContext dialogContext) {
          return StatefulBuilder(
            builder: (context, setDialogState) {
              // Update dialog state when processing message changes
              _recordingService.setProcessingCallback((message) {
                processingMessage = message;
                setDialogState(() {});
              });

              return WillPopScope(
                onWillPop: () async => false,
                child: AlertDialog(
                  content: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const CircularProgressIndicator(),
                      const SizedBox(height: 20),
                      Text(
                        processingMessage,
                        style: Theme.of(context).textTheme.bodyLarge,
                        textAlign: TextAlign.center,
                      ),
                    ],
                  ),
                ),
              );
            },
          );
        },
      );

      // Stop recording (this will take time)
      String? path = await _recordingService.stopRecording();

      // Close processing dialog
      if (mounted) {
        Navigator.of(context).pop();
      }

      setState(() {
        _isRecording = false;
      });

      if (path != null) {
        if (mounted) {
          ToastUtils.showSuccess(
            context,
            'Recording saved successfully',
          );
        }
        widget.onRecordingStopped?.call(path);
      } else {
        if (mounted) {
          ToastUtils.showError(
            context,
            'Failed to save recording',
          );
        }
      }
    } else {
      // Start recording with internal audio only (no microphone)
      _recordingService.setAudioCaptureMode(internalOnly: true);
      bool started = await _recordingService.startRecording();

      setState(() {
        _isRecording = started;
      });

      if (started) {
        widget.onRecordingStarted?.call();
      } else {
        if (mounted) {
          ToastUtils.showError(
            context,
            'Failed to start recording. Please check permissions.',
          );
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return FloatingActionButton(
      onPressed: _toggleRecording,
      backgroundColor: _isRecording ? Colors.red : Colors.blue,
      child: AnimatedBuilder(
        animation: _pulseController,
        builder: (context, child) {
          return Stack(
            alignment: Alignment.center,
            children: [
              // Pulsing circle when recording
              if (_isRecording)
                Container(
                  width: 56 * (1 + _pulseController.value * 0.3),
                  height: 56 * (1 + _pulseController.value * 0.3),
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: Colors.red
                        .withOpacity(0.3 * (1 - _pulseController.value)),
                  ),
                ),
              // Icon
              Icon(
                _isRecording ? Icons.stop : Icons.fiber_manual_record,
                color: Colors.white,
                size: 28,
              ),
            ],
          );
        },
      ),
    );
  }
}

/// A compact screen recording toggle widget for app bars or drawers
class ScreenRecordingToggle extends StatefulWidget {
  final VoidCallback? onRecordingStarted;
  final void Function(String path)? onRecordingStopped;

  const ScreenRecordingToggle({
    Key? key,
    this.onRecordingStarted,
    this.onRecordingStopped,
  }) : super(key: key);

  @override
  State<ScreenRecordingToggle> createState() => _ScreenRecordingToggleState();
}

class _ScreenRecordingToggleState extends State<ScreenRecordingToggle> {
  final ScreenRecordingService _recordingService = ScreenRecordingService();
  bool _isRecording = false;

  @override
  void initState() {
    super.initState();
    _isRecording = _recordingService.isRecording;
  }

  Future<void> _toggleRecording() async {
    if (_isRecording) {
      // Show processing dialog
      if (!mounted) return;

      String processingMessage = 'Processing frames...';

      // Show modal dialog
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (BuildContext dialogContext) {
          return StatefulBuilder(
            builder: (context, setDialogState) {
              // Update dialog state when processing message changes
              _recordingService.setProcessingCallback((message) {
                processingMessage = message;
                setDialogState(() {});
              });

              return WillPopScope(
                onWillPop: () async => false,
                child: AlertDialog(
                  content: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const CircularProgressIndicator(),
                      const SizedBox(height: 20),
                      Text(
                        processingMessage,
                        style: Theme.of(context).textTheme.bodyLarge,
                        textAlign: TextAlign.center,
                      ),
                    ],
                  ),
                ),
              );
            },
          );
        },
      );

      // Stop recording
      String? path = await _recordingService.stopRecording();

      // Close processing dialog
      if (mounted) {
        Navigator.of(context).pop();
      }

      setState(() {
        _isRecording = false;
      });

      if (path != null) {
        if (mounted) {
          ToastUtils.showSuccess(context, 'Recording saved');
        }
        widget.onRecordingStopped?.call(path);
      } else {
        if (mounted) {
          ToastUtils.showError(context, 'Failed to save recording');
        }
      }
    } else {
      // Start recording with internal audio only (no microphone)
      _recordingService.setAudioCaptureMode(internalOnly: true);
      bool started = await _recordingService.startRecording();
      setState(() {
        _isRecording = started;
      });

      if (started) {
        widget.onRecordingStarted?.call();
      } else {
        if (mounted) {
          ToastUtils.showError(context, 'Failed to start recording');
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return IconButton(
      icon: Icon(
        _isRecording ? Icons.stop_circle : Icons.radio_button_checked,
        color: _isRecording ? Colors.red : null,
      ),
      tooltip: _isRecording ? 'Stop Recording' : 'Start Recording',
      onPressed: _toggleRecording,
    );
  }
}
