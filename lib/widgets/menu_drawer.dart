import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:liquid_glass_renderer/liquid_glass_renderer.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../blocs/auth/auth_bloc_export.dart';
import '../blocs/credits/credits_bloc.dart';
import '../blocs/memory/memory_bloc.dart';
import '../utils/toast_utils.dart';
import 'memory_screen.dart';

class MenuDrawer extends StatefulWidget {
  final VoidCallback onClose;

  const MenuDrawer({
    super.key,
    required this.onClose,
  });

  @override
  State<MenuDrawer> createState() => _MenuDrawerState();
}

class _MenuDrawerState extends State<MenuDrawer> {
  @override
  Widget build(BuildContext context) {
    final menuOptions = [
      _MenuOption(
        icon: Icons.auto_awesome,
        title: 'My Memories',
        onTap: () {
          widget.onClose();
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => BlocProvider.value(
                value: context.read<MemoryBloc>()
                  ..add(const MemoriesRequested()),
                child: const MemoryScreen(),
              ),
            ),
          );
        },
      ),
      _MenuOption(
        icon: Icons.settings,
        title: 'Settings',
        onTap: () {
          widget.onClose();
          ToastUtils.showInfo(context, 'Settings coming soon');
        },
      ),
      _MenuOption(
        icon: Icons.help_outline,
        title: 'Help & Support',
        onTap: () {
          widget.onClose();
          ToastUtils.showInfo(context, 'Help & Support coming soon');
        },
      ),
      _MenuOption(
        icon: Icons.logout,
        title: 'Sign Out',
        textColor: Colors.redAccent,
        onTap: () {
          context.read<AuthBloc>().add(const AuthSignOutRequested());
          widget.onClose();
        },
      ),
    ];

    return BackdropFilter(
      filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
      child: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              Colors.black.withOpacity(0.32),
              Colors.black.withOpacity(0.25),
            ],
          ),
        ),
        child: Stack(
          children: [
            // Menu options centered
            SafeArea(
              bottom: false,
              child: Center(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 42),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      // Profile info at top
                      BlocBuilder<AuthBloc, AuthState>(
                        builder: (context, authState) {
                          if (authState is AuthAuthenticated) {
                            final user = authState.user;
                            final name =
                                user.userMetadata?['full_name'] as String? ??
                                    user.userMetadata?['name'] as String? ??
                                    'User';
                            final email = user.email ?? '';

                            return Column(
                              children: [
                                Text(
                                  name,
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 21,
                                    fontWeight: FontWeight.w700,
                                    letterSpacing: 0.3,
                                  ),
                                ),
                                const SizedBox(height: 6),
                                Text(
                                  email,
                                  style: TextStyle(
                                    color: Colors.white.withOpacity(0.58),
                                    fontSize: 14,
                                    letterSpacing: 0.2,
                                  ),
                                ),
                                const SizedBox(height: 18),
                                // Credits info
                                BlocBuilder<CreditsBloc, CreditsState>(
                                  builder: (context, creditsState) {
                                    if (creditsState is CreditsLoaded) {
                                      return Container(
                                        padding: const EdgeInsets.symmetric(
                                          horizontal: 22,
                                          vertical: 14,
                                        ),
                                        decoration: BoxDecoration(
                                          color: Colors.white.withOpacity(0.09),
                                          borderRadius:
                                              BorderRadius.circular(14),
                                          border: Border.all(
                                            color:
                                                Colors.white.withOpacity(0.18),
                                            width: 0.8,
                                          ),
                                        ),
                                        child: Row(
                                          mainAxisSize: MainAxisSize.min,
                                          children: [
                                            Icon(
                                              creditsState.isPro
                                                  ? Icons.star
                                                  : Icons.bolt,
                                              color: creditsState.isPro
                                                  ? Colors.amber
                                                  : Colors.blue,
                                              size: 20,
                                            ),
                                            const SizedBox(width: 8),
                                            Text(
                                              creditsState.isPro
                                                  ? 'Unlimited'
                                                  : '${creditsState.totalCredits} Credits',
                                              style: const TextStyle(
                                                color: Colors.white,
                                                fontSize: 16,
                                                fontWeight: FontWeight.w600,
                                                letterSpacing: 0.2,
                                              ),
                                            ),
                                            const SizedBox(width: 8),
                                            Container(
                                              padding:
                                                  const EdgeInsets.symmetric(
                                                horizontal: 8,
                                                vertical: 2,
                                              ),
                                              decoration: BoxDecoration(
                                                color: creditsState.isPro
                                                    ? Colors.amber
                                                        .withOpacity(0.2)
                                                    : Colors.blue
                                                        .withOpacity(0.2),
                                                borderRadius:
                                                    BorderRadius.circular(8),
                                              ),
                                              child: Text(
                                                creditsState.planType
                                                    .toUpperCase(),
                                                style: TextStyle(
                                                  color: creditsState.isPro
                                                      ? Colors.amber
                                                      : Colors.blue,
                                                  fontSize: 11,
                                                  fontWeight: FontWeight.w600,
                                                ),
                                              ),
                                            ),
                                          ],
                                        ),
                                      );
                                    }
                                    return const SizedBox.shrink();
                                  },
                                ),
                                const SizedBox(height: 26),
                                // Divider
                                Container(
                                  height: 0.5,
                                  decoration: BoxDecoration(
                                    gradient: LinearGradient(
                                      colors: [
                                        Colors.white.withOpacity(0),
                                        Colors.white.withOpacity(0.45),
                                        Colors.white.withOpacity(0),
                                      ],
                                    ),
                                  ),
                                ),
                              ],
                            );
                          }
                          return const SizedBox.shrink();
                        },
                      ),
                      // Menu options
                      ...menuOptions.asMap().entries.map((entry) {
                        final index = entry.key;
                        final option = entry.value;
                        final isLast = index == menuOptions.length - 1;

                        return Column(
                          children: [
                            InkWell(
                              onTap: option.onTap,
                              child: Padding(
                                padding:
                                    const EdgeInsets.symmetric(vertical: 18),
                                child: Row(
                                  children: [
                                    Icon(
                                      option.icon,
                                      color: option.iconColor ??
                                          option.textColor ??
                                          Colors.white.withOpacity(0.92),
                                      size: 23,
                                    ),
                                    const SizedBox(width: 18),
                                    Expanded(
                                      child: Text(
                                        option.title,
                                        style: TextStyle(
                                          color:
                                              option.textColor ?? Colors.white,
                                          fontSize: 17,
                                          fontWeight: FontWeight.w600,
                                          letterSpacing: 0.2,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                            // Gradient divider
                            if (!isLast)
                              Container(
                                height: 0.5,
                                decoration: BoxDecoration(
                                  gradient: LinearGradient(
                                    colors: [
                                      Colors.white.withOpacity(0),
                                      Colors.white.withOpacity(0.40),
                                      Colors.white.withOpacity(0),
                                    ],
                                  ),
                                ),
                              ),
                          ],
                        );
                      }).toList(),
                    ],
                  ),
                ),
              ),
            ),
            // Close menu chip fixed at bottom
            Positioned(
              bottom: 60,
              left: 0,
              right: 0,
              child: Center(
                child: GestureDetector(
                  onTap: widget.onClose,
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 18, vertical: 10),
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [
                          Colors.white.withOpacity(0.18),
                          Colors.white.withOpacity(0.10),
                        ],
                      ),
                      borderRadius: BorderRadius.circular(22),
                      border: Border.all(
                        color: Colors.white.withOpacity(0.28),
                        width: 0.8,
                      ),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          Icons.keyboard_arrow_down,
                          color: Colors.white.withOpacity(0.85),
                          size: 19,
                        ),
                        const SizedBox(width: 7),
                        Text(
                          'Close Menu',
                          style: TextStyle(
                            color: Colors.white.withOpacity(0.92),
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                            letterSpacing: 0.2,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _MenuOption {
  final IconData icon;
  final String title;
  final VoidCallback onTap;
  final Color? textColor;
  final Color? iconColor;

  _MenuOption({
    required this.icon,
    required this.title,
    required this.onTap,
    this.textColor,
    this.iconColor,
  });
}
