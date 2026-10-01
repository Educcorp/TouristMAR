import 'package:flutter/material.dart';

import '../../models/business_profile.dart';
import '../../pages/login_page.dart';
import '../../services/auth_service.dart';
import '../../services/session_storage.dart';
import '../../theme/app_theme.dart';
import '../../theme/breakpoints.dart';
import '../notification_bell.dart';
import '../theme_toggle_tile.dart';
import '../app_logo.dart';
import '../../utils/keyboard.dart';

/// Secciones persistentes del panel de empresa.
enum BusinessSection { dashboard, perfil, experiencias, resenas }

void businessLogout(BuildContext context) {
  SessionStorage.clearToken();
  Navigator.of(context).pushAndRemoveUntil(
    MaterialPageRoute(builder: (_) => const LoginPage()),
    (route) => false,
  );
}

class _BusinessNavLeaf {
  final BusinessSection? section;
  final IconData icon;
  final String label;
  const _BusinessNavLeaf(this.section, this.icon, this.label);
}

const _businessNavItems = [
  _BusinessNavLeaf(BusinessSection.dashboard, Icons.bar_chart, 'Dashboard'),
  _BusinessNavLeaf(BusinessSection.perfil, Icons.apartment, 'Mi negocio'),
  _BusinessNavLeaf(BusinessSection.experiencias, Icons.view_in_ar_outlined, 'Mapa y experiencias'),
  _BusinessNavLeaf(BusinessSection.resenas, Icons.forum_outlined, 'Reseñas'),
  _BusinessNavLeaf(null, Icons.trending_up, 'Estadísticas'),
  _BusinessNavLeaf(null, Icons.settings_outlined, 'Configuración'),
];

/// Shell del panel de empresa: mismo patrón que [AdminShell] (sidebar fijo en
/// pantallas anchas, drawer en angostas, contenido central intercambiado
/// dentro del mismo Scaffold — nunca se remonta el sidebar/drawer al cambiar
/// de sección). A diferencia de [AdminShell], el cuerpo se renderiza directo
/// (sin `AnimatedSwitcher`): el cambio de sección debe ser inmediato, sin
/// animación.
class BusinessShell extends StatelessWidget {
  final List<BusinessProfile> negocios;
  final BusinessProfile selected;
  final ValueChanged<String> onSelectNegocio;
  final VoidCallback onAddNegocio;
  final BusinessSection section;
  final ValueChanged<BusinessSection> onSelectSection;
  final Widget body;
  final ValueChanged<AppNotification>? onNotificationTap;

  const BusinessShell({
    super.key,
    required this.negocios,
    required this.selected,
    required this.onSelectNegocio,
    required this.onAddNegocio,
    required this.section,
    required this.onSelectSection,
    required this.body,
    this.onNotificationTap,
  });

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final isWide = Breakpoints.isExpanded(constraints.maxWidth);

        if (isWide) {
          return Scaffold(
            backgroundColor: AppColors.panelNavy,
            body: Row(
              children: [
                SizedBox(
                  width: 280,
                  child: Container(
                    decoration: BoxDecoration(
                      color: AppColors.panelNavySoft,
                      border: Border(right: BorderSide(color: AppColors.overlay(0.08))),
                    ),
                    child: SafeArea(
                      child: _BusinessSidebarContent(
                        negocios: negocios,
                        selected: selected,
                        onSelectNegocio: onSelectNegocio,
                        onAddNegocio: onAddNegocio,
                        section: section,
                        onSelectSection: onSelectSection,
                        closeDrawerOnTap: false,
                        showCloseButton: false,
                      ),
                    ),
                  ),
                ),
                Expanded(
                  child: Column(
                    children: [
                      _BusinessCompactTopBar(onNotificationTap: onNotificationTap),
                      Expanded(child: body),
                    ],
                  ),
                ),
              ],
            ),
          );
        }

        return Scaffold(
          backgroundColor: AppColors.panelNavy,
          // Al abrir o cerrar el menú lateral se quita el foco de cualquier
          // campo de texto, para que el teclado no se despliegue solo (Error 2).
          onEndDrawerChanged: (_) => hideKeyboard(),
          endDrawer: Drawer(
            backgroundColor: AppColors.panelNavySoft,
            width: 320,
            child: SafeArea(
              child: _BusinessSidebarContent(
                negocios: negocios,
                selected: selected,
                onSelectNegocio: onSelectNegocio,
                onAddNegocio: onAddNegocio,
                section: section,
                onSelectSection: onSelectSection,
                closeDrawerOnTap: true,
                showCloseButton: true,
              ),
            ),
          ),
          body: Column(
            children: [
              _BusinessTopBar(onNotificationTap: onNotificationTap),
              Expanded(child: body),
            ],
          ),
        );
      },
    );
  }
}

class _BusinessCompactTopBar extends StatelessWidget {
  final ValueChanged<AppNotification>? onNotificationTap;

  const _BusinessCompactTopBar({this.onNotificationTap});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
      decoration: BoxDecoration(
        color: AppColors.panelNavy,
        border: Border(bottom: BorderSide(color: AppColors.overlay(0.08))),
      ),
      child: SafeArea(
        // Respeta la barra de estado del teléfono: sin esto la barra de
        // notificaciones del sistema se encima con la campana y el botón del
        // menú (Error 3).
        left: false,
        right: false,
        bottom: false,
        child: Row(
          mainAxisAlignment: MainAxisAlignment.end,
          children: [
            NotificationBell(accentColor: AppColors.businessOrange, onNotificationTap: onNotificationTap),
          ],
        ),
      ),
    );
  }
}

class _BusinessTopBar extends StatelessWidget {
  final ValueChanged<AppNotification>? onNotificationTap;

  const _BusinessTopBar({this.onNotificationTap});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
      decoration: BoxDecoration(
        color: AppColors.panelNavy,
        border: Border(bottom: BorderSide(color: AppColors.overlay(0.08))),
      ),
      child: SafeArea(
        // Respeta la barra de estado del teléfono: sin esto la barra de
        // notificaciones del sistema se encima con la campana y el botón del
        // menú (Error 3).
        left: false,
        right: false,
        bottom: false,
        child: Row(
          children: [
            AppLogo(size: 32),
            const SizedBox(width: 8),
            Text(
              'TOURISTMAR',
              style: TextStyle(color: AppColors.textPrimary, fontWeight: FontWeight.w600, letterSpacing: 2, fontSize: 13),
            ),
            const SizedBox(width: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              decoration: BoxDecoration(
                color: AppColors.businessOrange.withOpacity(0.15),
                borderRadius: BorderRadius.circular(4),
                border: Border.all(color: AppColors.businessOrange.withOpacity(0.3)),
              ),
              child: Text(
                'EMPRESA',
                style: TextStyle(color: AppColors.businessOrange, fontWeight: FontWeight.w700, fontSize: 9, letterSpacing: 1),
              ),
            ),
            const Spacer(),
            NotificationBell(accentColor: AppColors.businessOrange, onNotificationTap: onNotificationTap),
            const SizedBox(width: 20),
            Builder(
              builder: (context) => GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: () {
                  hideKeyboard();
                  Scaffold.of(context).openEndDrawer();
                },
                child: Container(
                  width: 32,
                  height: 32,
                  decoration: BoxDecoration(
                    color: AppColors.businessOrange.withOpacity(0.12),
                    shape: BoxShape.circle,
                    border: Border.all(color: AppColors.businessOrange.withOpacity(0.4)),
                  ),
                  child: Icon(Icons.apartment, size: 16, color: AppColors.businessOrange),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

Color _estadoColor(String estado) {
  switch (estado) {
    case 'aprobado':
      return AppColors.brandTeal;
    case 'rechazado':
      return AppColors.errorRed;
    default:
      return AppColors.amber;
  }
}

String _estadoLabel(String estado) {
  switch (estado) {
    case 'aprobado':
      return 'Activo';
    case 'rechazado':
      return 'Rechazado';
    default:
      return 'Pendiente';
  }
}

/// Contenido compartido entre el sidebar fijo y el drawer móvil del panel de
/// empresa: logo, negocio seleccionado (con acceso al selector), lista de
/// secciones, toggle de tema y cerrar sesión.
class _BusinessSidebarContent extends StatelessWidget {
  final List<BusinessProfile> negocios;
  final BusinessProfile selected;
  final ValueChanged<String> onSelectNegocio;
  final VoidCallback onAddNegocio;
  final BusinessSection section;
  final ValueChanged<BusinessSection> onSelectSection;
  final bool closeDrawerOnTap;
  final bool showCloseButton;

  const _BusinessSidebarContent({
    required this.negocios,
    required this.selected,
    required this.onSelectNegocio,
    required this.onAddNegocio,
    required this.section,
    required this.onSelectSection,
    required this.closeDrawerOnTap,
    required this.showCloseButton,
  });

  void _handleSelectSection(BuildContext context, BusinessSection s) {
    if (closeDrawerOnTap) Navigator.of(context).pop();
    onSelectSection(s);
  }

  void _handleComingSoon(BuildContext context) {
    if (closeDrawerOnTap) Navigator.of(context).pop();
    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Próximamente')));
  }

  void _handleLogout(BuildContext context) {
    if (closeDrawerOnTap) Navigator.of(context).pop();
    businessLogout(context);
  }

  Future<void> _openSwitcher(BuildContext context) async {
    final tieneAprobado = negocios.any((n) => n.verified);
    await showDialog<void>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        backgroundColor: AppColors.panelNavySoft,
        title: Text('Tus negocios', style: TextStyle(color: AppColors.textPrimary)),
        content: SizedBox(
          width: 320,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ...negocios.map((n) => Material(
                    color: n.id == selected.id ? AppColors.businessOrange.withOpacity(0.1) : Colors.transparent,
                    borderRadius: BorderRadius.circular(10),
                    child: InkWell(
                      borderRadius: BorderRadius.circular(10),
                      onTap: () {
                        Navigator.of(dialogContext).pop();
                        onSelectNegocio(n.id);
                      },
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
                        child: Row(
                          children: [
                            Icon(Icons.apartment, size: 16, color: AppColors.businessOrange),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Text(
                                n.businessName,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(color: AppColors.textPrimary, fontSize: 13, fontWeight: FontWeight.w600),
                              ),
                            ),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                              decoration: BoxDecoration(
                                color: _estadoColor(n.estado).withOpacity(0.15),
                                borderRadius: BorderRadius.circular(999),
                              ),
                              child: Text(
                                _estadoLabel(n.estado),
                                style: TextStyle(color: _estadoColor(n.estado), fontSize: 10, fontWeight: FontWeight.w700),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  )),
              if (tieneAprobado) ...[
                const Divider(height: 20),
                Material(
                  color: Colors.transparent,
                  borderRadius: BorderRadius.circular(10),
                  child: InkWell(
                    borderRadius: BorderRadius.circular(10),
                    onTap: () {
                      Navigator.of(dialogContext).pop();
                      onAddNegocio();
                    },
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
                      child: Row(
                        children: [
                          Icon(Icons.add, size: 16, color: AppColors.brandTeal),
                          const SizedBox(width: 10),
                          Text(
                            'Sugerir negocio nuevo',
                            style: TextStyle(color: AppColors.brandTeal, fontSize: 13, fontWeight: FontWeight.w600),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(),
            child: Text('Cerrar', style: TextStyle(color: AppColors.slate400)),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
          decoration: BoxDecoration(border: Border(bottom: BorderSide(color: AppColors.overlay(0.08)))),
          child: Row(
            children: [
              AppLogo(size: 24),
              const SizedBox(width: 8),
              // Flexible + ellipsis: con letra grande (o en los tests) el
              // encabezado ya no se desborda del sidebar.
              Flexible(
                child: Text(
                  'TOURISTMAR',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(color: AppColors.textPrimary, fontWeight: FontWeight.w700, fontSize: 12, letterSpacing: 1.5),
                ),
              ),
              const SizedBox(width: 6),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                decoration: BoxDecoration(
                  color: AppColors.businessOrange.withOpacity(0.15),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Text(
                  'EMPRESA',
                  style: TextStyle(color: AppColors.businessOrange, fontSize: 9, fontWeight: FontWeight.w700),
                ),
              ),
              const Spacer(),
              if (showCloseButton)
                IconButton(
                  onPressed: () => Navigator.of(context).pop(),
                  icon: Icon(Icons.close, color: AppColors.slate300, size: 18),
                ),
            ],
          ),
        ),
        Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: () => _openSwitcher(context),
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(border: Border(bottom: BorderSide(color: AppColors.overlay(0.08)))),
              child: Row(
                children: [
                  Container(
                    width: 44,
                    height: 44,
                    decoration: BoxDecoration(
                      color: AppColors.businessOrange.withOpacity(0.12),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: AppColors.businessOrange.withOpacity(0.3)),
                    ),
                    child: Icon(Icons.apartment, color: AppColors.businessOrange, size: 20),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Flexible(
                              child: Text(
                                selected.businessName,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(color: AppColors.textPrimary, fontWeight: FontWeight.w600, fontSize: 14),
                              ),
                            ),
                            if (negocios.length > 1) ...[
                              const SizedBox(width: 4),
                              Icon(Icons.unfold_more, size: 14, color: AppColors.slate400),
                            ],
                          ],
                        ),
                        Text(
                          negocios.length > 1 ? '${negocios.length} negocios · toca para cambiar' : _estadoLabel(selected.estado),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(color: AppColors.slate400, fontSize: 12),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
        Expanded(
          child: ListView(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
            children: _businessNavItems.map((item) {
              final active = item.section != null && item.section == section;
              final color = active ? AppColors.businessOrange : AppColors.slate300;
              return Padding(
                padding: const EdgeInsets.only(bottom: 4),
                child: Material(
                  color: active ? AppColors.businessOrange.withOpacity(0.1) : Colors.transparent,
                  borderRadius: BorderRadius.circular(12),
                  child: InkWell(
                    borderRadius: BorderRadius.circular(12),
                    onTap: () => item.section != null ? _handleSelectSection(context, item.section!) : _handleComingSoon(context),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                      child: Row(
                        children: [
                          Icon(item.icon, size: 18, color: color),
                          const SizedBox(width: 12),
                          Flexible(
                            child: Text(
                              item.label,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                color: active ? color : AppColors.overlay(0.85),
                                fontSize: 14,
                                fontWeight: active ? FontWeight.w600 : FontWeight.w500,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              );
            }).toList(),
          ),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12),
          child: ThemeToggleTile(),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 16),
          child: Material(
            color: Colors.transparent,
            borderRadius: BorderRadius.circular(12),
            child: InkWell(
              borderRadius: BorderRadius.circular(12),
              onTap: () => _handleLogout(context),
              child: Padding(
                padding: EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                child: Row(
                  children: [
                    Icon(Icons.logout, size: 18, color: AppColors.errorRed),
                    SizedBox(width: 12),
                    Text(
                      'Cerrar sesión',
                      style: TextStyle(color: AppColors.errorRed, fontSize: 14, fontWeight: FontWeight.w500),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}
