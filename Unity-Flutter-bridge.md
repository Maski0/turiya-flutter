# Unity-Flutter Audio Bridge

Quick reference for streaming ElevenLabs audio from Flutter to Unity for real-time lip-sync.

## Architecture

```
User Input (Flutter)
  → ElevenLabs API (PCM stream)
  → Base64 encode chunks
  → Send to Unity via flutter_embed_unity
  → Unity decodes & plays with lip-sync
```

## Flutter Setup

### 1. Dependencies (`pubspec.yaml`)
```yaml
dependencies:
  flutter_embed_unity: ^1.3.1
  http: ^1.2.0
```

### 2. Configuration (`main.dart`)
```dart
// Replace with your credentials
final elevenLabsService = ElevenLabsService(
  apiKey: 'YOUR_ELEVENLABS_API_KEY',
  voiceId: 'YOUR_VOICE_ID',
);
```

### 3. Usage
```dart
// Type text → Press "Generate" button
_audioStreamer.streamToUnity(text);
```

## Unity Setup

### 1. Create GameObject
- Name: `AudioManager`
- Attach: `AudioManager.cs` script

### 2. Message Protocol

Flutter sends these messages to Unity:

| Message | Description |
|---------|-------------|
| `START` | Beginning of audio stream |
| `CHUNK\|<base64>` | Audio data chunk (base64-encoded PCM) |
| `END` | Stream complete, play audio |

### 3. Audio Format
- **Format**: PCM 16-bit
- **Sample Rate**: 24kHz
- **Channels**: Mono
- **Encoding**: Little-endian

## Key Files

| File | Purpose |
|------|---------|
| `lib/elevenlabs_service.dart` | ElevenLabs API streaming (PCM format) |
| `lib/audio_streamer.dart` | Sends base64 chunks to Unity |
| `lib/main.dart` | UI and audio generation trigger |
| `unity_audio_manager_example.cs` | Unity receiver, PCM decoder, lip-sync |

## Unity Script Methods

### Public Methods (Called from Flutter)
```csharp
OnAudioChunk(string message)  // Receives audio chunks
OnAudioError(string error)     // Handles errors
```

### Core Processing
```csharp
ProcessAndPlayAudio()           // Combines chunks
ConvertPCMToAudioClip()         // PCM → AudioClip (no overhead)
PlayAudioWithLipSync()          // Plays + triggers lip-sync
LipSyncCoroutine()              // Reads amplitude for animation
```

## Lip-Sync Integration

Current implementation uses audio amplitude (`unity_audio_manager_example.cs:172`):

```csharp
audioSource.GetOutputData(samples, 0);
float volume = CalculateVolume(samples);

// Apply to your character
// characterBlendShapes["MouthOpen"] = volume * 100f;
```

### Integration Options
1. **Blend Shapes**: Direct volume → mouth open amount
2. **Bone Animation**: Volume → jaw rotation
3. **Third-party**: Oculus Lipsync, SALSA, etc.

## Performance Notes

- **No conversion overhead**: PCM → float samples directly in memory
- **No file I/O**: Everything happens in-memory
- **Real-time**: Audio starts playing as soon as streaming completes
- **Chunk size**: Automatic from ElevenLabs (typically 4-8KB)

## Troubleshooting

| Issue | Solution |
|-------|----------|
| No audio in Unity | Check GameObject name is exactly `AudioManager` |
| API errors | Verify API key and voice ID in `main.dart:30-31` |
| Distorted audio | Ensure PCM format (`output_format: 'pcm_24000'`) |
| Lip-sync not working | Check AudioSource component exists and is enabled |

## Message Flow Example

```
Flutter:  "Hello world"
    ↓
ElevenLabs API streaming PCM chunks
    ↓
Flutter:  START
Flutter:  CHUNK|UklGRiQAAABXQVZFZm10...
Flutter:  CHUNK|IBAAAAABAEGApAAAQKBJ...
Flutter:  CHUNK|AAAAABAASAAAWABgAHA...
Flutter:  END
    ↓
Unity: Decode base64 → Combine → Create AudioClip → Play with lip-sync
```

## References

- [flutter_embed_unity docs](https://github.com/learntoflutter/flutter_embed_unity)
- [ElevenLabs API](https://elevenlabs.io/docs/api-reference)
- Audio format: PCM 24kHz 16-bit mono
