import 'package:flutter/material.dart';

import '../models/visitor_profile.dart';
import '../pages/explorar_mapa_page.dart';
import '../pages/favoritos_page.dart';
import '../pages/login_page.dart';
import '../pages/profile_page.dart';
import '../services/session_storage.dart';
import '../theme/app_theme.dart';
import '../theme/breakpoints.dart';
import 'notification_bell.dart';
import 'theme_toggle_tile.dart';
import 'user_avatar.dart';
import 'app_logo.dart';
import '../utils/keyboard.dart';

class NavItem {
  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final bool highlight;

  const NavItem({
    required this.icon,
    required this.label,
    required this.onTap,
    this.highlight = false,
  });
}

void _comingSoon(BuildContext context) {
  ScaffoldMessenger.of(context).showSnackBar(
    const SnackBar(content: Text('Próximamente')),
  );
}

/// Ruta sin animación de transición: navegar a "Mi perfil" desde el sidebar
/// debe sentirse como cambiar de pestaña, no como abrir una pantalla nueva
/// encima de la anterior.
Route<T> _instantRoute<T>(WidgetBuilder builder) {
  return PageRouteBuilder<T>(
    pageBuilder: (context, animation, secondaryAnimation) => builder(context),
    transitionDuration: Duration.zero,
    reverseTransitionDuration: Duration.zero,
  );
}

void _logout(BuildContext context) {
  SessionStorage.clearToken();
  Navigator.of(context).pushAndRemoveUntil(
    MaterialPageRoute(builder: (_) => const LoginPage()),
    (route) => false,
  );
}

/// Qué página del flujo de visitante está activa — decide qué ítem del nav
/// se resalta. Antes el resaltado era fijo por ítem ("Mi perfil" siempre
/// marcado); ahora cada página que arma la lista dice cuál es, vía [current].
enum VisitorSection { home, mapa, favoritos, profile }

/// Abre "Mis favoritos" (sin animación, como un cambio de pestaña).
void openVisitorFavoritos(BuildContext context, VisitorProfile profile, {VisitorSection? from}) {
  if (from == VisitorSection.favoritos) return;
  Navigator.of(context).push(_instantRoute((_) => FavoritosPage(profile: profile)));
}

/// Abre el mapa del visitante (sin animación, como un cambio de pestaña).
/// Desde el propio mapa no hace nada, para no apilar otra copia.
void openVisitorMap(BuildContext context, VisitorProfile profile, {VisitorSection? from}) {
  if (from == VisitorSection.mapa) return;
  Navigator.of(context).push(_instantRoute((_) => ExplorarMapaPage(profile: profile)));
}

List<NavItem> visitorNavItems(
  BuildContext context, {
  required VisitorProfile profile,
  required VisitorSection current,
}) {
  return [
    NavItem(
      icon: Icons.home_outlined,
      label: 'Inicio',
      highlight: current == VisitorSection.home,
      onTap: () => Navigator.of(context).popUntil((r) => r.isFirst),
    ),
    NavItem(
      icon: Icons.map_outlined,
      label: 'Explorar mapa',
      highlight: current == VisitorSection.mapa,
      onTap: () => openVisitorMap(context, profile, from: current),
    ),
    NavItem(
      icon: Icons.favorite_border,
      label: 'Mis favoritos',
      highlight: current == VisitorSection.favoritos,
      onTap: () => openVisitorFavoritos(context, profile, from: current),
    ),
    NavItem(
      icon: Icons.person_outline,
      label: 'Mi perfil',
      highlight: current == VisitorSection.profile,
      onTap: () => Navigator.of(context).push(
        _instantRoute((_) => ProfilePage(profile: profile)),
      ),
    ),
    NavItem(
      icon: Icons.notifications_outlined,
      label: 'Notificaciones',
      onTap: () => showNotificationsDialog(context, AppColors.brandTeal),
    ),
    NavItem(icon: Icons.settings_outlined, label: 'Configuración', onTap: () => _comingSoon(context)),
  ];
}

class _DrawerStat extends StatelessWidget {
  final String value;
  final String label;

  const _DrawerStat({required this.value, required this.label});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(value, style: TextStyle(color: AppColors.textPrimary, fontWeight: FontWeight.w700, fontSize: 16)),
        Text(label, style: TextStyle(color: AppColors.slate400, fontSize: 10)),
      ],
    );
  }
}

/// Bloque de identidad del visitante mostrado arriba del menú de navegación
/// (avatar, nombre, correo, y stats de lugares/reseñas).
class VisitorIdentityCard extends StatelessWidget {
  final String name;
  final String email;
  final String? avatarUrl;
  final int visitedCount;
  final int reviewsCount;

  const VisitorIdentityCard({
    super.key,
    required this.name,
    required this.email,
    this.avatarUrl,
    required this.visitedCount,
    required this.reviewsCount,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            UserAvatar(imageUrl: avatarUrl, fallbackLetter: name, radius: 24),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(color: AppColors.textPrimary, fontWeight: FontWeight.w600, fontSize: 14)),
                  Text(email,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(color: AppColors.slate400, fontSize: 12)),
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),
        Row(
          children: [
            _DrawerStat(value: '$visitedCount', label: 'Lugares'),
            const SizedBox(width: 24),
            _DrawerStat(value: '$reviewsCount', label: 'Reseñas'),
          ],
        ),
      ],
    );
  }
}

/// Shell del flujo de visitante: sidebar izquierdo fijo (siempre visible,
/// sin botón para abrirlo) en pantallas anchas; en pantallas angostas —donde
/// un sidebar fijo no cabe— cae a un drawer con botón. El panel de empresa
/// usa su propio [BusinessShell] (necesita un selector de negocio que este
/// no tiene), y el panel admin su [AdminShell] — los tres comparten el mismo
/// patrón visual pero cada uno vive en su propio widget.
class AppShell extends StatelessWidget {
  final Color accentColor;
  final String? badgeText;
  final Widget avatarIcon;
  final Widget drawerIdentity;
  final List<NavItem> navItems;
  final Widget body;

  const AppShell({
    super.key,
    required this.accentColor,
    required this.avatarIcon,
    required this.drawerIdentity,
    required this.navItems,
    required this.body,
    this.badgeText,
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
                  child: _SidebarPanel(
                    accentColor: accentColor,
                    badgeText: badgeText,
                    identity: drawerIdentity,
                    navItems: navItems,
                  ),
                ),
                Expanded(
                  child: Column(
                    children: [
                      _CompactTopBar(accentColor: accentColor),
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
              child: _SidebarContent(
                accentColor: accentColor,
                badgeText: badgeText,
                identity: drawerIdentity,
                navItems: navItems,
                closeDrawerOnTap: true,
                showCloseButton: true,
              ),
            ),
          ),
          body: Column(
            children: [
              _TopBar(accentColor: accentColor, badgeText: badgeText, avatarIcon: avatarIcon),
              Expanded(child: body),
            ],
          ),
        );
      },
    );
  }
}

/// Barra superior mínima para cuando el sidebar ya está fijo a la izquierda:
/// solo campana de notificaciones, sin logo (ya está en el sidebar) ni botón
/// de avatar (no hay drawer que abrir).
class _CompactTopBar extends StatelessWidget {
  final Color accentColor;

  const _CompactTopBar({required this.accentColor});

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
            NotificationBell(accentColor: accentColor),
          ],
        ),
      ),
    );
  }
}

class _TopBar extends StatelessWidget {
  final Color accentColor;
  final String? badgeText;
  final Widget avatarIcon;

  const _TopBar({required this.accentColor, required this.avatarIcon, this.badgeText});

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
            if (badgeText != null) ...[
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: accentColor.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(4),
                  border: Border.all(color: accentColor.withValues(alpha: 0.3)),
                ),
                child: Text(
                  badgeText!,
                  style: TextStyle(color: accentColor, fontWeight: FontWeight.w700, fontSize: 9, letterSpacing: 1),
                ),
              ),
            ],
            const Spacer(),
            NotificationBell(accentColor: accentColor),
            const SizedBox(width: 14),
            Builder(
              builder: (context) => GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: () {
                  hideKeyboard();
                  Scaffold.of(context).openEndDrawer();
                },
                // Padding extra = área táctil más grande (antes solo 32 px).
                child: Padding(padding: const EdgeInsets.all(6), child: avatarIcon),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Panel de sidebar fijo (pantallas anchas): mismo contenido que el drawer
/// pero sin barra de cierre y sin necesidad de popear nada al navegar.
class _SidebarPanel extends StatelessWidget {
  final Color accentColor;
  final String? badgeText;
  final Widget identity;
  final List<NavItem> navItems;

  const _SidebarPanel({
    required this.accentColor,
    required this.identity,
    required this.navItems,
    this.badgeText,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.panelNavySoft,
        border: Border(right: BorderSide(color: AppColors.overlay(0.08))),
      ),
      child: SafeArea(
        child: _SidebarContent(
          accentColor: accentColor,
          badgeText: badgeText,
          identity: identity,
          navItems: navItems,
          closeDrawerOnTap: false,
          showCloseButton: false,
        ),
      ),
    );
  }
}

/// Contenido compartido entre el sidebar fijo y el drawer móvil: logo,
/// identidad, lista de navegación, toggle de tema y cerrar sesión.
class _SidebarContent extends StatelessWidget {
  final Color accentColor;
  final String? badgeText;
  final Widget identity;
  final List<NavItem> navItems;
  final bool closeDrawerOnTap;
  final bool showCloseButton;

  const _SidebarContent({
    required this.accentColor,
    required this.identity,
    required this.navItems,
    required this.closeDrawerOnTap,
    required this.showCloseButton,
    this.badgeText,
  });

  void _handleTap(BuildContext context, VoidCallback onTap) {
    if (closeDrawerOnTap) Navigator.of(context).pop();
    onTap();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
          decoration: BoxDecoration(
            border: Border(bottom: BorderSide(color: AppColors.overlay(0.08))),
          ),
          child: Row(
            children: [
              AppLogo(size: 24),
              const SizedBox(width: 8),
              Text(
                'TOURISTMAR',
                style: TextStyle(color: AppColors.textPrimary, fontWeight: FontWeight.w700, fontSize: 12, letterSpacing: 1.5),
              ),
              if (badgeText != null) ...[
                const SizedBox(width: 6),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                  decoration: BoxDecoration(
                    color: accentColor.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Text(
                    badgeText!,
                    style: TextStyle(color: accentColor, fontSize: 9, fontWeight: FontWeight.w700),
                  ),
                ),
              ],
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
          decoration: BoxDecoration(
            border: Border(bottom: BorderSide(color: AppColors.overlay(0.08))),
          ),
          child: identity,
        ),
        Expanded(
          child: ListView(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
            children: navItems.map((item) {
              final color = item.highlight ? accentColor : AppColors.slate300;
              return Padding(
                padding: const EdgeInsets.only(bottom: 4),
                child: Material(
                  color: item.highlight ? accentColor.withValues(alpha: 0.1) : Colors.transparent,
                  borderRadius: BorderRadius.circular(12),
                  child: InkWell(
                    borderRadius: BorderRadius.circular(12),
                    onTap: () => _handleTap(context, item.onTap),
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
                                color: item.highlight ? color : AppColors.overlay(0.85),
                                fontSize: 14,
                                fontWeight: item.highlight ? FontWeight.w600 : FontWeight.w500,
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
              onTap: () => _handleTap(context, () => _logout(context)),
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
