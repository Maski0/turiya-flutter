import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter_liquid_glass_plus/flutter_liquid_glass.dart';
import 'package:rive/rive.dart' hide Animation;

class LoginModal extends StatelessWidget {
  final VoidCallback onClose;
  final Future<void> Function() onGoogleSignIn;
  final bool isSigningIn;
  final Animation<double> animation;

  const LoginModal({
    super.key,
    required this.onClose,
    required this.onGoogleSignIn,
    required this.isSigningIn,
    required this.animation,
  });

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: animation,
      builder: (context, child) {
        final t = animation.value;
        final blurSigma = 18.0 * t;

        return GestureDetector(
          onTap: onClose,
          child: Stack(
            children: [
              // Blurred + glassy background overlay
              Positioned.fill(
                child: LGContainer(
                  useOwnLayer: true,
                  quality: LGQuality.premium,
                  shape: const LiquidRoundedSuperellipse(borderRadius: 0),
                  settings: LiquidGlassSettings(
                    thickness: 26,
                    blur: blurSigma,
                    refractiveIndex: 1.12,
                    chromaticAberration: 0.004,
                    lightIntensity: 0.12,
                    glassColor: Color.fromRGBO(0, 0, 0, 0.18 * t),
                    saturation: 1.02,
                  ),
                  child: const SizedBox.expand(),
                ),
              ),
              // Modal content with opacity fade (card itself stays fully opaque)
              Opacity(
                opacity: t,
                child: child!,
              ),
            ],
          ),
        );
      },
      child: Builder(
        builder: (context) {
          final mq = MediaQuery.of(context);
          final scale = mq.size.height / 852.0;
          final cardRadius = 20.0 * scale;

          return Center(
            child: GestureDetector(
              onTap: () {},
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 355),
                child: Container(
                  margin: const EdgeInsets.symmetric(horizontal: 16),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(cardRadius),
                    border: Border.all(
                      color: Colors.white.withOpacity(0.10),
                      width: 1,
                    ),
                    boxShadow: const [
                      BoxShadow(
                        color: Color(0x14111111),
                        blurRadius: 16,
                        offset: Offset(0, 4),
                      ),
                    ],
                  ),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(cardRadius),
                    child: LGContainer(
                      useOwnLayer: true,
                      quality: LGQuality.premium,
                      shape: LiquidRoundedSuperellipse(
                        borderRadius: cardRadius,
                      ),
                      settings: const LiquidGlassSettings(
                        thickness: 34,
                        blur: 14,
                        refractiveIndex: 1.28,
                        chromaticAberration: 0.004,
                        lightIntensity: 0.18,
                        glassColor: Color.fromRGBO(0, 0, 0, 0.14),
                        saturation: 0.95,
                      ),
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          // Rive feather
                          Padding(
                            padding: EdgeInsets.only(
                              top: 8 * scale,
                              bottom: 8 * scale,
                            ),
                            child: SizedBox(
                              width: 140 * scale,
                              height: 140 * scale,
                              child: RiveWidgetBuilder(
                                fileLoader: FileLoader.fromAsset(
                                  'assets/images/onboarding/feather.riv',
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

                          // Logo
                          SizedBox(
                            width: 80,
                            child: Image.asset(
                              'assets/images/logo.png',
                              fit: BoxFit.contain,
                              errorBuilder: (context, error, stackTrace) {
                                return const Text(
                                  'Turiya',
                                  style: TextStyle(
                                    color: Colors.white,
                                    fontSize: 28,
                                    fontWeight: FontWeight.w400,
                                    fontStyle: FontStyle.italic,
                                    fontFamily: 'Alegreya',
                                  ),
                                  textAlign: TextAlign.center,
                                );
                              },
                            ),
                          ),
                          SizedBox(height: 14 * scale),

                          // Subtitle
                          Text(
                            'Please login to continue',
                            style: Theme.of(context).textTheme.titleLarge?.copyWith(
                                  color: Colors.white,
                                  fontWeight: FontWeight.w500,
                                  height: 1.0,
                                ),
                            textAlign: TextAlign.center,
                          ),
                          SizedBox(height: 16 * scale),

                          // Button container (liquid glass)
                          ClipRRect(
                            borderRadius: BorderRadius.circular(16),
                            child: LGContainer(
                              useOwnLayer: true,
                              quality: LGQuality.premium,
                              shape: const LiquidRoundedSuperellipse(
                                borderRadius: 16,
                              ),
                              settings: const LiquidGlassSettings(
                                thickness: 22,
                                blur: 12,
                                refractiveIndex: 1.12,
                                chromaticAberration: 0.004,
                                lightIntensity: 0.14,
                                glassColor: Color.fromRGBO(255, 255, 255, 0.08),
                                saturation: 1.02,
                              ),
                              padding: const EdgeInsets.all(8),
                              child: Material(
                                color: Colors.transparent,
                                child: InkWell(
                                  onTap: isSigningIn ? null : onGoogleSignIn,
                                  borderRadius: BorderRadius.circular(12),
                                  child: Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 24,
                                      vertical: 12,
                                    ),
                                    decoration: BoxDecoration(
                                      color: isSigningIn
                                          ? Colors.white.withOpacity(0.7)
                                          : Colors.white,
                                      borderRadius: BorderRadius.circular(12),
                                      border: Border.all(
                                        color: const Color(0x33CCCCCC),
                                        width: 1,
                                      ),
                                    ),
                                    child: Row(
                                      mainAxisAlignment: MainAxisAlignment.center,
                                      children: [
                                        if (isSigningIn)
                                          SizedBox(
                                            width: 20,
                                            height: 20,
                                            child: CircularProgressIndicator(
                                              strokeWidth: 2,
                                              valueColor: AlwaysStoppedAnimation<Color>(
                                                Colors.grey,
                                              ),
                                            ),
                                          )
                                        else
                                          SizedBox(
                                            width: 20,
                                            height: 20,
                                            child: Image.network(
                                              'https://www.google.com/favicon.ico',
                                              errorBuilder: (context, error, stackTrace) {
                                                return Container(
                                                  decoration: const BoxDecoration(
                                                    color: Colors.blue,
                                                    shape: BoxShape.circle,
                                                  ),
                                                  child: const Center(
                                                    child: Text(
                                                      'G',
                                                      style: TextStyle(
                                                        color: Colors.white,
                                                        fontSize: 12,
                                                        fontWeight: FontWeight.bold,
                                                      ),
                                                    ),
                                                  ),
                                                );
                                              },
                                            ),
                                          ),
                                        const SizedBox(width: 12),
                                        Text(
                                          isSigningIn
                                              ? 'Signing in...'
                                              : 'Sign in with Google',
                                          style: Theme.of(context).textTheme.titleLarge?.copyWith(
                                                color: Colors.black,
                                                fontWeight: FontWeight.w500,
                                                height: 1.75,
                                              ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}
