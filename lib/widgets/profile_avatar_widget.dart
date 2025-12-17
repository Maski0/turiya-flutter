import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../blocs/credits/credits_bloc.dart';
import '../blocs/auth/auth_bloc_export.dart';

class ProfileAvatarWidget extends StatefulWidget {
  final VoidCallback onTap;

  const ProfileAvatarWidget({
    super.key,
    required this.onTap,
  });

  @override
  State<ProfileAvatarWidget> createState() => _ProfileAvatarWidgetState();
}

class _ProfileAvatarWidgetState extends State<ProfileAvatarWidget>
    with SingleTickerProviderStateMixin {
  late AnimationController _fadeController;
  late Animation<double> _fadeAnimation;
  bool _hasAnimated = false;

  @override
  void initState() {
    super.initState();
    _fadeController = AnimationController(
      duration: const Duration(milliseconds: 400),
      vsync: this,
    );
    _fadeAnimation = CurvedAnimation(
      parent: _fadeController,
      curve: Curves.easeIn,
    );
  }

  @override
  void dispose() {
    _fadeController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: widget.onTap,
      child: BlocBuilder<AuthBloc, AuthState>(
        builder: (context, authState) {
          if (authState is! AuthAuthenticated) {
            return const SizedBox.shrink();
          }

          final user = authState.user;
          final avatarUrl = user.userMetadata?['avatar_url'] as String?;

          return BlocBuilder<CreditsBloc, CreditsState>(
            builder: (context, creditsState) {
              // Determine credits display
              String creditsText = '';
              bool isUnlimited = false;

              if (creditsState is CreditsLoaded) {
                if (creditsState.isPro) {
                  creditsText = '∞';
                  isUnlimited = true;
                } else {
                  creditsText = '${creditsState.totalCredits}';
                }

                // Trigger fade in animation when credits load
                if (!_hasAnimated) {
                  _hasAnimated = true;
                  _fadeController.forward();
                }
              }

              // Don't show until credits are loaded
              if (creditsState is! CreditsLoaded) {
                return const SizedBox.shrink();
              }

              // Full pill shape - rounded on both sides with fade animation
              return FadeTransition(
                opacity: _fadeAnimation,
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(28),
                  child: BackdropFilter(
                    filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
                    child: Container(
                      height: 52,
                      decoration: BoxDecoration(
                        color: const Color(0x1AFFFFFF),
                        borderRadius: BorderRadius.circular(28),
                        border: Border.all(
                          color: const Color(0x33FFFFFF),
                          width: 1,
                        ),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        crossAxisAlignment: CrossAxisAlignment.center,
                        children: [
                          // Credits display on the left
                          Container(
                            height: 52,
                            alignment: Alignment.center,
                            margin: const EdgeInsets.only(left: 18, right: 10),
                            child: Text(
                              creditsText,
                              textAlign: TextAlign.center,
                              strutStyle: const StrutStyle(
                                forceStrutHeight: true,
                                height: 1.0,
                              ),
                              style: TextStyle(
                                fontFamily: 'Alegreya',
                                fontSize: isUnlimited ? 26 : 20,
                                fontWeight: FontWeight.w600,
                                color: Colors.white.withOpacity(0.9),
                                height: 1.0,
                                leadingDistribution:
                                    TextLeadingDistribution.even,
                              ),
                            ),
                          ),
                          // Profile image on the right (circular)
                          Container(
                            width: 40,
                            height: 40,
                            margin: const EdgeInsets.only(
                                right: 6, top: 6, bottom: 6),
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: Colors.blue,
                            ),
                            child: ClipOval(
                              child: avatarUrl != null
                                  ? Image.network(
                                      avatarUrl,
                                      fit: BoxFit.cover,
                                      errorBuilder:
                                          (context, error, stackTrace) =>
                                              _buildDefaultAvatar(
                                                  user.email ?? 'U', context),
                                    )
                                  : _buildDefaultAvatar(
                                      user.email ?? 'U', context),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }

  Widget _buildDefaultAvatar(String email, BuildContext context) {
    final initial = email.isNotEmpty ? email[0].toUpperCase() : 'U';
    return Container(
      color: Colors.blueGrey[700],
      child: Center(
        child: Text(
          initial,
          style: Theme.of(context).textTheme.titleLarge?.copyWith(
                color: Colors.white,
                fontWeight: FontWeight.bold,
              ),
        ),
      ),
    );
  }
}
