import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

class CopyIcon extends StatelessWidget {
  final double size;
  final Color color;

  const CopyIcon({
    super.key,
    this.size = 24,
    this.color = Colors.white,
  });

  @override
  Widget build(BuildContext context) {
    return SvgPicture.asset(
      'assets/icons/copy.svg',
      width: size,
      height: size,
      colorFilter: ColorFilter.mode(color, BlendMode.srcIn),
    );
  }
}
