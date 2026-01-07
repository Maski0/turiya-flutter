import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

/// Arrow enter left icon - matches web ArrowEnterLeft exactly
class ArrowEnterLeftIcon extends StatelessWidget {
  final double size;
  final Color color;

  const ArrowEnterLeftIcon({
    super.key,
    this.size = 24,
    this.color = Colors.white,
  });

  @override
  Widget build(BuildContext context) {
    return SvgPicture.asset(
      'assets/icons/arrow_enter_left.svg',
      width: size,
      height: size,
      colorFilter: ColorFilter.mode(color, BlendMode.srcIn),
    );
  }
}
