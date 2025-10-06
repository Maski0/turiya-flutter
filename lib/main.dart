import 'package:flutter/material.dart';
import 'package:flutter_embed_unity/flutter_embed_unity.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'elevenlabs_service.dart';
import 'audio_streamer.dart';

Future<void> main() async {
  await dotenv.load(fileName: ".env");
  runApp(const ExampleApp());
}

class ExampleApp extends StatefulWidget {
  const ExampleApp({super.key});

  @override
  State<ExampleApp> createState() => _ExampleAppState();
}

class _ExampleAppState extends State<ExampleApp> {

  final TextEditingController _textController = TextEditingController();
  int _numberOfTaps = 0;
  late AudioStreamer _audioStreamer;
  bool _isGenerating = false;

  @override
  void initState() {
    super.initState();
    // Initialize ElevenLabs service with your API key and voice ID from environment
    final elevenLabsService = ElevenLabsService(
      apiKey: dotenv.env['ELEVENLABS_API_KEY'] ?? '',
      voiceId: dotenv.env['ELEVENLABS_VOICE_ID'] ?? '',
    );
    _audioStreamer = AudioStreamer(elevenLabsService);
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      home: Scaffold(
        appBar: AppBar(
          title: const Text('Plugin example app'),
        ),
        body: SafeArea(
          child: Builder(
            builder: (context) {
              final theme = Theme.of(context);

              return Column(
                children: [
                  Expanded(
                    child: EmbedUnity(
                      onMessageFromUnity: (String data) {
                        // A message has been received from a Unity script
                        if(data == "touch"){
                          setState(() {
                            _numberOfTaps += 1;
                          });
                        }
                        else if(data == "scene_loaded") {
                          // Scene loaded
                        }
                        else if(data == "ar:true") {
                          setState(() {
                          });
                        }
                        else if(data == "ar:false") {
                          setState(() {
                          });
                        }
                      },
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.all(16),
                    child: Text(
                      "Flutter has been touched $_numberOfTaps times",
                      textAlign: TextAlign.center,
                      style: theme.textTheme.titleMedium,
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: Row(
                      children: [
                        Expanded(
                          child: TextField(
                            controller: _textController,
                            decoration: const InputDecoration(
                              hintText: 'Enter text',
                              border: OutlineInputBorder(),
                            ),
                            onSubmitted: (value) {
                              _generateAudio(value, context);
                            },
                          ),
                        ),
                        const SizedBox(width: 8),
                        ElevatedButton(
                          onPressed: _isGenerating
                              ? null
                              : () {
                                  _generateAudio(_textController.text, context);
                                },
                          child: _isGenerating
                              ? const SizedBox(
                                  width: 16,
                                  height: 16,
                                  child: CircularProgressIndicator(strokeWidth: 2),
                                )
                              : const Text('Generate'),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Expanded(
                        child: Padding(
                          padding: const EdgeInsets.all(8.0),
                          child: ElevatedButton(
                            onPressed: () {
                              pauseUnity();
                            },
                            child: const Text("Pause"),
                          ),
                        ),
                      ),
                      Expanded(
                        child: Padding(
                          padding: const EdgeInsets.all(8.0),
                          child: ElevatedButton(
                            onPressed: () {
                              resumeUnity();
                            },
                            child: const Text("Resume"),
                          ),
                        ),
                      ),
                      Expanded(
                        child: Padding(
                          padding: const EdgeInsets.all(8.0),
                          child: ElevatedButton(
                            onPressed: () {
                              Navigator.push(
                                context,
                                MaterialPageRoute(builder: (context) => const Route2()),
                              );
                            },
                            child: const Text("Open route 2", textAlign: TextAlign.center),
                          ),
                        ),
                      ),
                    ],
                  )
                ],
              );
            },
          ),
        ),
      ),
    );
  }


  Future<void> _generateAudio(String text, BuildContext context) async {
    if (text.trim().isEmpty) return;

    setState(() {
      _isGenerating = true;
    });

    try {
      await _audioStreamer.streamToUnity(text);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Audio generated and sent to Unity')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e')),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isGenerating = false;
        });
      }
    }
  }

  @override
  void dispose() {
    _textController.dispose();
    super.dispose();
  }
}


class Route2 extends StatelessWidget {

  const Route2({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
        appBar: AppBar(
          title: const Text('Route 2'),
        ),
        body: SafeArea(
          child: Builder(
              builder: (context) =>
                  Column(
                    children: [
                      const Padding(
                        padding: EdgeInsets.all(16),
                        child: Text(
                          "Unity can only be shown in 1 widget at a time. Therefore if a second route "
                              "with a FlutterEmbed is pushed onto the stack, Unity is 'detached' from "
                              "the first route, and attached to the second. When the second route is "
                              "popped from the stack, Unity is reattached to the first route.",
                        ),
                      ),
                      const Expanded(
                        child: EmbedUnity(),
                      ),
                      Padding(
                        padding: const EdgeInsets.all(8.0),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            const BackButton(),
                            ElevatedButton(
                              onPressed: () {
                                showDialog(context: context, builder: (_) => const Route3());
                              },
                              child: const Text("Open route 3", textAlign: TextAlign.center),
                            ),
                          ],
                        ),
                      )
                    ],
                  )
          ),
        )
    );
  }
}


class Route3 extends StatelessWidget {

  const Route3({super.key});

  @override
  Widget build(BuildContext context) {
    return const AlertDialog(
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            "Route 3",
            textAlign: TextAlign.center,
          ),
          SizedBox(
            height: 100,
            width: 80,
            child: EmbedUnity(),
          ),
        ],
      ),
    );
  }
}