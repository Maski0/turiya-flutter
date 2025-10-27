import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../blocs/auth/auth_bloc_export.dart';
import '../blocs/memory/memory_bloc.dart';
import 'memory_screen.dart';

class MenuDrawer extends StatelessWidget {
  final VoidCallback onClose;

  const MenuDrawer({
    super.key,
    required this.onClose,
  });

  @override
  Widget build(BuildContext context) {
    final menuOptions = [
      _MenuOption(
        icon: Icons.auto_awesome,
        title: 'My Memories',
        onTap: () {
          onClose();
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
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Settings coming soon'),
              behavior: SnackBarBehavior.floating,
              margin: EdgeInsets.only(top: 80, left: 20, right: 20),
            ),
          );
        },
      ),
      _MenuOption(
        icon: Icons.help_outline,
        title: 'Help & Support',
        onTap: () {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Help & Support coming soon'),
              behavior: SnackBarBehavior.floating,
              margin: EdgeInsets.only(top: 80, left: 20, right: 20),
            ),
          );
        },
      ),
      _MenuOption(
        icon: Icons.logout,
        title: 'Sign Out',
        textColor: Colors.redAccent,
        onTap: () {
          context.read<AuthBloc>().add(const AuthSignOutRequested());
          onClose();
        },
      ),
    ];

    return BackdropFilter(
      filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
      child: Container(
        color: Colors.transparent,
        child: Stack(
          children: [
            // Menu options centered
            SafeArea(
              bottom: false,
              child: Center(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 40),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      ...menuOptions.asMap().entries.map((entry) {
                        final index = entry.key;
                        final option = entry.value;
                        final isLast = index == menuOptions.length - 1;
                        
                        return Column(
                          children: [
                            InkWell(
                              onTap: option.onTap,
                              child: Padding(
                                padding: const EdgeInsets.symmetric(vertical: 16),
                                child: Row(
                                  children: [
                                    Icon(
                                      option.icon,
                                      color: option.textColor ?? Colors.white.withOpacity(0.9),
                                      size: 24,
                                    ),
                                    const SizedBox(width: 16),
                                    Expanded(
                                      child: Text(
                                        option.title,
                                        style: TextStyle(
                                          color: option.textColor ?? Colors.white,
                                          fontSize: 17,
                                          fontWeight: FontWeight.w500,
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
                                height: 1,
                                decoration: BoxDecoration(
                                  gradient: LinearGradient(
                                    colors: [
                                      Colors.white.withOpacity(0),
                                      Colors.white.withOpacity(0.5),
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
              bottom: 20,
              left: 0,
              right: 0,
              child: Center(
                child: GestureDetector(
                  onTap: onClose,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
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
                          Icons.keyboard_arrow_down,
                          color: Colors.white.withOpacity(0.8),
                          size: 20,
                        ),
                        const SizedBox(width: 6),
                        Text(
                          'Close Menu',
                          style: TextStyle(
                            color: Colors.white.withOpacity(0.9),
                            fontSize: 13,
                            fontWeight: FontWeight.w500,
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

  _MenuOption({
    required this.icon,
    required this.title,
    required this.onTap,
    this.textColor,
  });
}

