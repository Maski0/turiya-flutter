import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

class PauseIcon extends StatelessWidget {
  final double size;

  const PauseIcon({
    super.key,
    this.size = 32,
  });

  @override
  Widget build(BuildContext context) {
    return SvgPicture.asset(
      'assets/icons/pause.svg',
      width: size,
      height: size,
    );
  }
}
