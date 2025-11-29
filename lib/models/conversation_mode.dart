/// Conversation mode types matching web frontend
enum ConversationMode {
  /// Text input → Voice output (text via LiveKit chat + RPC to toggle output mode)
  chatAudio('chat-audio'),
  
  /// Voice input → Voice output (uses LiveKit STT/TTS)
  audioAudio('audio-audio'),
  
  /// Text input → Text output
  chatChat('chat-chat');

  const ConversationMode(this.value);
  final String value;

  @override
  String toString() => value;

  static ConversationMode fromString(String value) {
    switch (value) {
      case 'chat-audio':
        return ConversationMode.chatAudio;
      case 'audio-audio':
        return ConversationMode.audioAudio;
      case 'chat-chat':
        return ConversationMode.chatChat;
      default:
        return ConversationMode.chatAudio; // default
    }
  }
}

