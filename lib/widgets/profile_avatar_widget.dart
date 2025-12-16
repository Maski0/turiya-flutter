import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../blocs/credits/credits_bloc.dart';
import '../blocs/auth/auth_bloc_export.dart';

class ProfileAvatarWidget extends StatelessWidget {
  final VoidCallback onTap;

  const ProfileAvatarWidget({
    super.key,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: BlocBuilder<AuthBloc, AuthState>(
        builder: (context, authState) {
          if (authState is! AuthAuthenticated) {
            return const SizedBox.shrink();
          }

          final user = authState.user;
          final avatarUrl = user.userMetadata?['avatar_url'] as String?;

          return BlocBuilder<CreditsBloc, CreditsState>(
            builder: (context, creditsState) {
              String displayText = '';
              Color backgroundColor = Colors.blue;

              if (creditsState is CreditsLoaded) {
                if (creditsState.isPro) {
                  displayText = '★';
                  backgroundColor = Colors.amber;
                } else {
                  displayText = '${creditsState.totalCredits}';
                  backgroundColor = Colors.blue;
                }
              }

              return ClipRRect(
                borderRadius: BorderRadius.circular(16),
                child: BackdropFilter(
                  filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
                  child: Container(
                    width: 48,
                    height: 48,
                    decoration: BoxDecoration(
                      color: const Color(0x1AFFFFFF),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(
                        color: const Color(0x33FFFFFF),
                        width: 1,
                      ),
                    ),
                    child: Stack(
                      clipBehavior: Clip.none,
                      children: [
                        // Profile image centered
                        Center(
                          child: Container(
                            width: 32,
                            height: 32,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              border: Border.all(
                                color: Colors.white.withOpacity(0.4),
                                width: 1,
                              ),
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
                        ),
                        // Credits badge (bottom right)
                        if (creditsState is CreditsLoaded)
                          Positioned(
                            right: 2,
                            bottom: 2,
                            child: Container(
                              constraints: const BoxConstraints(minWidth: 16),
                              height: 16,
                              padding:
                                  const EdgeInsets.symmetric(horizontal: 4),
                              decoration: BoxDecoration(
                                color: backgroundColor,
                                borderRadius: BorderRadius.circular(8),
                                border: Border.all(
                                  color: Colors.white.withOpacity(0.8),
                                  width: 1,
                                ),
                              ),
                              child: Center(
                                child: Text(
                                  displayText,
                                  style: Theme.of(context)
                                      .textTheme
                                      .labelSmall
                                      ?.copyWith(
                                        color: Colors.white,
                                        fontSize: displayText == '★' ? 9 : 8,
                                        fontWeight: FontWeight.bold,
                                        height: 1.0,
                                      ),
                                ),
                              ),
                            ),
                          ),
                      ],
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
