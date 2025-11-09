import 'dart:io';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:share_plus/share_plus.dart';
import 'package:video_player/video_player.dart';
import '../services/screen_recording_service.dart';
import '../utils/toast_utils.dart';

/// Overlay that shows the recorded video with preview and share options
class RecordingPreviewOverlay extends StatefulWidget {
  final String videoPath;
  final VoidCallback onClose;

  const RecordingPreviewOverlay({
    Key? key,
    required this.videoPath,
    required this.onClose,
  }) : super(key: key);

  static void show(BuildContext context, String videoPath) {
    showDialog(
      context: context,
      barrierDismissible: true,
      barrierColor: Colors.transparent,
      builder: (context) => RecordingPreviewOverlay(
        videoPath: videoPath,
        onClose: () => Navigator.of(context).pop(),
      ),
    );
  }

  @override
  State<RecordingPreviewOverlay> createState() => _RecordingPreviewOverlayState();
}

class _RecordingPreviewOverlayState extends State<RecordingPreviewOverlay> {
  VideoPlayerController? _videoController;
  bool _isLoading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _initializeVideo();
  }

  Future<void> _initializeVideo() async {
    try {
      final file = File(widget.videoPath);
      if (!await file.exists()) {
        setState(() {
          _error = 'Video file not found';
          _isLoading = false;
        });
        return;
      }

      _videoController = VideoPlayerController.file(file);
      await _videoController!.initialize();
      
      // Listen to video position changes to update progress bar
      _videoController!.addListener(() {
        if (mounted) {
          setState(() {});
        }
      });
      
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    } catch (e) {
      debugPrint('Error initializing video: $e');
      if (mounted) {
        setState(() {
          _error = 'Failed to load video';
          _isLoading = false;
        });
      }
    }
  }

  @override
  void dispose() {
    _videoController?.dispose();
    super.dispose();
  }

  Future<void> _shareVideo() async {
    try {
      final file = XFile(widget.videoPath);
      await Share.shareXFiles(
        [file],
        subject: 'Turiya Screen Recording',
        text: 'Check out my screen recording!',
      );
    } catch (e) {
      debugPrint('Error sharing video: $e');
      if (mounted) {
        ToastUtils.showError(context, 'Failed to share video');
      }
    }
  }

  Future<void> _deleteVideo() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: Colors.black.withOpacity(0.9),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
          side: BorderSide(color: Colors.white.withOpacity(0.2)),
        ),
        title: const Text(
          'Delete Recording?',
          style: TextStyle(color: Colors.white),
        ),
        content: const Text(
          'This action cannot be undone.',
          style: TextStyle(color: Colors.white70),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirm == true && mounted) {
      bool deleted = await ScreenRecordingService().deleteRecording(widget.videoPath);
      if (mounted) {
        // Close the dialog first to avoid Navigator conflicts
        widget.onClose();
        
        // Show toast after a small delay to ensure dialog is dismissed
        await Future.delayed(const Duration(milliseconds: 100));
        
        if (mounted) {
          if (deleted) {
            ToastUtils.showSuccess(context, 'Recording deleted');
          } else {
            ToastUtils.showError(context, 'Failed to delete recording');
          }
        }
      }
    }
  }

  void _togglePlayPause() {
    if (_videoController == null) return;
    
    setState(() {
      if (_videoController!.value.isPlaying) {
        _videoController!.pause();
      } else {
        _videoController!.play();
      }
    });
  }

  String _formatDuration(Duration duration) {
    String twoDigits(int n) => n.toString().padLeft(2, '0');
    final hours = twoDigits(duration.inHours);
    final minutes = twoDigits(duration.inMinutes.remainder(60));
    final seconds = twoDigits(duration.inSeconds.remainder(60));
    
    if (duration.inHours > 0) {
      return '$hours:$minutes:$seconds';
    }
    return '$minutes:$seconds';
  }

  @override
  Widget build(BuildContext context) {
    final screenHeight = MediaQuery.of(context).size.height;
    final topPadding = MediaQuery.of(context).padding.top;
    final videoHeight = screenHeight * 0.7;
    
    return Material(
      type: MaterialType.transparency,
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
        child: Container(
          color: Colors.black.withOpacity(0.3),
          child: Stack(
            children: [
              // Main content - video with buttons
              Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  // Top spacing for close button
                  SizedBox(height: topPadding + 60),
                  
                  // Video preview
                    GestureDetector(
                      onTap: _togglePlayPause,
                      child: Container(
                        width: double.infinity,
                        height: videoHeight,
                        color: Colors.black,
                        child: _isLoading
                              ? Center(
                                  child: CircularProgressIndicator(
                                    color: Colors.white.withOpacity(0.8),
                                  ),
                                )
                              : _error != null
                                  ? Column(
                                      mainAxisAlignment: MainAxisAlignment.center,
                                      children: [
                                        Icon(
                                          Icons.error_outline,
                                          size: 48,
                                          color: Colors.red.withOpacity(0.8),
                                        ),
                                        const SizedBox(height: 12),
                                        Text(
                                          _error!,
                                          style: TextStyle(
                                            color: Colors.white.withOpacity(0.8),
                                            fontSize: 14,
                                          ),
                                        ),
                                      ],
                                    )
                                  : Stack(
                                      alignment: Alignment.center,
                                      children: [
                                        // Video player
                                        if (_videoController != null)
                                          SizedBox.expand(
                                            child: FittedBox(
                                              fit: BoxFit.contain,
                                              child: SizedBox(
                                                width: _videoController!.value.size.width,
                                                height: _videoController!.value.size.height,
                                                child: VideoPlayer(_videoController!),
                                              ),
                                            ),
                                          ),
                                        
                                        // Play/Pause overlay
                                        if (_videoController != null && !_videoController!.value.isPlaying)
                                          Container(
                                            decoration: BoxDecoration(
                                              color: Colors.black.withOpacity(0.5),
                                              shape: BoxShape.circle,
                                            ),
                                            padding: const EdgeInsets.all(20),
                                            child: Icon(
                                              Icons.play_arrow,
                                              size: 64,
                                              color: Colors.white.withOpacity(0.9),
                                            ),
                                          ),
                                        
                                        // Time display (bottom right)
                                        if (_videoController != null)
                                          Positioned(
                                            bottom: 16,
                                            right: 16,
                                            child: Container(
                                              padding: const EdgeInsets.symmetric(
                                                horizontal: 10,
                                                vertical: 6,
                                              ),
                                              decoration: BoxDecoration(
                                                color: Colors.black.withOpacity(0.7),
                                                borderRadius: BorderRadius.circular(8),
                                              ),
                                              child: Text(
                                                '${_formatDuration(_videoController!.value.position)} / ${_formatDuration(_videoController!.value.duration)}',
                                                style: const TextStyle(
                                                  color: Colors.white,
                                                  fontSize: 13,
                                                  fontWeight: FontWeight.w500,
                                                ),
                                              ),
                                            ),
                                          ),
                                        
                                        // Progress bar (bottom)
                                        if (_videoController != null)
                                          Positioned(
                                            bottom: 0,
                                            left: 0,
                                            right: 0,
                                            child: VideoProgressIndicator(
                                              _videoController!,
                                              allowScrubbing: true,
                                              padding: const EdgeInsets.symmetric(vertical: 4),
                                              colors: VideoProgressColors(
                                                playedColor: Colors.blue,
                                                bufferedColor: Colors.white.withOpacity(0.3),
                                                backgroundColor: Colors.white.withOpacity(0.1),
                                              ),
                                            ),
                                          ),
                                      ],
                                    ),
                      ),
                    ),
                    
                    const SizedBox(height: 16),
                    
                    // Action buttons
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 20),
                      child: Row(
                        children: [
                          // Delete button
                          Expanded(
                            child: _ActionButton(
                              icon: Icons.delete_outline,
                              label: 'Delete',
                              color: Colors.red,
                              onTap: _deleteVideo,
                            ),
                          ),
                          const SizedBox(width: 16),
                          // Share button
                          Expanded(
                            child: _ActionButton(
                              icon: Icons.share,
                              label: 'Share',
                              color: Colors.blue,
                              isPrimary: true,
                              onTap: _shareVideo,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              
              // Close button (top right)
              Positioned(
                top: MediaQuery.of(context).padding.top + 16,
                right: 16,
                child: Material(
                  color: Colors.transparent,
                  child: InkWell(
                    onTap: widget.onClose,
                    borderRadius: BorderRadius.circular(30),
                    child: Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.black.withOpacity(0.5),
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: Colors.white.withOpacity(0.3),
                          width: 1.5,
                        ),
                      ),
                      child: Icon(
                        Icons.close,
                        color: Colors.white.withOpacity(0.9),
                        size: 24,
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ActionButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  final bool isPrimary;
  final VoidCallback onTap;

  const _ActionButton({
    required this.icon,
    required this.label,
    required this.color,
    this.isPrimary = false,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 14),
          decoration: BoxDecoration(
            gradient: isPrimary
                ? LinearGradient(
                    colors: [
                      color.withOpacity(0.8),
                      color.withOpacity(0.6),
                    ],
                  )
                : null,
            color: isPrimary ? null : color.withOpacity(0.15),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: isPrimary ? Colors.transparent : color.withOpacity(0.3),
              width: 1,
            ),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                icon,
                color: isPrimary ? Colors.white : color,
                size: 20,
              ),
              const SizedBox(width: 8),
              Text(
                label,
                style: TextStyle(
                  color: isPrimary ? Colors.white : color,
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
