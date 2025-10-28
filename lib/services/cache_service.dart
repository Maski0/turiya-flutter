import 'package:isar/isar.dart';
import '../models/cached_message.dart';
import '../blocs/chat/chat_bloc_export.dart';

class CacheService {
  late final Isar isar;
  
  CacheService(this.isar);
  
  /// Watch messages for a thread (Observable pattern)
  /// Returns a Stream that emits whenever messages change
  Stream<List<ChatMessage>> watchMessages(String threadId) {
    return isar.cachedMessages
        .where()
        .threadIdEqualTo(threadId)
        .sortByTimestamp()
        .watch(fireImmediately: true)
        .map((cachedMessages) {
      // Convert CachedMessages to ChatMessages
      return cachedMessages.map((cached) => ChatMessage(
        id: cached.messageId,
        content: cached.content,
        type: cached.type,
        timestamp: cached.timestamp,
        speaker: cached.speaker,
        isPlayed: cached.isPlayed,
      )).toList();
    });
  }
  
  /// Cache messages for a thread (This triggers the stream)
  Future<void> cacheMessages(List<ChatMessage> messages, String threadId, {List<String>? followUpQuestions}) async {
    await isar.writeTxn(() async {
      // Delete old messages for this thread first
      final oldMessages = await isar.cachedMessages
          .where()
          .threadIdEqualTo(threadId)
          .findAll();
      await isar.cachedMessages.deleteAll(oldMessages.map((m) => m.id).toList());
      
      // Convert ChatMessages to CachedMessages
      final cachedMessages = messages.map((msg) => 
        CachedMessage.fromChatMessage(msg, threadId)
      ).toList();
      
      // Save all messages (this will trigger the stream)
      await isar.cachedMessages.putAll(cachedMessages);
      
      // Update thread timestamp (find existing or create new)
      var thread = await isar.cachedThreads.filter()
          .threadIdEqualTo(threadId)
          .findFirst();
      
      if (thread == null) {
        thread = CachedThread()
          ..threadId = threadId
          ..lastUpdated = DateTime.now()
          ..followUpQuestions = followUpQuestions;
      } else {
        thread.lastUpdated = DateTime.now();
        thread.followUpQuestions = followUpQuestions;
      }
      
      await isar.cachedThreads.put(thread);
    });
  }
  
  /// Get cached follow-up questions for a thread
  Future<List<String>> getFollowUpQuestions(String threadId) async {
    final thread = await isar.cachedThreads.filter()
        .threadIdEqualTo(threadId)
        .findFirst();
    
    return thread?.followUpQuestions ?? [];
  }
  
  /// Get cached messages once (for compatibility)
  Future<List<ChatMessage>> getCachedMessages(String threadId) async {
    final cachedMessages = await isar.cachedMessages
        .where()
        .threadIdEqualTo(threadId)
        .sortByTimestamp()
        .findAll();
    
    // Convert CachedMessages back to ChatMessages
    return cachedMessages.map((cached) => ChatMessage(
      id: cached.messageId,
      content: cached.content,
      type: cached.type,
      timestamp: cached.timestamp,
      speaker: cached.speaker,
      isPlayed: cached.isPlayed,
    )).toList();
  }
  
  /// Update a specific message's isPlayed status
  Future<void> updateMessagePlayedStatus(String messageId, String threadId, bool isPlayed) async {
    await isar.writeTxn(() async {
      final message = await isar.cachedMessages
          .where()
          .threadIdEqualTo(threadId)
          .filter()
          .messageIdEqualTo(messageId)
          .findFirst();
      
      if (message != null) {
        message.isPlayed = isPlayed;
        await isar.cachedMessages.put(message);
      }
    });
  }
  
  /// Get last active thread ID
  Future<String?> getLastThreadId() async {
    final thread = await isar.cachedThreads
        .where()
        .sortByLastUpdatedDesc()
        .findFirst();
    
    return thread?.threadId;
  }
  
  /// Save last thread ID
  Future<void> saveThreadId(String threadId) async {
    await isar.writeTxn(() async {
      // Find existing or create new
      var thread = await isar.cachedThreads.filter()
          .threadIdEqualTo(threadId)
          .findFirst();
      
      if (thread == null) {
        thread = CachedThread()
          ..threadId = threadId
          ..lastUpdated = DateTime.now();
      } else {
        thread.lastUpdated = DateTime.now();
      }
      
      await isar.cachedThreads.put(thread);
    });
  }
  
  /// Clear all messages for a thread
  Future<void> clearThread(String threadId) async {
    await isar.writeTxn(() async {
      final messages = await isar.cachedMessages
          .where()
          .threadIdEqualTo(threadId)
          .findAll();
      
      await isar.cachedMessages.deleteAll(messages.map((m) => m.id).toList());
      
      final thread = await isar.cachedThreads
          .where()
          .threadIdEqualTo(threadId)
          .findFirst();
      
      if (thread != null) {
        await isar.cachedThreads.delete(thread.id);
      }
    });
  }
  
  /// Clear all cached data
  Future<void> clearAll() async {
    await isar.writeTxn(() async {
      await isar.cachedMessages.clear();
      await isar.cachedThreads.clear();
    });
  }
}

