import 'package:flutter/material.dart';

import '../../theme/app_theme.dart';
import 'ds_card.dart';
import 'ds_icon_badge.dart';

/// Tarjeta de acceso rápido a un módulo del sistema (Solicitudes, Usuarios,
/// Negocios, Admins). Si se da [backgroundImage], se usa como fondo con una
/// capa radial del color de acento: sólida al centro y difuminada hacia los
/// bordes (donde se ve la foto sin tinte). Sin imagen, cae al gradiente
/// lineal sutil de siempre.
class DsSectionCard extends StatelessWidget {
  final IconData icon;
  final String title;
  final String description;
  final Color accent;
  final VoidCallback onTap;
  final String? backgroundImage;

  const DsSectionCard({
    super.key,
    required this.icon,
    required this.title,
    required this.description,
    required this.accent,
    required this.onTap,
    this.backgroundImage,
  });

  @override
  Widget build(BuildContext context) {
    return DsCard(
      onTap: onTap,
      padding: EdgeInsets.zero,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(AppRadius.card),
        child: Stack(
          children: [
            if (backgroundImage != null)
              Positioned.fill(
                child: Image.asset(backgroundImage!, fit: BoxFit.cover),
              ),
            if (backgroundImage != null)
              // Scrim uniforme para mantener el texto legible sin importar
              // qué tan clara/oscura sea la foto de fondo.
              Positioned.fill(
                child: DecoratedBox(decoration: BoxDecoration(color: AppColors.bgDeep.withOpacity(0.45))),
              ),
            Positioned.fill(
              child: DecoratedBox(
                decoration: BoxDecoration(
                  gradient: backgroundImage != null
                      ? RadialGradient(
                          center: Alignment.center,
                          radius: 1.1,
                          colors: [accent.withOpacity(0.55), accent.withOpacity(0.0)],
                        )
                      : LinearGradient(
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                          colors: [accent.withOpacity(0.10), Colors.transparent],
                        ),
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(AppSpacing.lg),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  DsIconBadgeCircle(icon: icon, color: accent, size: 200),
                  const SizedBox(height: AppSpacing.lg),
                  Text(title, style: AppTypography.h3),
                  const SizedBox(height: 4),
                  Text(
                    description,
                    style: AppTypography.bodySmall.copyWith(color: AppColors.slate300),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
            Positioned(
              top: AppSpacing.lg,
              right: AppSpacing.lg,
              child: Container(
                width: 30,
                height: 30,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(color: accent.withOpacity(0.4)),
                ),
                child: Icon(Icons.arrow_outward, size: 14, color: accent),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
