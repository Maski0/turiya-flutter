import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

class SidebarIcon extends StatelessWidget {
  final double size;

  const SidebarIcon({
    super.key,
    this.size = 18,
  });

  @override
  Widget build(BuildContext context) {
    return SvgPicture.asset(
      'assets/icons/sidebar.svg',
      width: size,
      height: size,
    );
  }
}
