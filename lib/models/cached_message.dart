import 'package:isar/isar.dart';

part 'cached_message.g.dart';

@collection
class CachedMessage {
  Id id = Isar.autoIncrement;
  
  late String messageId;
  late String content;
  late String type; // 'user' or 'ai'
  late DateTime timestamp;
  
  @Index()
  String? threadId;
  
  String? speaker;
  
  // Track if TTS has been played for this message
  late bool isPlayed;
  
  // Convert from ChatMessage to CachedMessage
  static CachedMessage fromChatMessage(dynamic chatMessage, String? threadId) {
    return CachedMessage()
      ..messageId = chatMessage.id
      ..content = chatMessage.content
      ..type = chatMessage.type
      ..timestamp = chatMessage.timestamp
      ..threadId = threadId
      ..speaker = chatMessage.speaker
      ..isPlayed = chatMessage.isPlayed;
  }
}

@collection
class CachedThread {
  Id id = Isar.autoIncrement;
  
  @Index(unique: true)
  late String threadId;
  
  late DateTime lastUpdated;
  
  String? userId;
  String? avatarId;
}

