import 'package:flutter/material.dart';

import '../../theme/app_theme.dart';

/// Ícono de cabecera de fila o de tarjeta: una placa cuadrada (como las de
/// la lista del mapa) con el ícono del color de su categoría o estado.
/// Antes era un círculo tintado con borde y brillo, el adorno genérico de
/// cualquier panel; [glow] se conserva solo por compatibilidad y ya no pinta.
class DsIconBadgeCircle extends StatelessWidget {
  final IconData icon;
  final Color color;
  final double size;
  final bool glow;

  const DsIconBadgeCircle({
    super.key,
    required this.icon,
    required this.color,
    this.size = 44,
    this.glow = false,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: AppColors.surfaceAlt,
        borderRadius: BorderRadius.circular(size * 0.24),
      ),
      child: Icon(icon, color: color, size: size * 0.5),
    );
  }
}
