import 'package:flutter/material.dart';

import '../../navegacion/rutas.dart';
import '../../services/auth_service.dart';
import '../../theme/app_theme.dart';
import '../../theme/breakpoints.dart';
import '../notification_bell.dart';
import '../theme_toggle_tile.dart';
import '../app_logo.dart';
import '../../utils/keyboard.dart';

/// Adónde debe mandar al admin una notificación según su tipo — usado por
/// [AdminDashboardPage] para pasarle a la campana un handler concreto.
AdminSection? adminSectionForNotification(String tipo) {
  switch (tipo) {
    case 'negocio_pendiente':
    case 'negocio_sugerido':
      return AdminSection.solicitudes;
    case 'usuario_nuevo':
      return AdminSection.usuarios;
    default:
      return null;
  }
}

/// Destinos disponibles en el panel admin. Los recorridos 360° viven dentro
/// de "Mapa y RA" (en cada lugar), ya no son una sección aparte.
enum AdminSection { inicio, solicitudes, usuarios, negocios, mapa, realidadAumentada, admins, reportes, configuracion, ayuda }

/// Nombre de cada sección en la URL (`/admin/<slug>`).
extension AdminSectionSlug on AdminSection {
  String get slug => switch (this) {
        AdminSection.realidadAumentada => 'ra',
        _ => name,
      };

  static AdminSection? desdeSlug(String? slug) {
    for (final s in AdminSection.values) {
      if (s.slug == slug) return s;
    }
    return null;
  }
}

void adminLogout(BuildContext context) => cerrarSesion(context);

class _AdminNavLeaf {
  final AdminSection section;
  final IconData icon;
  final String label;
  const _AdminNavLeaf(this.section, this.icon, this.label);
}

const _adminNavItems = [
  _AdminNavLeaf(AdminSection.inicio, Icons.home_outlined, 'Inicio'),
  _AdminNavLeaf(AdminSection.solicitudes, Icons.report_gmailerrorred_outlined, 'Solicitudes'),
  _AdminNavLeaf(AdminSection.usuarios, Icons.group_outlined, 'Usuarios'),
  _AdminNavLeaf(AdminSection.negocios, Icons.apartment_outlined, 'Negocios'),
  _AdminNavLeaf(AdminSection.mapa, Icons.view_in_ar_outlined, 'Mapa y RA'),
  _AdminNavLeaf(AdminSection.realidadAumentada, Icons.view_in_ar_outlined, 'Realidad aumentada'),
  _AdminNavLeaf(AdminSection.admins, Icons.shield_outlined, 'Admins'),
  _AdminNavLeaf(AdminSection.reportes, Icons.bar_chart_outlined, 'Reportes'),
  _AdminNavLeaf(AdminSection.configuracion, Icons.settings_outlined, 'Configuración'),
  _AdminNavLeaf(AdminSection.ayuda, Icons.help_outline, 'Ayuda'),
];

/// Shell del panel admin: sidebar izquierdo fijo (siempre visible, sin botón
/// para abrirlo) en pantallas anchas, igual que [AppShell] de visitante y
/// empresa; en pantallas angostas cae a un drawer con botón. El contenido
/// central se intercambia dentro del mismo Scaffold en vez de empujar una
/// pantalla nueva, así el sidebar/drawer nunca se remonta al cambiar de
/// sección.
class AdminShell extends StatelessWidget {
  final AuthUser admin;
  final AdminSection selected;
  final ValueChanged<AdminSection> onSelect;
  final Widget body;
  final ValueChanged<AppNotification>? onNotificationTap;

  const AdminShell({
    super.key,
    required this.admin,
    required this.selected,
    required this.onSelect,
    required this.body,
    this.onNotificationTap,
  });

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final isWide = Breakpoints.isExpanded(constraints.maxWidth);
        final content = ClipRect(
          child: AnimatedSwitcher(
            duration: const Duration(milliseconds: 200),
            switchInCurve: Curves.easeOut,
            child: KeyedSubtree(key: ValueKey(selected), child: body),
          ),
        );

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
                      child: _AdminSidebarContent(
                        admin: admin,
                        selected: selected,
                        onSelect: onSelect,
                        closeDrawerOnTap: false,
                        showCloseButton: false,
                      ),
                    ),
                  ),
                ),
                Expanded(
                  child: Column(
                    children: [
                      _AdminCompactTopBar(onNotificationTap: onNotificationTap),
                      Expanded(child: content),
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
              child: _AdminSidebarContent(
                admin: admin,
                selected: selected,
                onSelect: onSelect,
                closeDrawerOnTap: true,
                showCloseButton: true,
              ),
            ),
          ),
          body: Column(
            children: [
              _AdminTopBar(onNotificationTap: onNotificationTap),
              Expanded(child: content),
            ],
          ),
        );
      },
    );
  }
}

class _AdminCompactTopBar extends StatelessWidget {
  final ValueChanged<AppNotification>? onNotificationTap;

  const _AdminCompactTopBar({this.onNotificationTap});

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
            NotificationBell(accentColor: AppColors.adminViolet, onNotificationTap: onNotificationTap),
          ],
        ),
      ),
    );
  }
}

class _AdminTopBar extends StatelessWidget {
  final ValueChanged<AppNotification>? onNotificationTap;

  const _AdminTopBar({this.onNotificationTap});

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
                color: AppColors.adminViolet.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(4),
                border: Border.all(color: AppColors.adminViolet.withValues(alpha: 0.3)),
              ),
              child: Text(
                'ADMIN',
                style: TextStyle(color: AppColors.adminViolet, fontWeight: FontWeight.w700, fontSize: 9, letterSpacing: 1),
              ),
            ),
            const Spacer(),
            NotificationBell(accentColor: AppColors.adminViolet, onNotificationTap: onNotificationTap),
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
                    color: AppColors.adminViolet.withValues(alpha: 0.12),
                    shape: BoxShape.circle,
                    border: Border.all(color: AppColors.adminViolet.withValues(alpha: 0.4)),
                  ),
                  child: Icon(Icons.shield_outlined, size: 16, color: AppColors.adminViolet),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Contenido compartido entre el sidebar fijo y el drawer móvil del panel
/// admin: logo, identidad, lista de secciones, toggle de tema y cerrar
/// sesión.
class _AdminSidebarContent extends StatelessWidget {
  final AuthUser admin;
  final AdminSection selected;
  final ValueChanged<AdminSection> onSelect;
  final bool closeDrawerOnTap;
  final bool showCloseButton;

  const _AdminSidebarContent({
    required this.admin,
    required this.selected,
    required this.onSelect,
    required this.closeDrawerOnTap,
    required this.showCloseButton,
  });

  void _handleSelect(BuildContext context, AdminSection section) {
    if (closeDrawerOnTap) Navigator.of(context).pop();
    onSelect(section);
  }

  void _handleLogout(BuildContext context) {
    if (closeDrawerOnTap) Navigator.of(context).pop();
    adminLogout(context);
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
              Text(
                'TOURISTMAR',
                style: TextStyle(color: AppColors.textPrimary, fontWeight: FontWeight.w700, fontSize: 12, letterSpacing: 1.5),
              ),
              const SizedBox(width: 6),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                decoration: BoxDecoration(
                  color: AppColors.adminViolet.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Text(
                  'ADMIN',
                  style: TextStyle(color: AppColors.adminViolet, fontSize: 9, fontWeight: FontWeight.w700),
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
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(border: Border(bottom: BorderSide(color: AppColors.overlay(0.08)))),
          child: Row(
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: AppColors.adminViolet.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: AppColors.adminViolet.withValues(alpha: 0.3)),
                ),
                child: Icon(Icons.shield_outlined, color: AppColors.adminViolet, size: 20),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      admin.isSuperAdmin ? 'Super administrador' : 'Administrador',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(color: AppColors.textPrimary, fontWeight: FontWeight.w600, fontSize: 14),
                    ),
                    Text(
                      admin.email,
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
        Expanded(
          child: ListView(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
            children: _adminNavItems.map((item) {
              final active = selected == item.section;
              final color = active ? AppColors.adminViolet : AppColors.slate300;
              return Padding(
                padding: const EdgeInsets.only(bottom: 4),
                child: Material(
                  color: active ? AppColors.adminViolet.withValues(alpha: 0.1) : Colors.transparent,
                  borderRadius: BorderRadius.circular(12),
                  child: InkWell(
                    borderRadius: BorderRadius.circular(12),
                    onTap: () => _handleSelect(context, item.section),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                      child: Row(
                        children: [
                          Icon(item.icon, size: 18, color: color),
                          const SizedBox(width: 12),
                          // Flexible + ellipsis: una etiqueta larga (o la letra
                          // agrandada por accesibilidad) no debe desbordar el menú.
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
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                child: Row(
                  children: [
                    Icon(Icons.logout, size: 18, color: AppColors.errorRed),
                    const SizedBox(width: 12),
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
