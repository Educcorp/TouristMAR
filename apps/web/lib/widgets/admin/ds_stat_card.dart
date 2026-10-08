import 'package:flutter/material.dart';

import '../../theme/app_theme.dart';
import 'ds_card.dart';

/// Celda de estadística del dashboard/reportes, como en un tablero: icono
/// discreto, la cifra en letra de matrícula y su etiqueta. [accent] solo pinta
/// la franja superior cuando la cifra pide atención (p. ej. pendientes).
class DsStatCard extends StatelessWidget {
  final IconData icon;
  final int value;
  final String label;
  final Color accent;

  /// La cifra pide atención: se marca con la franja del esmalte [accent].
  final bool alerta;

  const DsStatCard({
    super.key,
    required this.icon,
    required this.value,
    required this.label,
    required this.accent,
    this.alerta = false,
  });

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(AppRadius.card),
      child: DsCard(
      padding: EdgeInsets.zero,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(height: kFranja, color: alerta ? accent : Colors.transparent),
          Padding(
            padding: const EdgeInsets.fromLTRB(AppSpacing.lg, AppSpacing.md, AppSpacing.lg, AppSpacing.lg),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
          Icon(icon, size: 20, color: AppColors.slate400),
          const SizedBox(height: AppSpacing.sm),
          TweenAnimationBuilder<double>(
            tween: Tween(begin: 0, end: value.toDouble()),
            duration: const Duration(milliseconds: 700),
            curve: Curves.easeOutCubic,
            builder: (context, animated, _) => Text(
              '${animated.round()}',
              style: AppTypography.cifra(size: 34),
            ),
          ),
          const SizedBox(height: 2),
          Text(label, style: AppTypography.bodySmall, maxLines: 2, overflow: TextOverflow.ellipsis),
              ],
            ),
          ),
        ],
      ),
      ),
    );
  }
}
