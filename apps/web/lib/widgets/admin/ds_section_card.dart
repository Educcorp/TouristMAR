import 'package:flutter/material.dart';

import '../../theme/app_theme.dart';
import 'ds_card.dart';
import 'ds_icon_badge.dart';

/// Tarjeta de acceso rápido a un módulo del sistema (Solicitudes, Usuarios,
/// Negocios, Admins) con gradiente contextual sutil por accent.
class DsSectionCard extends StatelessWidget {
  final IconData icon;
  final String title;
  final String description;
  final Color accent;
  final VoidCallback onTap;

  const DsSectionCard({
    super.key,
    required this.icon,
    required this.title,
    required this.description,
    required this.accent,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return DsCard(
      onTap: onTap,
      padding: EdgeInsets.zero,
      child: Container(
        padding: const EdgeInsets.all(AppSpacing.lg),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(AppRadius.card),
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [accent.withOpacity(0.10), Colors.transparent],
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                DsIconBadgeCircle(icon: icon, color: accent, size: 40),
                Container(
                  width: 30,
                  height: 30,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    border: Border.all(color: accent.withOpacity(0.4)),
                  ),
                  child: Icon(Icons.arrow_outward, size: 14, color: accent),
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.lg),
            Text(title, style: AppTypography.h3),
            const SizedBox(height: 4),
            Text(description, style: AppTypography.bodySmall, maxLines: 2, overflow: TextOverflow.ellipsis),
          ],
        ),
      ),
    );
  }
}
