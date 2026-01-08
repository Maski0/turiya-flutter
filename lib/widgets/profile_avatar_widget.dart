import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../blocs/credits/credits_bloc.dart';
import '../blocs/auth/auth_bloc_export.dart';
import '../theme/app_theme.dart';

class ProfileAvatarWidget extends StatefulWidget {
  final VoidCallback onSettingsTap;
  final VoidCallback? onMusicToggle;
  final bool isMusicMuted;
  final VoidCallback? onRecordTap;
  final VoidCallback? onLanguageTap;
  final String? currentLanguage;
  final bool isPendingRecording;
  final bool isRecording;

  const ProfileAvatarWidget({
    super.key,
    required this.onSettingsTap,
    this.onMusicToggle,
    this.isMusicMuted = false,
    this.onRecordTap,
    this.onLanguageTap,
    this.currentLanguage,
    this.isPendingRecording = false,
    this.isRecording = false,
  });

  @override
  State<ProfileAvatarWidget> createState() => _ProfileAvatarWidgetState();
}

class _ProfileAvatarWidgetState extends State<ProfileAvatarWidget>
    with SingleTickerProviderStateMixin {
  late AnimationController _fadeController;
  late Animation<double> _fadeAnimation;
  bool _hasAnimated = false;
  OverlayEntry? _dropdownOverlay;
  final LayerLink _layerLink = LayerLink();

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
    _removeDropdown();
    _fadeController.dispose();
    super.dispose();
  }

  void _toggleDropdown() {
    if (_dropdownOverlay != null) {
      _removeDropdown();
    } else {
      _showDropdown();
    }
  }

  void _showDropdown() {
    _dropdownOverlay = OverlayEntry(
      builder: (context) => GestureDetector(
        behavior: HitTestBehavior.translucent,
        onTap: _removeDropdown,
        child: Stack(
          children: [
            // Invisible full-screen barrier to catch taps outside
            Positioned.fill(
              child: Container(color: Colors.transparent),
            ),
            // The dropdown positioned relative to the button
            CompositedTransformFollower(
              link: _layerLink,
              targetAnchor: Alignment.bottomRight,
              followerAnchor: Alignment.topRight,
              offset: const Offset(0, 8),
              child: Material(
                color: Colors.transparent,
                child: _buildDropdownContent(),
              ),
            ),
          ],
        ),
      ),
    );
    Overlay.of(context).insert(_dropdownOverlay!);
  }

  void _removeDropdown() {
    _dropdownOverlay?.remove();
    _dropdownOverlay = null;
  }

  Widget _buildDropdownContent() {
    return ClipRRect(
      borderRadius: BorderRadius.circular(12),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
        child: Container(
          width: 200,
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [
                Colors.white.withOpacity(0.22),
                Colors.white.withOpacity(0.08),
              ],
            ),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: const Color(0x40FFFFFF),
              width: 0.5,
            ),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Mute/Unmute Music
              if (widget.onMusicToggle != null) ...[
                _buildDropdownItem(
                  icon: widget.isMusicMuted
                      ? Icons.volume_off_rounded
                      : Icons.volume_up_rounded,
                  title: widget.isMusicMuted ? 'Unmute Music' : 'Mute Music',
                  onTap: () {
                    _removeDropdown();
                    widget.onMusicToggle?.call();
                  },
                ),
                _buildDivider(),
              ],

              // Record
              if (widget.onRecordTap != null) ...[
                _buildDropdownItem(
                  icon: Icons.fiber_manual_record_outlined,
                  title: 'Record',
                  onTap: () {
                    _removeDropdown();
                    widget.onRecordTap?.call();
                  },
                ),
                _buildDivider(),
              ],

              // Settings
              _buildDropdownItem(
                icon: Icons.settings_outlined,
                title: 'Settings',
                onTap: () {
                  _removeDropdown();
                  widget.onSettingsTap();
                },
              ),
              _buildDivider(),

              // Log Out
              _buildDropdownItem(
                icon: Icons.logout,
                title: 'Log Out',
                isDestructive: true,
                onTap: () {
                  _removeDropdown();
                  context.read<AuthBloc>().add(const AuthSignOutRequested());
                },
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<AuthBloc, AuthState>(
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

            return FadeTransition(
              opacity: _fadeAnimation,
              child: CompositedTransformTarget(
                link: _layerLink,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    GestureDetector(
                      onTap: _toggleDropdown,
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
                                  margin: const EdgeInsets.only(
                                      left: 18, right: 10),
                                  child: Text(
                                    creditsText,
                                    textAlign: TextAlign.center,
                                    strutStyle: const StrutStyle(
                                      forceStrutHeight: true,
                                      height: 1.0,
                                    ),
                                    style: TextStyle(
                                      fontFamily: AppTheme.fontFamily,
                                      fontSize: isUnlimited ? 26 : 20,
                                      fontWeight: FontWeight.w600,
                                      color: AppTheme.secondaryWhite,
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
                                  decoration: const BoxDecoration(
                                    shape: BoxShape.circle,
                                    color: Colors.blue,
                                  ),
                                  child: ClipOval(
                                    child: avatarUrl != null
                                        ? Image.network(
                                            avatarUrl,
                                            fit: BoxFit.cover,
                                            errorBuilder: (context, error,
                                                    stackTrace) =>
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
                    ),
                    // Recording indicator dot below profile
                    if (widget.isPendingRecording || widget.isRecording)
                      Padding(
                        padding: const EdgeInsets.only(top: 6),
                        child: widget.isPendingRecording
                            ? _BlinkingRecordDot()
                            : Container(
                                width: 8,
                                height: 8,
                                decoration: const BoxDecoration(
                                  color: Colors.red,
                                  shape: BoxShape.circle,
                                ),
                              ),
                      ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildDropdownItem({
    required IconData icon,
    required String title,
    required VoidCallback onTap,
    String? subtitle,
    bool isDestructive = false,
  }) {
    final color = isDestructive
        ? const Color(0xFFef4444) // red-500 (darker)
        : Colors.white;

    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        child: Row(
          children: [
            Icon(
              icon,
              color: color,
              size: 22,
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    title,
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                          color: color,
                        ),
                  ),
                  if (subtitle != null) ...[
                    const SizedBox(height: 2),
                    Text(
                      subtitle,
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                            color: AppTheme.tertiaryWhite,
                          ),
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDivider() {
    return Container(
      height: 1,
      width: double.infinity,
      color: const Color(0x20FFFFFF),
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

/// Blinking red dot for pending recording state
class _BlinkingRecordDot extends StatefulWidget {
  @override
  State<_BlinkingRecordDot> createState() => _BlinkingRecordDotState();
}

class _BlinkingRecordDotState extends State<_BlinkingRecordDot>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _animation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(milliseconds: 800),
      vsync: this,
    )..repeat(reverse: true);

    _animation = Tween<double>(begin: 0.3, end: 1.0).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _animation,
      builder: (context, child) {
        return Opacity(
          opacity: _animation.value,
          child: Container(
            width: 8,
            height: 8,
            decoration: const BoxDecoration(
              color: Colors.red,
              shape: BoxShape.circle,
            ),
          ),
        );
      },
    );
  }
}
