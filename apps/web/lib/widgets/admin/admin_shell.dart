import 'package:flutter/material.dart';

import '../../pages/login_page.dart';
import '../../services/auth_service.dart';
import '../../services/session_storage.dart';
import '../../theme/app_theme.dart';
import '../../theme/breakpoints.dart';
import '../user_avatar.dart';

/// Destinos disponibles en el sidebar del panel admin.
enum AdminSection { inicio, solicitudes, usuarios, negocios, admins, reportes, configuracion, ayuda }

void adminLogout(BuildContext context) {
  SessionStorage.clearToken();
  Navigator.of(context).pushAndRemoveUntil(
    MaterialPageRoute(builder: (_) => const LoginPage()),
    (route) => false,
  );
}

/// Shell persistente del panel admin: sidebar fijo + topbar en escritorio,
/// drawer + topbar compacto en pantallas angostas. A diferencia de [AppShell]
/// (usado por visitante/negocio), el contenido central se intercambia dentro
/// del mismo Scaffold en vez de empujar una pantalla completa nueva — así el
/// sidebar nunca se remonta al cambiar de sección.
class AdminShell extends StatefulWidget {
  final AuthUser admin;
  final AdminSection selected;
  final ValueChanged<AdminSection> onSelect;
  final Widget body;

  const AdminShell({
    super.key,
    required this.admin,
    required this.selected,
    required this.onSelect,
    required this.body,
  });

  @override
  State<AdminShell> createState() => _AdminShellState();
}

class _AdminShellState extends State<AdminShell> {
  final _scaffoldKey = GlobalKey<ScaffoldState>();
  bool _gestionExpanded = true;

  @override
  void initState() {
    super.initState();
    _gestionExpanded = _gestionSections.contains(widget.selected);
  }

  static const _gestionSections = {
    AdminSection.solicitudes,
    AdminSection.usuarios,
    AdminSection.negocios,
    AdminSection.admins,
  };

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final isDesktop = Breakpoints.isExpanded(constraints.maxWidth);
        return Scaffold(
          key: _scaffoldKey,
          backgroundColor: AppColors.bgDeep,
          drawer: isDesktop
              ? null
              : Drawer(
                  backgroundColor: AppColors.surfaceAlt,
                  width: 280,
                  child: _Sidebar(
                    admin: widget.admin,
                    selected: widget.selected,
                    gestionExpanded: _gestionExpanded,
                    onToggleGestion: () => setState(() => _gestionExpanded = !_gestionExpanded),
                    onSelect: (s) {
                      Navigator.of(context).pop();
                      widget.onSelect(s);
                    },
                  ),
                ),
          body: Stack(
            children: [
              const _AmbientBackground(),
              SafeArea(
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (isDesktop)
                      SizedBox(
                        width: 260,
                        child: _Sidebar(
                          admin: widget.admin,
                          selected: widget.selected,
                          gestionExpanded: _gestionExpanded,
                          onToggleGestion: () => setState(() => _gestionExpanded = !_gestionExpanded),
                          onSelect: widget.onSelect,
                        ),
                      ),
                    Expanded(
                      child: Column(
                        children: [
                          _Topbar(admin: widget.admin, isDesktop: isDesktop, scaffoldKey: _scaffoldKey, onSelect: widget.onSelect),
                          Expanded(
                            child: ClipRect(
                              child: AnimatedSwitcher(
                                duration: const Duration(milliseconds: 200),
                                switchInCurve: Curves.easeOut,
                                child: KeyedSubtree(key: ValueKey(widget.selected), child: widget.body),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

class _AmbientBackground extends StatelessWidget {
  const _AmbientBackground();

  @override
  Widget build(BuildContext context) {
    return Positioned.fill(
      child: IgnorePointer(
        child: Stack(
          children: [
            Positioned(
              top: -120,
              right: -80,
              child: _glow(AppColors.adminViolet, 320),
            ),
            Positioned(
              bottom: -140,
              left: -100,
              child: _glow(AppColors.oceanBlue, 300),
            ),
            Positioned(
              top: 240,
              left: 200,
              child: _glow(AppColors.brandTeal, 260),
            ),
          ],
        ),
      ),
    );
  }

  Widget _glow(Color color, double size) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: RadialGradient(
          colors: [color.withOpacity(0.10), color.withOpacity(0.0)],
        ),
      ),
    );
  }
}

class _NavLeaf {
  final AdminSection section;
  final IconData icon;
  final String label;
  const _NavLeaf(this.section, this.icon, this.label);
}

const _gestionItems = [
  _NavLeaf(AdminSection.solicitudes, Icons.report_gmailerrorred_outlined, 'Solicitudes'),
  _NavLeaf(AdminSection.usuarios, Icons.group_outlined, 'Usuarios'),
  _NavLeaf(AdminSection.negocios, Icons.apartment_outlined, 'Negocios'),
  _NavLeaf(AdminSection.admins, Icons.shield_outlined, 'Admins'),
];

class _Sidebar extends StatelessWidget {
  final AuthUser admin;
  final AdminSection selected;
  final bool gestionExpanded;
  final VoidCallback onToggleGestion;
  final ValueChanged<AdminSection> onSelect;

  const _Sidebar({
    required this.admin,
    required this.selected,
    required this.gestionExpanded,
    required this.onToggleGestion,
    required this.onSelect,
  });

  bool get _gestionActive => _gestionItems.any((i) => i.section == selected);

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        border: Border(right: BorderSide(color: AppColors.borderSubtle)),
      ),
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(AppSpacing.lg, AppSpacing.xl, AppSpacing.lg, AppSpacing.lg),
            child: Row(
              children: [
                Container(
                  width: 34,
                  height: 34,
                  decoration: const BoxDecoration(color: AppColors.adminViolet, shape: BoxShape.circle),
                  child: const Icon(Icons.waves, size: 18, color: AppColors.bgDeep),
                ),
                const SizedBox(width: AppSpacing.sm),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('TOURISMAR', style: AppTypography.h3.copyWith(letterSpacing: 1.2)),
                      Text('Sistema Turístico', style: AppTypography.caption),
                    ],
                  ),
                ),
              ],
            ),
          ),
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
              child: Column(
                children: [
                  _NavTile(
                    icon: Icons.home_outlined,
                    label: 'Inicio',
                    active: selected == AdminSection.inicio,
                    onTap: () => onSelect(AdminSection.inicio),
                  ),
                  _NavTile(
                    icon: Icons.dashboard_outlined,
                    label: 'Gestión',
                    active: _gestionActive,
                    expandable: true,
                    expanded: gestionExpanded,
                    onTap: onToggleGestion,
                  ),
                  AnimatedCrossFade(
                    duration: const Duration(milliseconds: 180),
                    crossFadeState: gestionExpanded ? CrossFadeState.showFirst : CrossFadeState.showSecond,
                    firstChild: Padding(
                      padding: const EdgeInsets.only(left: AppSpacing.lg),
                      child: Column(
                        children: _gestionItems
                            .map((item) => _NavTile(
                                  icon: item.icon,
                                  label: item.label,
                                  active: selected == item.section,
                                  dense: true,
                                  onTap: () => onSelect(item.section),
                                ))
                            .toList(),
                      ),
                    ),
                    secondChild: const SizedBox(width: double.infinity),
                  ),
                  _NavTile(
                    icon: Icons.bar_chart_outlined,
                    label: 'Reportes',
                    active: selected == AdminSection.reportes,
                    onTap: () => onSelect(AdminSection.reportes),
                  ),
                  _NavTile(
                    icon: Icons.settings_outlined,
                    label: 'Configuración',
                    active: selected == AdminSection.configuracion,
                    onTap: () => onSelect(AdminSection.configuracion),
                  ),
                  _NavTile(
                    icon: Icons.help_outline,
                    label: 'Ayuda',
                    active: selected == AdminSection.ayuda,
                    onTap: () => onSelect(AdminSection.ayuda),
                  ),
                ],
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(AppSpacing.lg),
            child: _FooterCallout(),
          ),
        ],
      ),
    );
  }
}

class _NavTile extends StatefulWidget {
  final IconData icon;
  final String label;
  final bool active;
  final bool dense;
  final bool expandable;
  final bool expanded;
  final VoidCallback onTap;

  const _NavTile({
    required this.icon,
    required this.label,
    required this.active,
    required this.onTap,
    this.dense = false,
    this.expandable = false,
    this.expanded = false,
  });

  @override
  State<_NavTile> createState() => _NavTileState();
}

class _NavTileState extends State<_NavTile> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    final color = widget.active ? AppColors.adminViolet : AppColors.slate300;
    return Padding(
      padding: const EdgeInsets.only(bottom: 2),
      child: MouseRegion(
        onEnter: (_) => setState(() => _hovered = true),
        onExit: (_) => setState(() => _hovered = false),
        cursor: SystemMouseCursors.click,
        child: Material(
          color: Colors.transparent,
          borderRadius: BorderRadius.circular(AppRadius.buttonLg),
          child: InkWell(
            onTap: widget.onTap,
            borderRadius: BorderRadius.circular(AppRadius.buttonLg),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 160),
              padding: EdgeInsets.symmetric(horizontal: AppSpacing.md, vertical: widget.dense ? 9 : 11),
              decoration: BoxDecoration(
                color: widget.active
                    ? AppColors.adminViolet.withOpacity(0.12)
                    : (_hovered ? Colors.white.withOpacity(0.04) : Colors.transparent),
                borderRadius: BorderRadius.circular(AppRadius.buttonLg),
              ),
              child: Row(
                children: [
                  AnimatedContainer(
                    duration: const Duration(milliseconds: 160),
                    width: 3,
                    height: 14,
                    decoration: BoxDecoration(
                      color: widget.active ? AppColors.adminViolet : Colors.transparent,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                  const SizedBox(width: AppSpacing.sm),
                  Icon(widget.icon, size: widget.dense ? 16 : 18, color: color),
                  const SizedBox(width: AppSpacing.sm),
                  Expanded(
                    child: Text(
                      widget.label,
                      style: TextStyle(
                        color: widget.active ? color : Colors.white.withOpacity(0.85),
                        fontSize: widget.dense ? 13 : 14,
                        fontWeight: widget.active ? FontWeight.w600 : FontWeight.w500,
                      ),
                    ),
                  ),
                  if (widget.expandable)
                    Icon(
                      widget.expanded ? Icons.expand_less : Icons.expand_more,
                      size: 16,
                      color: AppColors.slate400,
                    ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _FooterCallout extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(AppRadius.card),
        border: Border.all(color: AppColors.borderSubtle),
      ),
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          Positioned(
            right: -6,
            bottom: -10,
            child: Opacity(
              opacity: 0.08,
              child: Icon(Icons.landscape, size: 64, color: AppColors.brandTeal),
            ),
          ),
          Text(
            'Impulsando el turismo de nuestro destino',
            style: AppTypography.bodySmall.copyWith(height: 1.4),
          ),
        ],
      ),
    );
  }
}

class _Topbar extends StatelessWidget {
  final AuthUser admin;
  final bool isDesktop;
  final GlobalKey<ScaffoldState> scaffoldKey;
  final ValueChanged<AdminSection> onSelect;

  const _Topbar({required this.admin, required this.isDesktop, required this.scaffoldKey, required this.onSelect});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.xl, vertical: AppSpacing.md),
      decoration: const BoxDecoration(
        border: Border(bottom: BorderSide(color: AppColors.borderSubtle)),
      ),
      child: Row(
        children: [
          if (!isDesktop) ...[
            IconButton(
              onPressed: () => scaffoldKey.currentState?.openDrawer(),
              icon: const Icon(Icons.menu, color: AppColors.slate300),
            ),
            const SizedBox(width: AppSpacing.xs),
          ],
          if (isDesktop)
            Expanded(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 360),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md, vertical: 9),
                  decoration: BoxDecoration(
                    color: AppColors.surface,
                    borderRadius: BorderRadius.circular(AppRadius.buttonLg),
                    border: Border.all(color: AppColors.borderSubtle),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.search, size: 16, color: AppColors.slate400),
                      const SizedBox(width: AppSpacing.sm),
                      Text('Buscar en el sistema...', style: AppTypography.bodySmall),
                    ],
                  ),
                ),
              ),
            )
          else
            const Spacer(),
          const SizedBox(width: AppSpacing.md),
          Stack(
            clipBehavior: Clip.none,
            children: [
              const Icon(Icons.notifications_none, color: AppColors.slate300),
              Positioned(
                right: -1,
                top: -1,
                child: Container(
                  width: 8,
                  height: 8,
                  decoration: const BoxDecoration(color: AppColors.orange, shape: BoxShape.circle),
                ),
              ),
            ],
          ),
          const SizedBox(width: AppSpacing.lg),
          _AvatarMenu(admin: admin, onSelect: onSelect),
        ],
      ),
    );
  }
}

class _AvatarMenu extends StatelessWidget {
  final AuthUser admin;
  final ValueChanged<AdminSection> onSelect;

  const _AvatarMenu({required this.admin, required this.onSelect});

  @override
  Widget build(BuildContext context) {
    return PopupMenuButton<String>(
      color: AppColors.surfaceAlt,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppRadius.buttonLg),
        side: const BorderSide(color: AppColors.borderSubtle),
      ),
      offset: const Offset(0, 44),
      onSelected: (value) {
        if (value == 'logout') {
          adminLogout(context);
        } else if (value == 'config') {
          onSelect(AdminSection.configuracion);
        }
      },
      itemBuilder: (context) => [
        PopupMenuItem(
          value: 'config',
          child: Row(
            children: const [
              Icon(Icons.settings_outlined, size: 16, color: AppColors.slate300),
              SizedBox(width: 10),
              Text('Configuración', style: TextStyle(color: Colors.white, fontSize: 13)),
            ],
          ),
        ),
        PopupMenuItem(
          value: 'logout',
          child: Row(
            children: const [
              Icon(Icons.logout, size: 16, color: AppColors.errorRed),
              SizedBox(width: 10),
              Text('Cerrar sesión', style: TextStyle(color: AppColors.errorRed, fontSize: 13)),
            ],
          ),
        ),
      ],
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          UserAvatar(imageUrl: admin.avatarUrl, fallbackLetter: admin.name, radius: 16, color: AppColors.adminViolet),
          const SizedBox(width: AppSpacing.sm),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(admin.name,
                  style: const TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.w600)),
              Text(admin.isSuperAdmin ? 'Super administrador' : 'Administrador', style: AppTypography.caption),
            ],
          ),
          const SizedBox(width: 4),
          const Icon(Icons.keyboard_arrow_down, size: 16, color: AppColors.slate400),
        ],
      ),
    );
  }
}
