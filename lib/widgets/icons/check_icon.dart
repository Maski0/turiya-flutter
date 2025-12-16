import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

class CheckIcon extends StatelessWidget {
  final double size;

  const CheckIcon({
    super.key,
    this.size = 32,
  });

  @override
  Widget build(BuildContext context) {
    return SvgPicture.asset(
      'assets/icons/check.svg',
      width: size,
      height: size,
    );
  }
}
