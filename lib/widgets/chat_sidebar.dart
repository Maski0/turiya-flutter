import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../blocs/chat/chat_bloc_export.dart';
import 'package:intl/intl.dart';
import '../utils/toast_utils.dart';
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
  });

  @override
  State<ChatSidebar> createState() => _ChatSidebarState();
}

class _ChatSidebarState extends State<ChatSidebar> {
  String _getFormattedDate() {
    final now = DateTime.now();
    return DateFormat('MMMM d, yyyy').format(now).toUpperCase();
  }

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

            // Date header - Web: 16px, 500 weight, white/70
            Padding(
              padding: const EdgeInsets.only(bottom: 20, top: 8),
              child: Center(
                child: Text(
                  _getFormattedDate(),
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        color: Colors.white.withOpacity(0.7),
                        fontWeight: FontWeight.w500,
                        fontSize: 16,
                        letterSpacing: 0.5,
                      ),
                ),
              ),
            ),

            // Messages list
            Expanded(
              child: BlocBuilder<ChatBloc, ChatState>(
                buildWhen: (previous, current) {
                  if (previous is ChatLoaded && current is ChatLoaded) {
                    return previous.messages != current.messages ||
                        previous.isGenerating != current.isGenerating;
                  }
                  return true;
                },
                builder: (context, state) {
                  if (state is ChatInitial ||
                      (state is ChatLoaded && state.messages.isEmpty)) {
                    return const SizedBox.shrink();
                  }

                  if (state is ChatLoaded) {
                    final messages = state.messages;
                    final itemCount =
                        messages.length + (state.isGenerating ? 1 : 0);

                    return ListView.builder(
                      controller: widget.scrollController,
                      reverse: true,
                      padding: const EdgeInsets.fromLTRB(0, 8, 0, 80),
                      itemCount: itemCount,
                      itemBuilder: (context, index) {
                        // Show typing indicator as first item (bottom of reversed list)
                        if (index == 0 && state.isGenerating) {
                          return const _TypingIndicator();
                        }

                        final messageIndex = messages.length -
                            index -
                            (state.isGenerating ? 0 : 1);
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

            // Bottom padding for input bar
            const SizedBox(height: 70),
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
    final messageTime = DateTime.fromMillisecondsSinceEpoch(
      int.parse(message.id),
    );
    final formattedTime = DateFormat('h:mm a').format(messageTime);

    // Web: gap 16px between messages
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: isUser
          ? _buildUserMessage(context)
          : _buildAIMessage(context, formattedTime),
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
            style: const TextStyle(
              fontFamily: 'Alegreya',
              fontSize: 18,
              fontWeight: FontWeight.w500,
              color: Colors.white,
              height: 1.25, // line-height 125%
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildAIMessage(BuildContext context, String formattedTime) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Speaker name - Web: 14px, 500 weight, white/60, paddingLeft 16px
        Padding(
          padding: const EdgeInsets.only(left: 16, bottom: 4),
          child: Text(
            'Kṛṣṇa',
            style: TextStyle(
              fontFamily: 'Alegreya',
              fontSize: 14,
              fontWeight: FontWeight.w500,
              color: Colors.white.withOpacity(0.6),
              height: 1.25,
            ),
          ),
        ),

        // Message content - Web: padding 16px, 18px, line-height 140%
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Text(
            message.content,
            style: const TextStyle(
              fontFamily: 'Alegreya',
              fontSize: 18,
              fontWeight: FontWeight.w500,
              color: Colors.white,
              height: 1.4, // line-height 140%
            ),
          ),
        ),

        // Time and copy button - Web: mt-3 pt-2, 14px, white/50
        Padding(
          padding: const EdgeInsets.only(left: 16, right: 16, top: 12),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                formattedTime,
                style: TextStyle(
                  fontFamily: 'Alegreya',
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                  color: Colors.white.withOpacity(0.5),
                  height: 1.25,
                ),
              ),
              GestureDetector(
                onTap: () {
                  Clipboard.setData(ClipboardData(text: message.content));
                  ToastUtils.showSuccess(context, 'Copied to clipboard');
                },
                child: CopyIcon(
                  size: 18,
                  color: Colors.white.withOpacity(0.5),
                ),
              ),
            ],
          ),
        ),
      ],
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
            padding: const EdgeInsets.only(left: 16, bottom: 4),
            child: Text(
              'Sathya Sai Baba',
              style: TextStyle(
                fontFamily: 'Alegreya',
                fontSize: 14,
                fontWeight: FontWeight.w500,
                color: Colors.white.withOpacity(0.6),
                height: 1.25,
              ),
            ),
          ),

          // "Pondering" with colored dots - Web style
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Row(
              children: [
                const Text(
                  'Pondering',
                  style: TextStyle(
                    fontFamily: 'Alegreya',
                    fontSize: 18,
                    fontWeight: FontWeight.w500,
                    color: Colors.white,
                    height: 1.25,
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
