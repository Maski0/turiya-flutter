import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

class VoiceModeIcon extends StatelessWidget {
  final double size;
  final Color color;

  const VoiceModeIcon({
    super.key,
    this.size = 24,
    this.color = Colors.white,
  });

  @override
  Widget build(BuildContext context) {
    return SvgPicture.asset(
      'assets/icons/voice_mode.svg',
      width: size,
      height: size,
      colorFilter: ColorFilter.mode(color, BlendMode.srcIn),
    );
  }
}
