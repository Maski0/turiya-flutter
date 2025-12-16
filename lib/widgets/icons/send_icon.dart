import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

class SendIcon extends StatelessWidget {
  final bool isActive;
  final double size;

  const SendIcon({
    super.key,
    this.isActive = false,
    this.size = 32,
  });

  @override
  Widget build(BuildContext context) {
    return SvgPicture.asset(
      isActive ? 'assets/icons/send_active.svg' : 'assets/icons/send.svg',
      width: size,
      height: size,
    );
  }
}
