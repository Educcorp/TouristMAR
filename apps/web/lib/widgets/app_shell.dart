import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../models/visitor_profile.dart';
import '../navegacion/rutas.dart';
import '../services/favoritos_service.dart';
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

  /// Pestaña de la barra inferior en móvil (las demás opciones viven en el
  /// menú que abre el avatar).
  final bool tab;

  /// Etiqueta corta para la barra inferior ("Mapa" en vez de "Explorar mapa").
  final String? tabLabel;

  const NavItem({
    required this.icon,
    required this.label,
    required this.onTap,
    this.highlight = false,
    this.tab = false,
    this.tabLabel,
  });
}

void _comingSoon(BuildContext context) {
  ScaffoldMessenger.of(context).showSnackBar(
    const SnackBar(content: Text('Próximamente')),
  );
}

void _logout(BuildContext context) => cerrarSesion(context);

/// Qué página del flujo de visitante está activa — decide qué ítem del nav
/// se resalta. Antes el resaltado era fijo por ítem ("Mi perfil" siempre
/// marcado); ahora cada página que arma la lista dice cuál es, vía [current].
enum VisitorSection { home, mapa, favoritos, profile }

/// Abre "Mis favoritos" (`/favoritos`, sin animación, como un cambio de pestaña).
void openVisitorFavoritos(BuildContext context, VisitorProfile profile, {VisitorSection? from}) {
  if (from == VisitorSection.favoritos) return;
  context.go('/favoritos');
}

/// Abre el mapa del visitante (`/mapa`, sin animación, como un cambio de pestaña).
void openVisitorMap(BuildContext context, VisitorProfile profile, {VisitorSection? from}) {
  if (from == VisitorSection.mapa) return;
  context.go('/mapa');
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
      tab: true,
      highlight: current == VisitorSection.home,
      onTap: () => context.go('/inicio'),
    ),
    NavItem(
      icon: Icons.map_outlined,
      label: 'Explorar mapa',
      tabLabel: 'Mapa',
      tab: true,
      highlight: current == VisitorSection.mapa,
      onTap: () => openVisitorMap(context, profile, from: current),
    ),
    NavItem(
      icon: Icons.favorite_border,
      label: 'Mis favoritos',
      tabLabel: 'Favoritos',
      tab: true,
      highlight: current == VisitorSection.favoritos,
      onTap: () => openVisitorFavoritos(context, profile, from: current),
    ),
    NavItem(
      icon: Icons.person_outline,
      label: 'Mi perfil',
      tabLabel: 'Perfil',
      tab: true,
      highlight: current == VisitorSection.profile,
      onTap: () => context.go('/perfil'),
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
        Text(label, style: TextStyle(color: AppColors.slate400, fontSize: 12)),
      ],
    );
  }
}

/// Bloque de identidad del visitante mostrado arriba del menú de navegación
/// (avatar, nombre, correo, y stats de favoritos/reseñas).
class VisitorIdentityCard extends StatelessWidget {
  final String name;
  final String email;
  final String? avatarUrl;
  final int reviewsCount;

  const VisitorIdentityCard({
    super.key,
    required this.name,
    required this.email,
    this.avatarUrl,
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
            // "Lugares" = favoritos guardados (el único conteo de lugares por
            // cuenta que hoy tiene datos reales); se escucha en vivo para que
            // se actualice solo al marcar/quitar un favorito en cualquier
            // pantalla, sin tener que volver a entrar al drawer.
            ValueListenableBuilder<Set<String>>(
              valueListenable: FavoritosService.instance.ids,
              builder: (context, ids, _) => _DrawerStat(value: '${ids.length}', label: 'Lugares'),
            ),
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
          bottomNavigationBar: _BarraPestanas(items: navItems.where((i) => i.tab).toList()),
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
              RolInsignia(badgeText!),
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
                RolInsignia(badgeText!),
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
              final color = item.highlight ? AppColors.casco : AppColors.slate300;
              return Padding(
                padding: const EdgeInsets.only(bottom: 4),
                child: Material(
                  color: item.highlight ? AppColors.tinta : Colors.transparent,
                  borderRadius: BorderRadius.circular(12),
                  child: InkWell(
                    borderRadius: BorderRadius.circular(12),
                    onTap: () => _handleTap(context, item.onTap),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                      child: Row(
                        children: [
                          Icon(item.icon, size: 20, color: color),
                          const SizedBox(width: 12),
                          // Flexible + ellipsis: una etiqueta larga (o la letra
                          // agrandada por accesibilidad) no debe desbordar el menú.
                          Flexible(
                            child: Text(
                              item.label,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                color: item.highlight ? color : AppColors.tinta,
                                fontSize: 15,
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

/// Insignia del rol (EMPRESA, ADMIN) pintada como matrícula: esmalte amarillo
/// con letra de plantilla. Es lo único que distingue el panel de cada rol.
class RolInsignia extends StatelessWidget {
  final String texto;

  const RolInsignia(this.texto, {super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
      decoration: BoxDecoration(color: AppColors.amarillo, borderRadius: BorderRadius.circular(3)),
      child: Text(texto, style: AppTypography.matricula(size: 13, color: AppColors.riel)),
    );
  }
}

/// Barra inferior del visitante en móvil: el riel de tinta marina, al alcance
/// del pulgar. La pestaña activa se marca con esmalte turquesa.
class _BarraPestanas extends StatelessWidget {
  final List<NavItem> items;

  const _BarraPestanas({required this.items});

  @override
  Widget build(BuildContext context) {
    if (items.length < 2) return const SizedBox.shrink();
    final activa = items.indexWhere((i) => i.highlight);
    return NavigationBar(
      selectedIndex: activa < 0 ? 0 : activa,
      labelBehavior: NavigationDestinationLabelBehavior.alwaysShow,
      onDestinationSelected: (i) {
        hideKeyboard();
        if (i != activa) items[i].onTap();
      },
      destinations: [
        for (final item in items)
          NavigationDestination(icon: Icon(item.icon), label: item.tabLabel ?? item.label, tooltip: item.label),
      ],
    );
  }
}
