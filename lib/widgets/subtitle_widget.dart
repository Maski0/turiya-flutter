import 'dart:async';
import 'dart:ui';
import 'package:flutter/material.dart';
import '../models/alignment_data.dart';

class SubtitleWidget extends StatefulWidget {
  final AlignmentData? alignment;
  final bool isPlaying;
  final VoidCallback? onAnimationFrame;

  const SubtitleWidget({
    super.key,
    required this.alignment,
    required this.isPlaying,
    this.onAnimationFrame,
  });

  @override
  State<SubtitleWidget> createState() => _SubtitleWidgetState();
}

class _SubtitleWidgetState extends State<SubtitleWidget> with SingleTickerProviderStateMixin {
  String _currentText = '';
  String _previousText = ''; // Text that's already been shown
  String _newText = ''; // New text that's fading in
  Timer? _timer;
  DateTime? _playbackStartTime;
  double _currentTime = 0.0;
  late AnimationController _textFadeController;
  late Animation<double> _textFadeAnimation;

  @override
  void initState() {
    super.initState();
    
    // Initialize fade animation controller
    _textFadeController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 300),
    );
    
    _textFadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _textFadeController, curve: Curves.easeIn),
    );
    
    _startPlayback();
  }
  
  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // Log alignment data when received
    if (widget.alignment != null) {
      print('📝 Subtitles: Alignment data received. '
          'Text: "${widget.alignment!.fullText.substring(0, widget.alignment!.fullText.length > 50 ? 50 : widget.alignment!.fullText.length)}...", '
          'Characters: ${widget.alignment!.characters.length}, '
          'Timestamps: ${widget.alignment!.characterStartTimesSeconds.length}');
    }
  }

  @override
  void didUpdateWidget(SubtitleWidget oldWidget) {
    super.didUpdateWidget(oldWidget);
    
    // Reset playback if alignment changes or playing state changes
    if (widget.alignment != oldWidget.alignment ||
        widget.isPlaying != oldWidget.isPlaying) {
      _startPlayback();
    }
  }

  void _startPlayback() {
    _timer?.cancel();
    
    if (!widget.isPlaying || widget.alignment == null) {
      setState(() {
        _currentText = '';
        _playbackStartTime = null;
        _currentTime = 0.0;
      });
      return;
    }

    // Add a small delay (~200ms) to account for Unity audio processing/buffering
    // This helps sync the subtitles with the actual audio playback
    Future.delayed(const Duration(milliseconds: 200), () {
      if (!mounted || !widget.isPlaying) return;
      
      // Start timing from now
      _playbackStartTime = DateTime.now();
      _currentTime = 0.0;

      // Update text at 60 FPS (similar to requestAnimationFrame)
      _timer = Timer.periodic(const Duration(milliseconds: 16), (_) {
        if (!mounted) return;
        _updateText();
      });
    });
  }

  void _updateText() {
    if (!widget.isPlaying || widget.alignment == null || _playbackStartTime == null) {
      return;
    }

    // Calculate current playback time
    _currentTime = DateTime.now().difference(_playbackStartTime!).inMilliseconds / 1000.0;

    final alignment = widget.alignment!;
    String currentSentence = '';

    // Find which character is currently being spoken
    int currentCharIndex = -1;
    bool isInPause = false;
    
    for (int i = 0; i < alignment.characters.length; i++) {
      final startTime = alignment.characterStartTimesSeconds[i];
      final endTime = alignment.characterEndTimesSeconds[i];

      if (_currentTime >= startTime && _currentTime <= endTime) {
        currentCharIndex = i;
        break;
      }
    }

    // If no character is currently being spoken, check if we're in a pause
    if (currentCharIndex == -1 && alignment.characterEndTimesSeconds.isNotEmpty) {
      // Find the last character that finished
      int lastSpokenCharIndex = -1;
      for (int i = alignment.characterEndTimesSeconds.length - 1; i >= 0; i--) {
        if (alignment.characterEndTimesSeconds[i] <= _currentTime) {
          lastSpokenCharIndex = i;
          break;
        }
      }
      
      // Check if there's a next character to be spoken
      int nextCharIndex = -1;
      for (int i = 0; i < alignment.characters.length; i++) {
        if (alignment.characterStartTimesSeconds[i] > _currentTime) {
          nextCharIndex = i;
          break;
        }
      }
      
      // If we're between characters, check if it's a pause between sentences
      if (lastSpokenCharIndex >= 0 && nextCharIndex >= 0) {
        final lastChar = alignment.characters[lastSpokenCharIndex];
        final gapDuration = alignment.characterStartTimesSeconds[nextCharIndex] - 
                           alignment.characterEndTimesSeconds[lastSpokenCharIndex];
        
        // If there's a gap > 100ms after sentence-ending punctuation, it's a pause
        if ('.!?'.contains(lastChar) && gapDuration > 0.1) {
          isInPause = true;
        } else {
          // Not a pause, use the last spoken character
          currentCharIndex = lastSpokenCharIndex;
        }
      } else if (lastSpokenCharIndex >= 0) {
        // No next character, use last spoken
        currentCharIndex = lastSpokenCharIndex;
      }
    }

    // Clear text during pauses
    if (isInPause) {
      currentSentence = '';
    }
    // If we found a current character, find its sentence boundaries
    else if (currentCharIndex >= 0) {
      // Find sentence start (look backwards for sentence ending punctuation)
      int sentenceStart = 0;
      for (int i = currentCharIndex - 1; i >= 0; i--) {
        final char = alignment.characters[i];
        if ('.!?'.contains(char)) {
          // Found punctuation, now find the first non-whitespace character after it
          sentenceStart = i + 1;
          while (sentenceStart < alignment.characters.length &&
              alignment.characters[sentenceStart] == ' ') {
            sentenceStart++;
          }
          break;
        }
      }

      // Find sentence end (look forwards for sentence ending punctuation)
      int sentenceEnd = alignment.characters.length - 1;
      for (int i = currentCharIndex; i < alignment.characters.length; i++) {
        final char = alignment.characters[i];
        if ('.!?'.contains(char)) {
          sentenceEnd = i;
          break;
        }
      }

      // Build current sentence up to the current character
      for (int i = sentenceStart; i <= currentCharIndex.clamp(sentenceStart, sentenceEnd); i++) {
        currentSentence += alignment.characters[i];
      }
    } else {
      // If no current character, find the last completed sentence
      int lastSentenceEnd = -1;

      for (int i = 0; i < alignment.characters.length; i++) {
        final charEndTime = alignment.characterEndTimesSeconds[i];
        final char = alignment.characters[i];

        if (charEndTime <= _currentTime) {
          if ('.!?'.contains(char)) {
            lastSentenceEnd = i;
          }
        } else {
          break;
        }
      }

      // Show the last completed sentence
      if (lastSentenceEnd >= 0) {
        int sentenceStart = 0;
        // Find where this sentence started
        for (int i = lastSentenceEnd - 1; i >= 0; i--) {
          final char = alignment.characters[i];
          if ('.!?'.contains(char)) {
            sentenceStart = i + 1;
            // Skip whitespace after punctuation
            while (sentenceStart < alignment.characters.length &&
                alignment.characters[sentenceStart] == ' ') {
              sentenceStart++;
            }
            break;
          }
        }

        for (int i = sentenceStart; i <= lastSentenceEnd; i++) {
          currentSentence += alignment.characters[i];
        }
      }
    }

    // Only update if text changed (to avoid unnecessary rebuilds)
    final trimmedSentence = currentSentence.trim();
    
    // Skip updates if text is too short (less than 2 chars) - keep showing previous text
    if (trimmedSentence.length < 2) {
      // Don't clear text, just skip the update
      return;
    }
    
    // Only update if text actually changed
    if (trimmedSentence != _currentText) {
      // Calculate what's new by comparing with current text
      
      if (trimmedSentence.startsWith(_currentText) && trimmedSentence.length > _currentText.length) {
        // Text is growing within same sentence - just update without animation
        setState(() {
          _currentText = trimmedSentence;
          _previousText = trimmedSentence;
          _newText = '';
        });
        _textFadeController.value = 1.0; // Keep at full opacity
      } else if (trimmedSentence.isEmpty) {
        // Keep text visible - don't clear to avoid empty box animation
      } else {
        // Text changed completely (new sentence) - show immediately from the start
        setState(() {
          _previousText = '';
          _newText = trimmedSentence;
          _currentText = trimmedSentence;
        });
        _textFadeController.forward(from: 0.0);
        
        // After animation, move to previous text
        Future.delayed(const Duration(milliseconds: 300), () {
          if (mounted && _currentText == trimmedSentence) {
            setState(() {
              _previousText = _currentText;
              _newText = '';
            });
          }
        });
      }
    }

    // Callback for animation frame updates (if needed)
    widget.onAnimationFrame?.call();
  }

  @override
  void dispose() {
    _timer?.cancel();
    _textFadeController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // Hide completely only when not playing or no alignment data
    if (!widget.isPlaying || widget.alignment == null) {
      return const SizedBox.shrink();
    }

    // Keep container visible but fade out when no text (prevents blink)
    // Also hide if text is less than 2 characters
    final hasText = _currentText.isNotEmpty && _currentText.length >= 2;

    return Positioned(
      left: 0,
      right: 0,
      bottom: MediaQuery.of(context).size.height * 0.25, // 25% from bottom (center-ish)
      child: IgnorePointer(  // Don't block touch events
        child: AnimatedOpacity(
          opacity: hasText ? 1.0 : 0.0,
          duration: const Duration(milliseconds: 150),
          child: Center(
            child: ClipRRect(
              borderRadius: BorderRadius.circular(16),
              child: BackdropFilter(
                filter: ImageFilter.blur(sigmaX: 16, sigmaY: 16),
                child: Container(
                    constraints: BoxConstraints(
                      maxWidth: MediaQuery.of(context).size.width * 0.8,
                    ),
                    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                        colors: [
                          Colors.white.withOpacity(0.08),
                          Colors.white.withOpacity(0.05),
                        ],
                      ),
                    ),
                  child: Stack(
                    children: [
                      // Base layer: Full current text for sizing (invisible)
                      Text(
                        _currentText.isNotEmpty ? _currentText : ' ',
                        textAlign: TextAlign.center,
                        strutStyle: const StrutStyle(
                          fontFamily: 'Alegreya',
                          fontSize: 14,
                          height: 1.3,
                          forceStrutHeight: true,
                        ),
                        style: const TextStyle(
                          fontFamily: 'Alegreya',
                          color: Colors.transparent,
                          fontSize: 14,
                          fontWeight: FontWeight.w500,
                          height: 1.3,
                        ),
                      ),
                      // Visible layer: Previous text + fading new text combined
                      Positioned.fill(
                        child: Align(
                          alignment: Alignment.center,
                          child: Text.rich(
                            TextSpan(
                              style: const TextStyle(
                                fontFamily: 'Alegreya',
                                color: Colors.white,
                                fontSize: 14,
                                fontWeight: FontWeight.w500,
                                height: 1.3,
                                shadows: [
                                  Shadow(
                                    color: Colors.black45,
                                    offset: Offset(0, 1),
                                    blurRadius: 2,
                                  ),
                                ],
                              ),
                              children: [
                                // Previous text (fully visible)
                                TextSpan(
                                  text: _previousText,
                                ),
                                // New text (fading in) - use a transparent to visible gradient effect
                                WidgetSpan(
                                  alignment: PlaceholderAlignment.baseline,
                                  baseline: TextBaseline.alphabetic,
                                  child: FadeTransition(
                                    opacity: _textFadeAnimation,
                                    child: Text(
                                      _newText,
                                      strutStyle: const StrutStyle(
                                        fontFamily: 'Alegreya',
                                        fontSize: 14,
                                        height: 1.3,
                                        forceStrutHeight: true,
                                      ),
                                      style: const TextStyle(
                                        fontFamily: 'Alegreya',
                                        color: Colors.white,
                                        fontSize: 14,
                                        fontWeight: FontWeight.w500,
                                        height: 1.3,
                                        shadows: [
                                          Shadow(
                                            color: Colors.black45,
                                            offset: Offset(0, 1),
                                            blurRadius: 2,
                                          ),
                                        ],
                                      ),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            strutStyle: const StrutStyle(
                              fontFamily: 'Alegreya',
                              fontSize: 14,
                              height: 1.3,
                              forceStrutHeight: true,
                            ),
                            textAlign: TextAlign.center,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

