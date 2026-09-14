import 'package:flutter/material.dart';

import '../../theme/app_theme.dart';
import 'ds_card.dart';
import 'ds_icon_badge.dart';

/// Tarjeta de estadística del dashboard/reportes.
class DsStatCard extends StatelessWidget {
  final IconData icon;
  final int value;
  final String label;
  final Color accent;

  const DsStatCard({
    super.key,
    required this.icon,
    required this.value,
    required this.label,
    required this.accent,
  });

  @override
  Widget build(BuildContext context) {
    return DsCard(
      padding: const EdgeInsets.all(AppSpacing.lg),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          DsIconBadgeCircle(icon: icon, color: accent, size: 36),
          const SizedBox(height: AppSpacing.md),
          TweenAnimationBuilder<double>(
            tween: Tween(begin: 0, end: value.toDouble()),
            duration: const Duration(milliseconds: 700),
            curve: Curves.easeOutCubic,
            builder: (context, animated, _) => Text(
              '${animated.round()}',
              style: const TextStyle(color: Colors.white, fontSize: 26, fontWeight: FontWeight.w700),
            ),
          ),
          const SizedBox(height: 2),
          Text(label, style: AppTypography.bodySmall, maxLines: 2, overflow: TextOverflow.ellipsis),
        ],
      ),
    );
  }
}
