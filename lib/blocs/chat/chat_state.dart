import 'dart:convert';
import 'package:equatable/equatable.dart';

/// State for chat/messages
abstract class ChatState extends Equatable {
  const ChatState();

  @override
  List<Object?> get props => [];
}

/// Initial state
class ChatInitial extends ChatState {
  const ChatInitial();
}

/// Loading state
class ChatLoading extends ChatState {
  final String? message;

  const ChatLoading({this.message});

  @override
  List<Object?> get props => [message];
}

/// Messages loaded
class ChatLoaded extends ChatState {
  final List<ChatMessage> messages;
  final String? threadId;
  final List<String> followUpQuestions;
  final bool isGenerating;
  final String? pendingMessage;

  const ChatLoaded({
    required this.messages,
    this.threadId,
    this.followUpQuestions = const [],
    this.isGenerating = false,
    this.pendingMessage,
  });

  @override
  List<Object?> get props => [messages, threadId, followUpQuestions, isGenerating, pendingMessage];

  ChatLoaded copyWith({
    List<ChatMessage>? messages,
    String? threadId,
    List<String>? followUpQuestions,
    bool? isGenerating,
    String? pendingMessage,
  }) {
    return ChatLoaded(
      messages: messages ?? this.messages,
      threadId: threadId ?? this.threadId,
      followUpQuestions: followUpQuestions ?? this.followUpQuestions,
      isGenerating: isGenerating ?? this.isGenerating,
      pendingMessage: pendingMessage,
    );
  }
}

/// Error state
class ChatError extends ChatState {
  final String message;

  const ChatError(this.message);

  @override
  List<Object?> get props => [message];
}

/// Chat message model
class ChatMessage {
  final String id;
  final String content;
  final String type; // 'user' or 'ai'
  final DateTime timestamp;
  final String? speaker;
  final bool isPlayed; // Track if TTS has been played for this message

  ChatMessage({
    required this.id,
    required this.content,
    required this.type,
    DateTime? timestamp,
    this.speaker,
    this.isPlayed = true, // Default to true for existing messages
  }) : timestamp = timestamp ?? DateTime.now();

  factory ChatMessage.fromJson(Map<String, dynamic> json) {
    // Backend uses "human" for user messages, map it to "user"
    String messageType = json['type'] ?? 'user';
    if (messageType == 'human') {
      messageType = 'user';
    }
    
    // Parse content - if it's AI message with JSON, extract the response
    String content = json['content'] ?? '';
    if (messageType == 'ai' && content.isNotEmpty) {
      try {
        final parsed = jsonDecode(content);
        // If content is JSON with a 'response' field, extract it
        if (parsed is Map && parsed.containsKey('response')) {
          content = parsed['response'];
        }
      } catch (e) {
        // If not JSON or parsing fails, use content as-is
      }
    }
    
    return ChatMessage(
      id: json['id'] ?? DateTime.now().millisecondsSinceEpoch.toString(),
      content: content,
      type: messageType,
      timestamp: json['timestamp'] != null
          ? DateTime.tryParse(json['timestamp']) ?? DateTime.now()
          : DateTime.now(),
      speaker: json['speaker'],
      isPlayed: json['isPlayed'] ?? true, // Default to true for backend messages
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'content': content,
      'type': type,
      'timestamp': timestamp.toIso8601String(),
      'speaker': speaker,
      'isPlayed': isPlayed,
    };
  }
  
  /// Create a copy of this message with updated fields
  ChatMessage copyWith({
    String? id,
    String? content,
    String? type,
    DateTime? timestamp,
    String? speaker,
    bool? isPlayed,
  }) {
    return ChatMessage(
      id: id ?? this.id,
      content: content ?? this.content,
      type: type ?? this.type,
      timestamp: timestamp ?? this.timestamp,
      speaker: speaker ?? this.speaker,
      isPlayed: isPlayed ?? this.isPlayed,
    );
  }
}

