import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

class CancelIcon extends StatelessWidget {
  final double size;

  const CancelIcon({
    super.key,
    this.size = 24,
  });

  @override
  Widget build(BuildContext context) {
    return SvgPicture.asset(
      'assets/icons/cancel.svg',
      width: size,
      height: size,
    );
  }
}
