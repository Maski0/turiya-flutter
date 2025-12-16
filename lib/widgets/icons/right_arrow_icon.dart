import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

class RightArrowIcon extends StatelessWidget {
  final double size;
  final Color color;

  const RightArrowIcon({
    super.key,
    this.size = 14,
    this.color = Colors.white,
  });

  @override
  Widget build(BuildContext context) {
    return SvgPicture.asset(
      'assets/icons/right_arrow.svg',
      width: size,
      height: size * 1.5, // Original ratio: 14x21
      colorFilter: ColorFilter.mode(color, BlendMode.srcIn),
    );
  }
}
