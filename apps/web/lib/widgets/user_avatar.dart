import 'package:flutter/material.dart';
import '../theme/app_theme.dart';

/// Foto de la cuenta o, sin foto, su inicial sobre esmalte turquesa.
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
    if (imageUrl != null && imageUrl!.isNotEmpty) {
      return CircleAvatar(
        radius: radius,
        backgroundColor: AppColors.surfaceAlt,
        backgroundImage: NetworkImage(imageUrl!),
      );
    }
    // Inicial grande y en tinta sobre el esmalte: antes iba al 60 % del radio
    // en turquesa sobre turquesa al 20 % y en la barra superior apenas se leía.
    final fondo = color ?? AppColors.turquesa;
    final letra = fondo.computeLuminance() < 0.3 ? Colors.white : AppColors.riel;
    final inicial = fallbackLetter.trim().isNotEmpty ? fallbackLetter.trim()[0].toUpperCase() : '?';
    return CircleAvatar(
      radius: radius,
      backgroundColor: fondo,
      child: Text(
        inicial,
        style: AppTypography.cifra(size: radius * 0.95, color: letra),
      ),
    );
  }
}
