import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../blocs/chat/chat_bloc_export.dart';
import 'package:intl/intl.dart';

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

  // Helper to extract actual response from AI message JSON
  String _parseMessageContent(ChatMessage message) {
    // Content is already parsed in ChatMessage.fromJson, return directly
    return message.content;
  }

  @override
  Widget build(BuildContext context) {
    return BackdropFilter(
      filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
      child: Container(
        color: Colors.transparent,
        child: SafeArea(
          bottom: false, // Don't apply SafeArea to bottom (let input stay visible)
          child: Column(
            children: [
              // Messages list
              Expanded(
                child: BlocBuilder<ChatBloc, ChatState>(
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

                        return ListView.builder(
                          controller: widget.scrollController,
                          reverse: true, // Start from bottom like messaging apps
                          padding: const EdgeInsets.fromLTRB(20, 40, 20, 100),
                          itemCount: messages.length + (state.isGenerating ? 1 : 0),
                          itemBuilder: (context, index) {
                            // Show typing indicator as first item (bottom of reversed list)
                            if (index == 0 && state.isGenerating) {
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
                                    Row(
                                      children: [
                                        _TypingDot(delay: 0),
                                        const SizedBox(width: 8),
                                        _TypingDot(delay: 200),
                                        const SizedBox(width: 8),
                                        _TypingDot(delay: 400),
                                      ],
                                    ),
                                  ],
                                ),
                              );
                            }

                            // Get actual message index (accounting for reversed list and typing indicator)
                            final messageIndex = messages.length - index - (state.isGenerating ? 0 : 1);
                            final message = messages[messageIndex];
                            final isUser = message.type == 'user';
                            
                            // Show date header if last message in reversed list (first chronologically) or different day
                            final isLastInReversedList = index == messages.length - (state.isGenerating ? 0 : 1);
                            final showDate = isLastInReversedList || 
                              (messageIndex < messages.length - 1 && !_isSameDay(
                                DateTime.fromMillisecondsSinceEpoch(int.parse(message.id)),
                                DateTime.fromMillisecondsSinceEpoch(int.parse(messages[messageIndex + 1].id))
                              ));
                            
                            final messageTime = DateTime.fromMillisecondsSinceEpoch(int.parse(message.id));

                            return Column(
                              crossAxisAlignment: CrossAxisAlignment.stretch,
                              children: [
                                // Date header
                                if (showDate)
                                  Padding(
                                    padding: const EdgeInsets.only(top: 12, bottom: 8),
                                    child: Center(
                                      child: Text(
                                        DateFormat('MMMM d, yyyy').format(messageTime).toUpperCase(),
                                        style: TextStyle(
                                          color: Colors.white.withOpacity(0.4),
                                          fontSize: 11,
                                          letterSpacing: 1,
                                          fontWeight: FontWeight.w400,
                                        ),
                                      ),
                                    ),
                                  ),
                                
                                // Message content
                                if (isUser)
                                  // User message - glass bubble on right
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
                                      decoration: BoxDecoration(
                                        gradient: LinearGradient(
                                          begin: Alignment.topLeft,
                                          end: Alignment.bottomRight,
                                          colors: [
                                            Colors.white.withOpacity(0.25),
                                            Colors.white.withOpacity(0.15),
                                          ],
                                        ),
                                        borderRadius: BorderRadius.circular(12),
                                        boxShadow: [
                                          BoxShadow(
                                            color: Colors.white.withOpacity(0.1),
                                            blurRadius: 10,
                                            spreadRadius: 0,
                                          ),
                                        ],
                                      ),
                                      child: Text(
                                        _parseMessageContent(message),
                                        style: const TextStyle(
                                          color: Colors.white,
                                          fontSize: 15,
                                          height: 1.35,
                                        ),
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
                                        // Speaker name
                                        Padding(
                                          padding: const EdgeInsets.only(bottom: 4),
                                          child: Text(
                                            'Kṛṣṇa',
                                            style: TextStyle(
                                              color: Colors.white.withOpacity(0.6),
                                              fontSize: 12,
                                              fontWeight: FontWeight.w500,
                                            ),
                                          ),
                                        ),
                                        // Message text
                                        Text(
                                          _parseMessageContent(message),
                                          style: const TextStyle(
                                            color: Colors.white,
                                            fontSize: 15,
                                            height: 1.35,
                                          ),
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
                                      // Time (always first)
                                      Text(
                                        DateFormat('h:mm a').format(messageTime),
                                        style: TextStyle(
                                          color: Colors.white.withOpacity(0.4),
                                          fontSize: 11,
                                        ),
                                      ),
                                      if (!isUser)
                                        // Action buttons for Krishna's message (on the right)
                                        Padding(
                                          padding: const EdgeInsets.only(right: 8),
                                          child: Row(
                                            children: [
                                              GestureDetector(
                                                onTap: () {
                                                  // TODO: Play audio
                                                  ScaffoldMessenger.of(context).showSnackBar(
                                                    const SnackBar(
                                                      content: Text('Audio playback coming soon!'),
                                                      duration: Duration(seconds: 1),
                                                    ),
                                                  );
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
                                                  Clipboard.setData(ClipboardData(text: _parseMessageContent(message)));
                                                  ScaffoldMessenger.of(context).showSnackBar(
                                                    const SnackBar(
                                                      content: Text('Copied to clipboard'),
                                                      duration: Duration(seconds: 1),
                                                    ),
                                                  );
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
                          },
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
                      return Padding(
                        padding: const EdgeInsets.fromLTRB(20, 0, 20, 100),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Keep exploring...',
                              style: TextStyle(
                                color: Colors.white.withOpacity(0.6),
                                fontSize: 14,
                                fontStyle: FontStyle.italic,
                              ),
                            ),
                            const SizedBox(height: 16),
                            ...state.followUpQuestions.asMap().entries.map((entry) {
                              final index = entry.key;
                              final question = entry.value;
                              final isLast = index == state.followUpQuestions.length - 1;
                              
                              return Column(
                                children: [
                                  InkWell(
                                    onTap: () {
                                      widget.onFollowUpTap(question);
                                      widget.onClose();
                                    },
                                    child: Padding(
                                      padding: const EdgeInsets.symmetric(vertical: 12),
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
                                  // Gradient divider
                                  if (!isLast)
                                    Container(
                                      height: 1,
                                      decoration: BoxDecoration(
                                        gradient: LinearGradient(
                                          colors: [
                                            Colors.white.withOpacity(0),
                                            Colors.white.withOpacity(0.5),
                                            Colors.white.withOpacity(0),
                                          ],
                                        ),
                                      ),
                                    ),
                                ],
                              );
                            }).toList(),
                          ],
                        ),
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
  
  bool _isSameDay(DateTime a, DateTime b) {
    return a.year == b.year && a.month == b.month && a.day == b.day;
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

