import 'package:flutter/material.dart';

import '../../theme/app_theme.dart';
import '../../widgets/admin/ds_card.dart';
import '../../widgets/admin/ds_icon_badge.dart';

class _HelpTopic {
  final IconData icon;
  final String title;
  final String description;
  const _HelpTopic(this.icon, this.title, this.description);
}

const _topics = [
  _HelpTopic(Icons.mark_email_read_outlined, 'Solicitudes',
      'Aprueba o rechaza negocios que solicitan unirse a la plataforma. Una vez aprobado, el negocio obtiene acceso a su propio panel.'),
  _HelpTopic(Icons.group_outlined, 'Usuarios',
      'Busca visitantes y negocios registrados, y bloquea el acceso de una cuenta si es necesario.'),
  _HelpTopic(Icons.apartment_outlined, 'Negocios',
      'Consulta el listado completo de negocios, filtra por categoría o estado.'),
  _HelpTopic(Icons.shield_outlined, 'Administradores',
      'Solo un super administrador puede crear o eliminar cuentas de administrador.'),
  _HelpTopic(Icons.bar_chart_outlined, 'Reportes',
      'Distribución de negocios y usuarios calculada en tiempo real a partir de los datos actuales del sistema.'),
];

/// Contenido de la sección "Ayuda": guía rápida del panel, con el mismo
/// lenguaje visual que el resto (no es un stub de "próximamente").
class AdminHelpPage extends StatelessWidget {
  // Sin `const`: build() lee AppColors/AppTypography (dependen de
  // ThemeController, un valor externo mutable) — con `const`, Dart
  // canonicalizaría la instancia y esta página se quedaría con los colores
  // del primer render si el tema cambia mientras está visible.
  // ignore: prefer_const_constructors_in_immutables
  AdminHelpPage({super.key});

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(AppSpacing.xl),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 720),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Ayuda', style: AppTypography.h1),
            const SizedBox(height: 4),
            Text('Guía rápida de los módulos del panel de administración.', style: AppTypography.body),
            const SizedBox(height: AppSpacing.xl),
            ..._topics.map((t) => Padding(
                  padding: const EdgeInsets.only(bottom: AppSpacing.md),
                  child: DsCard(
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        DsIconBadgeCircle(icon: t.icon, color: AppColors.adminViolet, size: 38),
                        const SizedBox(width: AppSpacing.md),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(t.title, style: AppTypography.h3),
                              const SizedBox(height: 4),
                              Text(t.description, style: AppTypography.body),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                )),
            const SizedBox(height: AppSpacing.lg),
            DsCard(
              background: AppColors.adminViolet.withValues(alpha: 0.06),
              child: Row(
                children: [
                  DsIconBadgeCircle(icon: Icons.support_agent_outlined, color: AppColors.adminViolet, size: 38),
                  const SizedBox(width: AppSpacing.md),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('¿Necesitas más ayuda?', style: AppTypography.h3),
                        const SizedBox(height: 4),
                        Text('Contacta al equipo técnico de TouristMAR a través de tus canales internos habituales.', style: AppTypography.body),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
