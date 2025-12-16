import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

class HamburgerIcon extends StatelessWidget {
  final double size;

  const HamburgerIcon({super.key, this.size = 24});

  @override
  Widget build(BuildContext context) {
    return SvgPicture.asset(
      'assets/icons/hamburger.svg',
      width: size,
      height: size,
    );
  }
}
