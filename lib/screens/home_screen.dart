import 'dart:math';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:flutter_liquid_glass_plus/flutter_liquid_glass.dart';
import '../blocs/auth/auth_bloc_export.dart';
import '../blocs/credits/credits_bloc.dart';
import '../theme/app_theme.dart';
import '../widgets/login_modal.dart';
import '../widgets/profile_menu.dart';

const _cardGlassSettingsDay = LiquidGlassSettings(
  // Day: avoid warm/brown cast (slightly cool/neutral glass)
  // Reduce refraction/distortion and keep tint neutral.
  thickness: 12,
  blur: 6,
  refractiveIndex: 5.08,
  chromaticAberration: 0.0006,
  lightIntensity: 0.99,
  // very subtle neutral/cool tint so warm dunes don't brown the glass
  glassColor: Color.fromARGB(10, 245, 248, 255),
  saturation: 0.90,
);

const _cardGlassSettingsNight = LiquidGlassSettings(
  // Night: subtle blue tint like Figma
  thickness: 14,
  blur: 12,
  refractiveIndex: 1.16,
  chromaticAberration: 0.001,
  lightIntensity: 0.09,
  glassColor: Color.fromARGB(18, 170, 210, 255),
  saturation: 0.88,
);

enum _DayState { missed, completed, today, future }

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen>
    with SingleTickerProviderStateMixin {
  late AnimationController _animationController;
  late Animation<double> _fadeAnimation;
  bool _showLoginModal = false;
  bool _showMenuDrawer = false;
  bool?
      _debugNightMode; // null = auto (time-based), true/false = manual override

  bool get _isNightMode {
    if (_debugNightMode != null) return _debugNightMode!;
    final hour = DateTime.now().hour;
    return hour >= 18 || hour < 6;
  }

  LiquidGlassSettings get _currentCardGlassSettings =>
      _isNightMode ? _cardGlassSettingsNight : _cardGlassSettingsDay;

  void _toggleDebugMode() {
    setState(() {
      _debugNightMode = !_isNightMode;
    });
  }

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 300),
    );
    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _animationController, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  void _toggleLoginModal() {
    if (_showLoginModal) {
      _animationController.reverse().then((_) {
        setState(() => _showLoginModal = false);
      });
    } else {
      FocusManager.instance.primaryFocus?.unfocus();
      setState(() => _showLoginModal = true);
      _animationController.forward();
    }
  }

  Future<void> _handleGoogleSignIn() async {
    context.read<AuthBloc>().add(const AuthGoogleSignInRequested());
  }

  void _openChat() {
    Navigator.of(context).pushNamed('/chat');
  }

  String _getInitials(String name) {
    final trimmed = name.trim();
    if (trimmed.isEmpty) return '?';
    final parts = trimmed.split(RegExp(r'\s+'));
    if (parts.length >= 2) {
      return '${parts[0][0]}${parts[1][0]}'.toUpperCase();
    }
    return trimmed[0].toUpperCase();
  }

  Widget _buildInitialsAvatar(String initials, double size) {
    return Container(
      width: size,
      height: size,
      color: const Color(0xFF1A6B5C),
      child: Center(
        child: Text(
          initials,
          style: TextStyle(
            color: Colors.white,
            fontSize: size * 0.38,
            fontWeight: FontWeight.w600,
            letterSpacing: 0.5,
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final nightMode = _isNightMode;

    return BlocListener<AuthBloc, AuthState>(
      listener: (context, state) {
        if (state is AuthAuthenticated) {
          if (_showLoginModal) _toggleLoginModal();
          context.read<CreditsBloc>().add(const CreditsRequested());
        }
      },
      child: Scaffold(
        backgroundColor:
            nightMode ? const Color(0xFF004459) : const Color(0xFF9D9CEB),
        body: Stack(
          children: [
            // Fixed background (does not scroll)
            _buildBackground(nightMode),

            // Top overlay (night only; day haze is painted in _DaySkyPainter)
            if (nightMode)
              Positioned(
                top: 0,
                left: 0,
                right: 0,
                child: IgnorePointer(
                  child: Container(
                    height: 109,
                    decoration: const BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [
                          Color(0x66000000),
                          Colors.transparent,
                        ],
                      ),
                    ),
                  ),
                ),
              ),

            // Bottom fade (fixed; does not scroll)
            Positioned(
              bottom: 0,
              left: 0,
              right: 0,
              child: IgnorePointer(
                child: ClipRect(
                  child: BackdropFilter(
                    filter: ui.ImageFilter.blur(sigmaX: 6, sigmaY: 6),
                    child: Container(
                      height: 56,
                      decoration: const BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.topCenter,
                          end: Alignment.bottomCenter,
                          colors: [
                            Colors.transparent,
                            Color(0x4D000000),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),

            // Scrollable foreground: header + cards move together (no nested scroll)
            SafeArea(
              bottom: false,
              child: SingleChildScrollView(
                physics: const BouncingScrollPhysics(),
                padding: const EdgeInsets.only(bottom: 96),
                child: Column(
                  children: [
                    Padding(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 16, vertical: 8),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          GestureDetector(
                            onLongPress: _toggleDebugMode,
                            child: SizedBox(
                              height: 46,
                              child: SvgPicture.asset(
                                'assets/images/onboarding/turiya_text_logo.svg',
                                height: 46,
                                colorFilter: const ColorFilter.mode(
                                  Colors.white,
                                  BlendMode.srcIn,
                                ),
                                placeholderBuilder: (_) => Text(
                                  'Turiya',
                                  style: AppTheme.headingM(context)
                                      .copyWith(color: Colors.white),
                                ),
                              ),
                            ),
                          ),
                          _buildProfileAvatar(context),
                        ],
                      ),
                    ),

                    const SizedBox(height: 20),
                    // tighter gap between top nav and first card (Figma is denser)

                    LiquidGlassLayer(
                      child: Column(
                        children: [
                          _buildChatWithKrishnaCard(context),
                          const SizedBox(height: 16),
                          _buildGreetingStreakCard(context),
                          const SizedBox(height: 16),
                          _buildTodaysVerseCard(context),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),

            if (_showMenuDrawer)
              FadeTransition(
                opacity: _fadeAnimation,
                child: ProfileMenu(
                  onClose: () {
                    _animationController.reverse().then((_) {
                      setState(() => _showMenuDrawer = false);
                    });
                  },
                ),
              ),

            if (_showLoginModal)
              BlocBuilder<AuthBloc, AuthState>(
                builder: (context, state) {
                  return LoginModal(
                    onClose: _toggleLoginModal,
                    onGoogleSignIn: _handleGoogleSignIn,
                    isSigningIn: state is AuthLoading,
                    animation: _fadeAnimation,
                  );
                },
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildBackground(bool nightMode) {
    final screenW = MediaQuery.of(context).size.width;
    return Positioned.fill(
      child: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: nightMode
                ? const [Color(0xFF004459), Color(0xFF00263B)]
                // Slightly toned down vs raw Figma export to match on-device brightness
                : const [Color(0xFF8F8EE0), Color(0xFFF39B63)],
          ),
        ),
        child: nightMode ? _buildNightSky(screenW) : _buildDaySky(screenW),
      ),
    );
  }

  // ─── Night mode: real Figma assets ───

  // ─── Day mode: drawn from Figma (no images) ───
  Widget _buildDaySky(double screenW) {
    final s = screenW / 393.0;
    return Stack(
      fit: StackFit.expand,
      children: [
        Positioned.fill(child: CustomPaint(painter: _DaySkyPainter(scale: s))),
        Positioned.fill(
            child: CustomPaint(painter: _DayDunesPainter(scale: s))),
      ],
    );
  }

  Widget _buildNightSky(double screenW) {
    final s = screenW / 393.0;
    const moonCx = 71.5;
    const moonCy = 158.5;
    const moonImgSize = 599.6;
    // Slightly bigger moon (keep center anchored)
    final moonDrawSize = moonImgSize * 1.08;
    // Nudge the moon down so the bottom ray feels connected.
    const moonVisualDy = 4.0;
    final moonCyDraw = moonCy + moonVisualDy;

    return Stack(
      fit: StackFit.expand,
      clipBehavior: Clip.none,
      children: [
        // Cross rays — 4 diverging beams from the moon (drawn behind the moon disc)
        ..._nightRays(s, moonCx * s, moonCy * s),

        // Moon glow (PNG with baked-in drop shadow filters from Figma)
        Positioned(
          left: (moonCx - moonDrawSize / 2) * s,
          top: (moonCyDraw - moonDrawSize / 2) * s,
          width: moonDrawSize * s,
          height: moonDrawSize * s,
          child: Image.asset(
            'assets/images/night_bg/moon_glow.png',
            fit: BoxFit.contain,
          ),
        ),

        // Stars at exact Figma positions
        ..._nightStars(s),

        // Mountain/wave layers at the bottom
        ..._nightMountains(s),
      ],
    );
  }

  List<Widget> _nightStars(double s) {
    // Each entry: [figmaLeft, figmaTop, elemW, elemH, assetBasename, imgW, imgH]
    const data = <List<dynamic>>[
      [374.0, 218.0, 5.0, 5.0, 'star_5px', 39.2, 39.2],
      [313.0, 251.0, 4.0, 3.0, 'star_4px', 38.2, 38.2],
      [197.0, 223.0, 5.0, 5.0, 'star_5px', 39.2, 39.2],
      [233.0, 287.0, 2.0, 2.0, 'star_3px', 37.2, 37.2],
      [83.0, 269.0, 5.0, 5.0, 'star_5px', 39.2, 39.2],
      [287.0, 376.0, 6.0, 6.0, 'star_6px', 40.2, 39.2],
      [69.0, 204.0, 5.0, 6.0, 'star_6px', 40.2, 39.2],
      [14.0, 176.0, 3.0, 4.0, 'star_4px', 38.2, 38.2],
      [50.0, 294.0, 3.0, 4.0, 'star_4px', 38.2, 38.2],
      [344.0, 350.0, 4.0, 4.0, 'star_4px', 38.2, 38.2],
      [126.0, 144.0, 3.0, 3.0, 'star_3px', 37.2, 37.2],
      [129.0, 322.0, 2.0, 3.0, 'star_3px', 37.2, 37.2],
      [119.0, 103.0, 5.0, 5.0, 'star_5px', 39.2, 39.2],
      [227.0, 155.0, 6.0, 6.0, 'star_6px', 40.2, 39.2],
      [314.0, 149.0, 4.0, 3.0, 'star_4px', 38.2, 38.2],
      [79.0, 179.0, 4.0, 5.0, 'star_5px', 39.2, 39.2],
      [212.0, 315.0, 3.0, 2.0, 'star_3px', 37.2, 37.2],
      [316.0, 210.0, 4.0, 3.0, 'star_4px', 38.2, 38.2],
      [286.0, 138.0, 4.0, 4.0, 'star_4px', 38.2, 38.2],
      [24.0, 263.0, 3.0, 4.0, 'star_4px', 38.2, 38.2],
      [131.0, 328.0, 1.0, 1.0, 'star_3px', 37.2, 37.2],
      [16.0, 227.0, 2.0, 1.0, 'star_3px', 37.2, 37.2],
      [294.0, 197.0, 4.0, 5.0, 'star_5px', 39.2, 39.2],
    ];

    return data.map((d) {
      final cx = (d[0] as double) + (d[2] as double) / 2;
      final cy = (d[1] as double) + (d[3] as double) / 2;
      final imgW = d[5] as double;
      final imgH = d[6] as double;
      return Positioned(
        left: (cx - imgW / 2) * s,
        top: (cy - imgH / 2) * s,
        width: imgW * s,
        height: imgH * s,
        child: Image.asset(
          'assets/images/night_bg/${d[4]}.png',
          fit: BoxFit.contain,
        ),
      );
    }).toList();
  }

  List<Widget> _nightMountains(double s) {
    return [
      // Layer 1 (back): wave1 – gradient mountain
      Positioned(
        left: -96 * s,
        bottom: -120 * s,
        width: 594.5 * s,
        height: 307 * s,
        child:
            Image.asset('assets/images/night_bg/wave1.png', fit: BoxFit.fill),
      ),
      // Layer 2: wave2 – solid teal wave
      Positioned(
        left: -15 * s,
        bottom: -15.5 * s,
        width: 408 * s,
        height: 171 * s,
        child:
            Image.asset('assets/images/night_bg/wave2.png', fit: BoxFit.fill),
      ),
      // Layer 3: wave1 flipped horizontally
      Positioned(
        left: -112 * s,
        bottom: -192 * s,
        width: 594.5 * s,
        height: 307 * s,
        child: Transform(
          alignment: Alignment.center,
          transform: Matrix4.identity()..scale(-1.0, 1.0),
          child:
              Image.asset('assets/images/night_bg/wave1.png', fit: BoxFit.fill),
        ),
      ),
      // Layer 4 (front): wave3 flipped horizontally
      Positioned(
        left: -6 * s,
        bottom: -88 * s,
        width: 614 * s,
        height: 171 * s,
        child: Transform(
          alignment: Alignment.center,
          transform: Matrix4.identity()..scale(-1.0, 1.0),
          child:
              Image.asset('assets/images/night_bg/wave3.png', fit: BoxFit.fill),
        ),
      ),
    ];
  }

  List<Widget> _nightRays(double s, double moonCxScaled, double moonCyScaled) {
    // Draw rays via painter for pixel-accurate trapezoid, blur, plus-lighter blend.
    return [
      Positioned.fill(
        child: CustomPaint(
          key: const ValueKey('night-rays-v6'),
          painter: _NightRaysPainter(
            cx: moonCxScaled,
            cy: moonCyScaled,
            scale: s,
          ),
        ),
      ),
    ];
  }

  Widget _buildProfileAvatar(BuildContext context) {
    return BlocBuilder<AuthBloc, AuthState>(
      builder: (context, state) {
        if (state is AuthAuthenticated) {
          final user = state.user;
          final avatarUrl = user.userMetadata?['avatar_url'] as String?;
          final fullName = user.userMetadata?['full_name'] as String? ??
              user.userMetadata?['name'] as String? ??
              user.email ??
              '';
          final initials = _getInitials(fullName);

          return GestureDetector(
            onTap: () {
              setState(() => _showMenuDrawer = true);
              _animationController.forward();
            },
            child: Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(
                  color: const Color(0x1AFFFFFF),
                  width: 1,
                ),
              ),
              child: ClipOval(
                child: avatarUrl != null && avatarUrl.isNotEmpty
                    ? Image.network(
                        avatarUrl,
                        width: 44,
                        height: 44,
                        fit: BoxFit.cover,
                        errorBuilder: (_, __, ___) =>
                            _buildInitialsAvatar(initials, 44),
                      )
                    : _buildInitialsAvatar(initials, 44),
              ),
            ),
          );
        }
        return GestureDetector(
          onTap: _toggleLoginModal,
          child: Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: Colors.transparent,
              borderRadius: BorderRadius.circular(24),
              border: Border.all(
                color: const Color(0x1AFFFFFF),
                width: 1,
              ),
            ),
            child: const Center(
              child: Icon(
                Icons.person_outline,
                color: Colors.white,
                size: 22,
              ),
            ),
          ),
        );
      },
    );
  }

  // ─── Content Cards ───

  Widget _buildChatWithKrishnaCard(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: GestureDetector(
        onTap: _openChat,
        child: Container(
          height: 199,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(24),
            border: Border.all(
              color: Colors.white.withOpacity(0.1),
              width: 0.5,
            ),
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(24),
            child: LGContainer(
              useOwnLayer: true,
              quality: LGQuality.premium,
              shape: const LiquidRoundedSuperellipse(borderRadius: 24),
              settings: _currentCardGlassSettings,
              child: Stack(
                children: [
                  Positioned(
                    right: -40,
                    top: 0,
                    bottom: -30,
                    width: 230,
                    child: Align(
                      alignment: Alignment.centerRight,
                      child: Transform.scale(
                        scale: 0.92,
                        alignment: Alignment.centerRight,
                        child: Image.asset(
                          'assets/images/krishna_home.png',
                          fit: BoxFit.contain,
                          alignment: Alignment.centerRight,
                          errorBuilder: (_, __, ___) => const SizedBox.shrink(),
                        ),
                      ),
                    ),
                  ),
                  Positioned(
                    left: 24,
                    top: 24,
                    width: 179,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Chat with Krishna',
                          style: AppTheme.headingL(context)
                              .copyWith(color: Colors.white),
                        ),
                        Text(
                          'Speak freely. Listen deeply.',
                          style: AppTheme.bodyS(context)
                              .copyWith(color: Colors.white),
                        ),
                      ],
                    ),
                  ),
                  Positioned(
                    left: 24,
                    bottom: 24,
                    child: Container(
                      height: 48,
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(16),
                      ),
                      alignment: Alignment.center,
                      child: Text(
                        'Start conversation \u2192',
                        style: AppTheme.bodyM(context)
                            .copyWith(color: const Color(0xFF111111)),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildGreetingStreakCard(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(24),
          border: Border.all(
            color: Colors.white.withOpacity(0.1),
            width: 0.5,
          ),
        ),
        child: LGContainer(
          useOwnLayer: true,
          quality: LGQuality.premium,
          shape: const LiquidRoundedSuperellipse(borderRadius: 24),
          settings: _currentCardGlassSettings,
          padding: const EdgeInsets.fromLTRB(24, 16, 24, 16),
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 8),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          BlocBuilder<AuthBloc, AuthState>(
                            builder: (context, state) {
                              String name = 'Friend';
                              if (state is AuthAuthenticated) {
                                name = state.user.userMetadata?['full_name']
                                        as String? ??
                                    state.user.userMetadata?['name']
                                        as String? ??
                                    'Friend';
                                final parts = name.split(' ');
                                if (parts.isNotEmpty) name = parts.first;
                              }
                              return Text(
                                'Namaste, $name',
                                style: AppTheme.bodyM(context).copyWith(
                                  color: Colors.white.withOpacity(0.5),
                                ),
                              );
                            },
                          ),
                          Text(
                            "Let\u2019s begin",
                            style: AppTheme.displayEL(context)
                                .copyWith(color: Colors.white),
                          ),
                        ],
                      ),
                    ),
                    _buildStreakBadge(context),
                  ],
                ),
              ),
              const SizedBox(height: 24),
              _buildWeeklyTracker(context),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildStreakBadge(BuildContext context) {
    return Container(
      height: 32,
      padding: const EdgeInsets.only(left: 8, right: 16),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.1),
        borderRadius: BorderRadius.circular(80),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Text('\u{1F525}', style: TextStyle(fontSize: 14)),
          const SizedBox(width: 4),
          Text(
            '2 Days',
            style: AppTheme.bodyEM(context).copyWith(color: Colors.white),
          ),
        ],
      ),
    );
  }

  Widget _buildWeeklyTracker(BuildContext context) {
    final days = ['M', 'T', 'W', 'Th', 'F', 'St', 'Su'];
    final states = [
      _DayState.missed, // M
      _DayState.missed, // T
      _DayState.completed, // W
      _DayState.completed, // Th
      _DayState.today, // F
      _DayState.future, // St
      _DayState.future, // Su
    ];

    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: List.generate(7, (i) {
        final state = states[i];
        final isFuture = state == _DayState.future;

        return Opacity(
          opacity: isFuture ? 0.5 : 1.0,
          child: SizedBox(
            width: 32,
            child: Column(
              children: [
                _buildTrackerCircle(state),
                const SizedBox(height: 8),
                Text(
                  days[i],
                  style: AppTheme.bodyM(context).copyWith(
                    color: Colors.white,
                    fontWeight: state == _DayState.today
                        ? FontWeight.w800
                        : FontWeight.normal,
                  ),
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          ),
        );
      }),
    );
  }

  Widget _buildTrackerCircle(_DayState state) {
    switch (state) {
      case _DayState.missed:
        return CustomPaint(
          size: const Size(32, 32),
          painter: _DashedCirclePainter(
            color: Colors.white.withOpacity(0.4),
            strokeWidth: 1.5,
            dashCount: 12,
          ),
        );
      case _DayState.completed:
        return Container(
          width: 32,
          height: 32,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: Colors.white,
            boxShadow: [
              BoxShadow(
                color: Colors.white.withOpacity(0.4),
                blurRadius: 12,
                spreadRadius: 2,
              ),
            ],
          ),
        );
      case _DayState.today:
        return Container(
          width: 32,
          height: 32,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: Colors.transparent,
            border: Border.all(color: Colors.white, width: 3),
            boxShadow: [
              BoxShadow(
                color: Colors.white.withOpacity(0.35),
                blurRadius: 10,
                spreadRadius: 1,
              ),
            ],
          ),
        );
      case _DayState.future:
        return Container(
          width: 32,
          height: 32,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            border: Border.all(
              color: Colors.white.withOpacity(0.5),
              width: 1,
            ),
          ),
        );
    }
  }

  Widget _buildTodaysVerseCard(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(24),
          border: Border.all(
            color: Colors.white.withOpacity(0.1),
            width: 0.5,
          ),
        ),
        child: LGContainer(
          useOwnLayer: true,
          quality: LGQuality.premium,
          shape: const LiquidRoundedSuperellipse(borderRadius: 24),
          settings: _currentCardGlassSettings,
          padding: const EdgeInsets.all(24),
          child: Column(
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    "TODAY'S VERSE",
                    style: AppTheme.captionS(context).copyWith(
                      color: Colors.white,
                      letterSpacing: 0.5,
                    ),
                  ),
                  Text(
                    'CHAPTER 1 : VERSE 1',
                    style: AppTheme.captionS(context).copyWith(
                      color: Colors.white,
                      letterSpacing: 0.5,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 40),
              const Text(
                '\u0915\u0930\u094D\u092E\u0923\u094D\u092F\u0947\u0935\u093E\u0927\u093F\u0915\u093E\u0930\u0938\u094D\u0924\u0947 \u092E\u093E \u092B\u0932\u0947\u0937\u0941 \u0915\u0926\u093E\u091A\u0928\u0964\n\u092E\u093E \u0915\u0930\u094D\u092E\u092B\u0932\u0939\u0947\u0924\u0941\u0930\u094D\u092D\u0942\u0930\u094D\u092E\u093E \u0924\u0947 \u0938\u0919\u094D\u0917\u094B\u2019\u0938\u094D\u0924\u094D\u0935\u0915\u0930\u094D\u092E\u0923\u093F\u0965\u0965',
                style: TextStyle(
                  fontFamily: 'Alegreya',
                  fontSize: 18,
                  fontWeight: FontWeight.w400,
                  color: Colors.white,
                  height: 1.25,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 16),
              Text(
                'Karma\u1E47y-ev\u0101dhik\u0101ras te m\u0101 phale\u1E63hu kad\u0101chana,\nm\u0101 karma-phala-hetur bh\u016Br m\u0101 te sa\u1E45go \'stvakarma\u1E47i.',
                style: AppTheme.bodyS(context).copyWith(color: Colors.white),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 16),
              Text(
                'You have a right to perform your prescribed duties,\nbut you are not entitled to the fruits of your actions.\nNever consider yourself the cause of the results of your activities,\nand never be attached to not doing your duty.',
                style: AppTheme.bodyS(context).copyWith(
                  color: Colors.white,
                  fontStyle: FontStyle.italic,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 40),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.share_outlined, color: Colors.white, size: 24),
                  const SizedBox(width: 8),
                  Icon(Icons.bookmark_border, color: Colors.white, size: 24),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ─── Dashed circle painter for "missed" day state ───
class _DashedCirclePainter extends CustomPainter {
  final Color color;
  final double strokeWidth;
  final int dashCount;

  _DashedCirclePainter({
    required this.color,
    required this.strokeWidth,
    required this.dashCount,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth
      ..strokeCap = StrokeCap.round;

    final center = Offset(size.width / 2, size.height / 2);
    final radius = (size.width - strokeWidth) / 2;
    const fullAngle = 2 * pi;
    final dashAngle = fullAngle / dashCount * 0.55;
    final gapAngle = fullAngle / dashCount * 0.45;

    double current = -pi / 2;
    for (int i = 0; i < dashCount; i++) {
      final rect = Rect.fromCircle(center: center, radius: radius);
      canvas.drawArc(rect, current, dashAngle, false, paint);
      current += dashAngle + gapAngle;
    }
  }

  @override
  bool shouldRepaint(covariant _DashedCirclePainter oldDelegate) =>
      color != oldDelegate.color ||
      strokeWidth != oldDelegate.strokeWidth ||
      dashCount != oldDelegate.dashCount;
}

// ─── Night rays: exact Figma trapezoid + blur + plus-lighter ───
class _NightRaysPainter extends CustomPainter {
  final double cx;
  final double cy;
  final double scale;

  _NightRaysPainter({
    required this.cx,
    required this.cy,
    required this.scale,
  });

  // Figma ray SVG (viewBox 0 0 377 179):
  // Path: M28 60 L349 28 V151 L28 119 Z
  // Pivot is the narrow-end center: (28, 89.5)
  static const _pivot = Offset(28, 89.5);
  static const _rayLen = 321.0; // (_rayEndX - 28)
  // Clip out the moon disc so rays start behind it.
  static const _moonClipR = 40.0;
  // Make rays a bit thinner without changing their length.
  static const _thicknessScale = 0.82;

  @override
  void paint(Canvas canvas, Size size) {
    final s = scale;

    final rayPath = Path()
      ..moveTo((28 - _pivot.dx) * s, (60 - _pivot.dy) * s * _thicknessScale)
      ..lineTo((349 - _pivot.dx) * s, (28 - _pivot.dy) * s * _thicknessScale)
      ..lineTo((349 - _pivot.dx) * s, (151 - _pivot.dy) * s * _thicknessScale)
      ..lineTo((28 - _pivot.dx) * s, (119 - _pivot.dy) * s * _thicknessScale)
      ..close();

    canvas.translate(cx, cy);

    // Base ray gradient (Figma is ~7%; bumped slightly for match on-device).
    final baseShader = ui.Gradient.linear(
      const Offset(0, 0),
      Offset(_rayLen * s, 0),
      [
        Colors.white.withOpacity(0.09),
        Colors.transparent,
      ],
      const [0.0, 1.0],
    );

    for (final angle in [0.0, pi / 2, pi, -pi / 2]) {
      canvas.save();
      canvas.rotate(angle);

      // Clip out moon disc so the ray starts from behind it.
      final outside = Path()
        ..addRect(const Rect.fromLTWH(-5000, -5000, 10000, 10000));
      final circle = Path()
        ..addOval(Rect.fromCircle(center: Offset.zero, radius: _moonClipR * s));
      canvas.clipPath(
        Path.combine(PathOperation.difference, outside, circle),
        doAntiAlias: true,
      );

      // Sharp → blur progression without hard slice seams:
      // draw multiple blurred layers and apply a soft alpha mask (dstIn) per layer.
      // Use very large bounds so blur never gets hard-clipped into rectangles.
      final layerBounds = Rect.fromLTWH(
        -size.width * 2,
        -size.height * 2,
        size.width * 4,
        size.height * 4,
      );

      void drawMaskedLayer({
        required double blurSigmaFigmaPx,
        required double opacity,
        required List<double> maskStops,
        required List<Color> maskColors,
      }) {
        canvas.saveLayer(layerBounds, Paint()..blendMode = BlendMode.plus);

        // Ray content (blurred)
        canvas.drawPath(
          rayPath,
          Paint()
            ..shader = baseShader
            ..colorFilter = ColorFilter.mode(
              Colors.white.withOpacity(opacity),
              BlendMode.modulate,
            )
            ..maskFilter = ui.MaskFilter.blur(
              ui.BlurStyle.normal,
              blurSigmaFigmaPx * s,
            ),
        );

        // Alpha mask along X to blend layers smoothly
        final maskShader = ui.Gradient.linear(
          const Offset(0, 0),
          Offset(_rayLen * s, 0),
          maskColors,
          maskStops,
        );
        canvas.drawRect(
          layerBounds,
          Paint()
            ..shader = maskShader
            ..blendMode = BlendMode.dstIn,
        );

        canvas.restore();
      }

      // Sharp core near moon (crisper edges)
      drawMaskedLayer(
        blurSigmaFigmaPx: 0.9,
        opacity: 1.0,
        maskColors: const [
          Color(0xFFFFFFFF),
          Color(0xFFFFFFFF),
          Color(0x00FFFFFF),
        ],
        maskStops: const [0.0, 0.18, 0.40],
      );

      // Mid diffusion (smoothly fades in/out)
      drawMaskedLayer(
        blurSigmaFigmaPx: 8.0,
        opacity: 1.0,
        maskColors: const [
          Color(0x00FFFFFF),
          Color(0xFFFFFFFF),
          Color(0xFFFFFFFF),
          Color(0x00FFFFFF),
        ],
        maskStops: const [0.0, 0.14, 0.72, 0.92],
      );

      // Far diffusion (tail)
      drawMaskedLayer(
        blurSigmaFigmaPx: 14.0,
        opacity: 0.85,
        maskColors: const [
          Color(0x00FFFFFF),
          Color(0xFFFFFFFF),
          Color(0xFFFFFFFF),
        ],
        maskStops: const [0.0, 0.38, 1.0],
      );

      // Very soft overall bloom
      drawMaskedLayer(
        blurSigmaFigmaPx: 18.0,
        opacity: 0.35,
        maskColors: const [
          Color(0x00FFFFFF),
          Color(0xFFFFFFFF),
        ],
        maskStops: const [0.0, 1.0],
      );

      canvas.restore();
    }
  }

  @override
  bool shouldRepaint(covariant _NightRaysPainter oldDelegate) {
    return cx != oldDelegate.cx ||
        cy != oldDelegate.cy ||
        scale != oldDelegate.scale;
  }
}

// (Old programmatic background painters removed; day/night use dedicated implementations.)

class _DaySkyPainter extends CustomPainter {
  final double scale;
  _DaySkyPainter({required this.scale});

  @override
  void paint(Canvas canvas, Size size) {
    final s = scale;

    // Top white haze (Figma: mix-blend plus-lighter, height ~320, starts near y=4)
    final hazeRect = Rect.fromLTWH(0, 4 * s, size.width, 320 * s);
    canvas.drawRect(
      hazeRect,
      Paint()
        ..blendMode = BlendMode.plus
        ..shader = ui.Gradient.linear(
          hazeRect.topCenter,
          hazeRect.bottomCenter,
          [
            Colors.white.withOpacity(0.10),
            Colors.white.withOpacity(0.10),
            Colors.transparent,
          ],
          const [0.0, 0.20538, 1.0],
        ),
    );

    // Crescent + glow (Figma group at x=233.06,y=102.72 rotated -28.36deg)
    final crescentCenter =
        Offset((233.06 + 67.876 / 2) * s, (102.72 + 70.562 / 2) * s);
    canvas.save();
    canvas.translate(crescentCenter.dx, crescentCenter.dy);
    canvas.rotate(-28.36 * pi / 180);

    // Glow behind crescent
    canvas.drawCircle(
      Offset.zero,
      38 * s,
      Paint()
        ..blendMode = BlendMode.plus
        ..color = Colors.white.withOpacity(0.22)
        ..maskFilter = ui.MaskFilter.blur(ui.BlurStyle.normal, 18 * s),
    );

    // Crescent body (difference of circles)
    final r = 16.5 * s;
    final outer = Path()
      ..addOval(Rect.fromCircle(center: Offset.zero, radius: r));
    final cutout = Path()
      ..addOval(
          Rect.fromCircle(center: Offset(6.5 * s, -2.0 * s), radius: r * 0.92));
    final crescent = Path.combine(PathOperation.difference, outer, cutout);
    canvas.drawPath(crescent, Paint()..color = Colors.white.withOpacity(0.85));
    canvas.restore();

    // Sun glow (Figma Ellipse 312):
    // circle r=37.5 with 2 drop shadows, both plus-lighter, color #FFD899
    // shadow1: dy=2, blur=42.6
    // shadow2: dilate=21, dy=4, blur=120.65
    final sunCenter = Offset((115 + 37.5) * s, (708 + 37.5) * s);
    const glowColor = Color(0xFFFFD899);
    final baseR = 37.5 * s;

    // Outer bloom (dilate 21)
    canvas.drawCircle(
      sunCenter.translate(0, 4 * s),
      (37.5 + 21) * s,
      Paint()
        ..blendMode = BlendMode.plus
        ..color = glowColor
        ..maskFilter = ui.MaskFilter.blur(ui.BlurStyle.normal, 120.65 * s),
    );

    // Inner bloom
    canvas.drawCircle(
      sunCenter.translate(0, 2 * s),
      baseR,
      Paint()
        ..blendMode = BlendMode.plus
        ..color = glowColor
        ..maskFilter = ui.MaskFilter.blur(ui.BlurStyle.normal, 42.6 * s),
    );

    // Core disc (white)
    canvas.drawCircle(
      sunCenter,
      baseR,
      Paint()
        ..blendMode = BlendMode.plus
        ..color = Colors.white,
    );

    // Diamond stars (Figma positions, no randomness)
    const stars = <List<double>>[
      // x, y, coreSize
      [337.76, 23.0, 6.0],
      [193.57, 73.14, 4.225],
      [376.92, 67.23, 4.225],
      [363.15, 118.28, 3.38],
      [334.83, 24.0, 1.69],
      [382.25, 110.81, 5.07],
      [250.93, 192.77, 5.07],
      [118.39, 115.39, 4.225],
      [126.32, 326.48, 2.535],
      [149.73, 249.94, 1.69],
      [328.86, 262.61, 1.69],
      [151.19, 247.41, 1.69],
      [356.52, 174.89, 3.38],
      [239.62, 193.83, 2.535],
      [123.73, 249.94, 1.69],
      [200.06, 330.50, 5.07],
      [293.92, 193.62, 5.07],
      [355.90, 78.21, 4.225],
      [72.00, 113.91, 1.69],
      [123.73, 249.41, 1.69],
    ];

    for (final st in stars) {
      final x = st[0] * s;
      final y = st[1] * s;
      final core = st[2] * s;
      _drawDiamondStar(canvas, Offset(x, y), core);
    }
  }

  void _drawDiamondStar(Canvas canvas, Offset c, double coreSize) {
    // Figma star: white diamond w/ yellowish glow
    final half = coreSize / 2;
    final diamond = Path()
      ..moveTo(c.dx, c.dy - half)
      ..lineTo(c.dx + half, c.dy)
      ..lineTo(c.dx, c.dy + half)
      ..lineTo(c.dx - half, c.dy)
      ..close();

    const glow = Color(0xFFFFFF7C); // #FFFF7C

    canvas.drawPath(
      diamond,
      Paint()
        ..blendMode = BlendMode.plus
        ..color = glow.withOpacity(0.35)
        ..maskFilter = ui.MaskFilter.blur(ui.BlurStyle.normal, 10),
    );
    canvas.drawPath(
      diamond,
      Paint()
        ..blendMode = BlendMode.plus
        ..color = glow.withOpacity(0.25)
        ..maskFilter = ui.MaskFilter.blur(ui.BlurStyle.normal, 6),
    );
    canvas.drawPath(diamond, Paint()..color = Colors.white.withOpacity(0.95));
  }

  @override
  bool shouldRepaint(covariant _DaySkyPainter oldDelegate) => false;
}

class _DayDunesPainter extends CustomPainter {
  final double scale;
  _DayDunesPainter({required this.scale});

  @override
  void paint(Canvas canvas, Size size) {
    final s = scale;

    // Back dune (Figma: bottom=-162, left=-106.25, w=627, h=325)
    _drawDuneRidge(
      canvas,
      size,
      left: -106.25 * s,
      bottom: -162 * s,
      width: 627 * s,
      height: 325 * s,
      color: const Color(0xFFBE8260),
      // points: xRel, yRel (0=top of rect, 1=base)
      ridge: const [
        [0.00, 0.92],
        [0.18, 0.72],
        [0.36, 0.40],
        [0.52, 0.30],
        [0.68, 0.46],
        [0.82, 0.36],
        [0.94, 0.44],
        [1.00, 0.52],
      ],
    );

    // Front dune (Figma: bottom=-51, left=-21.25, w=431, h=180)
    _drawDuneRidge(
      canvas,
      size,
      left: -21.25 * s,
      bottom: -51 * s,
      width: 431 * s,
      height: 180 * s,
      color: const Color(0xFFB07050),
      ridge: const [
        [0.00, 0.92],
        [0.12, 0.80],
        [0.28, 0.66],
        [0.44, 0.74],
        [0.60, 0.68],
        [0.76, 0.76],
        [0.90, 0.70],
        [1.00, 0.76],
      ],
    );

    // Solid base fill (prevents any 1px gaps at bottom due to AA)
    canvas.drawRect(
      Rect.fromLTWH(0, size.height - 2, size.width, 2),
      Paint()..color = const Color(0xFFB07050),
    );
  }

  void _drawDuneRidge(
    Canvas canvas,
    Size size, {
    required double left,
    required double bottom,
    required double width,
    required double height,
    required Color color,
    required List<List<double>> ridge,
  }) {
    // Figma uses Positioned(bottom: negative) for these layers.
    // Translate to a top/base in our canvas coordinate space.
    final topY = size.height - height - bottom;
    final baseY = topY + height;

    final points = ridge
        .map((p) => Offset(left + width * p[0], topY + height * p[1]))
        .toList(growable: false);

    final path = Path()..moveTo(points.first.dx, points.first.dy);
    for (int i = 0; i < points.length - 1; i++) {
      final p0 = points[i];
      final p1 = points[i + 1];
      final dx = (p1.dx - p0.dx) * 0.45;
      path.cubicTo(
        p0.dx + dx,
        p0.dy,
        p1.dx - dx,
        p1.dy,
        p1.dx,
        p1.dy,
      );
    }

    // Extend to cover full width and bottom
    path.lineTo(points.last.dx, baseY);
    path.lineTo(left + width, baseY);
    path.lineTo(left + width, size.height + 400);
    path.lineTo(left, size.height + 400);
    path.close();

    canvas.drawPath(path, Paint()..color = color);
  }

  @override
  bool shouldRepaint(covariant _DayDunesPainter oldDelegate) => false;
}
