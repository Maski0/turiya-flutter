import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../blocs/auth/auth_bloc_export.dart';
import '../blocs/credits/credits_bloc.dart';

class ProfileDetailsOverlay extends StatelessWidget {
  final VoidCallback onClose;

  const ProfileDetailsOverlay({
    super.key,
    required this.onClose,
  });

  @override
  Widget build(BuildContext context) {
    return BackdropFilter(
      filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
      child: Container(
        color: Colors.black.withOpacity(0.3),
        child: Center(
          child: BlocBuilder<AuthBloc, AuthState>(
            builder: (context, authState) {
              if (authState is! AuthAuthenticated) {
                return const SizedBox.shrink();
              }

              final user = authState.user;
              final avatarUrl = user.userMetadata?['avatar_url'] as String?;
              final email = user.email ?? 'No email';
              final name = user.userMetadata?['full_name'] as String? ??
                  user.userMetadata?['name'] as String? ??
                  'User';

              return BlocBuilder<CreditsBloc, CreditsState>(
                builder: (context, creditsState) {
                  return Container(
                    margin: const EdgeInsets.symmetric(horizontal: 24),
                    constraints: const BoxConstraints(maxWidth: 400),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(24),
                      color: Colors.black.withOpacity(0.5),
                      border: Border.all(
                        color: Colors.white.withOpacity(0.2),
                        width: 1,
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.3),
                          blurRadius: 20,
                          offset: const Offset(0, 10),
                        ),
                      ],
                    ),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(24),
                      child: BackdropFilter(
                        filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
                        child: Padding(
                          padding: const EdgeInsets.all(24),
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              // Avatar
                              Container(
                                width: 80,
                                height: 80,
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  border: Border.all(
                                    color: Colors.white.withOpacity(0.3),
                                    width: 2,
                                  ),
                                ),
                                child: ClipOval(
                                  child: avatarUrl != null
                                      ? Image.network(
                                          avatarUrl,
                                          fit: BoxFit.cover,
                                          errorBuilder:
                                              (context, error, stackTrace) =>
                                                  _buildDefaultAvatar(email),
                                        )
                                      : _buildDefaultAvatar(email),
                                ),
                              ),
                              const SizedBox(height: 16),

                              // Name
                              Text(
                                name,
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 22,
                                  fontWeight: FontWeight.w600,
                                ),
                                textAlign: TextAlign.center,
                              ),
                              const SizedBox(height: 4),

                              // Email
                              Text(
                                email,
                                style: TextStyle(
                                  color: Colors.white.withOpacity(0.6),
                                  fontSize: 14,
                                ),
                                textAlign: TextAlign.center,
                              ),
                              const SizedBox(height: 24),

                              // Credits/Plan Info
                              if (creditsState is CreditsLoaded) ...[
                                Container(
                                  padding: const EdgeInsets.all(16),
                                  decoration: BoxDecoration(
                                    color: Colors.white.withOpacity(0.08),
                                    borderRadius: BorderRadius.circular(16),
                                    border: Border.all(
                                      color: Colors.white.withOpacity(0.15),
                                      width: 1,
                                    ),
                                  ),
                                  child: Column(
                                    children: [
                                      Row(
                                        mainAxisAlignment:
                                            MainAxisAlignment.spaceBetween,
                                        children: [
                                          Text(
                                            'Plan',
                                            style: TextStyle(
                                              color:
                                                  Colors.white.withOpacity(0.6),
                                              fontSize: 14,
                                            ),
                                          ),
                                          Container(
                                            padding: const EdgeInsets.symmetric(
                                              horizontal: 12,
                                              vertical: 4,
                                            ),
                                            decoration: BoxDecoration(
                                              color: creditsState.isPro
                                                  ? Colors.amber.withOpacity(0.2)
                                                  : Colors.blue.withOpacity(0.2),
                                              borderRadius:
                                                  BorderRadius.circular(12),
                                              border: Border.all(
                                                color: creditsState.isPro
                                                    ? Colors.amber
                                                        .withOpacity(0.5)
                                                    : Colors.blue
                                                        .withOpacity(0.5),
                                                width: 1,
                                              ),
                                            ),
                                            child: Row(
                                              mainAxisSize: MainAxisSize.min,
                                              children: [
                                                Icon(
                                                  creditsState.isPro
                                                      ? Icons.star
                                                      : Icons.person,
                                                  color: creditsState.isPro
                                                      ? Colors.amber
                                                      : Colors.blue,
                                                  size: 14,
                                                ),
                                                const SizedBox(width: 4),
                                                Text(
                                                  creditsState.planType
                                                      .toUpperCase(),
                                                  style: TextStyle(
                                                    color: creditsState.isPro
                                                        ? Colors.amber
                                                        : Colors.blue,
                                                    fontSize: 12,
                                                    fontWeight: FontWeight.w600,
                                                  ),
                                                ),
                                              ],
                                            ),
                                          ),
                                        ],
                                      ),
                                      const SizedBox(height: 16),
                                      Row(
                                        mainAxisAlignment:
                                            MainAxisAlignment.spaceBetween,
                                        children: [
                                          Text(
                                            'Credits',
                                            style: TextStyle(
                                              color:
                                                  Colors.white.withOpacity(0.6),
                                              fontSize: 14,
                                            ),
                                          ),
                                          Row(
                                            children: [
                                              if (creditsState.isPro)
                                                Icon(
                                                  Icons.all_inclusive,
                                                  color: Colors.amber,
                                                  size: 20,
                                                )
                                              else
                                                Text(
                                                  '${creditsState.totalCredits}',
                                                  style: const TextStyle(
                                                    color: Colors.white,
                                                    fontSize: 20,
                                                    fontWeight: FontWeight.w600,
                                                  ),
                                                ),
                                            ],
                                          ),
                                        ],
                                      ),
                                      if (!creditsState.isPro &&
                                          creditsState.currentCredits !=
                                              creditsState.totalCredits) ...[
                                        const SizedBox(height: 12),
                                        Row(
                                          mainAxisAlignment:
                                              MainAxisAlignment.spaceBetween,
                                          children: [
                                            Text(
                                              'Free Credits',
                                              style: TextStyle(
                                                color: Colors.white
                                                    .withOpacity(0.5),
                                                fontSize: 12,
                                              ),
                                            ),
                                            Text(
                                              '${creditsState.currentCredits}',
                                              style: TextStyle(
                                                color: Colors.white
                                                    .withOpacity(0.7),
                                                fontSize: 14,
                                              ),
                                            ),
                                          ],
                                        ),
                                        const SizedBox(height: 8),
                                        Row(
                                          mainAxisAlignment:
                                              MainAxisAlignment.spaceBetween,
                                          children: [
                                            Text(
                                              'Purchased',
                                              style: TextStyle(
                                                color: Colors.white
                                                    .withOpacity(0.5),
                                                fontSize: 12,
                                              ),
                                            ),
                                            Text(
                                              '${creditsState.purchasedCredits}',
                                              style: TextStyle(
                                                color: Colors.white
                                                    .withOpacity(0.7),
                                                fontSize: 14,
                                              ),
                                            ),
                                          ],
                                        ),
                                      ],
                                    ],
                                  ),
                                ),
                              ] else if (creditsState is CreditsLoading)
                                const CircularProgressIndicator(
                                  valueColor: AlwaysStoppedAnimation<Color>(
                                      Colors.white),
                                )
                              else if (creditsState is CreditsError)
                                Text(
                                  'Failed to load credits',
                                  style: TextStyle(
                                    color: Colors.red.withOpacity(0.8),
                                    fontSize: 14,
                                  ),
                                ),

                              const SizedBox(height: 24),

                              // Close button
                              GestureDetector(
                                onTap: onClose,
                                child: Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 24,
                                    vertical: 12,
                                  ),
                                  decoration: BoxDecoration(
                                    gradient: LinearGradient(
                                      colors: [
                                        Colors.white.withOpacity(0.2),
                                        Colors.white.withOpacity(0.1),
                                      ],
                                    ),
                                    borderRadius: BorderRadius.circular(20),
                                    border: Border.all(
                                      color: Colors.white.withOpacity(0.3),
                                      width: 1,
                                    ),
                                  ),
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Icon(
                                        Icons.close,
                                        color: Colors.white.withOpacity(0.8),
                                        size: 18,
                                      ),
                                      const SizedBox(width: 6),
                                      Text(
                                        'Close',
                                        style: TextStyle(
                                          color: Colors.white.withOpacity(0.9),
                                          fontSize: 14,
                                          fontWeight: FontWeight.w500,
                                        ),
                                      ),
                                    ],
                                  ),
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
        ),
      ),
    );
  }

  Widget _buildDefaultAvatar(String email) {
    final initial = email.isNotEmpty ? email[0].toUpperCase() : 'U';
    return Container(
      color: Colors.blueGrey[700],
      child: Center(
        child: Text(
          initial,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 32,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
    );
  }
}

