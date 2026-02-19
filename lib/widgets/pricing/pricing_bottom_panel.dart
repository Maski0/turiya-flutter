import 'package:flutter/material.dart';
import 'package:flutter_liquid_glass_plus/flutter_liquid_glass.dart';

import '../../theme/app_theme.dart';
import 'pricing_styles.dart';

enum _PricingPlan { pro, max }

class PricingBottomPanel extends StatefulWidget {
  final String primaryLabel;
  final VoidCallback? onPrimary;
  final VoidCallback? onDayPass;
  final bool wrapInGlass;
  final EdgeInsetsGeometry contentPadding;

  const PricingBottomPanel({
    super.key,
    required this.primaryLabel,
    this.onPrimary,
    this.onDayPass,
    this.wrapInGlass = true,
    this.contentPadding = const EdgeInsets.fromLTRB(16, 32, 16, 16),
  });

  @override
  State<PricingBottomPanel> createState() => _PricingBottomPanelState();
}

class _PricingBottomPanelState extends State<PricingBottomPanel> {
  _PricingPlan _selectedPlan = _PricingPlan.max;

  static const _w = Colors.white;

  @override
  Widget build(BuildContext context) {
    final content = Padding(
      padding: widget.contentPadding,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          _planSelector(context),
          const SizedBox(height: 16),
          _primaryBtn(context),
          const SizedBox(height: 8),
          Text('-or-', style: AppTheme.captionS(context)),
          const SizedBox(height: 8),
          _dayPassBtn(context),
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

    if (!widget.wrapInGlass) return content;

    final shadow = BoxShadow(
      color: const Color(0x14111111),
      blurRadius: 16,
      offset: const Offset(0, 4),
    );

    return Container(
      decoration: BoxDecoration(
        boxShadow: [shadow],
        borderRadius: BorderRadius.circular(24),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(24),
        child: LGContainer(
          useOwnLayer: true,
          quality: LGQuality.premium,
          shape: const LiquidRoundedSuperellipse(borderRadius: 24),
          settings: LiquidGlassSettings(
            thickness: 30,
            blur: 8,
            refractiveIndex: 1.15,
            chromaticAberration: 0.005,
            lightIntensity: 0.5,
            glassColor:
                kPricingDaytime ? kPricingGlassTintDay : kPricingGlassTintNight,
            saturation: 1.3,
          ),
          child: content,
        ),
      ),
    );
  }

  Widget _planSelector(BuildContext context) {
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
              Expanded(child: _planTile(context, _PricingPlan.pro, 'Pro', '₹599/mo', '60 mins')),
              Expanded(child: _planTile(context, _PricingPlan.max, 'Max', '₹1499/mo', '150 mins')),
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
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 2),
                    decoration: const BoxDecoration(
                      color: _w,
                      borderRadius: BorderRadius.only(
                        topLeft: Radius.circular(12),
                        topRight: Radius.circular(12),
                      ),
                    ),
                    child: Text(
                      '50% off',
                      style: AppTheme.captionS(context).copyWith(color: const Color(0xFF111111)),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _planTile(
    BuildContext context,
    _PricingPlan plan,
    String name,
    String price,
    String mins,
  ) {
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
            Text(name, textAlign: TextAlign.center, style: AppTheme.bodyEL(context)),
            Text(price, textAlign: TextAlign.center, style: AppTheme.bodyS(context)),
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

  Widget _primaryBtn(BuildContext context) {
    return GestureDetector(
      onTap: widget.onPrimary,
      child: Container(
        width: double.infinity,
        height: 64,
        decoration: BoxDecoration(color: _w, borderRadius: BorderRadius.circular(16)),
        alignment: Alignment.center,
        child: Text(
          widget.primaryLabel,
          style: AppTheme.bodyEL(context).copyWith(color: const Color(0xFF111111)),
        ),
      ),
    );
  }

  Widget _dayPassBtn(BuildContext context) {
    return GestureDetector(
      onTap: widget.onDayPass,
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
                TextSpan(text: 'Continue with a ', style: AppTheme.bodyM(context)),
                TextSpan(
                  text: 'day pass',
                  style: AppTheme.bodyM(context).copyWith(fontWeight: FontWeight.w700),
                ),
              ]),
              textAlign: TextAlign.center,
            ),
            Text(
              '₹99 · Unlimited voice today',
              textAlign: TextAlign.center,
              style: AppTheme.bodyM(context).copyWith(color: _w.withOpacity(0.7)),
            ),
          ],
        ),
      ),
    );
  }
}

