import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:rive/rive.dart' hide Animation;
import '../theme/app_theme.dart';
import 'pricing/pricing_styles.dart';
import 'pricing/pricing_bottom_panel.dart';

class PricingBottomSheet extends StatefulWidget {
  final VoidCallback? onClose;
  final VoidCallback? onUpgrade;

  const PricingBottomSheet({
    super.key,
    this.onClose,
    this.onUpgrade,
  });

  @override
  State<PricingBottomSheet> createState() => _PricingBottomSheetState();
}

class _PricingBottomSheetState extends State<PricingBottomSheet> {
  static const _w = Colors.white;

  @override
  Widget build(BuildContext context) {
    final mq = MediaQuery.of(context);
    final topPad = mq.padding.top - 10;
    final botPad = mq.padding.bottom;
    final h = mq.size.height;
    final scale = h / 812.0;
    final krishnaH = 380.0 * scale;
    final bgGradient = kPricingDaytime
        ? kPricingDayBackgroundGradient
        : kPricingNightBackgroundGradient;
    final krishnaFadeGradient = kPricingDaytime
        ? kPricingDayKrishnaFadeGradient
        : kPricingNightKrishnaFadeGradient;

    return Container(
      decoration: BoxDecoration(gradient: bgGradient),
      child: Stack(
        children: [
          // ── Layer 0: Scrollable background ──
          SingleChildScrollView(
            physics: const ClampingScrollPhysics(),
            child: Column(
              children: [
                SizedBox(height: topPad),
                SizedBox(
                  height: krishnaH,
                  width: double.infinity,
                  child: Stack(
                    clipBehavior: Clip.none,
                    children: [
                      Positioned.fill(
                        child: Image.asset(
                          'assets/images/pricing/krishna.png',
                          fit: BoxFit.cover,
                          alignment: Alignment.topCenter,
                          errorBuilder: (_, __, ___) => const SizedBox.expand(),
                        ),
                      ),
                      Positioned(
                        left: 0,
                        right: 0,
                        bottom: -60,
                        height: krishnaH * 0.6 + 60,
                        child: DecoratedBox(
                          decoration:
                              BoxDecoration(gradient: krishnaFadeGradient),
                        ),
                      ),
                    ],
                  ),
                ),

                // Pull text + rive up into the image area
                Transform.translate(
                  offset: Offset(0, -160 * scale),
                  child: Column(
                    children: [
                      // Rive peacock feather
                      SizedBox(
                        width: 100 * scale,
                        height: 100 * scale,
                        child: RiveWidgetBuilder(
                          fileLoader: FileLoader.fromAsset(
                            'assets/images/pricing/feather.riv',
                            riveFactory: Factory.flutter,
                          ),
                          builder: (context, state) {
                            if (state is RiveLoaded) {
                              return SizedBox.expand(
                                child: RiveWidget(
                                  controller: state.controller,
                                  fit: Fit.contain,
                                ),
                              );
                            }
                            return const SizedBox.shrink();
                          },
                        ),
                      ),
                      _title(),
                      const SizedBox(height: 30),
                      _descriptionSectionBackground(
                        child: Column(
                          children: [
                            _subtitle(),
                            const SizedBox(height: 16),
                            _features(),
                          ],
                        ),
                      ),
                      // Extra bottom space so content can scroll behind the sticky card
                      SizedBox(height: 200 * scale),
                    ],
                  ),
                ),
              ],
            ),
          ),

          // ── Layer 1: Sticky pricing card (liquid glass) ──
          Positioned(
            left: 16,
            right: 16,
            bottom: botPad - 5,
            child: PricingBottomPanel(
              primaryLabel: 'Continue',
              onPrimary: widget.onUpgrade,
              onDayPass: () {},
            ),
          ),

          // ── Layer 2: Close button ──
          if (widget.onClose != null)
            Positioned(
              top: topPad + 8,
              right: 16,
              child: GestureDetector(
                onTap: widget.onClose,
                behavior: HitTestBehavior.opaque,
                child: Padding(
                  padding: const EdgeInsets.all(8),
                  child: SizedBox(
                    width: 24,
                    height: 24,
                    child: SvgPicture.asset(
                      'assets/images/pricing/close_icon.svg',
                      colorFilter: const ColorFilter.mode(_w, BlendMode.srcIn),
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _descriptionSectionBackground({required Widget child}) {
    // This is the brownish band in Figma behind the description + feature list.
    // It prevents the top purple region from showing through when the user scrolls.
    if (!kPricingDaytime) return child;

    return DecoratedBox(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          // What you meant by "opposite direction":
          // start at TOP of description, then fade towards bottom.
          stops: [0.0, 0.16, 0.72, 1.0],
          colors: [
            Color(0x66CBA0AD),
            Color(0x4DCBA0AD),
            Color(0x1ACBA0AD),
            Color(0x00CBA0AD),
          ],
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 12),
        child: child,
      ),
    );
  }

  // ─── Title with decorative Turiya script ───────────────────────
  Widget _title(
      {EdgeInsetsGeometry padding =
          const EdgeInsets.symmetric(horizontal: 32)}) {
    return Padding(
      padding: padding,
      child: Column(
        children: [
          Text(
            'Unlock the full',
            textAlign: TextAlign.center,
            style: AppTheme.displayEL(context),
          ),
          const SizedBox(height: 2),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              SizedBox(
                height: 38,
                child: SvgPicture.asset(
                  'assets/images/pricing/turiya_vector.svg',
                  height: 38,
                  colorFilter: const ColorFilter.mode(_w, BlendMode.srcIn),
                ),
              ),
              const SizedBox(width: 6),
              Text(
                'experience',
                style: AppTheme.displayEL(context),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // ─── Subtitle ──────────────────────────────────────────────────
  Widget _subtitle(
      {EdgeInsetsGeometry padding =
          const EdgeInsets.symmetric(horizontal: 40)}) {
    return Padding(
      padding: padding,
      child: Text(
        'Krishna can respond in voice.\ncalm, reflective, and present.',
        textAlign: TextAlign.center,
        style: AppTheme.bodyL(context),
      ),
    );
  }

  // ─── Feature rows ──────────────────────────────────────────────
  Widget _features() {
    const items = [
      {
        'icon': 'assets/images/pricing/icon_voice.svg',
        'text': 'Krishna speaking in his own voice'
      },
      {
        'icon': 'assets/images/pricing/icon_conversation.svg',
        'text': 'Voice-to-voice conversations'
      },
      {
        'icon': 'assets/images/pricing/icon_immersive.svg',
        'text': 'A more immersive, personal experience'
      },
    ];
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 52),
      child: Column(
        children: [
          for (final item in items)
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Row(
                children: [
                  SizedBox(
                    width: 24,
                    height: 24,
                    child:
                        SvgPicture.asset(item['icon']!, width: 24, height: 24),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      item['text']!,
                      style: AppTheme.bodyM(context),
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}
