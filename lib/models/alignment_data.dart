/// Models for ElevenLabs TTS with character-level timestamps
/// Used for real-time subtitle synchronization

class AlignmentData {
  final List<String> characters;
  final List<double> characterStartTimesSeconds;
  final List<double> characterEndTimesSeconds;

  AlignmentData({
    required this.characters,
    required this.characterStartTimesSeconds,
    required this.characterEndTimesSeconds,
  });

  factory AlignmentData.fromJson(Map<String, dynamic> json) {
    return AlignmentData(
      characters: (json['characters'] as List<dynamic>?)
              ?.map((e) => e.toString())
              .toList() ??
          [],
      characterStartTimesSeconds: (json['characterStartTimesSeconds'] as List<dynamic>?)  // camelCase
              ?.map((e) => (e as num).toDouble())
              .toList() ??
          [],
      characterEndTimesSeconds: (json['characterEndTimesSeconds'] as List<dynamic>?)  // camelCase
              ?.map((e) => (e as num).toDouble())
              .toList() ??
          [],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'characters': characters,
      'characterStartTimesSeconds': characterStartTimesSeconds,  // camelCase to match ElevenLabs
      'characterEndTimesSeconds': characterEndTimesSeconds,  // camelCase to match ElevenLabs
    };
  }

  /// Get the full text from characters
  String get fullText => characters.join('');

  /// Check if alignment data is valid
  bool get isValid =>
      characters.isNotEmpty &&
      characters.length == characterStartTimesSeconds.length &&
      characters.length == characterEndTimesSeconds.length;
}

class AudioChunk {
  final String? audioBase64;
  final AlignmentData? alignment;
  final AlignmentData? normalizedAlignment;

  AudioChunk({
    this.audioBase64,
    this.alignment,
    this.normalizedAlignment,
  });

  factory AudioChunk.fromJson(Map<String, dynamic> json) {
    return AudioChunk(
      audioBase64: json['audioBase64'] as String?,  // camelCase to match ElevenLabs/Next.js
      alignment: json['alignment'] != null
          ? AlignmentData.fromJson(json['alignment'] as Map<String, dynamic>)
          : null,
      normalizedAlignment: json['normalizedAlignment'] != null
          ? AlignmentData.fromJson(json['normalizedAlignment'] as Map<String, dynamic>)
          : null,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'audioBase64': audioBase64,  // camelCase to match ElevenLabs/Next.js
      'alignment': alignment?.toJson(),
      'normalizedAlignment': normalizedAlignment?.toJson(),
    };
  }

  /// Get the best available alignment data
  AlignmentData? get bestAlignment => alignment ?? normalizedAlignment;
}

/// Consolidated alignment data from multiple chunks
class ConsolidatedAlignment {
  final List<String> characters;
  final List<double> characterStartTimesSeconds;
  final List<double> characterEndTimesSeconds;
  double timeOffset;
  double actualAudioDurationSeconds;

  ConsolidatedAlignment({
    List<String>? characters,
    List<double>? characterStartTimesSeconds,
    List<double>? characterEndTimesSeconds,
    this.timeOffset = 0.0,
    this.actualAudioDurationSeconds = 0.0,
  })  : characters = characters ?? [],
        characterStartTimesSeconds = characterStartTimesSeconds ?? [],
        characterEndTimesSeconds = characterEndTimesSeconds ?? [];

  /// Add a chunk's alignment data, normalizing timestamps
  void addChunk(AlignmentData alignment) {
    if (!alignment.isValid) return;

    // Normalize the chunk timestamps to start from 0
    final chunkStartOffset = alignment.characterStartTimesSeconds.isNotEmpty
        ? alignment.characterStartTimesSeconds[0]
        : 0.0;

    // Normalize and adjust start times
    final normalizedStartTimes = alignment.characterStartTimesSeconds
        .map((time) => time - chunkStartOffset + timeOffset)
        .toList();

    // Normalize and adjust end times
    final normalizedEndTimes = alignment.characterEndTimesSeconds
        .map((time) => time - chunkStartOffset + timeOffset)
        .toList();

    // Add to consolidated data
    characters.addAll(alignment.characters);
    characterStartTimesSeconds.addAll(normalizedStartTimes);
    characterEndTimesSeconds.addAll(normalizedEndTimes);

    // Update time offset for next chunk
    if (normalizedEndTimes.isNotEmpty) {
      timeOffset = normalizedEndTimes.reduce((a, b) => a > b ? a : b);
    }
  }

  /// Convert to AlignmentData
  AlignmentData toAlignmentData() {
    return AlignmentData(
      characters: List.from(characters),
      characterStartTimesSeconds: List.from(characterStartTimesSeconds),
      characterEndTimesSeconds: List.from(characterEndTimesSeconds),
    );
  }

  /// Get the full text
  String get fullText => characters.join('');

  /// Clear all data
  void clear() {
    characters.clear();
    characterStartTimesSeconds.clear();
    characterEndTimesSeconds.clear();
    timeOffset = 0.0;
  }

  /// Check if has data
  bool get isNotEmpty => characters.isNotEmpty;
}

