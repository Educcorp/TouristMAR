import 'package:flutter/material.dart';

import '../../theme/app_theme.dart';

/// Tono semántico de un [DsBadge]. Centraliza el mapeo color/uso para que
/// "pendiente", "activo", "rechazado", etc. se vean igual en toda la app
/// admin en vez de que cada página elija su propio color.
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

class DsBadge extends StatelessWidget {
  final String text;
  final BadgeTone tone;
  final IconData? icon;

  const DsBadge({super.key, required this.text, required this.tone, this.icon});

  @override
  Widget build(BuildContext context) {
    final color = tone.color;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: color.withOpacity(0.12),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[
            Icon(icon, size: 12, color: color),
            const SizedBox(width: 4),
          ],
          Text(
            text,
            style: TextStyle(color: color, fontSize: 11, fontWeight: FontWeight.w600),
          ),
        ],
      ),
    );
  }
}
