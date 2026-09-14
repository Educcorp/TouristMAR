import 'package:flutter/material.dart';

/// Círculo con ícono usado para avatares de identidad, cabeceras de card y
/// stat cards. Reemplaza el patrón `Container(shape: circle) + Icon` que
/// antes se repetía copiado en cada página admin.
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
        color: color.withOpacity(0.14),
        shape: BoxShape.circle,
        border: Border.all(color: color.withOpacity(0.3)),
        boxShadow: glow
            ? [
                BoxShadow(
                  color: color.withOpacity(0.25),
                  blurRadius: 16,
                  spreadRadius: 1,
                ),
              ]
            : null,
      ),
      child: Icon(icon, color: color, size: size * 0.42),
    );
  }
}
