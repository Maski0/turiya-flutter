import 'dart:convert';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../services/backend_api_service.dart';
import '../../services/cache_service.dart';
import '../../services/livekit_service.dart';
import 'chat_event.dart';
import 'chat_state.dart';

/// BLoC for managing chat/message state
class ChatBloc extends Bloc<ChatEvent, ChatState> {
  final BackendApiService _backendApi;
  final CacheService _cacheService;
  final LiveKitService _liveKitService;

  ChatBloc({
    BackendApiService? backendApi,
    required CacheService cacheService,
    required LiveKitService liveKitService,
  })  : _backendApi = backendApi ?? BackendApiService(),
        _cacheService = cacheService,
        _liveKitService = liveKitService,
        super(const ChatInitial()) {
    on<ChatMessageSent>(_onMessageSent);
    on<ChatHistoryRequested>(_onHistoryRequested);
    on<ChatHistoryDeleted>(_onHistoryDeleted);
    on<ChatMessagesCleared>(_onMessagesCleared);
    on<ChatLocalMessageAdded>(_onLocalMessageAdded);
    on<ChatLastAiMessageUpdated>(_onLastAiMessageUpdated);
    on<ChatThreadWatchRequested>(_onThreadWatchRequested);
    on<ChatMessagePlayedStatusUpdated>(_onMessagePlayedStatusUpdated);
    
    // Listen to LiveKit messages
    _liveKitService.onMessageReceived.listen((messageJson) {
      try {
        final data = jsonDecode(messageJson);
        // Assuming the agent sends { "response": "..." } or similar
        // Adjust based on actual agent output format
        final content = data['response'] ?? data['message'] ?? messageJson;
        add(ChatLastAiMessageUpdated(content: content));
      } catch (e) {
        // If not JSON, treat as plain text
        add(ChatLastAiMessageUpdated(content: messageJson));
      }
    });
  }

  /// Handle sending a message (Observable pattern)
  Future<void> _onMessageSent(
    ChatMessageSent event,
    Emitter<ChatState> emit,
  ) async {
    // Get current messages
    List<ChatMessage> currentMessages = [];
    String? currentThreadId = event.threadId;
    
    if (state is ChatLoaded) {
      final loaded = state as ChatLoaded;
      currentMessages = List.from(loaded.messages);
      currentThreadId = loaded.threadId ?? currentThreadId;
    }

    // Add user message immediately
    final userMessage = ChatMessage(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      content: event.message,
      type: 'user',
    );
    currentMessages.add(userMessage);
    
    // Save user message to cache immediately (triggers stream)
    // Also clear old follow-ups from cache
    if (currentThreadId != null) {
      await _cacheService.cacheMessages(
        currentMessages, 
        currentThreadId,
        followUpQuestions: [], // Clear old follow-ups when sending new message
      );
    }

    // Show loading state and clear old follow-ups
    if (state is ChatLoaded) {
      emit((state as ChatLoaded).copyWith(
        isGenerating: true,
        followUpQuestions: [], // Clear old follow-ups when starting new message
      ));
    }

    print('🚀 Sending message via LiveKit (same as beta.turiya.now)...');

    try {
      // Send via LiveKit chat (web beta: await sendMessageRef.current(message))
      // Agent will receive it and respond with audio + text transcription
      await _liveKitService.sendMessage(event.message);
      
      print('✅ Message sent via LiveKit chat');
      print('   Agent will respond with audio track + text transcription');
      
      // Keep isGenerating=true state
      // Agent response will come via onMessageReceived listener
      
    } catch (e) {
      print('❌ Error sending message: $e');
      
      // Remove the optimistically added user message
      currentMessages.removeLast();
      
      // Get current follow-ups before updating cache
      final currentFollowUps = state is ChatLoaded ? (state as ChatLoaded).followUpQuestions : <String>[];
      
      // Update cache to reflect removal
      if (currentThreadId != null) {
        await _cacheService.cacheMessages(
          currentMessages, 
          currentThreadId,
          followUpQuestions: currentFollowUps,
        );
      }
      
      // Show error toast
      emit(ChatError(e.toString().replaceAll('Exception: ', '')));
      
      // Restore to ChatLoaded state with pending message after showing error
      await Future.delayed(const Duration(seconds: 2));
      emit(ChatLoaded(
        messages: currentMessages,
        threadId: currentThreadId,
        followUpQuestions: currentFollowUps,
        isGenerating: false, // Make sure loading is stopped
        pendingMessage: event.message, // Restore message in input field
      ));
    }
  }

  /// Load conversation history (Observable pattern)
  Future<void> _onHistoryRequested(
    ChatHistoryRequested event,
    Emitter<ChatState> emit,
  ) async {
    print('📜 ChatHistoryRequested for thread: ${event.threadId}');
    
    // Start watching the thread first (instant cache load)
    print('👁️ Starting to watch thread: ${event.threadId}');
    add(ChatThreadWatchRequested(event.threadId));
    
    // Then fetch fresh data from backend
    try {
      print('🌐 Fetching history from backend for thread: ${event.threadId}');
      final history = await _backendApi.getHistory(event.threadId);
      
      final messages = (history['messages'] as List)
          .map((msg) => ChatMessage.fromJson(msg))
          .toList();

      print('✅ Received ${messages.length} messages from backend');
      
      // Get cached follow-ups to preserve them
      final cachedFollowUps = await _cacheService.getFollowUpQuestions(event.threadId);
      
      // Save to cache (this will trigger the stream and update UI)
      await _cacheService.cacheMessages(messages, event.threadId, followUpQuestions: cachedFollowUps);
      print('💾 Cached ${messages.length} messages');
    } catch (e) {
      // If backend fails, cache will still show (if any)
      print('⚠️ Failed to load history from backend: $e');
      // Stream will handle showing cached data or empty state
    }
  }

  /// Delete conversation history
  Future<void> _onHistoryDeleted(
    ChatHistoryDeleted event,
    Emitter<ChatState> emit,
  ) async {
    emit(const ChatLoading(message: 'Clearing history...'));

    try {
      await _backendApi.deleteHistory(event.threadId);
      
      emit(const ChatLoaded(messages: []));
    } catch (e) {
      emit(ChatError('Failed to delete history: ${e.toString()}'));
    }
  }

  /// Clear local messages
  Future<void> _onMessagesCleared(
    ChatMessagesCleared event,
    Emitter<ChatState> emit,
  ) async {
    emit(const ChatLoaded(messages: []));
  }

  /// Add local message
  Future<void> _onLocalMessageAdded(
    ChatLocalMessageAdded event,
    Emitter<ChatState> emit,
  ) async {
    List<ChatMessage> currentMessages = [];
    String? currentThreadId;

    if (state is ChatLoaded) {
      final loaded = state as ChatLoaded;
      currentMessages = List.from(loaded.messages);
      currentThreadId = loaded.threadId;
    }

    final message = ChatMessage(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      content: event.content,
      type: event.type,
      speaker: event.type == 'ai' ? 'Kṛṣṇa' : null,
    );

    currentMessages.add(message);

    emit(ChatLoaded(
      messages: currentMessages,
      threadId: currentThreadId,
    ));
  }
  
  /// Update last AI message (for streaming)
  Future<void> _onLastAiMessageUpdated(
    ChatLastAiMessageUpdated event,
    Emitter<ChatState> emit,
  ) async {
    List<ChatMessage> currentMessages = [];
    String? currentThreadId;

    if (state is ChatLoaded) {
      final loaded = state as ChatLoaded;
      currentMessages = List.from(loaded.messages);
      currentThreadId = loaded.threadId;
    }

    // Check if last message is AI
    if (currentMessages.isNotEmpty && currentMessages.last.type == 'ai') {
      // Update existing message
      final lastMsg = currentMessages.last;
      currentMessages[currentMessages.length - 1] = ChatMessage(
        id: lastMsg.id,
        content: event.content,
        type: lastMsg.type,
        speaker: lastMsg.speaker,
        isPlayed: lastMsg.isPlayed,
        timestamp: lastMsg.timestamp,
      );
    } else {
      // Add new message
      final message = ChatMessage(
        id: DateTime.now().millisecondsSinceEpoch.toString(),
        content: event.content,
        type: 'ai',
        speaker: 'Kṛṣṇa',
        isPlayed: false, // Mark as unplayed so TTS will play it
      );
      currentMessages.add(message);
    }

    // Save to cache if we have a thread ID (this triggers the stream)
    if (currentThreadId != null) {
      _cacheService.cacheMessages(
        currentMessages, 
        currentThreadId,
        followUpQuestions: state is ChatLoaded ? (state as ChatLoaded).followUpQuestions : [],
      );
    }

    emit(ChatLoaded(
      messages: currentMessages,
      threadId: currentThreadId,
      followUpQuestions: state is ChatLoaded ? (state as ChatLoaded).followUpQuestions : [],
      isGenerating: false,
    ));
  }

  /// Start watching a thread for changes (Observable pattern)
  Future<void> _onThreadWatchRequested(
    ChatThreadWatchRequested event,
    Emitter<ChatState> emit,
  ) async {
    // Load cached follow-up questions once
    final cachedFollowUps = await _cacheService.getFollowUpQuestions(event.threadId);
    print('📋 Cached follow-ups loaded: $cachedFollowUps');
    print('📊 Cached follow-ups count: ${cachedFollowUps.length}');
    
    // Use emit.forEach to properly handle the stream
    await emit.forEach<List<ChatMessage>>(
      _cacheService.watchMessages(event.threadId),
      onData: (messages) {
        print('💬 Messages from stream: ${messages.length} messages');
        print('🔍 Last message type: ${messages.isNotEmpty ? messages.last.type : "none"}');
        
        // Return new state whenever cache updates
        // Use cached follow-ups if available, otherwise preserve from state
        final followUps = cachedFollowUps.isNotEmpty 
            ? cachedFollowUps 
            : (state is ChatLoaded ? (state as ChatLoaded).followUpQuestions : <String>[]);
        
        print('✅ Final follow-ups to emit: $followUps (count: ${followUps.length})');
        
        return ChatLoaded(
          messages: messages,
          threadId: event.threadId,
          followUpQuestions: followUps,
          isGenerating: state is ChatLoaded ? (state as ChatLoaded).isGenerating : false,
        );
      },
      onError: (error, stackTrace) {
        return ChatError('Stream error: ${error.toString()}');
      },
    );
  }
  
  /// Update message played status (for TTS tracking)
  Future<void> _onMessagePlayedStatusUpdated(
    ChatMessagePlayedStatusUpdated event,
    Emitter<ChatState> emit,
  ) async {
    // Update in cache (this will trigger the stream)
    await _cacheService.updateMessagePlayedStatus(
      event.messageId,
      event.threadId,
      event.isPlayed,
    );
  }
}

