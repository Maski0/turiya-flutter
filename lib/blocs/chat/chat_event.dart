import 'package:equatable/equatable.dart';

/// Events for chat/message management
abstract class ChatEvent extends Equatable {
  const ChatEvent();

  @override
  List<Object?> get props => [];
}

/// Send a message to Sai Baba
class ChatMessageSent extends ChatEvent {
  final String message;
  final String? threadId;

  const ChatMessageSent({
    required this.message,
    this.threadId,
  });

  @override
  List<Object?> get props => [message, threadId];
}

/// Load conversation history
class ChatHistoryRequested extends ChatEvent {
  final String threadId;

  const ChatHistoryRequested(this.threadId);

  @override
  List<Object?> get props => [threadId];
}

/// Delete conversation history
class ChatHistoryDeleted extends ChatEvent {
  final String threadId;

  const ChatHistoryDeleted(this.threadId);

  @override
  List<Object?> get props => [threadId];
}

/// Clear local messages
class ChatMessagesCleared extends ChatEvent {
  const ChatMessagesCleared();
}

/// Add a local message (user input before sending)
class ChatLocalMessageAdded extends ChatEvent {
  final String content;
  final String type; // 'user' or 'ai'

  const ChatLocalMessageAdded({
    required this.content,
    required this.type,
  });

  @override
  List<Object?> get props => [content, type];
}

/// Start watching a thread (Observable pattern)
class ChatThreadWatchRequested extends ChatEvent {
  final String threadId;

  const ChatThreadWatchRequested(this.threadId);

  @override
  List<Object?> get props => [threadId];
}

/// Update message isPlayed status (for TTS tracking)
class ChatMessagePlayedStatusUpdated extends ChatEvent {
  final String messageId;
  final String threadId;
  final bool isPlayed;

  const ChatMessagePlayedStatusUpdated({
    required this.messageId,
    required this.threadId,
    required this.isPlayed,
  });

  @override
  List<Object?> get props => [messageId, threadId, isPlayed];
}

