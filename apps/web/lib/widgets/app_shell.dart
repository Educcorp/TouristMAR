import 'package:flutter/material.dart';

import '../models/business_profile.dart';
import '../models/visitor_profile.dart';
import '../pages/business_profile_page.dart';
import '../pages/business_reviews_page.dart';
import '../pages/login_page.dart';
import '../pages/profile_page.dart';
import '../services/session_storage.dart';
import '../theme/app_theme.dart';
import '../theme/breakpoints.dart';
import 'theme_toggle_tile.dart';
import 'user_avatar.dart';

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

/// Ruta sin animación de transición: la navegación entre secciones del
/// sidebar (Dashboard, Mi negocio, Reseñas...) debe sentirse como cambiar de
/// pestaña, no como abrir una pantalla nueva encima de la anterior.
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
enum VisitorSection { home, profile }

/// Análogo a [VisitorSection] para el flujo de empresa.
enum BusinessSection { dashboard, profile, reviews }

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
    NavItem(icon: Icons.map_outlined, label: 'Explorar mapa', onTap: () => _comingSoon(context)),
    NavItem(icon: Icons.favorite_border, label: 'Mis favoritos', onTap: () => _comingSoon(context)),
    NavItem(
      icon: Icons.person_outline,
      label: 'Mi perfil',
      highlight: current == VisitorSection.profile,
      onTap: () => Navigator.of(context).push(
        _instantRoute((_) => ProfilePage(profile: profile)),
      ),
    ),
    NavItem(icon: Icons.notifications_outlined, label: 'Notificaciones', onTap: () => _comingSoon(context)),
    NavItem(icon: Icons.settings_outlined, label: 'Configuración', onTap: () => _comingSoon(context)),
  ];
}

List<NavItem> businessNavItems(
  BuildContext context, {
  required BusinessProfile business,
  required BusinessSection current,
}) {
  return [
    NavItem(
      icon: Icons.bar_chart,
      label: 'Dashboard',
      highlight: current == BusinessSection.dashboard,
      onTap: () => Navigator.of(context).popUntil((r) => r.isFirst),
    ),
    NavItem(
      icon: Icons.apartment,
      label: 'Mi negocio',
      highlight: current == BusinessSection.profile,
      onTap: () => Navigator.of(context).push(
        _instantRoute((_) => BusinessProfilePage(business: business)),
      ),
    ),
    NavItem(
      icon: Icons.forum_outlined,
      label: 'Reseñas',
      highlight: current == BusinessSection.reviews,
      onTap: () => Navigator.of(context).push(
        _instantRoute((_) => BusinessReviewsPage(business: business)),
      ),
    ),
    NavItem(icon: Icons.trending_up, label: 'Estadísticas', onTap: () => _comingSoon(context)),
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

/// Bloque de identidad del negocio mostrado arriba del menú de navegación
/// (logo, nombre, verificado, categoría y stats de calificación/reseñas/visitas).
class BusinessIdentityCard extends StatelessWidget {
  final BusinessProfile business;

  const BusinessIdentityCard({super.key, required this.business});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
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
                        child: Text(business.businessName,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(color: AppColors.textPrimary, fontWeight: FontWeight.w600, fontSize: 14)),
                      ),
                      if (business.verified) ...[
                        const SizedBox(width: 4),
                        Icon(Icons.check_circle, color: AppColors.brandTeal, size: 12),
                      ],
                    ],
                  ),
                  Text(business.category,
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
            _DrawerStat(value: '${business.rating}★', label: 'Calificación'),
            const SizedBox(width: 20),
            _DrawerStat(value: '${business.totalReviews}', label: 'Reseñas'),
            const SizedBox(width: 20),
            _DrawerStat(value: '${business.monthlyVisits}', label: 'Visitas/mes'),
          ],
        ),
      ],
    );
  }
}

/// Shell compartido por todas las páginas de visitante y de empresa: sidebar
/// izquierdo fijo (siempre visible, sin botón para abrirlo) en pantallas
/// anchas; en pantallas angostas —donde un sidebar fijo no cabe— cae a un
/// drawer con botón, igual que antes. Solo cambia el color de acento, el
/// badge y los nav items — el resto de la estructura es idéntica en ambos
/// flujos (visitante/empresa).
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
      child: Row(
        mainAxisAlignment: MainAxisAlignment.end,
        children: [
          Stack(
            clipBehavior: Clip.none,
            children: [
              Icon(Icons.notifications_none, color: AppColors.slate300),
              Positioned(
                right: -1,
                top: -1,
                child: Container(
                  width: 8,
                  height: 8,
                  decoration: BoxDecoration(color: AppColors.orange, shape: BoxShape.circle),
                ),
              ),
            ],
          ),
        ],
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
      child: Row(
        children: [
          Container(
            width: 32,
            height: 32,
            decoration: BoxDecoration(color: accentColor, shape: BoxShape.circle),
            child: Icon(Icons.waves, size: 18, color: AppColors.panelNavy),
          ),
          const SizedBox(width: 8),
          Text(
            'TOURISMAR',
            style: TextStyle(color: AppColors.textPrimary, fontWeight: FontWeight.w600, letterSpacing: 2, fontSize: 13),
          ),
          if (badgeText != null) ...[
            const SizedBox(width: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              decoration: BoxDecoration(
                color: accentColor.withOpacity(0.15),
                borderRadius: BorderRadius.circular(4),
                border: Border.all(color: accentColor.withOpacity(0.3)),
              ),
              child: Text(
                badgeText!,
                style: TextStyle(color: accentColor, fontWeight: FontWeight.w700, fontSize: 9, letterSpacing: 1),
              ),
            ),
          ],
          const Spacer(),
          Stack(
            clipBehavior: Clip.none,
            children: [
              Icon(Icons.notifications_none, color: AppColors.slate300),
              Positioned(
                right: -1,
                top: -1,
                child: Container(
                  width: 8,
                  height: 8,
                  decoration: BoxDecoration(color: AppColors.orange, shape: BoxShape.circle),
                ),
              ),
            ],
          ),
          const SizedBox(width: 20),
          Builder(
            builder: (context) => GestureDetector(
              onTap: () => Scaffold.of(context).openEndDrawer(),
              child: avatarIcon,
            ),
          ),
        ],
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
              Container(
                width: 24,
                height: 24,
                decoration: BoxDecoration(color: accentColor, shape: BoxShape.circle),
                child: Icon(Icons.waves, size: 12, color: AppColors.panelNavy),
              ),
              const SizedBox(width: 8),
              Text(
                'TOURISMAR',
                style: TextStyle(color: AppColors.textPrimary, fontWeight: FontWeight.w700, fontSize: 12, letterSpacing: 1.5),
              ),
              if (badgeText != null) ...[
                const SizedBox(width: 6),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                  decoration: BoxDecoration(
                    color: accentColor.withOpacity(0.15),
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
                  color: item.highlight ? accentColor.withOpacity(0.1) : Colors.transparent,
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
                          Text(
                            item.label,
                            style: TextStyle(
                              color: item.highlight ? color : AppColors.overlay(0.85),
                              fontSize: 14,
                              fontWeight: item.highlight ? FontWeight.w600 : FontWeight.w500,
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
          child: const ThemeToggleTile(),
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
