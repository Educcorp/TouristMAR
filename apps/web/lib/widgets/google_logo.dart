import 'package:flutter/widgets.dart';
import 'package:flutter_svg/flutter_svg.dart';

class GoogleLogo extends StatelessWidget {
  final double size;

  const GoogleLogo({super.key, this.size = 18});

  @override
  Widget build(BuildContext context) {
    return SvgPicture.asset('assets/icons/google_logo.svg', width: size, height: size);
  }
}
