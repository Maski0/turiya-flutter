import 'package:flutter/material.dart';
import 'package:flutter_liquid_glass_plus/flutter_liquid_glass.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:rive/rive.dart' hide Animation;

import '../../theme/app_theme.dart';
import 'pricing_bottom_panel.dart';

class ChatPricingBottomSheet extends StatelessWidget {
  final VoidCallback? onClose;
  final VoidCallback? onPrimary;
  final VoidCallback? onDayPass;
  final Animation<Offset>? sheetSlide;
  final Animation<double>? backdropOpacity;

  const ChatPricingBottomSheet({
    super.key,
    this.onClose,
    this.onPrimary,
    this.onDayPass,
    this.sheetSlide,
    this.backdropOpacity,
  });

  @override
  Widget build(BuildContext context) {
    final mq = MediaQuery.of(context);
    final botPad = mq.padding.bottom;

    // Match Figma iPhone (393x852) proportions.
    final scale = mq.size.height / 852.0;
    final sheetH = 648.0 * scale;
    final sheetRadius = 32.0;
    final headerH = 64.0 * scale;
    final slide = sheetSlide ?? const AlwaysStoppedAnimation(Offset.zero);
    final dimOpacity = backdropOpacity ?? const AlwaysStoppedAnimation(1.0);

    return Stack(
      children: [
        // Dim backdrop.
        Positioned.fill(
          child: FadeTransition(
            opacity: dimOpacity,
            child: Container(color: const Color.fromRGBO(0, 0, 0, 0.40)),
          ),
        ),

        // Bottom sheet (flush like a normal bottom sheet).
        Positioned(
          left: 0,
          right: 0,
          bottom: 0,
          child: SlideTransition(
            position: slide,
            child: ClipRRect(
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(32),
                topRight: Radius.circular(32),
              ),
              child: LGContainer(
                useOwnLayer: true,
                quality: LGQuality.premium,
                shape: LiquidRoundedSuperellipse(borderRadius: sheetRadius),
                settings: const LiquidGlassSettings(
                  thickness: 26,
                  blur: 10,
                  refractiveIndex: 1.12,
                  chromaticAberration: 0.004,
                  lightIntensity: 0.25,
                  glassColor: Color.fromRGBO(255, 255, 255, 0.10),
                  saturation: 1.15,
                ),
                width: double.infinity,
                height: sheetH + botPad,
                padding: EdgeInsets.only(
                  left: 16,
                  right: 16,
                  top: 32 * scale,
                  // iOS safe-area inset (home indicator). Tweak the +8 if needed.
                  bottom: botPad + 8,
                ),
                child: Column(
                  children: [
                    // Top feather (Rive) + close.
                    SizedBox(
                      height: headerH,
                      child: Stack(
                        children: [
                          Align(
                            alignment: Alignment.center,
                            child: SizedBox(
                              width: 90 * scale,
                              height: 90 * scale,
                              child: RiveWidgetBuilder(
                                fileLoader: FileLoader.fromAsset(
                                  'assets/images/pricing/feather.riv',
                                  riveFactory: Factory.flutter,
                                ),
                                builder: (context, state) {
                                  if (state is RiveLoaded) {
                                    return RiveWidget(
                                      controller: state.controller,
                                      fit: Fit.cover,
                                    );
                                  }
                                  return const SizedBox.shrink();
                                },
                              ),
                            ),
                          ),
                          Positioned(
                            right: 0,
                            top: -12,
                            child: GestureDetector(
                              onTap: onClose,
                              behavior: HitTestBehavior.opaque,
                              child: SizedBox(
                                width: 40,
                                height: 40,
                                child: Center(
                                  child: SizedBox(
                                    width: 24,
                                    height: 24,
                                    child: SvgPicture.asset(
                                      'assets/images/pricing/close_icon.svg',
                                      colorFilter: const ColorFilter.mode(
                                        Colors.white,
                                        BlendMode.srcIn,
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),

                    SizedBox(height: 16 * scale),

                    Text(
                      'Want Krishna to continue\nspeaking with you?',
                      textAlign: TextAlign.center,
                      style: AppTheme.displayEL(context),
                    ),

                    SizedBox(height: 8 * scale),

                    Text(
                      'Voice chat is limited on the free experience.\nContinue with spoken guidance anytime.',
                      textAlign: TextAlign.center,
                      style: AppTheme.bodyL(context),
                    ),

                    SizedBox(height: 20 * scale),

                    PricingBottomPanel(
                      primaryLabel: 'Continue talking',
                      onPrimary: onPrimary,
                      onDayPass: onDayPass,
                      // Prevent nested liquid-glass artifacts inside the sheet glass.
                      wrapInGlass: false,
                      contentPadding: EdgeInsets.zero,
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}
