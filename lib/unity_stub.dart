/// Stub for flutter_embed_unity when running on simulator.
/// Remove this file and uncomment the real package when done testing.
import 'package:flutter/widgets.dart';

void sendToUnity(String gameObject, String method, String message) {
  // no-op on simulator
}

/// Placeholder widget so the code compiles.
class EmbedUnity extends StatelessWidget {
  const EmbedUnity({super.key});
  @override
  Widget build(BuildContext context) => const SizedBox.shrink();
}
