import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../blocs/chat/chat_bloc_export.dart';
import '../theme/app_theme.dart';
import '../utils/toast_utils.dart';
import 'icons/arrow_enter_left_icon.dart';
import 'icons/copy_icon.dart';

class ChatSidebar extends StatefulWidget {
  final ScrollController scrollController;
  final VoidCallback onClose;
  final Function(String) onFollowUpTap;
  final VoidCallback onLoginTap;
  final TextEditingController messageController;
  final VoidCallback onSendMessage;
  final bool isRecording;
  final bool isAudioPlaying;
  final VoidCallback onMicTap;
  final VoidCallback? onStopAudio;
  final double bottomPadding; // Space for input bar + keyboard

  const ChatSidebar({
    super.key,
    required this.scrollController,
    required this.onClose,
    required this.onFollowUpTap,
    required this.onLoginTap,
    required this.messageController,
    required this.onSendMessage,
    required this.isRecording,
    required this.isAudioPlaying,
    required this.onMicTap,
    this.onStopAudio,
    this.bottomPadding = 90, // Default space for input bar
  });

  @override
  State<ChatSidebar> createState() => _ChatSidebarState();
}

class _ChatSidebarState extends State<ChatSidebar> {
  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: Color(0x03FFFFFF), // Web: rgba(255, 255, 255, 0.01)
      ),
      child: SafeArea(
        child: Column(
          children: [
            // Top spacing to start below the close button
            const SizedBox(height: 70),

            // Top divider
            Padding(
              padding: const EdgeInsets.only(top: 12),
              child: Container(
                height: 1,
                color: Colors.white.withOpacity(0.1),
              ),
            ),

            // Messages list
            Expanded(
              child: BlocBuilder<ChatBloc, ChatState>(
                // Always rebuild to ensure messages show instantly
                builder: (context, state) {
                  if (state is ChatInitial ||
                      (state is ChatLoaded && state.messages.isEmpty)) {
                    return const SizedBox.shrink();
                  }

                  if (state is ChatLoaded) {
                    final messages = state.messages;
                    final followUps = state.followUpQuestions;
                    final isGenerating = state.isGenerating;
                    final hasFollowUps = followUps.isNotEmpty && !isGenerating;

                    // +1 for typing indicator when generating
                    // +1 for follow-up section when has follow-ups
                    final itemCount = messages.length +
                        (isGenerating ? 1 : 0) +
                        (hasFollowUps ? 1 : 0);

                    return ListView.builder(
                      controller: widget.scrollController,
                      reverse: true,
                      padding: const EdgeInsets.fromLTRB(0, 8, 0, 16),
                      itemCount: itemCount,
                      itemBuilder: (context, index) {
                        // Show typing indicator as first item (bottom of reversed list)
                        if (index == 0 && isGenerating) {
                          return const _TypingIndicator();
                        }

                        // Show follow-ups as first item when not generating
                        if (index == 0 && hasFollowUps) {
                          return _FollowUpSection(
                            questions: followUps,
                            onQuestionTap: widget.onFollowUpTap,
                          );
                        }

                        // Adjust index for messages
                        int adjustedIndex = index;
                        if (isGenerating) adjustedIndex -= 1;
                        if (hasFollowUps && !isGenerating) adjustedIndex -= 1;

                        final messageIndex =
                            messages.length - adjustedIndex - 1;

                        if (messageIndex < 0 ||
                            messageIndex >= messages.length) {
                          return const SizedBox.shrink();
                        }

                        final message = messages[messageIndex];

                        return _MessageItem(
                          key: ValueKey(message.id),
                          message: message,
                        );
                      },
                    );
                  }

                  return const SizedBox.shrink();
                },
              ),
            ),

            // Divider above input bar - adjusts with keyboard
            Padding(
              padding: EdgeInsets.only(bottom: widget.bottomPadding),
              child: Container(
                height: 1,
                color: Colors.white.withOpacity(0.1),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Message item widget matching web ChatWindow exactly
class _MessageItem extends StatelessWidget {
  final ChatMessage message;

  const _MessageItem({super.key, required this.message});

  @override
  Widget build(BuildContext context) {
    final isUser = message.type == 'user';

    // Web: gap 16px between messages
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: isUser ? _buildUserMessage(context) : _buildAIMessage(context),
    );
  }

  Widget _buildUserMessage(BuildContext context) {
    // Web: rounded-2xl rounded-tr-md, background #FFFFFF14, border 1px solid #FFFFFF14
    // padding 16px, max-width 80%
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Align(
        alignment: Alignment.centerRight,
        child: Container(
          constraints: BoxConstraints(
            maxWidth: MediaQuery.of(context).size.width * 0.8,
          ),
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: const Color(0x14FFFFFF), // #FFFFFF14
            borderRadius: const BorderRadius.only(
              topLeft: Radius.circular(16),
              topRight: Radius.circular(6), // rounded-tr-md
              bottomLeft: Radius.circular(16),
              bottomRight: Radius.circular(16),
            ),
            border: Border.all(
              color: const Color(0x14FFFFFF), // #FFFFFF14
              width: 1,
            ),
          ),
          child: Text(
            message.content,
            style: Theme.of(context).textTheme.bodyLarge?.copyWith(
              fontWeight: FontWeight.w500,
                  height: 1.25,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildAIMessage(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Speaker name
        Padding(
          padding: const EdgeInsets.only(left: 16, bottom: 12),
          child: Text(
            'Kṛṣṇa',
            style: Theme.of(context).textTheme.titleSmall?.copyWith(
                  color: AppTheme.tertiaryWhite,
            ),
          ),
        ),

        // Message content
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Text(
            message.content,
            style: Theme.of(context).textTheme.bodyLarge?.copyWith(
              fontWeight: FontWeight.w500,
                  height: 1.4,
            ),
          ),
        ),

        // Copy button
        Padding(
          padding: const EdgeInsets.only(left: 16, right: 16, top: 12),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: () async {
                  await Clipboard.setData(ClipboardData(text: message.content));
                  if (context.mounted) {
                  ToastUtils.showSuccess(context, 'Copied to clipboard');
                  }
                },
                child: Padding(
                  padding: const EdgeInsets.all(8),
                child: CopyIcon(
                  size: 18,
                    color: AppTheme.subtleWhite,
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

/// Follow-up questions section - matches web FollowUpButtons
class _FollowUpSection extends StatelessWidget {
  final List<String> questions;
  final Function(String) onQuestionTap;

  const _FollowUpSection({
    required this.questions,
    required this.onQuestionTap,
  });

  @override
  Widget build(BuildContext context) {
    if (questions.isEmpty) return const SizedBox.shrink();

    return Padding(
      padding: const EdgeInsets.only(left: 16, right: 16, top: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header text: "Keep exploring..."
          Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: Text(
              'Keep exploring...',
              style: TextStyle(
                fontFamily: 'Alegreya',
                fontSize: 12,
                fontWeight: FontWeight.w400,
                color: Colors.white.withOpacity(0.48),
                height: 1.25,
              ),
            ),
          ),

          // Questions list
          ...questions.asMap().entries.map((entry) {
            final index = entry.key;
            final question = entry.value;
            final isFirst = index == 0;
            final isLast = index == questions.length - 1;

            return Column(
              children: [
                // Question button
                GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onTap: () => onQuestionTap(question),
                  child: Padding(
                    padding: EdgeInsets.only(
                      top: isFirst ? 0 : 12,
                      bottom: isLast ? 0 : 12,
                    ),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Arrow icon
                        const Padding(
                          padding: EdgeInsets.only(top: 2),
                          child: ArrowEnterLeftIcon(
                            size: 20,
                            color: Colors.white,
                          ),
                        ),
                        const SizedBox(width: 12),

                        // Question text
                        Expanded(
                          child: Text(
                            question,
                            style: const TextStyle(
                              fontFamily: 'Alegreya',
                              fontSize: 16,
                              fontWeight: FontWeight.w500,
                              color: Colors.white,
                              height: 1.25,
                            ),
                          ),
                        ),

                        // "✨ New" badge for first item
                        if (isFirst) ...[
                          const SizedBox(width: 8),
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 8, vertical: 4),
                            decoration: BoxDecoration(
                              color: Colors.white.withOpacity(0.1),
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(
                                color: Colors.white.withOpacity(0.08),
                                width: 1,
                              ),
                            ),
                            child: const Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Text(
                                  '✨',
                                  style: TextStyle(fontSize: 10),
                                ),
                                SizedBox(width: 4),
                                Text(
                                  'New',
                                  style: TextStyle(
                                    fontFamily: 'Alegreya',
                                    fontSize: 12,
                                    fontWeight: FontWeight.w500,
                                    color: Colors.white,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                ),

                // Divider between items (not after last)
                if (!isLast)
                  Container(
                    height: 1,
                    color: Colors.white.withOpacity(0.08),
                  ),
              ],
            );
          }),
        ],
      ),
    );
  }
}

/// Typing indicator matching web exactly
class _TypingIndicator extends StatelessWidget {
  const _TypingIndicator();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Speaker name
          Padding(
            padding: const EdgeInsets.only(left: 16, bottom: 12),
            child: Text(
              'Kṛṣṇa',
              style: Theme.of(context).textTheme.titleSmall?.copyWith(
                    color: AppTheme.tertiaryWhite,
              ),
            ),
          ),

          // "Pondering" with colored dots - Web style
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Row(
              children: [
                Text(
                  'Pondering',
                  style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                    fontWeight: FontWeight.w500,
                        height: 1.4,
                  ),
                ),
                const SizedBox(width: 8),
                // Colored bouncing dots matching web
                _AnimatedDot(color: const Color(0xFFFF0000), delay: 0),
                const SizedBox(width: 4),
                _AnimatedDot(color: const Color(0xFFFFA569), delay: 150),
                const SizedBox(width: 4),
                _AnimatedDot(color: const Color(0xFFA7A6FB), delay: 300),
                const SizedBox(width: 4),
                _AnimatedDot(color: const Color(0xFF046E80), delay: 450),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Animated bouncing dot
class _AnimatedDot extends StatefulWidget {
  final Color color;
  final int delay;

  const _AnimatedDot({required this.color, required this.delay});

  @override
  State<_AnimatedDot> createState() => _AnimatedDotState();
}

class _AnimatedDotState extends State<_AnimatedDot>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _animation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(milliseconds: 500),
      vsync: this,
    );

    // Web uses cubic-bezier(0.68, -0.55, 0.27, 1.55) - bouncy effect
    _animation = Tween<double>(
      begin: 0,
      end: -6,
    ).animate(CurvedAnimation(
      parent: _controller,
      curve: const Cubic(0.68, -0.55, 0.27, 1.55),
    ));

    Future.delayed(Duration(milliseconds: widget.delay), () {
      if (mounted) {
        _controller.repeat(reverse: true);
      }
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _animation,
      builder: (context, child) {
        return Transform.translate(
          offset: Offset(0, _animation.value),
          child: Container(
            width: 4,
            height: 4,
            decoration: BoxDecoration(
              color: widget.color,
              shape: BoxShape.circle,
            ),
          ),
        );
      },
    );
  }
}
