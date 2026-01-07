import 'dart:convert';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../services/backend_api_service.dart';
import '../../services/cache_service.dart';
import 'chat_event.dart';
import 'chat_state.dart';

/// BLoC for managing chat/message state
class ChatBloc extends Bloc<ChatEvent, ChatState> {
  final BackendApiService _backendApi;
  final CacheService _cacheService;

  ChatBloc({
    BackendApiService? backendApi,
    required CacheService cacheService,
  })  : _backendApi = backendApi ?? BackendApiService(),
        _cacheService = cacheService,
        super(const ChatInitial()) {
    on<ChatMessageSent>(_onMessageSent);
    on<ChatHistoryRequested>(_onHistoryRequested);
    on<ChatHistoryDeleted>(_onHistoryDeleted);
    on<ChatMessagesCleared>(_onMessagesCleared);
    on<ChatLocalMessageAdded>(_onLocalMessageAdded);
    on<ChatThreadWatchRequested>(_onThreadWatchRequested);
    on<ChatMessagePlayedStatusUpdated>(_onMessagePlayedStatusUpdated);
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

    // Emit immediately with the new user message so it shows instantly
    emit(ChatLoaded(
      messages: currentMessages,
      threadId: currentThreadId,
      isGenerating: true,
      followUpQuestions: [], // Clear old follow-ups when starting new message
    ));

    // Save user message to cache (for persistence and stream sync)
    if (currentThreadId != null) {
      await _cacheService.cacheMessages(
        currentMessages,
        currentThreadId,
        followUpQuestions: [], // Clear old follow-ups when sending new message
      );
    }

    try {
      // Call backend
      final response = await _backendApi.invokeAgent(
        message: event.message,
        threadId: currentThreadId,
        model: 'claude-sonnet-4-0',
        agentId: 'krsna-agent',
        language: event.language, // Pass language from event
      );

      // Parse response
      final aiContent = response['content'];
      final aiData = jsonDecode(aiContent);
      final saiBabaResponse = aiData['response'];
      final followUps = (aiData['follow_ups'] as List?)?.cast<String>() ?? [];

      // Debug logging
      print('═══════════════════════════════════════════════');
      print('✅ MESSAGE SENT SUCCESSFULLY');
      print('🔍 Backend response keys: ${aiData.keys.toList()}');
      print('📝 Follow-ups received: $followUps');
      print('📊 Follow-ups count: ${followUps.length}');
      print('═══════════════════════════════════════════════');

      // Store thread ID if new
      final isNewThread = currentThreadId == null;
      if (isNewThread && response['thread_id'] != null) {
        currentThreadId = response['thread_id'];
        // Start watching the new thread
        add(ChatThreadWatchRequested(currentThreadId!));
      }

      // Add AI message with isPlayed=false so TTS plays it
      final aiMessage = ChatMessage(
        id: DateTime.now().millisecondsSinceEpoch.toString(),
        content: saiBabaResponse,
        type: 'ai',
        speaker: 'Kṛṣṇa',
        isPlayed: false, // Mark as unplayed so TTS will play it
      );
      currentMessages.add(aiMessage);

      // Save to cache (this triggers the stream and updates UI)
      if (currentThreadId != null) {
        await _cacheService.cacheMessages(
          currentMessages,
          currentThreadId,
          followUpQuestions: followUps, // Save follow-ups to cache
        );
        await _cacheService.saveThreadId(currentThreadId);
      }

      // Update follow-up questions in state (stream handles messages)
      if (state is ChatLoaded) {
        emit((state as ChatLoaded).copyWith(
          followUpQuestions: followUps,
          isGenerating: false,
          pendingMessage: null, // Clear pending message on successful send
        ));
      }
    } catch (e) {
      print('═════════════════════════════════════════');
      print('🚨🚨🚨 CRITICAL ERROR SENDING MESSAGE 🚨🚨🚨');
      print('❌ Error: $e');
      print('═════════════════════════════════════════');

      // Remove the optimistically added user message
      currentMessages.removeLast();

      // Get current follow-ups before updating cache
      final currentFollowUps = state is ChatLoaded
          ? (state as ChatLoaded).followUpQuestions
          : <String>[];

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
      final cachedFollowUps =
          await _cacheService.getFollowUpQuestions(event.threadId);

      // Save to cache (this will trigger the stream and update UI)
      await _cacheService.cacheMessages(messages, event.threadId,
          followUpQuestions: cachedFollowUps);
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

  /// Start watching a thread for changes (Observable pattern)
  Future<void> _onThreadWatchRequested(
    ChatThreadWatchRequested event,
    Emitter<ChatState> emit,
  ) async {
    // Load follow-ups from cache once at the start for initial load
    final initialFollowUps =
        await _cacheService.getFollowUpQuestions(event.threadId);
    print('═══════════════════════════════════════════════');
    print('📋 INITIAL FOLLOW-UPS LOADED');
    print('Follow-ups: $initialFollowUps');
    print('Count: ${initialFollowUps.length}');
    print('═══════════════════════════════════════════════');

    // Keep track of current follow-ups
    List<String> currentFollowUps = initialFollowUps;

    // Create a combined stream that emits both messages and follow-ups together
    final messagesStream = _cacheService.watchMessages(event.threadId);

    await emit.forEach(
      messagesStream,
      onData: (messages) {
        print('💬 Messages from stream: ${messages.length} messages');
        print(
            '🔍 Last message type: ${messages.isNotEmpty ? messages.last.type : "none"}');

        // Update current follow-ups from state if available (set by _onMessageSent)
        // Otherwise use the current tracked value
        if (state is ChatLoaded &&
            (state as ChatLoaded).followUpQuestions.isNotEmpty) {
          currentFollowUps = (state as ChatLoaded).followUpQuestions;
        }

        print('═══════════════════════════════════════════════');
        print('📋 EMITTING FOLLOW-UPS TO UI');
        print('Follow-ups: $currentFollowUps');
        print('Count: ${currentFollowUps.length}');
        print('═══════════════════════════════════════════════');

        return ChatLoaded(
          messages: messages,
          threadId: event.threadId,
          followUpQuestions: currentFollowUps,
          isGenerating:
              state is ChatLoaded ? (state as ChatLoaded).isGenerating : false,
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
