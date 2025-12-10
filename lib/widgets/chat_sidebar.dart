import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../blocs/chat/chat_bloc_export.dart';
import 'package:intl/intl.dart';
import '../utils/toast_utils.dart';
import 'package:liquid_glass_renderer/liquid_glass_renderer.dart';

class ChatSidebar extends StatefulWidget {
  final ScrollController scrollController;
  final VoidCallback onClose;
  final Function(String) onFollowUpTap;

  const ChatSidebar({
    super.key,
    required this.scrollController,
    required this.onClose,
    required this.onFollowUpTap,
  });

  @override
  State<ChatSidebar> createState() => _ChatSidebarState();
}

class _ChatSidebarState extends State<ChatSidebar> {
  // No need to create or dispose scroll controller - it's passed from parent

  @override
  Widget build(BuildContext context) {
    return BackdropFilter(
      filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
      child: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              Colors.black.withOpacity(0.35),
              Colors.black.withOpacity(0.28),
            ],
          ),
        ),
        child: SafeArea(
          bottom:
              false, // Don't apply SafeArea to bottom (let input stay visible)
          child: Column(
            children: [
              // Top bar with back button
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                decoration: BoxDecoration(
                  border: Border(
                    bottom: BorderSide(
                      color: Colors.white.withOpacity(0.12),
                      width: 0.5,
                    ),
                  ),
                ),
                child: Row(
                  children: [
                    IconButton(
                      icon: Icon(Icons.arrow_back,
                          color: Colors.white.withOpacity(0.95)),
                      onPressed: widget.onClose,
                      padding: const EdgeInsets.all(8),
                      constraints: const BoxConstraints(),
                      iconSize: 22,
                    ),
                    const SizedBox(width: 10),
                    const Text(
                      'Chat with Sathya Sai Baba',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 17,
                        fontWeight: FontWeight.w600,
                        letterSpacing: 0.3,
                      ),
                    ),
                  ],
                ),
              ),

              // Messages list
              Expanded(
                child: BlocBuilder<ChatBloc, ChatState>(
                  // Only rebuild when messages actually change (prevent jitter from unrelated state changes)
                  buildWhen: (previous, current) {
                    if (previous is ChatLoaded && current is ChatLoaded) {
                      return previous.messages != current.messages ||
                          previous.isGenerating != current.isGenerating;
                    }
                    return true;
                  },
                  builder: (context, state) {
                    // Show empty state for initial or empty loaded state
                    if (state is ChatInitial ||
                        (state is ChatLoaded && state.messages.isEmpty)) {
                      return Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              Icons.forum_outlined,
                              size: 56,
                              color: Colors.white.withOpacity(0.2),
                            ),
                            const SizedBox(height: 20),
                            const Text(
                              'No messages yet',
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 24,
                                fontWeight: FontWeight.w300,
                              ),
                            ),
                            const SizedBox(height: 12),
                            Text(
                              'Ask Sathya Sai Baba a question',
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                color: Colors.white.withOpacity(0.5),
                                fontSize: 16,
                              ),
                            ),
                          ],
                        ),
                      );
                    }

                    if (state is ChatLoaded) {
                      final messages = state.messages;
                      final itemCount =
                          messages.length + (state.isGenerating ? 1 : 0);

                      return CustomScrollView(
                        controller: widget.scrollController,
                        reverse: true, // Start from bottom like messaging apps
                        physics: const BouncingScrollPhysics(
                          parent: AlwaysScrollableScrollPhysics(),
                        ),
                        slivers: [
                          SliverPadding(
                            padding: const EdgeInsets.fromLTRB(14, 8, 14, 110),
                            sliver: SliverList(
                              delegate: SliverChildBuilderDelegate(
                                (context, index) {
                                  // Show typing indicator as first item (bottom of reversed list)
                                  if (index == 0 && state.isGenerating) {
                                    return const _TypingIndicator();
                                  }

                                  // Get actual message index (accounting for reversed list and typing indicator)
                                  final messageIndex = messages.length -
                                      index -
                                      (state.isGenerating ? 0 : 1);
                                  final message = messages[messageIndex];

                                  // Check if we need to show date header
                                  final isLastInReversedList = index ==
                                      messages.length -
                                          (state.isGenerating ? 0 : 1);
                                  final showDate = isLastInReversedList ||
                                      (messageIndex < messages.length - 1);

                                  return _MessageItem(
                                    key: ValueKey(message.id),
                                    message: message,
                                    showDate: showDate,
                                    previousMessage: !isLastInReversedList &&
                                            messageIndex < messages.length - 1
                                        ? messages[messageIndex + 1]
                                        : null,
                                  );
                                },
                                childCount: itemCount,
                                addAutomaticKeepAlives: true,
                                addRepaintBoundaries: true,
                              ),
                            ),
                          ),
                        ],
                      );
                    }

                    return const SizedBox.shrink();
                  },
                ),
              ),

              // Follow-up questions
              BlocBuilder<ChatBloc, ChatState>(
                builder: (context, state) {
                  if (state is ChatLoaded &&
                      state.followUpQuestions.isNotEmpty) {
                    return Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        // Divider above follow-ups
                        Container(
                          height: 0.5,
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              colors: [
                                Colors.white.withOpacity(0),
                                Colors.white.withOpacity(0.15),
                                Colors.white.withOpacity(0),
                              ],
                            ),
                          ),
                        ),
                        Padding(
                          padding: const EdgeInsets.fromLTRB(18, 14, 18, 85),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(
                                'Keep exploring...',
                                style: TextStyle(
                                  color: Colors.white.withOpacity(0.55),
                                  fontSize: 13,
                                  fontStyle: FontStyle.italic,
                                  letterSpacing: 0.2,
                                ),
                              ),
                              const SizedBox(height: 14),
                              // Use ListView.builder for memory efficiency
                              ListView.builder(
                                shrinkWrap: true,
                                physics: const NeverScrollableScrollPhysics(),
                                itemCount: state.followUpQuestions.length,
                                itemBuilder: (context, index) {
                                  final question =
                                      state.followUpQuestions[index];
                                  final isLast = index ==
                                      state.followUpQuestions.length - 1;

                                  return Column(
                                    children: [
                                      InkWell(
                                        onTap: () {
                                          widget.onFollowUpTap(question);
                                          widget.onClose();
                                        },
                                        child: Padding(
                                          padding: const EdgeInsets.symmetric(
                                              vertical: 8),
                                          child: Row(
                                            crossAxisAlignment:
                                                CrossAxisAlignment.start,
                                            children: [
                                              Padding(
                                                padding: const EdgeInsets.only(
                                                    top: 2),
                                                child: Icon(
                                                  Icons
                                                      .subdirectory_arrow_right,
                                                  size: 20,
                                                  color: Colors.white
                                                      .withOpacity(0.7),
                                                ),
                                              ),
                                              const SizedBox(width: 12),
                                              Expanded(
                                                child: Text(
                                                  question,
                                                  style: const TextStyle(
                                                    color: Colors.white,
                                                    fontSize: 15,
                                                    height: 1.4,
                                                  ),
                                                ),
                                              ),
                                            ],
                                          ),
                                        ),
                                      ),
                                      // Simple divider
                                      if (!isLast)
                                        Container(
                                          height: 0.5,
                                          color: Colors.white.withOpacity(0.12),
                                        ),
                                    ],
                                  );
                                },
                              ),
                            ],
                          ),
                        ),
                      ],
                    );
                  }
                  return const SizedBox.shrink();
                },
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Message item widget (isolated for better scroll performance)
class _MessageItem extends StatefulWidget {
  final ChatMessage message;
  final bool showDate;
  final ChatMessage? previousMessage;

  const _MessageItem({
    super.key,
    required this.message,
    required this.showDate,
    this.previousMessage,
  });

  @override
  State<_MessageItem> createState() => _MessageItemState();
}

class _MessageItemState extends State<_MessageItem>
    with AutomaticKeepAliveClientMixin {
  @override
  bool get wantKeepAlive =>
      true; // Keep widget alive to prevent rebuilds during scroll

  // Cache expensive calculations
  late final DateTime messageTime;
  late final bool isUser;
  late final String formattedDate;
  late final String formattedTime;
  late final bool shouldShowDate;

  @override
  void initState() {
    super.initState();
    // Pre-calculate all expensive operations once
    isUser = widget.message.type == 'user';
    messageTime =
        DateTime.fromMillisecondsSinceEpoch(int.parse(widget.message.id));
    formattedDate =
        DateFormat('MMMM d, yyyy').format(messageTime).toUpperCase();
    formattedTime = DateFormat('h:mm a').format(messageTime);

    shouldShowDate = widget.showDate &&
        (widget.previousMessage == null ||
            !_isSameDay(
                messageTime,
                DateTime.fromMillisecondsSinceEpoch(
                    int.parse(widget.previousMessage!.id))));
  }

  @override
  Widget build(BuildContext context) {
    super.build(context); // Required for AutomaticKeepAliveClientMixin

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // Date header
        if (shouldShowDate)
          Padding(
            padding: const EdgeInsets.only(top: 16, bottom: 10),
            child: Center(
              child: Text(
                formattedDate,
                style: _dateHeaderStyle,
              ),
            ),
          ),

        // Message content
        if (isUser)
          // User message - simple bubble on right
          Align(
            alignment: Alignment.centerRight,
            child: Container(
              constraints: BoxConstraints(
                maxWidth: MediaQuery.of(context).size.width * 0.72,
              ),
              margin: const EdgeInsets.only(top: 14, bottom: 5),
              padding: const EdgeInsets.symmetric(
                horizontal: 15,
                vertical: 10,
              ),
              decoration: _userBubbleDecoration,
              child: Text(
                widget.message.content,
                style: _messageTextStyle,
              ),
            ),
          )
        else
          // Sai Baba's message - no bubble
          Padding(
            padding: const EdgeInsets.only(bottom: 4),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Padding(
                  padding: const EdgeInsets.only(bottom: 4),
                  child: Text(
                    'Sathya Sai Baba',
                    style: _speakerNameStyle,
                  ),
                ),
                Text(
                  widget.message.content,
                  style: _messageTextStyle,
                ),
              ],
            ),
          ),

        // Time and action buttons
        Padding(
          padding: const EdgeInsets.only(top: 2, bottom: 8),
          child: Row(
            mainAxisAlignment:
                isUser ? MainAxisAlignment.end : MainAxisAlignment.spaceBetween,
            children: [
              Text(
                formattedTime,
                style: _timeTextStyle,
              ),
              if (!isUser)
                Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: GestureDetector(
                    onTap: () {
                      Clipboard.setData(
                          ClipboardData(text: widget.message.content));
                      ToastUtils.showSuccess(context, 'Copied to clipboard');
                    },
                    child: Icon(
                      Icons.content_copy,
                      color: Colors.white.withOpacity(0.5),
                      size: 16,
                    ),
                  ),
                ),
            ],
          ),
        ),
      ],
    );
  }

  bool _isSameDay(DateTime a, DateTime b) {
    return a.year == b.year && a.month == b.month && a.day == b.day;
  }

  // Static const styles to avoid recreating on every build
  static final _dateHeaderStyle = TextStyle(
    color: Colors.white.withOpacity(0.38),
    fontSize: 11,
    letterSpacing: 1.2,
    fontWeight: FontWeight.w500,
  );

  static final _speakerNameStyle = TextStyle(
    color: Colors.white.withOpacity(0.58),
    fontSize: 12,
    fontWeight: FontWeight.w600,
    letterSpacing: 0.3,
  );

  static const _messageTextStyle = TextStyle(
    color: Colors.white,
    fontSize: 15,
    height: 1.4,
    letterSpacing: 0.1,
  );

  static final _timeTextStyle = TextStyle(
    color: Colors.white.withOpacity(0.38),
    fontSize: 10,
  );

  static final _userBubbleDecoration = BoxDecoration(
    color: Colors.white.withOpacity(0.18),
    borderRadius: const BorderRadius.all(Radius.circular(14)),
    border: Border.all(
      color: Colors.white.withOpacity(0.08),
      width: 0.5,
    ),
  );
}

/// Typing indicator widget (extracted for const optimization)
class _TypingIndicator extends StatelessWidget {
  const _TypingIndicator();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 8, bottom: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Sai Baba',
            style: TextStyle(
              color: Colors.white.withOpacity(0.6),
              fontSize: 12,
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 4),
          const Row(
            children: [
              _TypingDot(delay: 0),
              SizedBox(width: 8),
              _TypingDot(delay: 200),
              SizedBox(width: 8),
              _TypingDot(delay: 400),
            ],
          ),
        ],
      ),
    );
  }
}

/// Animated typing dot indicator
class _TypingDot extends StatefulWidget {
  final int delay;

  const _TypingDot({required this.delay});

  @override
  State<_TypingDot> createState() => _TypingDotState();
}

class _TypingDotState extends State<_TypingDot>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _animation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(milliseconds: 600),
      vsync: this,
    );

    _animation = Tween<double>(begin: 0.4, end: 1.0).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeInOut),
    );

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
    return FadeTransition(
      opacity: _animation,
      child: Container(
        width: 8,
        height: 8,
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.7),
          shape: BoxShape.circle,
        ),
      ),
    );
  }
}
