import 'package:flutter/material.dart';

import '../../services/auth_service.dart';
import '../../theme/app_theme.dart';
import '../../widgets/admin/admin_shell.dart';
import '../../widgets/admin/ds_badge.dart';
import '../../widgets/admin/ds_button.dart';
import '../../widgets/admin/ds_card.dart';
import '../../widgets/admin/ds_icon_badge.dart';
import '../../widgets/user_avatar.dart';

/// Contenido de la sección "Configuración". El backend admin no expone
/// edición de perfil ni preferencias de notificaciones todavía, así que esas
/// categorías se muestran de solo lectura / "Próximamente" en vez de simular
/// controles que no harían nada real.
class AdminSettingsPage extends StatefulWidget {
  final AuthUser admin;

  const AdminSettingsPage({super.key, required this.admin});

  @override
  State<AdminSettingsPage> createState() => _AdminSettingsPageState();
}

class _AdminSettingsPageState extends State<AdminSettingsPage> {
  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(AppSpacing.xl),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 640),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Configuración', style: AppTypography.h1),
            const SizedBox(height: 4),
            Text('Administra tu cuenta y las preferencias del panel.', style: AppTypography.body),
            const SizedBox(height: AppSpacing.xl),
            _SettingsSection(
              title: 'Perfil',
              child: DsCard(
                child: Row(
                  children: [
                    UserAvatar(fallbackLetter: widget.admin.name, imageUrl: widget.admin.avatarUrl, radius: 24, color: AppColors.adminViolet),
                    const SizedBox(width: AppSpacing.md),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(widget.admin.name, style: TextStyle(color: AppColors.textPrimary, fontWeight: FontWeight.w600, fontSize: 14)),
                          const SizedBox(height: 2),
                          Text(widget.admin.email, style: AppTypography.bodySmall),
                        ],
                      ),
                    ),
                    DsBadge(
                      text: widget.admin.isSuperAdmin ? 'Super Admin' : 'Administrador',
                      tone: widget.admin.isSuperAdmin ? BadgeTone.info : BadgeTone.neutral,
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: AppSpacing.xl),
            _SettingsSection(
              title: 'Cuenta',
              child: DsCard(
                child: Row(
                  children: [
                    DsIconBadgeCircle(icon: Icons.logout, color: AppColors.errorRed, size: 36),
                    const SizedBox(width: AppSpacing.md),
                    Expanded(
                      child: Text('Cerrar sesión en este dispositivo.', style: TextStyle(color: AppColors.textPrimary, fontSize: 13)),
                    ),
                    DsButton(
                      label: 'Cerrar sesión',
                      variant: DsButtonVariant.danger,
                      onPressed: () => adminLogout(context),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SettingsSection extends StatelessWidget {
  final String title;
  final Widget child;

  const _SettingsSection({required this.title, required this.child});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(title, style: AppTypography.h3),
        const SizedBox(height: AppSpacing.sm),
        child,
      ],
    );
  }
}
