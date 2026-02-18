import 'package:flutter/material.dart';
import 'package:flutter_liquid_glass_plus/flutter_liquid_glass.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:rive/rive.dart' hide Animation;
import '../theme/app_theme.dart';

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

enum _PricingPlan { pro, max }

class _PricingBottomSheetState extends State<PricingBottomSheet> {
  _PricingPlan _selectedPlan = _PricingPlan.max;

  static const _bgTop = Color(0xFF004459);
  static const _bgBot = Color(0xFF00263B);
  static const _w = Colors.white;

  @override
  Widget build(BuildContext context) {
    final mq = MediaQuery.of(context);
    final topPad = mq.padding.top - 10;
    final botPad = mq.padding.bottom;
    final h = mq.size.height;
    final scale = h / 812.0;
    final krishnaH = 380.0 * scale;

    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [_bgTop, _bgTop, _bgTop, _bgBot],
        ),
      ),
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
                        child: Container(
                          decoration: const BoxDecoration(
                            gradient: LinearGradient(
                              begin: Alignment.topCenter,
                              end: Alignment.bottomCenter,
                              stops: [0.0, 0.45, 0.8, 1.0],
                              colors: [
                                Color(0x00004459),
                                Color(0xAA004459),
                                _bgTop,
                                _bgTop,
                              ],
                            ),
                          ),
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
                      _subtitle(),
                      const SizedBox(height: 16),
                      _features(),
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
            child: _stickyPricingCard(),
          ),

          // ── Layer 2: Close button ──
          Positioned(
            top: topPad + 8,
            right: 16,
            child: GestureDetector(
              onTap: widget.onClose,
              behavior: HitTestBehavior.opaque,
              child: const Padding(
                padding: EdgeInsets.all(8),
                child: Icon(Icons.close, color: _w, size: 22),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ─── Sticky pricing card with liquid glass ──────────────────────
  Widget _stickyPricingCard() {
    return LGContainer(
      useOwnLayer: true,
      quality: LGQuality.premium,
      shape: const LiquidRoundedSuperellipse(borderRadius: 24),
      settings: const LiquidGlassSettings(
        thickness: 30,
        blur: 8,
        refractiveIndex: 1.15,
        chromaticAberration: 0.005,
        lightIntensity: 0.5,
        glassColor: Color.fromARGB(25, 255, 255, 255),
        saturation: 1.3,
      ),
      padding: const EdgeInsets.fromLTRB(16, 32, 16, 16),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          _planSelector(),
          const SizedBox(height: 16),
          _continueBtn(),
          const SizedBox(height: 8),
          Text(
            '-or-',
            style: AppTheme.captionS(context),
          ),
          const SizedBox(height: 8),
          _dayPassBtn(),
          const SizedBox(height: 10),
          Text(
            'You can continue with text anytime. Voice is optional.',
            textAlign: TextAlign.center,
            style:
                AppTheme.captionS(context).copyWith(color: _w.withOpacity(0.6)),
          ),
        ],
      ),
    );
  }

  // ─── Title with decorative Turiya script ───────────────────────
  Widget _title() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 32),
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
  Widget _subtitle() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 40),
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

  // ─── Plan selector ─────────────────────────────────────────────
  Widget _planSelector() {
    return Stack(
      clipBehavior: Clip.none,
      children: [
        Container(
          decoration: BoxDecoration(
            border: Border.all(color: _w.withOpacity(0.2)),
            borderRadius: BorderRadius.circular(24),
          ),
          child: Row(
            children: [
              Expanded(
                  child:
                      _planTile(_PricingPlan.pro, 'Pro', '₹599/mo', '60 mins')),
              Expanded(
                  child: _planTile(
                      _PricingPlan.max, 'Max', '₹1499/mo', '150 mins')),
            ],
          ),
        ),
        Positioned(
          top: -14,
          left: 0,
          right: 0,
          child: Row(
            children: [
              const Spacer(),
              Expanded(
                child: Center(
                  child: Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 16, vertical: 2),
                    decoration: const BoxDecoration(
                      color: _w,
                      borderRadius: BorderRadius.only(
                        topLeft: Radius.circular(12),
                        topRight: Radius.circular(12),
                      ),
                    ),
                    child: Text('50% off',
                        style: AppTheme.captionS(context)
                            .copyWith(color: const Color(0xFF111111))),
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _planTile(_PricingPlan plan, String name, String price, String mins) {
    final on = _selectedPlan == plan;
    return GestureDetector(
      onTap: () => setState(() => _selectedPlan = plan),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
        decoration: BoxDecoration(
          border: Border.all(color: on ? _w : Colors.transparent, width: 2),
          borderRadius: BorderRadius.circular(24),
        ),
        child: Column(
          children: [
            Text(name,
                textAlign: TextAlign.center, style: AppTheme.bodyEL(context)),
            Text(price,
                textAlign: TextAlign.center, style: AppTheme.bodyS(context)),
            const SizedBox(height: 6),
            Text.rich(
              TextSpan(children: [
                TextSpan(text: mins, style: AppTheme.captionSBold(context)),
                TextSpan(text: ' of voice', style: AppTheme.captionS(context)),
              ]),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  // ─── Buttons ───────────────────────────────────────────────────
  Widget _continueBtn() {
    return GestureDetector(
      onTap: widget.onUpgrade,
      child: Container(
        width: double.infinity,
        height: 64,
        decoration:
            BoxDecoration(color: _w, borderRadius: BorderRadius.circular(16)),
        alignment: Alignment.center,
        child: Text('Continue',
            style: AppTheme.bodyEL(context)
                .copyWith(color: const Color(0xFF111111))),
      ),
    );
  }

  Widget _dayPassBtn() {
    return GestureDetector(
      onTap: () {},
      child: Container(
        width: double.infinity,
        height: 64,
        decoration: BoxDecoration(
          border: Border.all(color: _w),
          borderRadius: BorderRadius.circular(16),
        ),
        alignment: Alignment.center,
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text.rich(
              TextSpan(children: [
                TextSpan(
                    text: 'Continue with a ', style: AppTheme.bodyM(context)),
                TextSpan(
                    text: 'day pass',
                    style: AppTheme.bodyM(context)
                        .copyWith(fontWeight: FontWeight.w700)),
              ]),
              textAlign: TextAlign.center,
            ),
            Text('₹99 · Unlimited voice today',
                textAlign: TextAlign.center,
                style: AppTheme.bodyM(context)
                    .copyWith(color: _w.withOpacity(0.7))),
          ],
        ),
      ),
    );
  }
}
