import 'dart:math';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_svg/flutter_svg.dart';
import '../blocs/auth/auth_bloc_export.dart';
import '../blocs/credits/credits_bloc.dart';
import '../theme/app_theme.dart';
import '../widgets/login_modal.dart';
import '../widgets/profile_menu.dart';

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
    return BlocListener<AuthBloc, AuthState>(
      listener: (context, state) {
        if (state is AuthAuthenticated) {
          if (_showLoginModal) _toggleLoginModal();
          context.read<CreditsBloc>().add(const CreditsRequested());
        }
      },
      child: Scaffold(
        backgroundColor: const Color(0xFF004459),
        body: Stack(
          children: [
            // Background
            _buildBackground(),

            // Scrollable content
            SafeArea(
              bottom: false,
              child: Padding(
                padding: const EdgeInsets.only(top: 60),
                child: SingleChildScrollView(
                  physics: const BouncingScrollPhysics(),
                  padding: const EdgeInsets.only(bottom: 40),
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
              ),
            ),

            // Header
            Positioned(
              top: 0,
              left: 0,
              right: 0,
              child: SafeArea(
                bottom: false,
                child: Padding(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Container(
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
                      _buildProfileAvatar(context),
                    ],
                  ),
                ),
              ),
            ),

            // Top gradient overlay for depth
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

            // Bottom gradient fade
            Positioned(
              bottom: 0,
              left: 0,
              right: 0,
              child: IgnorePointer(
                child: ClipRect(
                  child: BackdropFilter(
                    filter: ImageFilter.blur(sigmaX: 6, sigmaY: 6),
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

            // Profile menu overlay
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

            // Login modal overlay
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

  Widget _buildBackground() {
    return Positioned.fill(
      child: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              Color(0xFF004459),
              Color(0xFF00263B),
            ],
          ),
        ),
        child: CustomPaint(
          painter: _StarFieldPainter(),
        ),
      ),
    );
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
            color: const Color(0x1A000000),
            borderRadius: BorderRadius.circular(24),
            boxShadow: const [
              BoxShadow(
                color: Color(0x14111111),
                blurRadius: 16,
                offset: Offset(0, 4),
              ),
            ],
          ),
          clipBehavior: Clip.antiAlias,
          child: Stack(
            children: [
              Positioned(
                right: 0,
                top: 0,
                bottom: 0,
                width: 213,
                child: Image.asset(
                  'assets/images/krishna_home.png',
                  fit: BoxFit.cover,
                  alignment: Alignment.centerLeft,
                  errorBuilder: (_, __, ___) => const SizedBox.shrink(),
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
    );
  }

  Widget _buildGreetingStreakCard(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Container(
        decoration: BoxDecoration(
          color: const Color(0x1A000000),
          borderRadius: BorderRadius.circular(24),
          boxShadow: const [
            BoxShadow(
              color: Color(0x14111111),
              blurRadius: 16,
              offset: Offset(0, 4),
            ),
          ],
        ),
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
            style:
                AppTheme.bodyEM(context).copyWith(color: Colors.white),
          ),
        ],
      ),
    );
  }

  Widget _buildWeeklyTracker(BuildContext context) {
    final days = ['M', 'T', 'W', 'Th', 'F', 'St', 'Su'];
    final activeStates = [true, true, true, true, true, false, false];
    final today = 4;

    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: List.generate(7, (i) {
        final isActive = activeStates[i];
        final isToday = i == today;

        return SizedBox(
          width: 32,
          child: Column(
            children: [
              Container(
                width: 32,
                height: 32,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: isActive
                      ? Colors.white.withOpacity(isToday ? 1.0 : 0.6)
                      : Colors.transparent,
                  border: !isActive
                      ? Border.all(
                          color: Colors.white.withOpacity(0.2),
                          width: 1.5,
                        )
                      : null,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                days[i],
                style: AppTheme.bodyM(context).copyWith(
                      color: Colors.white.withOpacity(isActive ? 1.0 : 0.5),
                      fontWeight:
                          isToday ? FontWeight.w800 : FontWeight.normal,
                    ),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        );
      }),
    );
  }

  Widget _buildTodaysVerseCard(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Container(
        decoration: BoxDecoration(
          color: const Color(0x1A000000),
          borderRadius: BorderRadius.circular(24),
          boxShadow: const [
            BoxShadow(
              color: Color(0x14111111),
              blurRadius: 16,
              offset: Offset(0, 4),
            ),
          ],
        ),
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
                  'CHAPTER 2 : VERSE 47',
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
              style:
                  AppTheme.bodyS(context).copyWith(color: Colors.white),
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
              children: [
                Icon(Icons.share_outlined, color: Colors.white, size: 20),
                const SizedBox(width: 8),
                Icon(Icons.bookmark_border, color: Colors.white, size: 20),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

/// Paints scattered stars on the background
class _StarFieldPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final rng = Random(42);
    final paint = Paint()..color = Colors.white;

    for (int i = 0; i < 60; i++) {
      final x = rng.nextDouble() * size.width;
      final y = rng.nextDouble() * size.height * 0.7;
      final radius = rng.nextDouble() * 2.0 + 0.5;
      paint.color = Colors.white.withOpacity(rng.nextDouble() * 0.4 + 0.1);
      canvas.drawCircle(Offset(x, y), radius, paint);
    }

    // Larger glowing orb (upper left area like the Figma design)
    final glowPaint = Paint()
      ..shader = RadialGradient(
        colors: [
          Colors.white.withOpacity(0.15),
          Colors.white.withOpacity(0.05),
          Colors.transparent,
        ],
      ).createShader(
        Rect.fromCircle(
          center: Offset(size.width * 0.2, size.height * 0.15),
          radius: 60,
        ),
      );
    canvas.drawCircle(
      Offset(size.width * 0.2, size.height * 0.15),
      60,
      glowPaint,
    );
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
