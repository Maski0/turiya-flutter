import 'package:flutter/material.dart';
import 'package:flutter_liquid_glass_plus/flutter_liquid_glass.dart';
import 'package:rive/rive.dart' hide Animation;

/// Figma node: 127:2511 (Memory consent dialog)
class MemoryConsentDialog extends StatelessWidget {
  final VoidCallback? onSkip;
  final VoidCallback? onEnableMemory;
  final VoidCallback? onBackdropTap;

  const MemoryConsentDialog({
    super.key,
    this.onSkip,
    this.onEnableMemory,
    this.onBackdropTap,
  });

  @override
  Widget build(BuildContext context) {
    final mq = MediaQuery.of(context);
    final scale = mq.size.height / 852.0;

    final cardRadius = 32.0 * scale;
    final cardW = 361.0 * (mq.size.width / 393.0);
    final padV = 16.0 * scale;
    final padH = 24.0 * scale;

    return Stack(
      children: [
        Positioned.fill(
          child: GestureDetector(
            onTap: onBackdropTap,
            behavior: HitTestBehavior.opaque,
            child: LGContainer(
              useOwnLayer: true,
              quality: LGQuality.premium,
              shape: const LiquidRoundedSuperellipse(borderRadius: 0),
              settings: const LiquidGlassSettings(
                thickness: 26,
                blur: 18,
                refractiveIndex: 1.12,
                chromaticAberration: 0.004,
                lightIntensity: 0.15,
                glassColor: Color.fromRGBO(0, 0, 0, 0.20),
                saturation: 1.05,
              ),
              child: const SizedBox.expand(),
            ),
          ),
        ),
        Center(
          child: GestureDetector(
            onTap: () {},
            child: ConstrainedBox(
              constraints: BoxConstraints.tightFor(width: cardW),
              child: DecoratedBox(
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(cardRadius),
                  border: Border.all(
                    color: Colors.white.withOpacity(0.08),
                    width: 1,
                  ),
                  boxShadow: const [
                    BoxShadow(
                      color: Color(0x14111111),
                      offset: Offset(0, 4),
                      blurRadius: 16,
                    ),
                  ],
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(cardRadius),
                  child: LGContainer(
                    useOwnLayer: true,
                    quality: LGQuality.premium,
                    shape: LiquidRoundedSuperellipse(borderRadius: cardRadius),
                    settings: const LiquidGlassSettings(
                      thickness: 40,
                      blur: 16,
                      refractiveIndex: 1.3,
                      chromaticAberration: 0.004,
                      lightIntensity: 0.22,
                      glassColor: Color.fromRGBO(0, 0, 0, 0.1),
                      saturation: 0.9,
                    ),
                    padding:
                        EdgeInsets.symmetric(horizontal: padH, vertical: padV),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Padding(
                          padding: EdgeInsets.only(
                            top: 16 * scale,
                            bottom: 8 * scale,
                          ),
                          child: SizedBox(
                            width: 160 * scale,
                            height: 160 * scale,
                            child: RiveWidgetBuilder(
                              fileLoader: FileLoader.fromAsset(
                                'assets/images/pricing/feather.riv',
                                riveFactory: Factory.flutter,
                              ),
                              builder: (context, state) {
                                if (state is RiveLoaded) {
                                  return RiveWidget(
                                    controller: state.controller,
                                    fit: Fit.contain,
                                  );
                                }
                                return const SizedBox.shrink();
                              },
                            ),
                          ),
                        ),
                        Padding(
                          padding: EdgeInsets.symmetric(vertical: 8 * scale),
                          child: Align(
                            alignment: Alignment.centerLeft,
                            child: Text(
                              'Would you like Krishna to remember?',
                              style: Theme.of(context)
                                  .textTheme
                                  .titleLarge
                                  ?.copyWith(
                                    color: Colors.white,
                                  ),
                            ),
                          ),
                        ),
                        Padding(
                          padding: EdgeInsets.only(bottom: 8 * scale),
                          child: Align(
                            alignment: Alignment.centerLeft,
                            child: Opacity(
                              opacity: 0.8,
                              child: Text(
                                'This helps Krishna recall your past thoughts, emotions, and questions to offer more meaningful guidance.',
                                style: Theme.of(context)
                                    .textTheme
                                    .bodyMedium
                                    ?.copyWith(
                                      color: Colors.white,
                                    ),
                              ),
                            ),
                          ),
                        ),
                        SizedBox(height: 8 * scale),
                        SizedBox(
                          height: 56 * scale,
                          child: Row(
                            children: [
                              Expanded(
                                child: _DialogButton(
                                  label: 'Skip for now',
                                  background: Colors.white.withOpacity(0.10),
                                  foreground: Colors.white,
                                  emphasized: false,
                                  onTap: onSkip,
                                  scale: scale,
                                ),
                              ),
                              SizedBox(width: 8 * scale),
                              Expanded(
                                child: _DialogButton(
                                  label: 'Enable Memory',
                                  background: Colors.white,
                                  foreground: const Color(0xFF111111),
                                  emphasized: true,
                                  onTap: onEnableMemory,
                                  scale: scale,
                                ),
                              ),
                            ],
                          ),
                        ),
                        SizedBox(height: 16 * scale),
                        Text(
                          'Your data stays private and secure.',
                          textAlign: TextAlign.center,
                          style:
                              Theme.of(context).textTheme.labelLarge?.copyWith(
                                    color: Colors.white.withOpacity(0.75),
                                  ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _DialogButton extends StatelessWidget {
  final String label;
  final Color background;
  final Color foreground;
  final bool emphasized;
  final VoidCallback? onTap;
  final double scale;

  const _DialogButton({
    required this.label,
    required this.background,
    required this.foreground,
    required this.emphasized,
    required this.onTap,
    required this.scale,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: background,
          borderRadius: BorderRadius.circular(16 * scale),
          boxShadow: emphasized
              ? const []
              : const [
                  BoxShadow(
                    color: Color(0x14111111),
                    offset: Offset(0, 4),
                    blurRadius: 16,
                  ),
                ],
        ),
        child: Center(
          child: Text(
            label,
            style: (emphasized
                    ? Theme.of(context).textTheme.titleSmall
                    : Theme.of(context).textTheme.bodyMedium)
                ?.copyWith(
              color: foreground,
            ),
          ),
        ),
      ),
    );
  }
}
