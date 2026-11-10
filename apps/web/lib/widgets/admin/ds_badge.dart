import 'package:flutter/material.dart';

import '../../theme/app_theme.dart';

/// Tono semántico de un [DsBadge]. Centraliza el mapeo color/uso para que
/// "pendiente", "activo", "rechazado", etc. se vean igual en todos los paneles
/// en vez de que cada página elija su propio color.
enum BadgeTone { success, warning, danger, info, neutral }

extension on BadgeTone {
  Color get color {
    switch (this) {
      case BadgeTone.success:
        return AppColors.emerald;
      case BadgeTone.warning:
        return AppColors.amber;
      case BadgeTone.danger:
        return AppColors.errorRed;
      case BadgeTone.info:
        return AppColors.brandTeal;
      case BadgeTone.neutral:
        return AppColors.slate400;
    }
  }
}

/// Estado o conteo pequeño junto a un dato.
///
/// - Un estado ("Activo", "Pendiente", "Bloqueado") se pinta como en un
///   tablero: punto de color y la palabra en ese color. Sin cápsula ni borde,
///   así una lista llena de estados no se vuelve una pared de pastillas.
/// - Un número suelto (el conteo junto a un título) va como cifra discreta.
class DsBadge extends StatelessWidget {
  final String text;
  final BadgeTone tone;
  final IconData? icon;

  const DsBadge({super.key, required this.text, required this.tone, this.icon});

  static final _soloNumero = RegExp(r'^\d+$');

  @override
  Widget build(BuildContext context) {
    final color = tone.color;
    if (_soloNumero.hasMatch(text)) {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 1),
        decoration: BoxDecoration(
          color: AppColors.surfaceAlt,
          borderRadius: BorderRadius.circular(6),
        ),
        child: Text(text, style: AppTypography.cifra(size: 16, color: AppColors.slate300)),
      );
    }
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (icon != null)
          Icon(icon, size: 16, color: color)
        else
          Container(width: 8, height: 8, decoration: BoxDecoration(color: color, shape: BoxShape.circle)),
        const SizedBox(width: 6),
        Text(text, style: TextStyle(color: color, fontSize: 14, fontWeight: FontWeight.w600)),
      ],
    );
  }
}
