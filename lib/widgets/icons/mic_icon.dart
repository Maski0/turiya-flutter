import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

class MicIcon extends StatelessWidget {
  final bool isActive;
  final double size;

  const MicIcon({
    super.key,
    this.isActive = false,
    this.size = 32,
  });

  @override
  Widget build(BuildContext context) {
    return SvgPicture.asset(
      'assets/icons/mic.svg',
      width: size,
      height: size,
    );
  }
}
