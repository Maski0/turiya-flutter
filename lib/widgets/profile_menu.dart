import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_embed_unity/flutter_embed_unity.dart';
import '../blocs/auth/auth_bloc_export.dart';
import '../blocs/credits/credits_bloc.dart';
import '../blocs/memory/memory_bloc.dart';
import '../blocs/chat/chat_bloc_export.dart';
import '../theme/app_theme.dart';
import '../utils/toast_utils.dart';

/// Profile menu that matches the web design
/// Shows tabs: Profile, Settings, Billing, Memory
class ProfileMenu extends StatefulWidget {
  final VoidCallback onClose;
  final bool isLiveKitMode;
  final VoidCallback? onToggleVoiceMode;

  const ProfileMenu({
    super.key,
    required this.onClose,
    this.isLiveKitMode = false,
    this.onToggleVoiceMode,
  });

  @override
  State<ProfileMenu> createState() => _ProfileMenuState();
}

class _ProfileMenuState extends State<ProfileMenu> {
  // Navigation state
  String? _selectedTab; // null = tab selection, else = content view

  // Settings state
  String _selectedLanguage = 'auto';
  bool _isLanguageDropdownOpen = false;
  String _selectedTimeOfDay = 'auto'; // auto, morning, evening, night
  bool _isTimeOfDayDropdownOpen = false;

  // Billing state
  bool _isManageDropdownOpen = false;

  final List<Map<String, String>> _languages = [
    {'name': 'Auto', 'iso': 'auto'},
    {'name': 'English', 'iso': 'en'},
    {'name': 'हिन्दी', 'iso': 'hi'},
  ];

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () {
        // Close dropdowns when tapping outside
        if (_isLanguageDropdownOpen ||
            _isManageDropdownOpen ||
            _isTimeOfDayDropdownOpen) {
          setState(() {
            _isLanguageDropdownOpen = false;
            _isManageDropdownOpen = false;
            _isTimeOfDayDropdownOpen = false;
          });
        }
      },
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
        child: Container(
          decoration: BoxDecoration(
            // Subtle black effect with slight white overlay
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [
                Colors.black.withOpacity(0.5),
                Colors.black.withOpacity(0.4),
              ],
            ),
          ),
          child: SafeArea(
            child: _selectedTab == null
                ? _buildTabSelection()
                : _buildTabContent(),
          ),
        ),
      ),
    );
  }

  /// Tab Selection Screen
  Widget _buildTabSelection() {
    return Column(
      children: [
        // Header with back button
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
          child: Row(
            children: [
              _buildBackButton(onTap: widget.onClose),
            ],
          ),
        ),

        // Tab buttons
        Expanded(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            child: Column(
              children: [
                const SizedBox(height: 16),
                _buildTabButton(
                  icon: Icons.person_outline,
                  title: 'Profile',
                  onTap: () => setState(() => _selectedTab = 'profile'),
                ),
                const SizedBox(height: 16),
                _buildTabButton(
                  icon: Icons.settings_outlined,
                  title: 'Settings',
                  onTap: () => setState(() => _selectedTab = 'settings'),
                ),
                const SizedBox(height: 16),
                _buildTabButton(
                  icon: Icons.receipt_long_outlined,
                  title: 'Billing',
                  onTap: () => setState(() => _selectedTab = 'billing'),
                ),
                const SizedBox(height: 16),
                _buildTabButton(
                  icon: Icons.psychology_outlined,
                  title: 'Memory',
                  onTap: () {
                    // Fetch memories when entering memory tab
                    context.read<MemoryBloc>().add(const MemoriesRequested());
                    setState(() => _selectedTab = 'memory');
                  },
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  /// Tab Content Screen
  Widget _buildTabContent() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Header with back button
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
          child: Row(
            children: [
              _buildBackButton(
                onTap: () => setState(() {
                  _selectedTab = null;
                  _isLanguageDropdownOpen = false;
                  _isManageDropdownOpen = false;
                }),
              ),
            ],
          ),
        ),

        // Title and description - full width, no extra padding
        Padding(
          padding: const EdgeInsets.only(left: 24, right: 24, bottom: 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                _getTabTitle(),
                style: Theme.of(context).textTheme.displaySmall,
              ),
              const SizedBox(height: 6),
              Text(
                _getTabDescription(),
                style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                      color: AppTheme.tertiaryWhite,
                    ),
              ),
            ],
          ),
        ),

        // Content
        Expanded(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            child: _buildContentForTab(),
          ),
        ),
      ],
    );
  }

  Widget _buildBackButton({required VoidCallback onTap}) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 48,
        height: 48,
        decoration: BoxDecoration(
          color: const Color(0x05FFFFFF),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: const Color(0x14FFFFFF),
            width: 1,
          ),
        ),
        child: const Center(
          child: Icon(
            Icons.arrow_back,
            color: Colors.white,
            size: 24,
          ),
        ),
      ),
    );
  }

  Widget _buildTabButton({
    required IconData icon,
    required String title,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 18),
        decoration: BoxDecoration(
          color: Colors.transparent,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: const Color(0x14FFFFFF),
            width: 1,
          ),
        ),
        child: Row(
          children: [
            Icon(
              icon,
              color: Colors.white,
              size: 26,
            ),
            const SizedBox(width: 14),
            Text(
              title,
              style: Theme.of(context).textTheme.headlineSmall,
            ),
          ],
        ),
      ),
    );
  }

  String _getTabTitle() {
    switch (_selectedTab) {
      case 'profile':
        return 'Profile';
      case 'settings':
        return 'Settings';
      case 'billing':
        return 'Billing';
      case 'memory':
        return 'Memory';
      default:
        return '';
    }
  }

  String _getTabDescription() {
    switch (_selectedTab) {
      case 'profile':
        return 'Manage your user account settings.';
      case 'settings':
        return 'General and Conversation Settings';
      case 'billing':
        return 'Plans and Transaction';
      case 'memory':
        return 'View and manage your memories.';
      default:
        return '';
    }
  }

  Widget _buildContentForTab() {
    switch (_selectedTab) {
      case 'profile':
        return _buildProfileContent();
      case 'settings':
        return _buildSettingsContent();
      case 'billing':
        return _buildBillingContent();
      case 'memory':
        return _buildMemoryContent();
      default:
        return const SizedBox.shrink();
    }
  }

  /// Profile Content
  Widget _buildProfileContent() {
    return BlocBuilder<AuthBloc, AuthState>(
      builder: (context, state) {
        if (state is AuthAuthenticated) {
          final user = state.user;
          final name = user.userMetadata?['full_name'] as String? ??
              user.userMetadata?['name'] as String? ??
              'User';
          final email = user.email ?? '';

          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildInfoField(value: name, label: 'Name'),
              const SizedBox(height: 24),
              _buildInfoField(value: email, label: 'Email'),
              const SizedBox(height: 32),
              // Sign out button
              GestureDetector(
                onTap: () {
                  context.read<AuthBloc>().add(const AuthSignOutRequested());
                  widget.onClose();
                },
                child: Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  decoration: BoxDecoration(
                    color: Colors.transparent,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: Colors.redAccent.withOpacity(0.5),
                      width: 1,
                    ),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        Icons.logout,
                        color: Colors.redAccent,
                        size: 20,
                      ),
                      const SizedBox(width: 8),
                      Text(
                        'Sign Out',
                        style:
                            Theme.of(context).textTheme.titleMedium?.copyWith(
                                  color: Colors.redAccent,
                                  fontWeight: FontWeight.w500,
                                ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          );
        }
        return const SizedBox.shrink();
      },
    );
  }

  Widget _buildInfoField({required String value, required String label}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          value,
          style: Theme.of(context).textTheme.headlineSmall,
        ),
        const SizedBox(height: 6),
        Text(
          label,
          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: AppTheme.tertiaryWhite,
              ),
        ),
      ],
    );
  }

  /// Settings Content
  Widget _buildSettingsContent() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Language setting
        Text(
          'Conversation Language',
          style: Theme.of(context).textTheme.headlineSmall,
        ),
        const SizedBox(height: 6),
        Text(
          'The language used by AI companion in your chat.',
          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: AppTheme.tertiaryWhite,
              ),
        ),
        const SizedBox(height: 16),
        _buildLanguageDropdown(),

        const SizedBox(height: 32),

        // Time of Day setting
        Text(
          'Scene Ambience',
          style: Theme.of(context).textTheme.headlineSmall,
        ),
        const SizedBox(height: 6),
        Text(
          'Auto-adjusts to your local time. Override here.',
          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: AppTheme.tertiaryWhite,
              ),
        ),
        const SizedBox(height: 16),
        _buildTimeOfDayDropdown(),

        const SizedBox(height: 32),

        // Voice Mode setting
        Text(
          'Voice Mode',
          style: Theme.of(context).textTheme.headlineSmall,
        ),
        const SizedBox(height: 6),
        Text(
          widget.isLiveKitMode
              ? 'Real-time voice with LiveKit (lower latency)'
              : 'Local speech-to-text (device STT)',
          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: AppTheme.tertiaryWhite,
              ),
        ),
        const SizedBox(height: 16),
        _buildVoiceModeToggle(),

        const SizedBox(height: 32),

        // Clear history setting
        Text(
          'Clear conversation history',
          style: Theme.of(context).textTheme.headlineSmall,
        ),
        const SizedBox(height: 6),
        Text(
          'Delete chat history for current avatar conversation.',
          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: AppTheme.tertiaryWhite,
              ),
        ),
        const SizedBox(height: 16),
        _buildClearHistoryButton(),
      ],
    );
  }

  Widget _buildLanguageDropdown() {
    final selectedLang = _languages.firstWhere(
      (l) => l['iso'] == _selectedLanguage,
      orElse: () => _languages.first,
    );

    return Column(
      children: [
        GestureDetector(
          onTap: () {
            setState(() {
              _isLanguageDropdownOpen = !_isLanguageDropdownOpen;
              _isManageDropdownOpen = false;
            });
          },
          child: Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            decoration: BoxDecoration(
              color: Colors.transparent,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: const Color(0x14FFFFFF),
                width: 1,
              ),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  selectedLang['name']!,
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        color: AppTheme.secondaryWhite,
                      ),
                ),
                AnimatedRotation(
                  turns: _isLanguageDropdownOpen ? 0.5 : 0,
                  duration: const Duration(milliseconds: 200),
                  child: Icon(
                    Icons.keyboard_arrow_down,
                    color: AppTheme.secondaryWhite,
                  ),
                ),
              ],
            ),
          ),
        ),
        if (_isLanguageDropdownOpen)
          Container(
            width: double.infinity,
            margin: const EdgeInsets.only(top: 8),
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
            ),
            child: Column(
              children: _languages.map((lang) {
                final isSelected = lang['iso'] == _selectedLanguage;
                return GestureDetector(
                  onTap: () {
                    setState(() {
                      _selectedLanguage = lang['iso']!;
                      _isLanguageDropdownOpen = false;
                    });
                  },
                  child: Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(
                        horizontal: 16, vertical: 12),
                    decoration: BoxDecoration(
                      color: isSelected ? Colors.black : Colors.transparent,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      lang['name']!,
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                            color: isSelected ? Colors.white : Colors.black,
                          ),
                    ),
                  ),
                );
              }).toList(),
            ),
          ),
      ],
    );
  }

  final List<Map<String, String>> _timeOfDayOptions = [
    {'name': 'Auto (Device Time)', 'value': 'auto', 'icon': '🕐'},
    {'name': 'Morning', 'value': 'morning', 'icon': '🌅'},
    {'name': 'Evening', 'value': 'evening', 'icon': '🌆'},
    {'name': 'Night', 'value': 'night', 'icon': '🌙'},
  ];

  Widget _buildTimeOfDayDropdown() {
    final selectedTime = _timeOfDayOptions.firstWhere(
      (t) => t['value'] == _selectedTimeOfDay,
      orElse: () => _timeOfDayOptions.first,
    );

    return Column(
      children: [
        GestureDetector(
          onTap: () {
            setState(() {
              _isTimeOfDayDropdownOpen = !_isTimeOfDayDropdownOpen;
              _isLanguageDropdownOpen = false;
              _isManageDropdownOpen = false;
            });
          },
          child: Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            decoration: BoxDecoration(
              color: Colors.transparent,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: const Color(0x14FFFFFF),
                width: 1,
              ),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    Text(
                      selectedTime['icon']!,
                      style: const TextStyle(fontSize: 18),
                    ),
                    const SizedBox(width: 10),
                    Text(
                      selectedTime['name']!,
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                            color: AppTheme.secondaryWhite,
                          ),
                    ),
                  ],
                ),
                AnimatedRotation(
                  turns: _isTimeOfDayDropdownOpen ? 0.5 : 0,
                  duration: const Duration(milliseconds: 200),
                  child: Icon(
                    Icons.keyboard_arrow_down,
                    color: AppTheme.secondaryWhite,
                  ),
                ),
              ],
            ),
          ),
        ),
        if (_isTimeOfDayDropdownOpen)
          Container(
            width: double.infinity,
            margin: const EdgeInsets.only(top: 8),
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
            ),
            child: Column(
              children: _timeOfDayOptions.map((time) {
                final isSelected = time['value'] == _selectedTimeOfDay;
                return GestureDetector(
                  onTap: () {
                    setState(() {
                      _selectedTimeOfDay = time['value']!;
                      _isTimeOfDayDropdownOpen = false;
                    });
                    _applyTimeOfDay(time['value']!);
                  },
                  child: Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(
                        horizontal: 16, vertical: 12),
                    decoration: BoxDecoration(
                      color: isSelected ? Colors.black : Colors.transparent,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Row(
                      children: [
                        Text(
                          time['icon']!,
                          style: const TextStyle(fontSize: 18),
                        ),
                        const SizedBox(width: 10),
                        Text(
                          time['name']!,
                          style: Theme.of(context)
                              .textTheme
                              .titleMedium
                              ?.copyWith(
                                color: isSelected ? Colors.white : Colors.black,
                              ),
                        ),
                      ],
                    ),
                  ),
                );
              }).toList(),
            ),
          ),
      ],
    );
  }

  void _applyTimeOfDay(String timeOfDay) {
    try {
      if (timeOfDay == 'auto') {
        // Re-apply based on device clock
        final hour = DateTime.now().hour;
        if (hour >= 5 && hour < 17) {
          sendToUnity("TimeOfDay", "SetMorning", "");
        } else if (hour >= 17 && hour < 20) {
          sendToUnity("TimeOfDay", "SetEvening", "");
        } else {
          sendToUnity("TimeOfDay", "SetNight", "");
        }
      } else {
        switch (timeOfDay) {
          case 'morning':
            sendToUnity("TimeOfDay", "SetMorning", "");
            break;
          case 'evening':
            sendToUnity("TimeOfDay", "SetEvening", "");
            break;
          case 'night':
            sendToUnity("TimeOfDay", "SetNight", "");
            break;
        }
      }
      print('🌅 Time of day changed to: $timeOfDay');
    } catch (e) {
      print('Error setting time of day: $e');
    }
  }

  Widget _buildVoiceModeToggle() {
    return GestureDetector(
      onTap: widget.onToggleVoiceMode,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        decoration: BoxDecoration(
          color: Colors.transparent,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: const Color(0x14FFFFFF),
            width: 1,
          ),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Row(
              children: [
                Icon(
                  widget.isLiveKitMode ? Icons.wifi : Icons.mic,
                  color: widget.isLiveKitMode
                      ? Colors.green
                      : AppTheme.secondaryWhite,
                  size: 20,
                ),
                const SizedBox(width: 12),
                Text(
                  widget.isLiveKitMode ? 'LiveKit (Real-time)' : 'Local STT',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        color: AppTheme.secondaryWhite,
                      ),
                ),
              ],
            ),
            Container(
              width: 50,
              height: 28,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(14),
                color: widget.isLiveKitMode
                    ? Colors.green.withOpacity(0.3)
                    : Colors.grey.withOpacity(0.3),
              ),
              child: Stack(
                children: [
                  AnimatedPositioned(
                    duration: const Duration(milliseconds: 200),
                    curve: Curves.easeInOut,
                    left: widget.isLiveKitMode ? 24 : 4,
                    top: 4,
                    child: Container(
                      width: 20,
                      height: 20,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color:
                            widget.isLiveKitMode ? Colors.green : Colors.white,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildClearHistoryButton() {
    return GestureDetector(
      onTap: () {
        _showClearHistoryDialog();
      },
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(vertical: 14),
        decoration: BoxDecoration(
          color: Colors.transparent,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: Colors.redAccent.withOpacity(0.3),
            width: 1,
          ),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.delete_outline,
              color: Colors.redAccent.withOpacity(0.8),
              size: 20,
            ),
            const SizedBox(width: 8),
            Text(
              'Clear History',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    color: Colors.redAccent.withOpacity(0.8),
                    fontWeight: FontWeight.w500,
                  ),
            ),
          ],
        ),
      ),
    );
  }

  void _showClearHistoryDialog() {
    showDialog(
      context: context,
      barrierColor: Colors.black.withOpacity(0.5),
      builder: (context) => BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
        child: AlertDialog(
          backgroundColor: const Color(0xFF1A1A1A),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
            side: BorderSide(
              color: Colors.white.withOpacity(0.1),
              width: 1,
            ),
          ),
          title: Text(
            'Clear Conversation History?',
            style: Theme.of(context).textTheme.titleLarge,
          ),
          content: Text(
            'This action is irreversible and will permanently delete your conversation history with this avatar.',
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: AppTheme.secondaryWhite,
                ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: Text(
                'Cancel',
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      color: AppTheme.secondaryWhite,
                    ),
              ),
            ),
            TextButton(
              onPressed: () {
                Navigator.pop(context);
                context.read<ChatBloc>().add(const ChatMessagesCleared());
                widget.onClose();
                ToastUtils.showSuccess(context, 'Conversation history cleared');
              },
              child: Text(
                'Clear History',
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      color: Colors.redAccent,
                      fontWeight: FontWeight.w600,
                    ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// Billing Content
  Widget _buildBillingContent() {
    return BlocBuilder<CreditsBloc, CreditsState>(
      builder: (context, state) {
        final credits = state is CreditsLoaded ? state.totalCredits : 0;
        final isPro = state is CreditsLoaded ? state.isPro : false;

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Plan info
            Text(
              isPro ? 'Pro Plan' : 'Free Plan',
              style: Theme.of(context).textTheme.headlineSmall,
            ),
            const SizedBox(height: 6),
            Text(
              isPro ? 'Unlimited conversations' : '$credits credits available',
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: AppTheme.tertiaryWhite,
                  ),
            ),
            const SizedBox(height: 16),
            _buildManageDropdown(),

            const SizedBox(height: 24),

            // Credits display
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.transparent,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: const Color(0x14FFFFFF),
                  width: 1,
                ),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Credits',
                        style: Theme.of(context).textTheme.titleLarge,
                      ),
                      const SizedBox(height: 4),
                      Text(
                        '1 Credit = 1 Conversation',
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                              color: AppTheme.tertiaryWhite,
                            ),
                      ),
                    ],
                  ),
                  Text(
                    isPro ? '∞' : '$credits',
                    style: Theme.of(context).textTheme.displaySmall,
                  ),
                ],
              ),
            ),

            const SizedBox(height: 24),

            // Transactions
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.transparent,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: const Color(0x14FFFFFF),
                  width: 1,
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Transactions',
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Coming Soon',
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          color: AppTheme.tertiaryWhite,
                        ),
                  ),
                ],
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _buildManageDropdown() {
    return Column(
      children: [
        GestureDetector(
          onTap: () {
            setState(() {
              _isManageDropdownOpen = !_isManageDropdownOpen;
              _isLanguageDropdownOpen = false;
            });
          },
          child: Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            decoration: BoxDecoration(
              color: Colors.transparent,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: const Color(0x14FFFFFF),
                width: 1,
              ),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Manage',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        color: AppTheme.secondaryWhite,
                      ),
                ),
                AnimatedRotation(
                  turns: _isManageDropdownOpen ? 0.5 : 0,
                  duration: const Duration(milliseconds: 200),
                  child: Icon(
                    Icons.keyboard_arrow_down,
                    color: AppTheme.secondaryWhite,
                  ),
                ),
              ],
            ),
          ),
        ),
        if (_isManageDropdownOpen)
          Container(
            width: double.infinity,
            margin: const EdgeInsets.only(top: 8),
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
            ),
            child: Column(
              children: [
                _buildManageOption('Buy Credits', () {
                  setState(() => _isManageDropdownOpen = false);
                  ToastUtils.showInfo(context, 'Coming soon');
                }),
                _buildManageOption('Adjust Plan', () {
                  setState(() => _isManageDropdownOpen = false);
                  ToastUtils.showInfo(context, 'Coming soon');
                }),
              ],
            ),
          ),
      ],
    );
  }

  Widget _buildManageOption(String title, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          color: Colors.transparent,
          borderRadius: BorderRadius.circular(8),
        ),
        child: Text(
          title,
          style: Theme.of(context).textTheme.titleMedium?.copyWith(
                color: Colors.black,
              ),
        ),
      ),
    );
  }

  /// Memory Content
  Widget _buildMemoryContent() {
    return BlocBuilder<MemoryBloc, MemoryState>(
      builder: (context, state) {
        if (state is MemoryLoading) {
          return Center(
            child: Padding(
              padding: const EdgeInsets.all(32),
              child: Text(
                'Loading memories...',
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      color: AppTheme.secondaryWhite,
                    ),
              ),
            ),
          );
        }

        if (state is MemoryError) {
          return Center(
            child: Padding(
              padding: const EdgeInsets.all(32),
              child: Text(
                'Error: ${state.message}',
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      color: Colors.redAccent,
                    ),
              ),
            ),
          );
        }

        if (state is MemoryLoaded) {
          if (state.memories.isEmpty) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(32),
                child: Text(
                  'No memories found.',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        color: AppTheme.secondaryWhite,
                      ),
                ),
              ),
            );
          }

          return Column(
            children: state.memories.map((memory) {
              return Container(
                width: double.infinity,
                margin: const EdgeInsets.only(bottom: 12),
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.transparent,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: const Color(0x14FFFFFF),
                    width: 1,
                  ),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      memory.memory,
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                    const SizedBox(height: 12),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          _formatDate(memory.createdAt),
                          style:
                              Theme.of(context).textTheme.bodyMedium?.copyWith(
                                    color: AppTheme.tertiaryWhite,
                                  ),
                        ),
                        GestureDetector(
                          onTap: () => _showDeleteMemoryDialog(memory.id),
                          child: Container(
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Icon(
                              Icons.delete_outline,
                              color: AppTheme.tertiaryWhite,
                              size: 20,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              );
            }).toList(),
          );
        }

        return const SizedBox.shrink();
      },
    );
  }

  String _formatDate(DateTime date) {
    return '${date.day}/${date.month}/${date.year} ${date.hour.toString().padLeft(2, '0')}:${date.minute.toString().padLeft(2, '0')}';
  }

  void _showDeleteMemoryDialog(String memoryId) {
    showDialog(
      context: context,
      barrierColor: Colors.black.withOpacity(0.5),
      builder: (dialogContext) => BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
        child: AlertDialog(
          backgroundColor: const Color(0xFF1A1A1A),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
            side: BorderSide(
              color: Colors.white.withOpacity(0.1),
              width: 1,
            ),
          ),
          title: Text(
            'Delete Memory?',
            style: Theme.of(context).textTheme.titleLarge,
          ),
          content: Text(
            'This action is irreversible and will permanently delete this specific memory. The AI will no longer remember this information about you.',
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: AppTheme.secondaryWhite,
                ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: Text(
                'Cancel',
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      color: AppTheme.secondaryWhite,
                    ),
              ),
            ),
            TextButton(
              onPressed: () {
                Navigator.pop(dialogContext);
                context.read<MemoryBloc>().add(MemoryDeleted(memoryId));
              },
              child: Text(
                'Delete Memory',
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      color: Colors.redAccent,
                      fontWeight: FontWeight.w600,
                    ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
