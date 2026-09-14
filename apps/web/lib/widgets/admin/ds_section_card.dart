import 'package:flutter/material.dart';

import '../../theme/app_theme.dart';
import 'ds_card.dart';
import 'ds_icon_badge.dart';

/// Botón de acceso rápido a un módulo del sistema (Solicitudes, Usuarios,
/// Negocios, Admins): ícono + título en una fila compacta. Sin imagen de
/// fondo ni descripción — se ve y se comporta como un botón, no como una
/// tarjeta destacada.
class DsSectionCard extends StatelessWidget {
  final IconData icon;
  final String title;
  final Color accent;
  final VoidCallback onTap;

  const DsSectionCard({
    super.key,
    required this.icon,
    required this.title,
    required this.accent,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return DsCard(
      onTap: onTap,
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md, vertical: AppSpacing.md),
      child: Row(
        children: [
          DsIconBadgeCircle(icon: icon, color: accent, size: 38),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Text(
              title,
              style: AppTypography.h3,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          Icon(Icons.chevron_right, size: 18, color: AppColors.slate500),
        ],
      ),
    );
  }
}
