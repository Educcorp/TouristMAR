import 'package:flutter/material.dart';
import '../theme/app_theme.dart';

class UserAvatar extends StatelessWidget {
  final String? imageUrl;
  final String fallbackLetter;
  final double radius;
  final Color? color;

  // Sin `const` a propósito: build() lee AppColors (depende de
  // ThemeController); una instancia const no se reconstruiría al cambiar el
  // tema y se quedaría con los colores viejos.
  // ignore: prefer_const_constructors_in_immutables
  UserAvatar({
    super.key,
    required this.imageUrl,
    required this.fallbackLetter,
    this.radius = 16,
    this.color,
  });

  @override
  Widget build(BuildContext context) {
    final resolvedColor = color ?? AppColors.brandTeal;
    if (imageUrl != null && imageUrl!.isNotEmpty) {
      return CircleAvatar(
        radius: radius,
        backgroundColor: resolvedColor.withValues(alpha: 0.2),
        backgroundImage: NetworkImage(imageUrl!),
      );
    }
    return CircleAvatar(
      radius: radius,
      backgroundColor: resolvedColor.withValues(alpha: 0.2),
      child: Text(
        fallbackLetter.isNotEmpty ? fallbackLetter[0].toUpperCase() : '?',
        style: TextStyle(color: resolvedColor, fontWeight: FontWeight.w700, fontSize: radius * 0.6),
      ),
    );
  }
}
