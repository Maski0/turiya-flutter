import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

class MainMenu extends StatelessWidget {
  final bool isOpen;
  final VoidCallback onClose;

  const MainMenu({
    super.key,
    required this.isOpen,
    required this.onClose,
  });

  Future<void> _openUrl(BuildContext context, String url) async {
    onClose();
    final uri = Uri.parse(url);
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    }
  }

  Future<void> _openEmail(BuildContext context) async {
    onClose();
    final Uri emailUri = Uri(
      scheme: 'mailto',
      path: 'support@turiya.now',
    );
    if (await canLaunchUrl(emailUri)) {
      await launchUrl(emailUri);
    }
  }

  @override
  Widget build(BuildContext context) {
    final screenHeight = MediaQuery.of(context).size.height;
    final screenWidth = MediaQuery.of(context).size.width;

    return Stack(
      children: [
        // Overlay background
        if (isOpen)
          GestureDetector(
            onTap: onClose,
            child: Container(
              color: Colors.black.withOpacity(0.2),
            ),
          ),
        // Menu panel
        AnimatedPositioned(
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeInOut,
          top: 16,
          left: isOpen ? 16 : -(screenWidth),
          child: SafeArea(
            child: Container(
              width: screenWidth - 32,
              height: screenHeight - 32 - MediaQuery.of(context).padding.top,
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(24),
                border: Border.all(
                  color: const Color(0x14FFFFFF),
                  width: 1,
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Close button
                  GestureDetector(
                    onTap: onClose,
                    child: Container(
                      width: 32,
                      height: 32,
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: const Center(
                        child: Icon(
                          Icons.close,
                          color: Color(0xFF111111),
                          size: 24,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 8),
                  // Menu items
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _MenuItem(
                          title: 'About',
                          onTap: () => _openUrl(
                            context,
                            'https://www.turiya.now/about',
                          ),
                        ),
                        _MenuItem(
                          title: 'FAQs',
                          onTap: () => _openUrl(
                            context,
                            'https://www.turiya.now/faqs',
                          ),
                        ),
                        _MenuItem(
                          title: 'Blog',
                          onTap: () => _openUrl(
                            context,
                            'https://www.turiya.now/blog',
                          ),
                        ),
                        _MenuItem(
                          title: 'Contact',
                          onTap: () => _openEmail(context),
                          showDivider: false,
                        ),
                      ],
                    ),
                  ),
                  // Footer - Privacy Policy
                  GestureDetector(
                    onTap: () => _openUrl(
                      context,
                      'https://walnut-tin-527.notion.site/Privacy-Policy-2508bdb5861080eeb8f5ed84ca71e7ea',
                    ),
                    child: Text(
                      'Privacy Policy',
                      style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                            color: const Color(0xFF111111),
                            fontWeight: FontWeight.w500,
                          ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _MenuItem extends StatelessWidget {
  final String title;
  final VoidCallback onTap;
  final bool showDivider;

  const _MenuItem({
    required this.title,
    required this.onTap,
    this.showDivider = true,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        GestureDetector(
          onTap: onTap,
          behavior: HitTestBehavior.opaque,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 24),
            child: SizedBox(
              width: double.infinity,
              child: Text(
                title,
                // Web: text-2xl font-medium (24px)
                style: Theme.of(context).textTheme.displaySmall?.copyWith(
                      color: const Color(0xFF111111),
                      fontWeight: FontWeight.w500,
                    ),
              ),
            ),
          ),
        ),
        if (showDivider)
          Container(
            height: 1,
            color: const Color(0x29111111), // rgba(17, 17, 17, 0.16)
          ),
      ],
    );
  }
}
