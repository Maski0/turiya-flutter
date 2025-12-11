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

              return SizedBox(
                width: 44,
                height: 44,
                child: Stack(
                  clipBehavior: Clip.none,
                  children: [
                    // Main profile circle
                    Container(
                      width: 44,
                      height: 44,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: Colors.white.withOpacity(0.3),
                          width: 1.5,
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.2),
                            blurRadius: 8,
                            offset: const Offset(0, 2),
                          ),
                        ],
                      ),
                      child: ClipOval(
                        child: avatarUrl != null
                            ? Image.network(
                                avatarUrl,
                                fit: BoxFit.cover,
                                errorBuilder: (context, error, stackTrace) =>
                                    _buildDefaultAvatar(
                                        user.email ?? 'U', context),
                              )
                            : _buildDefaultAvatar(user.email ?? 'U', context),
                      ),
                    ),
                    // Credits badge (bottom right)
                    if (creditsState is CreditsLoaded)
                      Positioned(
                        right: -2,
                        bottom: -2,
                        child: Container(
                          constraints: const BoxConstraints(minWidth: 18),
                          height: 18,
                          padding: const EdgeInsets.symmetric(horizontal: 5),
                          decoration: BoxDecoration(
                            color: backgroundColor,
                            shape: displayText == '★'
                                ? BoxShape.circle
                                : BoxShape.rectangle,
                            borderRadius: displayText == '★'
                                ? null
                                : BorderRadius.circular(10),
                            border: Border.all(
                              color: Colors.white,
                              width: 1.2,
                            ),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withOpacity(0.3),
                                blurRadius: 4,
                                offset: const Offset(0, 1),
                              ),
                            ],
                          ),
                          child: Center(
                            child: Text(
                              displayText,
                              style: Theme.of(context)
                                  .textTheme
                                  .labelSmall
                                  ?.copyWith(
                                    color: Colors.white,
                                    fontSize: displayText == '★' ? 10 : 9,
                                    fontWeight: FontWeight.bold,
                                    height: 1.0,
                                  ),
                            ),
                          ),
                        ),
                      ),
                  ],
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
