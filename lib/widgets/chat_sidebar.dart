import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../blocs/chat/chat_bloc_export.dart';
import 'package:intl/intl.dart';
import '../utils/toast_utils.dart';

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
      filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
      child: Container(
        color: Colors.black.withOpacity(0.3),
        child: SafeArea(
          bottom: false, // Don't apply SafeArea to bottom (let input stay visible)
          child: Column(
            children: [
              // Top bar with back button
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                decoration: BoxDecoration(
                  border: Border(
                    bottom: BorderSide(
                      color: Colors.white.withOpacity(0.1),
                      width: 1,
                    ),
                  ),
                ),
                child: Row(
                  children: [
                    IconButton(
                      icon: const Icon(Icons.arrow_back, color: Colors.white),
                      onPressed: widget.onClose,
                      padding: const EdgeInsets.all(8),
                      constraints: const BoxConstraints(),
                      iconSize: 24,
                    ),
                    const SizedBox(width: 8),
                    const Text(
                      'Chat with Kṛṣṇa',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 18,
                        fontWeight: FontWeight.w500,
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
                      if (state is ChatInitial || (state is ChatLoaded && state.messages.isEmpty)) {
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
                                  'Ask Kṛṣṇa a question',
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
                        final itemCount = messages.length + (state.isGenerating ? 1 : 0);

                        return CustomScrollView(
                          controller: widget.scrollController,
                          reverse: true, // Start from bottom like messaging apps
                          physics: const BouncingScrollPhysics(
                            parent: AlwaysScrollableScrollPhysics(),
                          ),
                          slivers: [
                            SliverPadding(
                              padding: const EdgeInsets.fromLTRB(10, 0, 10, 20),
                              sliver: SliverList(
                                delegate: SliverChildBuilderDelegate(
                                  (context, index) {
                            // Show typing indicator as first item (bottom of reversed list)
                            if (index == 0 && state.isGenerating) {
                                      return const _TypingIndicator();
                            }

                            // Get actual message index (accounting for reversed list and typing indicator)
                            final messageIndex = messages.length - index - (state.isGenerating ? 0 : 1);
                            final message = messages[messageIndex];
                            
                                    // Check if we need to show date header
                            final isLastInReversedList = index == messages.length - (state.isGenerating ? 0 : 1);
                            final showDate = isLastInReversedList || 
                                      (messageIndex < messages.length - 1);

                                    return _MessageItem(
                                      key: ValueKey(message.id),
                                      message: message,
                                      showDate: showDate,
                                      previousMessage: !isLastInReversedList && messageIndex < messages.length - 1
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
                    if (state is ChatLoaded && state.followUpQuestions.isNotEmpty) {
                      return Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          // Divider above follow-ups
                          Container(
                            height: 1,
                            color: Colors.white.withOpacity(0.1),
                          ),
                          Padding(
                            padding: const EdgeInsets.fromLTRB(16, 12, 16, 80),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                              mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              'Keep exploring...',
                              style: TextStyle(
                                color: Colors.white.withOpacity(0.6),
                                fontSize: 14,
                                fontStyle: FontStyle.italic,
                              ),
                            ),
                                const SizedBox(height: 12),
                            // Use ListView.builder for memory efficiency
                            ListView.builder(
                              shrinkWrap: true,
                              physics: const NeverScrollableScrollPhysics(),
                              itemCount: state.followUpQuestions.length,
                              itemBuilder: (context, index) {
                                final question = state.followUpQuestions[index];
                              final isLast = index == state.followUpQuestions.length - 1;
                              
                              return Column(
                                children: [
                                  InkWell(
                                    onTap: () {
                                      widget.onFollowUpTap(question);
                                      widget.onClose();
                                    },
                                    child: Padding(
                                      padding: const EdgeInsets.symmetric(vertical: 8),
                                      child: Row(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Padding(
                                            padding: const EdgeInsets.only(top: 2),
                                            child: Icon(
                                              Icons.subdirectory_arrow_right,
                                              size: 20,
                                              color: Colors.white.withOpacity(0.7),
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
                                    // Simple divider (removed gradient for performance)
                                  if (!isLast)
                                    Container(
                                      height: 1,
                                        color: Colors.white.withOpacity(0.15),
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

class _MessageItemState extends State<_MessageItem> with AutomaticKeepAliveClientMixin {
  @override
  bool get wantKeepAlive => true; // Keep widget alive to prevent rebuilds during scroll

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
    messageTime = DateTime.fromMillisecondsSinceEpoch(int.parse(widget.message.id));
    formattedDate = DateFormat('MMMM d, yyyy').format(messageTime).toUpperCase();
    formattedTime = DateFormat('h:mm a').format(messageTime);
    
    shouldShowDate = widget.showDate && 
      (widget.previousMessage == null || 
       !_isSameDay(messageTime, DateTime.fromMillisecondsSinceEpoch(int.parse(widget.previousMessage!.id))));
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
            padding: const EdgeInsets.only(top: 12, bottom: 8),
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
                maxWidth: MediaQuery.of(context).size.width * 0.7,
              ),
              margin: const EdgeInsets.only(top: 12, bottom: 4),
              padding: const EdgeInsets.symmetric(
                horizontal: 14,
                vertical: 8,
              ),
              decoration: _userBubbleDecoration,
              child: Text(
                widget.message.content,
                style: _messageTextStyle,
              ),
            ),
          )
        else
          // Krishna's message - no bubble
          Padding(
            padding: const EdgeInsets.only(bottom: 4),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Padding(
                  padding: const EdgeInsets.only(bottom: 4),
                  child: Text(
                    'Kṛṣṇa',
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
            mainAxisAlignment: isUser 
                ? MainAxisAlignment.end 
                : MainAxisAlignment.spaceBetween,
            children: [
              Text(
                formattedTime,
                style: _timeTextStyle,
              ),
              if (!isUser)
                Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: Row(
                    children: [
                      GestureDetector(
                        onTap: () {
                          ToastUtils.showInfo(context, 'Audio playback coming soon!');
                        },
                        child: Icon(
                          Icons.play_arrow,
                          color: Colors.white.withOpacity(0.5),
                          size: 18,
                        ),
                      ),
                      const SizedBox(width: 14),
                      GestureDetector(
                        onTap: () {
                          Clipboard.setData(ClipboardData(text: widget.message.content));
                          ToastUtils.showSuccess(context, 'Copied to clipboard');
                        },
                        child: Icon(
                          Icons.content_copy,
                          color: Colors.white.withOpacity(0.5),
                          size: 16,
                        ),
                      ),
                    ],
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
    color: Colors.white.withOpacity(0.4),
    fontSize: 11,
    letterSpacing: 1,
    fontWeight: FontWeight.w400,
  );
  
  static final _speakerNameStyle = TextStyle(
    color: Colors.white.withOpacity(0.6),
    fontSize: 12,
    fontWeight: FontWeight.w500,
  );
  
  static const _messageTextStyle = TextStyle(
    color: Colors.white,
    fontSize: 15,
    height: 1.35,
  );
  
  static final _timeTextStyle = TextStyle(
    color: Colors.white.withOpacity(0.4),
    fontSize: 11,
  );
  
  static final _userBubbleDecoration = BoxDecoration(
    color: Colors.white.withOpacity(0.20),
    borderRadius: const BorderRadius.all(Radius.circular(12)),
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
            'Kṛṣṇa',
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

class _TypingDotState extends State<_TypingDot> with SingleTickerProviderStateMixin {
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

